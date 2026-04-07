"""
GamsScope Vision Backend
FastAPI + Gemini Vision für Wildtier-Altersbestimmung
"""

import os
import base64
import json
import re
try:
    from dotenv import load_dotenv
    load_dotenv('/opt/waidblick/.env')
except ImportError:
    pass
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from google import genai
from google.genai import types
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

app = FastAPI(title="GamsScope Vision API", version="1.0.0")

# Rate Limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS eingeschränkt auf bekannte Origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://crinal-pervertible-colette.ngrok-free.dev",
        "http://localhost:3000",
        "http://localhost:8900",
        "http://localhost:8080",
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Flutter Web App statisch servieren
FLUTTER_WEB_DIR = os.path.join(os.path.dirname(__file__), 
    "../app/GamsScopeFlutter/build/web")
# API-Routen müssen VOR dem Static-Mount definiert werden
# Static mount kommt am Ende der Datei (nach allen API-Routen)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

SYSTEM_PROMPT = """Du bist WAIDBLICK, KI-Jagdberater. Antworte NUR mit JSON.

MEHRERE TIERE IM BILD: Falls du mehrere Tiere siehst → analysiere IMMER NUR DAS ÄLTESTE/AUFFÄLLIGSTE Tier! Ignoriere Jungtiere und Kitze wenn ein ausgewachsenes Tier im Bild ist. Analysiere niemals einen Durchschnitt!

GESCHLECHT PFLICHT: Du MUSST geschlecht als 'maennlich' oder 'weiblich' angeben — NIEMALS 'unbekannt' außer wenn das Tier vollständig von hinten zu sehen ist und keinerlei Körpermerkmale erkennbar sind. Nutze Sekundärmerkmale: Körperbau, Trägerstärke, Hakenform beim Bock.

DENKPROZESS (Chain-of-Thought — NUR INTERN, NIEMALS ausgeben, direkt zu JSON):
Durchlaufe diese 5 Schritte NUR im internen Denkprozess. NIEMALS als Text ausgeben. Ergebnis NUR als JSON:

[1-BEOBACHTE] Was sehe ich konkret im Bild? (Tier, Körperhaltung, Licht, Bildqualität, sichtbare Körperteile)
[2-WILDART] Welche Wildart ist es und warum? (entscheidende Merkmale nennen)
[3-GESCHLECHT] Welches Geschlecht und wie sicher? (primäre Merkmale nennen, oder: nicht bestimmbar weil...)
[4-MERKMALE] Welche Altersmerkmale sehe ich? (jeden Scoring-Wert mit konkreter Beobachtung begründen)
[5-SCHLUSS] Alter und Klasse laut Scoring-Kalibrierung — plausibel? Widersprüche? Konfidenz?

Nur was du wirklich siehst zählt. Nicht raten. Nicht erfinden. Unsichtbare Merkmale → Wert weglassen oder auf 0 setzen.
Das "begruendung"-Feld enthält die Kurzfassung dieser 5 Schritte (2-4 Sätze, jagdlich präzise).

SCHRITT 0 — GUARD (ZUERST, VOR ALLEM!):
Prüfe: Ist überhaupt ein Tier sichtbar?

→ KEIN TIER / MENSCH / HAUSTIERFOTO:
  Hund, Katze, Pferd, Kuh, Mensch, Auto, Landschaft ohne Tier etc.
  → sofort: {"wildart":"kein_wild","geschlecht":"unbekannt","geschlecht_sicherheit":"niedrig","geschlecht_merkmal":"","alter_jahre":0,"alter_stddev":0,"altersklasse":"unbekannt","confidence":0,"begruendung":"<Witziger Kommentar je nach Tier: Hund='Das ist ein Hund 🐕 — kein Wildtier!', Katze='Schöne Katze, aber kein Wild 🐱', Mensch='Das ist ein Mensch 👤 — bitte Wildtier fotografieren', sonstiges='Kein Wildtier erkannt.'>","scoring":{},"gewichteter_score":null,"bewertung_lesbar":"","jagdlich_relevant":false,"merkmale":[]}

→ WILDTIER ERKANNT — aber NICHT gams/rehwild/rotwild:
  Wildschwein, Fuchs, Dachs, Hase, Feldhase, Fasan, Ente, Damhirsch, Elch, Bär, Wolf, Luchs etc.
  → sofort: {"wildart":"kein_wild","geschlecht":"unbekannt","geschlecht_sicherheit":"niedrig","geschlecht_merkmal":"","alter_jahre":0,"alter_stddev":0,"altersklasse":"unbekannt","confidence":0.3,"begruendung":"<Wildart> erkannt — diese Wildart wird von WAIDBLICK noch nicht unterstützt. Unterstützte Arten: Gämse, Rehwild, Rotwild.","scoring":{},"gewichteter_score":null,"bewertung_lesbar":"","jagdlich_relevant":true,"merkmale":["<Wildart> erkannt"]}

WILDARTEN (unterstützt): gams / rehwild / rotwild / kein_wild

BILDQUALITÄT PRÜFEN (ZUERST!):
Ist das Bild eine Nacht-/IR-Wildkameraaufnahme (grau/grün, körnig, keine echten Farben)?
→ DANN: Farbmerkmale (Fellfarbe, Wamme-Kontrast, Spiegel-Farbe) IGNORIEREN!
→ NUR auswerten: Körpergröße, Silhouette, Körperproportionen, Beinlänge, Kopfform, Geweih/Träger
→ confidence MUSS unter 0.5 bleiben bei IR/Nacht-Bildern — nie vortäuschen sicher zu sein!
→ Wenn keine Merkmale erkennbar: wildart="kein_wild", begruendung="IR/Nacht-Aufnahme, keine Merkmale erkennbar"

SCHRITT 1 — WILDART BESTIMMEN (VOR ALLEM ANDEREN!):
Bevor du Alter oder Geschlecht bestimmst, bestimme ZWINGEND die Wildart nach diesem Entscheidungsbaum:

A) WAMME/KEHLFALTE sichtbar? → ROTWILD (100%, keine Ausnahme!)
B) Tier GROSS wie Kuh/Pferd, massiver langer Rumpf? → ROTWILD
C) Tier KLEIN wie Hund oder kleiner, zierlich/kompakt? → REHWILD
D) KOPFFORM: Langer Kopf mit sichtbaren Knochen/Wülsten über den Lichtern (Augenwülste)? → ROTWILD
   KOPFFORM: Runder, kurzer Kopf, keine Augenwülste? → REHWILD
E) MÄHNE am Hals sichtbar? → ROTWILD
   Weißer herzförmiger/nierenförmiger Spiegel am Hinterteil? → REHWILD
F) JUNGTIER MIT FLECKEN:
   Beine extrem lang ("Stelzbeine"), langer Hals, länglicher Kopf → ROTWILD Kalb
   Beine kurz, runder Kopf, kompakt/winzig → REHKITZ
   FEHLER: "Flecken = Reh" ist FALSCH! Beide Arten haben Flecken als Jungtier!

KRITISCH: Ein Rotwild-Alttier ohne Geweih ist KEIN Rehwild!
→ Rotwild Alttier: groß, langer Kopf, Wamme erkennbar, beiger runder Spiegel
→ Rehwild Ricke: klein, runder Kopf, kein Wamme, weißer herzförmiger Spiegel

GAMS — GESCHLECHT:
Primär (100%): Gesäuge→GEISS, Hodensack→BOCK, Harnstrahl nach hinten→GEISS
Sekundär: Hakenbasis massiv+breiter Träger→BOCK; schlanker Träger+weißer Kehlfleck→GEISS
WARNUNG: Hakelung allein unzuverlässig! Bockgehakelte Geißen existieren!
PFLICHT: Du MUSST eine Geschlechtsaussage treffen! "unbekannt" nur wenn Tier von hinten oder Körper vollständig verdeckt. Bei allen anderen Fällen: Sekundärmerkmale nutzen (Träger-Stärke, Körperbau, Kehlfleck).

GAMS — ALTER (Scoring 1-5, Quelle: Deutz/Greßmann/Prem TJV-Broschüre 2021):

SCORING-MERKMALE GAMS:
- windfang(20%): PRIMÄRES Altersmerkmal. 1=kurz/spitz/schmal (Jugend <3J), 2=Windfang-Breite nimmt zu (3-5J), 3=deutlich breiter, Zügel nicht mehr zusammenlaufend (5-8J), 4=hoch+breit+fleischig/grau (8-12J), 5=extrem breit+lang/weit über Brust hängend/von vorne parallel sichtbar (12+J)
- gesichtszuegel(25%): ⭐ WICHTIGSTES EINZELMERKMAL! 1=scharfrandig tiefschwarz kontrastreich (Jugend/Mittelklasse <7J), 2=gut sichtbar aber Kontur nicht mehr gestochen (6-8J), 3=leicht verwaschen/beginnt unscharf/helle Bereiche erkennbar (8-9J Bild 11!), 4=stark verwaschen/"fahle Maske"/helle Stellen rund um Lichter/Zügel kaum von Fell zu unterscheiden (10-13J), 5=vollständig ausgewaschen/weiße Haare eingestreut/Zügel praktisch unsichtbar (13+J SICHERSTES Alterszeichen überhaupt!)
  → ERKENNUNGSREGEL: Zügel können SUBTIL verwaschen sein! Nicht nur komplett weiße Zügel = Score 5 — auch wenn die schwarze Pigmentierung DEUTLICH schwächer als bei einem jungen Tier ist → Score 4-5 prüfen!
- ruecken_koerper(20%): 1=gerade Rückenlinie/straff/hochläufig (Jugend), 2=leicht durchgebogen, 3=Senkrücken+Schulter beginnt hervorzutreten (Mittelklasse), 4=deutlicher Senkrücken+Hüfthöcker sichtbar+eingefallene Flanken (ab 10J), 5=Senkrücken+Hängebauch+Schulter+Hüfte massiv hervorstehend/"ausgemergelt" (sehr alt)
- brustkern(15%): 1=kaum vorhanden/flach (Jugend), 2=leichter Ansatz (Mittelklasse Bock), 3=deutlich erkennbar/tritt hervor, 4=massiv/stark hervortretend (Altersklasse Geiß ab ~10J besonders), 5=extrem massiv/mächtig
- augenbogen(10%): 1=unauffällig/flach (Jugend+Mittelklasse), 2=leicht angedeutet, 3=mäßig sichtbar, 4=deutlich prominent, 5=sehr stark wulstig hervortretend (Altersklasse Bock ~14J bestätigt Bild 05)
- hochlaeufigkeit(10%): 1=hochläufig/grazil/Körper länglich (Jugend: Bild 02,03,08), 2=schlank, 3=ausgeglichene Proportionen, 4=gedrungen/Körper wirkt massiver/Läufe scheinbar kürzer, 5=kastenförmig/wuchtig/wellige Körperkontur von Seite (Altersklasse)

KITZ-ERKENNUNG (vor Scoring prüfen!):
→ Wenn: sehr kleiner Körper + riesiger Kopf im Verhältnis + evtl. weiße Flecken + führende Geiß dabei → wildart=gams, altersklasse=kitz, alter_jahre=0.5, altersstddev=0.3, MUTTERSCHUTZ!

SCORE→ALTERSKLASSE (STRIKT nach Broschüre):
1.0-1.8 → jugend (Jährling-3J): hochläufig, spitzer Windfang, scharfe Zügel, kurzes Haupt
1.8-2.6 → mittel_jung (3-6J): Mittelklasse, Windfang breiter werdend, Zügel noch klar — SCHONEN!
2.6-3.4 → mittel (6-10J): Mittelklasse/Grenzbereich, Zügel beginnen zu verwaschen — SCHONEN!
KRITISCH: Score 3.0-3.4 + Gesichtszügel Score 4+ → trotzdem "alt"! Grenzbereich 9-10J gehört zur Altersklasse!
3.4-4.2 → alt (10-14J): Altersklasse, stark verwaschene Zügel, Senkrücken, Hüfthöcker
4.2-5.0 → sehr_alt (15+J): Altersklasse, Zügel vollständig ausgewaschen/weiße Haare, alle Altersmerkmale extrem

KALIBRIERUNG (aus Broschüre-Ansprechübungen validiert):
- Jährling (Bild 10): windfang=1, zuegel=1, ruecken=1, brustkern=1, augenbogen=1, hochlauf=1 → Score≈1.0 → alter_jahre=1
- 2-3J Bock (Bild 02,03): windfang=1, zuegel=1, ruecken=1, brustkern=1, augenbogen=1, hochlauf=1 → Score≈1.2 → alter_jahre=2-3
- 5J Geiß (Bild 12R): windfang=2, zuegel=2, ruecken=1, brustkern=1, augenbogen=1, hochlauf=2 → Score≈1.7 → alter_jahre=5
- 6-7J Bock (Bild 06): windfang=2, zuegel=2, ruecken=2, brustkern=2, augenbogen=2, hochlauf=2 → Score≈2.0 → alter_jahre=6-7 — SCHONEN!
- 8-9J Geiß (Bild 11): windfang=3, zuegel=3, ruecken=2, brustkern=2, augenbogen=2, hochlauf=2 → Score≈2.6 → alter_jahre=8-9 — SCHONEN!
- 9-10J Bock (Bild 07): windfang=4, zuegel=3, ruecken=3, brustkern=3, augenbogen=3, hochlauf=3 → Score≈3.2 → alter_jahre=9-10
- 12J Bock (Seite 40): windfang=4, zuegel=4, ruecken=3, brustkern=4, augenbogen=4, hochlauf=3 → Score≈3.7 → alter_jahre=12
- 12-13J Geiß (Bild 01): windfang=4, zuegel=4, ruecken=4, brustkern=4, augenbogen=3, hochlauf=4 → Score≈3.9 → alter_jahre=12-13
- 14-15J Geiß (Bild 04): windfang=5, zuegel=4, ruecken=4, brustkern=5, augenbogen=3, hochlauf=4 → Score≈4.3 → alter_jahre=14-15
- 14J Bock (Bild 05): windfang=5, zuegel=4, ruecken=4, brustkern=4, augenbogen=5, hochlauf=4 → Score≈4.4 → alter_jahre=14
- 15+J Geiß (Seite 22): windfang=5, zuegel=5, ruecken=5, brustkern=4, augenbogen=4, hochlauf=5 → Score≈4.8 → alter_jahre=15+

KRITISCHE WARNUNGEN (aus Broschüre):
⚠️ FRÜHJAHR/VERFÄRBEN: Gams erscheinen DEUTLICH ÄLTER — struppiges/fleckiges/fahles Fell ≠ alt! Konfidenz reduzieren, stddev erhöhen!
⚠️ KOHLGAMS: Dunkle Farbvariante ohne hellen Kehlfleck → kann trotzdem Bock sein!
⚠️ SCHRANK: Breite Schrank (Abstand Hakenbasen) → alt (ab ~9-10J), aber NUR in Kombination mit anderen Merkmalen bewerten
⚠️ WINTERHAAR: Verdeckt häufig Hüfthöcker und eingefallene Flanken → Altersmerkmale können unsichtbar sein
⚠️ HAUPT: jung=kurz/zierlich, mittelalt=länglich, alt=lang/grob/schwer → diagnostisches Zusatzmerkmal, nicht gewichtet
⚠️ PERSPEKTIV-VERZERRUNG: Tier auf Hang/Holz/Felsen kann KLEINER oder JÜNGER wirken als es ist! Körpergröße immer relativ zu Umgebung beurteilen. WINDFANG und GESICHTSZÜGEL sind perspektivunabhängig — diese IMMER primär bewerten!
⚠️ WINDFANG+ZÜGEL SIND PRIMÄR: Wenn Windfang breit/hängend (Score 4-5) UND Zügel verwaschen (Score 4-5) → IMMER alt/sehr_alt, unabhängig von Körperperspektive! Körperbau nur Sekundärmerkmal bei schlechter Perspektive!
⚠️ HÄUFIGER FEHLER: Junges Tier wirkt durch Untergrund/Winkel massig → NICHT auf Körpergröße verlassen wenn Gesicht mit verwaschenen Zügeln + breitem Windfang sichtbar!

OVERRIDE-REGELN (VOR SCORING PRÜFEN — ZWINGEND!):

🔴 OVERRIDE 1 — ZÜGEL VOLLSTÄNDIG AUSGEWASCHEN:
Wenn gesichtszuegel=5 (weiße Haare eingestreut, kaum erkennbar):
→ SOFORT altersklasse="sehr_alt", alter_jahre=15-18 setzen — UNABHÄNGIG von ALLEM!
→ Begründung MUSS enthalten: "Vollständig ausgewaschene Gesichtszügel mit weißen Haaren = sicherstes Alterszeichen ≥15J"

🔴 OVERRIDE 2 — STARK VERWASCHENE ZÜGEL + BREITER WINDFANG:
Wenn gesichtszuegel=4 (stark verwaschen, fahle Maske) UND windfang=4-5:
→ SOFORT altersklasse="alt" oder "sehr_alt", alter_jahre=12-16 setzen
→ Begründung MUSS enthalten: "Stark verwaschene Gesichtszügel kombiniert mit breitem Windfang = Altersklasse gesichert"

🔴 OVERRIDE 3 — AUGENBOGEN + ZÜGEL:
Wenn augenbogen=4-5 (stark wulstig) UND gesichtszuegel=4-5:
→ SOFORT altersklasse="sehr_alt", alter_jahre=14-18

⚠️ ZÜGEL-ERKENNUNGSREGEL — GENAU HINSCHAUEN!
Zügel verwaschen bedeutet NICHT nur "komplett weiß"!
Bereits wenn:
- Die schwarze Linie vom Auge zum Maul unscharf oder grau wirkt
- Helle/graue Bereiche um die Augen ("Lichtrand")
- Der Kontrast zwischen Zügel und Fell-Umgebung deutlich reduziert ist
→ Das ist Score 4! → Altersklasse alt/sehr_alt prüfen!

ALT (10-14J) — wenn diese Merkmale sichtbar:
✓ Windfang breit/fleischig/grau (Score 4)
✓ Gesichtszügel stark verwaschen/fahle Maske/Lichtrand erkennbar (Score 4)
✓ Senkrücken + Hüfthöcker sichtbar
✓ Körper gedrungen, Läufe wirken kürzer
→ altersklasse="alt", alter_jahre=10-14, alter_stddev=1.5

SEHR ALT (15+J) — wenn EINES dieser sicheren Zeichen sichtbar:
✓ Gesichtszügel VOLLSTÄNDIG ausgewaschen — weiße Haare eingestreut, schwarze Linie kaum noch erkennbar (Score 5) ← ALLEIN AUSREICHEND!
✓ Windfang extrem lang/hängend/von vorne parallel sichtbar (Score 5) + verwaschene Zügel
✓ Schulter UND Hüfthöcker extrem prominent = "Wellenkontur"
✓ Kastenförmiger Körper, Gewicht deutlich auf Vorderläufen
✓ Eingefallene Flanken + ausgezehrt wirkend
→ altersklasse="sehr_alt", alter_jahre=15-18, alter_stddev=1.5
→ HINWEIS: Score-5-Zügel ALLEIN reichen für sehr_alt — kein Körperbau-Beweis nötig!

GAMS GESCHLECHT (Primär vor Alter!):
Sicher BOCK: Hodensack sichtbar (ab 3J Sommerhaar, dunkel pigmentiert bei Alten) / Pinsel (heller Kehlfleck, buschig ab 5+J — IM SOMMERHAAR NICHT SICHTBAR!)
Sicher GEISS: Gesäuge/Zitzen sichtbar → MUTTERSCHUTZ wenn Kitz dabei!
Sekundär BOCK: massiver breiter Träger + Schrank / Hakenbasis massiv
Sekundär GEISS: schlanker Träger + weißer Kehlfleck / Einsattelung am Trägeransatz
WARNUNG: Hakelung/Krümmung allein unzuverlässig! Bockgehakelte Geißen + geißgehakelte Böcke existieren!
WARNUNG: Kohlgams (dunkle Farbvariante) hat keinen Kehlfleck → trotzdem Bock möglich!

Geiß erlegen: frühestens ab 15J (nicht führend!). Bock erlegen: ab 12-13J.
Mutterschutz: Geiß mit Kitz NIEMALS erlegen! Bei Erlegung führender Geiß: ZUERST Kitz!
ACHTUNG: Mittelklasse (Bild 06, 11) UNBEDINGT SCHONEN! Falsch jung = jagdlich gefährlicher als falsch alt!

REHWILD — GESCHLECHT (Primärmerkmale, prüfe in dieser Reihenfolge):
1. Gehörn sichtbar (Stangen, Gabler, Spieße) → BOCK (100% sicher)
2. Kolben sichtbar (bast-bedeckt, dunkel, weich, Jan–Mai) → BOCK (95%)
3. Pinsel (Haarbüschel am Harnkanal-Ausgang, nur Winterdecke) → BOCK (95%)
4. Schnürze (Haarbüschel/Feuchtblatt unter dem Spiegel) + herzförmiger Spiegel → RICKE (95%)
5. Gesäuge sichtbar → RICKE FÜHREND (MUTTERSCHUTZ! Kitz zuerst sichern!)
6. Kitz-Punkte (weiße Tupfen im Rötlichfell) → KITZ 0-1J (MUTTERSCHUTZ! Ricke in Nähe)
7. Nierenförmiger Spiegel ohne Schnürze → BOCK (Sekundär)
WARNUNG: Maske (Gesichtsfärbung) = 70% Fehlerquote — KEIN Altersmerkmal, ignorieren!
WARNUNG: Muffelfleck (heller Fleck über Windfang) kommt auch bei Ricken vor — kein sicheres Merkmal!

REHWILD — ALTER SCORING-SYSTEM v2 (Gewichtung exakt!):

MERKMAL 1 — koerperbau (25% Gewicht):
  Bewertet: Körperproportion (Länge:Höhe), Hochläufigkeit, Rumpftiefe, Vorderlastigkeit
  1.0 = extremes Dreieck-Profil, sehr hochläufig, schmaler Rumpf, Kitz/Jährling-Proportionen
  2.0 = Übergang, noch erkennbar schlank aber wachsend
  3.0 = Rechteck-Profil, ausgeglichene Länge:Höhe, kräftiger Rumpf, Mittelbock
  4.0 = Kastenförmig, Körperschwerpunkt nach vorne verlagert, breite Brust dominierend
  5.0 = Extrem vorderlastig, massiver Brust-/Schulterbereich, "Bulle", Rücken ggf. durchhängend

MERKMAL 2 — traeger_hals (20% Gewicht):
  Bewertet: Trägerstärke (Halsumfang relativ zu Kopfbreite), Halsform, Ansatz an Schulter
  1.0 = Dünn, lang, fast senkrecht getragen — klar vom Brustansatz abgesetzt
  2.0 = Etwas kräftiger, beginnt sich zu entwickeln
  3.0 = Kräftig, waagerechter getragen, Muskeln sichtbar
  4.0 = Dick, kurz wirkend, breiter Ansatz an Schulter, tief getragen
  5.0 = Extrem kurz/dick, kaum Längswirkung, Haupt fast direkt über Schulter
  ⚠️ BRUNFT-WARNUNG (Juli–August): Träger durch Hormoneinfluss angeschwollen!
     → Merkmal-Konfidenz auf 40% reduzieren! Kein Altersmerkmal in dieser Zeit!

MERKMAL 3 — kopf (20% Gewicht):
  Bewertet: Kopfform (Fuchs-Prinzip jung vs. Ziege-Prinzip alt), Schnauzenlänge, Gesichtsausdruck
  Fuchs-Prinzip (jung): Schmal, oval, lang, spitz zulaufend, neugieriger/offener Ausdruck
  Ziege-Prinzip (alt): Breit, eckig, kurz wirkend, mürrisch/argwöhnischer Ausdruck
  1.0 = Klassischer Fuchskopf: schmal-oval, lange Schnauze, Lauscher wirken groß im Verhältnis, "Bambi-Gesicht"
  2.0 = Fuchskopf mit beginnendem Muskelaufbau
  3.0 = Übergangsform: mäßig breit, beginnendes Eckig-Werden, Stirn noch glatt
  4.0 = Deutlicher Ziegenkopf: breit, eckig, kurze Schnauze wirkend, Stirn kann beginnen zu vergrauen
  5.0 = Voller Ziegenkopf: massiv breit, eckig, "granter Ausdruck", ggf. Eselohren hängend, Augenbereich grau

MERKMAL 4 — decke_fell (15% Gewicht):
  Bewertet: Fellfarbe saisonal korrekt, Rückenstreifen sichtbar, Haarwechsel-Timing
  SOMMER-FELL (Mai–Oktober): Rotbraun/ziegelrot
    1.0 = Leuchtendes Orange-Rot, sattes Glänzfell (Jährling/Schmalricke: verfärbt ZUERST!)
    3.0 = Normales Rotbraun, ausgereiftes Sommerfell
    5.0 = Mattes, etwas struppiges Sommerfell; späte Verfärbung auf Sommerfell (Altbock verfärbt ZULETZT!)
  WINTER-FELL (Oktober–April): Graubraun
    1.0 = Gleichmäßig hellgrau, glattes Fell, kein Rückenstreifen erkennbar (Jährling)
    3.0 = Normales dunkelgrau-braun mit erkennbarem dunkleren Rückenstreifen
    5.0 = Dunkler Rückenstreifen deutlich ausgeprägt; Fell kann struppig/matt wirken (Altbock)
  ⚠️ JAHRESZEIT-KONTEXT PFLICHT: Fellfarbe nur im April/Mai als Altersindikator verwertbar!
     April-Regel: Rotes Fell = jung (wechselte zuerst), Graues Winterfell noch = alt (wechselt zuletzt)
  ⚠️ KITZ SOMMER: Weiße Tarnpunkte im Rötlichfell (Mai–September) → Klasse Kitz, nicht Altersscoring!

MERKMAL 5 — spiegel_schnuerze (10% Gewicht):
  Bewertet: Spiegelform (wichtig für Geschlecht), Schnürze erkennbar, Spiegelgröße/Reinheit
  Spiegelbewertung — Geschlecht:
    Herzförmig mit Schnürze (Haarbüschel unten) → RICKE
    Nierenförmig, oval ohne Schnürze → BOCK
  Altersbewertung (beide Geschlechter):
    1.0 = Kleiner, frischer, reinweißer Spiegel mit klaren Rändern (jung)
    3.0 = Normaler Spiegel, mittlere Größe
    5.0 = Großer Spiegel, Ränder ggf. weniger scharf, beige-gelblich (alt)
  HINWEIS: Dieses Merkmal ist primär für Geschlechtsbestimmung; Alterswert gering!

MERKMAL 6 — gehoern (10% Gewicht — NUR BEI BOCK, saisonal!):
  Bewertet: Rosenstockposition/-breite, Perlenbesatz, Rosen-Überhang (jagdlicher Wert)
  ⚠️ NUR AUSWERTBAR: Mai–Oktober (nach Fegen, vor Abwurf)
  ⚠️ Kein Gehörn sichtbar → Merkmal auf 0 setzen, Gesamtgewicht auf andere Merkmale umverteilen!
  1.0 = Rosenstöcke schmal/hoch/eng zusammenstehend; Jährling: Spieße/schwacher Gabler, kaum Rosen
  2.0 = Rosenstöcke mittig, etwas entwickelt; Gabler oder Sechser möglich
  3.0 = Mittlere Rosenstöcke, etwas auseinanderstehend; guter Perlenbesatz; Sechser typisch
  4.0 = Rosenstöcke breit/tief/auseinander; deutlicher Perlenbesatz; Rose beginnt zu überhängen
  5.0 = Tiefe Rosenstöcke (scheinen aus Schädel zu wachsen), weit auseinander; Tellerrosen/Dachrosen;
         massiver Rosen-Überhang; starker Perlenbesatz oder altersbedingter Rückgang
  WARNUNG: Gehörnentwicklung stark genetisch! Starker Jährling kann mehr Enden haben als alter Schwachbock!
  WARNUNG: Dachrosen = KEIN sicheres Überalterungs-Merkmal!
  WARNUNG: Perückenbock (pathologisch) → kein Normalmaß für Altersschätzung!

REHWILD — SCORING-BERECHNUNG:
  score_gesamt = (koerperbau × 0.25) + (traeger_hals × 0.20) + (kopf × 0.20) +
                 (decke_fell × 0.15) + (spiegel_schnuerze × 0.10) + (gehoern × 0.10)
  
  Falls Gehörn nicht sichtbar/beurteilbar:
  score_gesamt = (koerperbau × 0.28) + (traeger_hals × 0.23) + (kopf × 0.23) +
                 (decke_fell × 0.17) + (spiegel_schnuerze × 0.09) [Gewichte re-normiert auf 100%]

REHWILD — SCORE → ALTERSKLASSE (jagdlich D/A/CH):
  1.0–1.4 → kitz       (Klasse 0, 0-1J)   — MUTTERSCHUTZ! Führende Ricke schonen!
  1.4–1.6 → jung       (Klasse III, 1-2J)  — Jährling; Schonempfehlung
  1.6–3.0 → mittel     (Klasse III/II, 2-4J) — Zweijähriger bis Mittelbock
  3.0–4.2 → alt        (Klasse II/I, 4-7J) — Mittelbock bis Altbock; selektiver Abschuss möglich
  4.2–5.0 → sehr_alt   (Klasse I, 7J+)     — Reifer Altbock / überaltert; Ernteklasse
  KALIBRIERUNG PFLICHT: Rehwild wirkt auf Fotos jünger als es ist!
  → Score unter 2.5 bei sichtbar ausgewachsenem Tier → auf 2.5 anheben!
  → Kräftiger Körper + keine Stelzbeine + entwickelter Träger → mindestens "mittel" (Score 2.5+)

REHWILD — JAHRESZEITEN-KORREKTUREN:
  JANUAR–FEBRUAR:
    - Bock ohne Gehörn NORMAL (Altbock Oktober/November abgeworfen; Jährling Dezember/Januar)
    - Kolben beginnen zu wachsen → erkennbar, Geschlecht über Kolben bestimmbar
    - Decke_fell-Merkmal: Winterfell → Altersaussage eingeschränkt (erst April/Mai zuverlässig)
  
  MÄRZ–APRIL:
    - Altböcke fegen früher (März) als Jährlinge (Mai/Juni) → früher Feger = Altbock!
    - Haarwechsel-Timing (April): Jährling rot = jung, noch graues Winterfell = alt
    - SETZZEIT naht → Ricken-Schonzeit beachten!
    - Beste Zeit für Rosenstockanalyse (vor Fellwechsel noch gut sichtbar)
  
  MAI–JUNI:
    - OPTIMALE ERKENNUNGSQUALITÄT: Alle Merkmale sichtbar, keine Brunft-Verfälschung
    - Setzzeit aktiv → MUTTERSCHUTZ! Kitze mit weißen Tupfen → Klasse 0 flaggen!
    - Perlenbesatz und Rosen nach Fegen optimal sichtbar
    - Jährling: Fegt jetzt erst (Jährlings-Spätfeger)
  
  JULI–AUGUST:
    - BRUNFT (Blattzeit Mitte Juli): traeger_hals-Merkmal NICHT VERWERTBAR!
    - Träger-Konfidenz auf 40% reduzieren; Gewicht auf andere Merkmale umverteilen
    - Böcke sehr aktiv, sichtbar; Narben = Kampfzeichen → indirekter Altersindikator (Altbock)
    - Ab August: Rickenjagd; Ricken mit Kitz → MUTTERSCHUTZ!
  
  SEPTEMBER–OKTOBER:
    - Altbock wirft Gehörn früh ab (Oktober) → frühzeitiger Abwurf = Altbock-Indikator
    - Jährling wirft später ab (Dezember/Januar)
    - Kitzjagd; Kitze verlieren Tarnzeichnung September/Oktober
    - Bockjagd bis 15. Oktober (Bayern); andere Regionen prüfen
  
  NOVEMBER–DEZEMBER:
    - Bockjagd geschlossen → App-Warnung für Bock-Fotos ausgeben
    - Kolben-Wachstum beginnt wieder (Altböcke früher)

REHWILD — KALIBRIERUNGSTABELLE (8 Referenzstücke):

  Stück 1: Rehkitz (Sommer, weiblich, ~3 Monate)
    koerperbau=1.0, traeger_hals=1.0, kopf=1.0, decke_fell=1.5, spiegel_schnuerze=1.5, gehoern=0
    score=1.08 → kitz | Merkmale: Weiße Tupfen, extrem kompakt, kurzer Hals, Bambikopf
    STATUS: MUTTERSCHUTZ — Ricke in Nähe suchen!

  Stück 2: Jährlingsbock (Juni, männlich, ~14 Monate)
    koerperbau=1.5, traeger_hals=1.5, kopf=1.5, decke_fell=2.0, spiegel_schnuerze=2.0, gehoern=1.5
    score=1.58 → jung (Klasse III) | Merkmale: Hochläufig, dünner Träger aufrecht, Fuchskopf,
    leuchtend rotes Sommerfell (verfärbt zuerst!), Spieße oder schwacher Gabler, Rosenstöcke hoch/eng
    STATUS: Schonen! Klasse III jung

  Stück 3: Schmalricke (April, weiblich, ~13 Monate)
    koerperbau=1.5, traeger_hals=1.5, kopf=1.5, decke_fell=1.0, spiegel_schnuerze=2.0, gehoern=0
    score=1.50 → jung (Klasse III) | Merkmale: Schlank, hochläufig, kein Gesäuge, kein Kitz,
    leuchtendes Orange (verfärbt als erste!), herzförmiger Spiegel + Schnürze
    STATUS: Schmalricke — keine Führung, trotzdem Schonempfehlung

  Stück 4: Zweijähriger Bock (Juni, männlich, ~26 Monate)
    koerperbau=2.0, traeger_hals=2.0, kopf=2.0, decke_fell=2.5, spiegel_schnuerze=2.0, gehoern=2.5
    score=2.13 → mittel_jung (Klasse III, 2-3J) | Merkmale: Schlanker werdend, noch Fuchskopf-Tendenz,
    Träger nimmt zu aber noch lang, Gabler oder Sechser mit beginnenden Rosen
    STATUS: Klasse III — schonen außer begründeter Selektion!
    WARNUNG: Gut veranlagter Jährling kann täuschend ähnlich aussehen!

  Stück 5: Mittelbock (Juli, männlich, ~4 Jahre)
    koerperbau=3.0, traeger_hals=2.5, kopf=3.0, decke_fell=3.0, spiegel_schnuerze=2.5, gehoern=3.0
    score=2.93 → mittel (Klasse II) | Merkmale: Rechteckiger Körper, kräftiger Träger (ACHTUNG: Brunft!),
    Übergangs-Kopf, Widerrist sichtbar, guter 6-Ender mit Perlenbesatz
    STATUS: Klasse II — selektiver Abschuss möglich
    ⚠️ BRUNFT-WARNUNG: Träger-Merkmal jetzt verfälscht! Konfidenz traeger_hals = 40%

  Stück 6: Führende Ricke mit Kitz (August, weiblich, ~5 Jahre)
    koerperbau=3.0, traeger_hals=2.5, kopf=3.0, decke_fell=3.0, spiegel_schnuerze=3.0, gehoern=0
    score=2.90 → mittel | Merkmale: Kräftiger Körper, Gesäuge erkennbar, herzförmiger Spiegel + Schnürze
    STATUS: ABSOLUTER MUTTERSCHUTZ! Ricke NICHT erlegen! Kitz zuerst sichern!
    OVERRIDE: Führende Ricke → hunting_forbidden = true, unabhängig vom Score

  Stück 7: Altbock Klasse I (September, männlich, ~7 Jahre)
    koerperbau=4.5, traeger_hals=4.5, kopf=4.5, decke_fell=4.0, spiegel_schnuerze=3.0, gehoern=4.5
    score=4.23 → alt (Klasse I, 6+J) | Merkmale: Vorderlastiger Kastenrumpf, kurzer/dicker Träger tief
    getragen, Ziegenkopf ausgeprägt, Herbstfell mit dunklem Rückenstreifen, tiefe/weit auseinander
    stehende Rosenstöcke, Tellerrosen möglich, Rücken leicht durchhängend, Hüftknochen sichtbar
    STATUS: Klasse I — Ernteklasse, Abschuss jagdlich korrekt

  Stück 8: Überalterter Bock (Oktober, männlich, ~10+ Jahre)
    koerperbau=5.0, traeger_hals=5.0, kopf=5.0, decke_fell=5.0, spiegel_schnuerze=3.0, gehoern=4.0
    score=4.65 → alt/sehr_alt (Klasse I, 8+J) | Merkmale: Massiv vorderlastig, extremes "Greisenhafte",
    Muskelrückgang unter schlaffer Decke, abstehende Hüftknochen, durchhängender Rücken/Bauch,
    Ziegenkopf extrem ausgeprägt, Eselohren möglich, Fell matt/struppig, Gehörn ggf. rückgebildet
    WARNUNG: Sehr alter Bock kann schwächeres Gehörn haben als junger Bock → Gehörn KEIN primäres Altersmerkmal!
    STATUS: Überaltert — Abschuss aus Hegegründen empfohlen

REHWILD vs. ROTWILD — VERWECHSLUNGSFALLEN (KRITISCH!):

  UNTERSCHIED 1 — WAMME (sicherster Marker, prüfe zuerst!):
    Wamme/Kehlfalte sichtbar → IMMER ROTWILD! Rehwild hat KEINE Wamme. Keine Ausnahme!

  UNTERSCHIED 2 — KÖRPERGRÖSSE:
    Rotwild: Groß wie Kuh/Pferd, massiver Rumpf → ROTWILD
    Rehwild: Klein wie Hund oder kleiner → REHWILD
    ⚠️ OHNE GRÖSSENREFERENZ IM BILD: Proportionen prüfen (nächste Punkte)!

  UNTERSCHIED 3 — KOPFFORM (saisonunabhängig, sehr zuverlässig!):
    Rotwild: Langer Kopf, sichtbare eckige Knochen/Wülste ÜBER DEN LICHTERN (Augenwülste) — "Tiergesicht"
    Rehwild: Runder, kurzer Kopf, KEINE Augenwülste, "Rehkitzgesicht" auch beim Adulttier
    → AUGENWÜLSTE = sicherstes Kopfmerkmal für Rotwild!

  UNTERSCHIED 4 — MÄHNE / SPIEGEL:
    Halsmähne sichtbar → fast sicher ROTWILD (Rehwild hat KEINE Mähne)
    Herzförmiger weißer Spiegel → REHWILD
    Hellbeiger/rundlicher Spiegel → ROTWILD Alttier

  UNTERSCHIED 5 — RÜCKENSTREIFEN:
    Rehwild: Dunkler Rückenstreifen (nur Winterfell, bei adulten Tieren saisonal variabel)
    Rotwild: Kein ausgeprägter Rückenstreifen
    ⚠️ NUR SEKUNDÄR verwenden — im Sommer bei Rehwild kaum sichtbar!

  KITZ vs. KALB VERWECHSLUNG (beide haben Flecken!):
    REHKITZ: Beine kurz, Hals kaum sichtbar, Kopf RUND ("Ball"), Flecken klein in Reihen,
             Gesamteindruck winzig/gedrungen, Sommer (Mai–August)
    ROTWILDKALB: Beine extrem lang ("Stelzbeine", Knie fast auf Rumpfhöhe), Hals lang,
                 Kopf länglich (ansatzweise Hirschkopf), Flecken groß/unregelmäßig/cremeweiß,
                 Rumpf schmal aber HOCH, Sommer (Juli–Oktober)
    ENTSCHEIDUNG ohne Größenreferenz: Beinlänge:Rumpfhöhe-Verhältnis + Kopfform!

  BESONDERE VERWECHSLUNG — Schmalricke/Jährlingsbock ohne Gehörn:
    Kann in schlechtem Licht wie junges Rotwild wirken!
    → Wamme prüfen: keine Wamme → kein Rotwild
    → Kopfform: Rundes Rehwild-Gesicht vs. längliches Rotwild-Gesicht
    → Spiegel: Weißer herzförmiger/nierenförmiger Spiegel → Rehwild



WILDART-UNTERSCHEIDUNG — ENTSCHEIDUNGSBAUM (Priorität 1-4):

SCHRITT 1 — WAMME prüfen (sicherster Marker, saisonstabil!):
✓ Kehlfalte/Wamme sichtbar → IMMER ROTWILD. Rehwild hat KEINE Wamme. Kein Ausnahme!

SCHRITT 2 — KÖRPERGRÖSSE:
✓ Groß wie Pferd/Kuh, massiver Rumpf → ROTWILD
✓ Klein wie Hund oder kleiner, zierlich → REHWILD

SCHRITT 3 — KOPFFORM (saisonunabhängig!):
✓ Rotwild: langer Kopf mit sichtbaren eckigen Knochen/Wülsten ÜBER DEN LICHTERN (Augenwülsten) — charakteristisches "Tiergesicht"
✓ Rehwild: runder kurzer Kopf, KEINE sichtbaren Knochenbögen über den Lichtern, "Rehkitzgesicht" auch beim Adulttier
✓ Rückenstreifen NUR als sekundäres Merkmal (saisonal variabel, im Winter kaum sichtbar!)

SCHRITT 4 — MÄHNE / SPIEGEL:
✓ Halsmähne sichtbar → fast sicher ROTWILD (Rehwild hat keine Mähne)
✓ Herzförmiger weißer Spiegel am Hinterteil → REHWILD
✓ Hellbeiger/runder Spiegel → ROTWILD Alttier

KÄLBER/KITZE MIT FLECKEN — ACHTUNG VERWECHSLUNGSGEFAHR:
BEIDE Arten haben Flecken — UNTERSCHEIDUNG NUR über Proportionen, NICHT Flecken allein!

ROTWILD KALB (typisch Juli–Oktober):
✓ Beine: extrem lang im Verhältnis zum Rumpf ("Stelzbeine"), Knie fast auf Rumpfhöhe
✓ Hals: lang, aufrecht, klar sichtbar
✓ Kopf: länglich, nicht rund — schon ansatzweise "Hirschkopf"
✓ Flecken: cremeweiß, groß, rund-unregelmäßig, über Rücken + Flanken verteilt
✓ Rumpf: schmal aber HOCH (Hochbeinigkeit)
✓ Ohren: lang, abstehend
✓ Wenn Alttier im Bild: Alttier GROSS wie Pferd/Kuh → Kalb ist entsprechend groß

REHKITZ (typisch Mai–August):
✓ Beine: kurz im Verhältnis zum Rumpf, gedrungen
✓ Hals: kurz, kaum sichtbar
✓ Kopf: RUND wie ein Ball, kurze Schnauze — "Bambikopf"
✓ Flecken: kleiner, gleichmäßiger in Reihen angeordnet
✓ Rumpf: sehr kompakt, gedrungen
✓ Gesamteindruck: winzig, "Spielzeug-Tier"-Proportionen

OHNE GRÖSSENREFERENZ IM BILD — Entscheidungsregeln:
→ Lange Beine + langer Hals + länglicher Kopf = ROTWILD Kalb
→ Kurze Beine + runder Kopf + kompakt = Rehkitz
→ Im Zweifel: Beinlänge-zu-Rumpf-Verhältnis entscheidet — Rotwild Kalb IMMER hochläufiger!

ROTWILD — GESCHLECHT:
Geweih sichtbar→HIRSCH. Bastgeweih (dunkel/weich/behaart)→HIRSCH.
Euter/Zitzen sichtbar→ALTTIER (MUTTERSCHUTZ!). Kalb mit weißen Flecken→KALB (MUTTERSCHUTZ!).
Kein Geweih + kein Euter = Schmaltier (jung weiblich) oder Hirsch im Bast (Feb–Apr) → Körper entscheidet.



ROTWILD — ALTER (Scoring 1-5):
- koerperprofil(25%): 1=hochläufig/schlank/dreieckig jung, 3=kräftig/rechteckig, 5=quadratisch/massiv/Schwerpunkt vorne alt
- haupt_kopf(20%): 1=kurz/spitz/jung (Kälbchenkopf), 3=mittel, 5=lang/trocken/eckig/grob alt ("Lange Gesichter" = Alterszeichen! Eckige Knochen über Lichtern sichtbar)
- wamme(20%): 1=keine Kehlfalte jung, 2=leichte Falte, 3=sichtbar, 4=deutlich hängend, 5=stark hängend alt (Alttier hat meist schwächere Wamme als alter Hirsch!)
- ruecken_widerrist(15%): 1=gerade/glatt jung, 3=leichte Einsattelung, 5=eckiger hervortretender Widerrist+Senkrücken alt (eckiger Widerrist = sicheres Alterszeichen!)
- traeger(10%): 1=schlank/aufrecht jung, 3=mittel, 5=massig/waagerecht alt (Brunft verfälscht bei Hirsch!)
- maehne_fell(10%): 1=kurz/glatt jung, 3=mittel, 5=lange Mähne/struppiges Fell/Verfärben-Flecken alt

ROTWILD TERMINOLOGIE — PFLICHT:
- Hirsch: "1. Kopf" (Kalb) → "2. Kopf" (Spießer) → "3. Kopf" → "4. Kopf" → ... → "10. Kopf+" 
- Alttier: "Kalb" → "Schmaltier (2. Kopf)" → "Jungalttier (3. Kopf)" → "Alttier (4.+ Kopf)" → "Altes Alttier (8.+ Kopf)"
- alter_jahre IMMER als Kopf ausgeben: z.B. alter_jahre=4 → Ausgabe "4. Kopf" in begruendung
- altersklasse Mapping: kalb=1.Kopf, jung=2-3.Kopf, mittel=4-6.Kopf, alt=7-10.Kopf, sehr_alt=10+.Kopf

ROTWILD SCORE→ALTERSKLASSE (in Köpfen):
1.0-1.8 → kalb (1. Kopf)
1.8-2.5 → jung (2.-3. Kopf)
2.5-3.3 → mittel (4.-6. Kopf)
3.3-4.2 → alt (7.-10. Kopf)
4.2-5.0 → sehr_alt (10.+ Kopf)

ROTWILD KALIBRIERUNG — Hirsch UND Alttier (Kopf-Angaben):
- Kalb (1. Kopf): koerperprofil=1, haupt=1, wamme=1, ruecken=1, traeger=1, fell=1 → Score≈1.0
- Spießer (2. Kopf): koerperprofil=1, haupt=1, wamme=1, ruecken=1, traeger=1, fell=1 → Score≈1.4
- Schmaltier (2. Kopf): wie Spießer aber kein Geweih → Score≈1.4
- Gabler (3. Kopf): koerperprofil=2, haupt=2, wamme=1, ruecken=1, traeger=2, fell=2 → Score≈1.8
- 4. Kopf Hirsch: koerperprofil=2, haupt=2, wamme=2, ruecken=2, traeger=2, fell=2 → Score≈2.1
- 5. Kopf Alttier: koerperprofil=3, haupt=2, wamme=2, ruecken=2, traeger=2, fell=2 → Score≈2.4
- 6. Kopf Hirsch: koerperprofil=3, haupt=3, wamme=2, ruecken=2, traeger=3, fell=3 → Score≈2.8
- 8. Kopf Alttier: koerperprofil=4, haupt=4, wamme=3, ruecken=4, traeger=3, fell=3 → Score≈3.6
- 9. Kopf Hirsch: koerperprofil=4, haupt=4, wamme=4, ruecken=3, traeger=4, fell=4 → Score≈3.9
- 12. Kopf Alttier (Altweibersommer): koerperprofil=5, haupt=5, wamme=3, ruecken=5, traeger=3, fell=4 → Score≈4.4
- 14. Kopf+ Hirsch: koerperprofil=5, haupt=5, wamme=5, ruecken=4, traeger=5, fell=5 → Score≈4.9

ALTES ROTWILD Schlüsselmerkmale:
✓ LANGES TROCKENES HAUPT — eckige Knochen über den Lichtern sichtbar = sicheres Alterszeichen!
✓ Eckiger hervortretender Widerrist von der Seite sichtbar
✓ Quadratischer Rumpf, Schwerpunkt vorne
✓ Senkrücken + eingefallene Flanken
✓ Verfärben-Flecken auf dem Rücken (struppiges/fleckiges Fell = Altweibersommer)
✓ Bei Alttier: Wamme weniger ausgeprägt als beim Hirsch — Haupt+Widerrist wichtiger!
→ altersklasse="sehr_alt", alter_jahre=10-15, stddev=2.0

ZURÜCKSETZER-WARNUNG: Hirsch mit niedrigem/schwachem Geweih kann trotzdem alt sein → KÖRPER entscheidet!
Alttier mit Kalb = MUTTERSCHUTZ! Kalb immer zuerst erlegen wenn Alttier entnommen wird.

AUSGABE — NUR dieses JSON:
{
  "wildart": "gams"|"rehwild"|"rotwild"|"kein_wild",
  "geschlecht": "maennlich"|"weiblich"|"unbekannt",
  "geschlecht_sicherheit": "hoch"|"mittel"|"niedrig",
  "geschlecht_merkmal": "<beobachtetes Primärmerkmal>",
  "alter_jahre": <Zahl>,
  "alter_stddev": <Zahl>,
  "altersklasse": "kitz"|"jung"|"mittel"|"alt"|"sehr_alt"|"unbekannt",
  "confidence": <0.0-1.0>,
  "scoring": {
    "windfang": {"wert": <1-5>, "beobachtung": "<kurz>"},
    "schrank": {"wert": <1-5>, "beobachtung": "<kurz>"},
    "gesichtszuegel": {"wert": <1-5>, "beobachtung": "<kurz>"},
    "ruecken_flanken": {"wert": <1-5>, "beobachtung": "<kurz>"},
    "augenbogen": {"wert": <1-5>, "beobachtung": "<kurz>"},
    "hochlaeufigkeit": {"wert": <1-5>, "beobachtung": "<kurz>"}
  },
  "gewichteter_score": <1.0-5.0>,
  "begruendung": "<2-3 Sätze>",
  "jagdlich_relevant": true|false,
  "merkmale": ["<merkmal1>", "<merkmal2>"]
}"""


LANDING_DIR = os.path.join(os.path.dirname(__file__), "landing")
LANDING_INDEX = os.path.join(LANDING_DIR, "index.html")

@app.get("/")
async def root():
    if os.path.exists(LANDING_INDEX):
        return FileResponse(LANDING_INDEX)
    return {"status": "WAIDBLICK API"}

@app.get("/app")
async def flutter_app():
    flutter_index = os.path.join(os.path.dirname(__file__),
        "../app/GamsScopeFlutter/build/web/index.html")
    if os.path.exists(flutter_index):
        return FileResponse(flutter_index)
    return {"error": "Flutter app not built"}

@app.get("/waidbuch.html")
async def waidbuch(): return FileResponse(os.path.join(LANDING_DIR, "waidbuch.html"))

@app.get("/info.html")
async def info(): return FileResponse(os.path.join(LANDING_DIR, "info.html"))

@app.get("/einstellungen.html")
async def einstellungen(): return FileResponse(os.path.join(LANDING_DIR, "einstellungen.html"))

@app.get("/login.html")
async def login_page(): return FileResponse(os.path.join(LANDING_DIR, "login.html"))

@app.get("/lookbook.html")
async def lookbook(): return FileResponse(os.path.join(LANDING_DIR, "lookbook.html"))

@app.get("/anleitung.html")
async def anleitung(): return FileResponse(os.path.join(LANDING_DIR, "anleitung.html"))

@app.get("/datenschutz.html")
async def datenschutz(): return FileResponse(os.path.join(LANDING_DIR, "datenschutz.html"))

@app.get("/agb.html")
async def agb(): return FileResponse(os.path.join(LANDING_DIR, "agb.html"))

@app.get("/landing/guide/{filename}")
async def guide_img(filename: str):
    import re
    if not re.match(r'^[\w\-]+\.(jpg|png|webp)$', filename):
        raise HTTPException(status_code=404, detail="Not found")
    p = os.path.join(LANDING_DIR, "guide", filename)
    if not os.path.exists(p): raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(p)

@app.get("/landing/alpine_bg.jpg")
async def alpine_bg(): return FileResponse(os.path.join(LANDING_DIR, "alpine_bg.jpg"))

@app.get("/landing/gams_bg.jpg")
async def gams_bg(): return FileResponse(os.path.join(LANDING_DIR, "gams_bg.jpg"))

@app.get("/landing/rehwild_bg.jpg")
async def rehwild_bg(): return FileResponse(os.path.join(LANDING_DIR, "rehwild_bg.jpg"))

@app.get("/landing/rotwild_bg.jpg")
async def rotwild_bg(): return FileResponse(os.path.join(LANDING_DIR, "rotwild_bg.jpg"))

@app.get("/landing/bayes.js")
async def bayes_js(): return FileResponse(os.path.join(LANDING_DIR, "bayes.js"))

@app.get("/landing/photodb.js")
async def photodb_js(): return FileResponse(os.path.join(LANDING_DIR, "photodb.js"))

@app.get("/landing/manifest.json")
async def manifest(): return FileResponse(os.path.join(LANDING_DIR, "manifest.json"), media_type="application/manifest+json")

@app.get("/landing/icons/{filename}")
async def landing_icons(filename: str):
    p = os.path.join(LANDING_DIR, "icons", filename)
    if os.path.exists(p): return FileResponse(p)
    from fastapi.responses import Response
    return Response(status_code=404)

@app.get("/landing/{filename}")
async def landing_static(filename: str):
    p = os.path.join(LANDING_DIR, filename)
    if os.path.exists(p): return FileResponse(p)
    from fastapi.responses import Response
    return Response(status_code=404)

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model": "gemini-2.0-flash",
        "openai_key_set": bool(OPENAI_API_KEY),
        "gemini_key_set": bool(GEMINI_API_KEY)
    }


@app.post("/analyze")
@limiter.limit("10/minute")
@limiter.limit("100/hour")
async def analyze_photo(
    request: Request,
    file: UploadFile = File(...),
    wildart_hint: str = Form(default="auto"),  # "gams", "rehwild", "auto"
    region: str = Form(default="steiermark"),
    training_consent: str = Form(default="false"),  # "true" = Nutzer hat Opt-in gegeben
):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not set")

    image_bytes = await file.read()
    if len(image_bytes) < 1000:
        raise HTTPException(status_code=400, detail="Bild zu klein oder leer")

    # ── Bildqualitäts-Check: IR/Nacht/Graustufen-Erkennung ────────────────
    image_quality_warning = None
    try:
        from PIL import Image as PILImage
        import io, numpy as np
        _img = PILImage.open(io.BytesIO(image_bytes)).convert("RGB")
        _arr = np.array(_img.resize((100, 100)))
        # Sättigung prüfen: IR/Nacht-Bilder haben kaum Farbe
        r, g, b = _arr[:,:,0].mean(), _arr[:,:,1].mean(), _arr[:,:,2].mean()
        saturation = max(abs(r-g), abs(g-b), abs(r-b))
        # Helligkeit
        brightness = (r + g + b) / 3
        if saturation < 8:  # fast grayscale
            if brightness < 80:
                image_quality_warning = "nacht_ir"  # Nachtsicht/IR-Kamera
            else:
                image_quality_warning = "graustufen"  # SW-Foto
        elif brightness < 30:
            image_quality_warning = "zu_dunkel"
    except Exception:
        pass

    # Bild komprimieren wenn >500KB (iPhone-Fotos sind 3-8MB!)
    if len(image_bytes) > 500_000:
        try:
            from PIL import Image as PILImage
            import io
            img = PILImage.open(io.BytesIO(image_bytes))
            img = img.convert("RGB")
            # Max 1200px auf längster Seite
            img.thumbnail((1200, 1200), PILImage.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=82, optimize=True)
            image_bytes = buf.getvalue()
        except Exception:
            pass  # Kompression fehlgeschlagen → Original verwenden

    content_type = "image/jpeg"

    # Wildart-spezifischer Hint im Prompt
    hint_text = ""
    if wildart_hint == "gams":
        hint_text = "\nHinweis: Der Nutzer vermutet eine GAMS. Fokussiere auf Gams-Merkmale."
    elif wildart_hint == "rehwild":
        hint_text = "\nHinweis: Der Nutzer vermutet REHWILD. Fokussiere auf Rehwild-Merkmale."

    try:
        raw = None

        # Versuche OpenAI zuerst (Gemini als Fallback)
        if OPENAI_API_KEY:
            try:
                import openai, base64
                oai_client = openai.OpenAI(api_key=OPENAI_API_KEY)
                b64_image = base64.b64encode(image_bytes).decode('utf-8')
                oai_response = oai_client.chat.completions.create(
                    model="gpt-4o",
                    messages=[{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": SYSTEM_PROMPT + hint_text},
                            {"type": "image_url", "image_url": {
                                "url": f"data:{content_type};base64,{b64_image}"
                            }},
                        ]
                    }],
                    max_tokens=1200,
                    response_format={"type": "json_object"},
                )
                raw = oai_response.choices[0].message.content.strip()
            except Exception as oai_err:
                print(f"OpenAI failed: {oai_err}, trying Gemini...")

        # Fallback: Gemini
        if raw is None and GEMINI_API_KEY:
            try:
                client = genai.Client(api_key=GEMINI_API_KEY)
                response = client.models.generate_content(
                    model="gemini-2.0-flash",
                    config=types.GenerateContentConfig(
                        temperature=0.1,
                        max_output_tokens=800,
                        response_mime_type="application/json",
                    ),
                    contents=[
                        types.Content(
                            role="user",
                            parts=[
                                types.Part(
                                    inline_data=types.Blob(
                                        mime_type=content_type,
                                        data=image_bytes,
                                    )
                                ),
                                types.Part(text=SYSTEM_PROMPT + hint_text),
                            ],
                        )
                    ],
                )
                raw = response.text.strip()
            except Exception as gemini_err:
                print(f"Gemini failed: {gemini_err}, trying OpenAI...")

        # (OpenAI ist jetzt primär, kein zweiter Block nötig)

        if raw is None:
            raise ValueError("Kein API-Provider verfügbar")

        # JSON extrahieren — robuster Parser für CoT-Output
        # Gemini gibt manchmal Text vor/nach JSON aus
        # Finde das erste { und matche bis zum korrekten schließenden }
        def extract_json(text):
            # Finde LETZTES vollständiges JSON-Objekt (CoT kommt vor JSON)
            # Suche rückwärts vom Ende nach dem letzten '}'
            last_end = text.rfind('}')
            if last_end == -1:
                return None
            # Suche zugehöriges '{' von hinten
            depth = 0
            for i in range(last_end, -1, -1):
                if text[i] == '}':
                    depth += 1
                elif text[i] == '{':
                    depth -= 1
                    if depth == 0:
                        candidate = text[i:last_end+1]
                        try:
                            import json as _j
                            _j.loads(candidate)
                            return candidate
                        except Exception:
                            # Kein valides JSON, weitersuchen
                            last_end = i - 1
                            last_end = text.rfind('}', 0, last_end+1)
                            if last_end == -1:
                                return None
                            depth = 0
                            continue
            return None

        json_str = extract_json(raw)
        if not json_str:
            raise ValueError(f"Kein JSON in Antwort: {raw[:200]}")

        result = json.loads(json_str)

        # None-Werte in Scoring auf 0 normalisieren (nicht beurteilbar)
        for k, v in result.get("scoring", {}).items():
            if isinstance(v, dict) and v.get("wert") is None:
                v["wert"] = 0

        # Validierung & Defaults
        result.setdefault("wildart", "unbekannt")
        # Geschlecht normalisieren — Backend gibt manchmal "bock", "hirsch", etc.
        g_raw = (result.get("geschlecht") or "unbekannt").lower()
        if g_raw in ["bock", "hirsch", "männlich", "maennlich", "male", "m"]:
            result["geschlecht"] = "maennlich"
        elif g_raw in ["geiss", "geiß", "ricke", "tier", "kuh", "weiblich", "female", "w", "f"]:
            result["geschlecht"] = "weiblich"
        else:
            result["geschlecht"] = "unbekannt"
        result.setdefault("geschlecht_sicherheit", "niedrig")
        result.setdefault("geschlecht_merkmal", "")
        result.setdefault("alter_jahre", 5)
        result.setdefault("alter_stddev", 3.0)

        # alter_jahre aus gewichteter_score ableiten wenn 0 oder fehlt
        if result.get("alter_jahre", 0) == 0 and result.get("gewichteter_score"):
            score = float(result["gewichteter_score"])
            if score <= 2.5:
                result["alter_jahre"] = round(1.0 + (score - 1.8) * 2.0, 1)
                result["altersklasse"] = "jung"
            elif score <= 3.2:
                result["alter_jahre"] = round(4.0 + (score - 2.5) * 5.7, 1)
                result["altersklasse"] = "mittel"
            elif score <= 4.0:
                result["alter_jahre"] = round(8.0 + (score - 3.2) * 6.25, 1)
                result["altersklasse"] = "alt"
            else:
                result["alter_jahre"] = round(13.0 + (score - 4.0) * 4.0, 1)
                result["altersklasse"] = "sehr_alt"
            result["alter_stddev"] = 1.5
        result.setdefault("altersklasse", "unbekannt")
        result.setdefault("confidence", 0.5)
        result.setdefault("scoring", {})
        result.setdefault("gewichteter_score", None)
        result.setdefault("begruendung", "Keine Begründung verfügbar")
        result.setdefault("jagdlich_relevant", True)
        result.setdefault("merkmale", [])

        # ── Post-Processing: Normalisierungen ─────────────────────────────
        # 0. Bildqualitäts-Warnung eintragen
        if image_quality_warning:
            warning_texts = {
                "nacht_ir": "Nacht-/IR-Aufnahme erkannt: Farbmerkmale nicht auswertbar. Bestimmung nur nach Silhouette — niedrige Zuverlässigkeit.",
                "graustufen": "Schwarz-Weiß-Bild: Fellfarbe nicht auswertbar. Bestimmung eingeschränkt.",
                "zu_dunkel": "Bild zu dunkel für zuverlässige Bestimmung."
            }
            result["bildqualitaet_warnung"] = warning_texts.get(image_quality_warning, "Bildqualität eingeschränkt.")
            result["bildqualitaet_typ"] = image_quality_warning
            # Confidence deckeln
            current_conf = float(result.get("confidence", 1.0))
            result["confidence"] = min(current_conf, 0.45)
            result["begruendung"] = f"⚠️ {result['bildqualitaet_warnung']} " + result.get("begruendung", "")

        # 1. kitz/kalf Alias: Rehwild "kitz" = "kalb" (jagdlich gleichwertig)
        if result.get("wildart") == "rehwild" and result.get("altersklasse") == "kitz":
            result["altersklasse"] = "kalb"

        # 2. wildart_hint Korrektur: Wenn Hint gesetzt und Confidence niedrig → Hint übernimmt
        if wildart_hint in ("rotwild", "rehwild", "gams"):
            detected = result.get("wildart")
            conf = float(result.get("confidence", 1.0))
            if detected != wildart_hint and conf < 0.75:
                result["wildart"] = wildart_hint
                result["begruendung"] = f"[Wildart-Korrektur: Nutzer-Hint '{wildart_hint}' bei niedriger Confidence {conf:.0%}] " + result.get("begruendung", "")

        # ── Training Data Collection (Opt-in) ─────────────────────────────
        if training_consent == "true" and result.get("wildart") not in ("kein_wild", "unbekannt"):
            try:
                import datetime, hashlib
                wildart = result.get("wildart", "unbekannt")
                altersklasse = result.get("altersklasse", "unbekannt")
                geschlecht = result.get("geschlecht", "unbekannt")
                ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                h = hashlib.md5(image_bytes).hexdigest()[:8]
                label = f"{wildart}_{altersklasse}_{geschlecht}"
                
                # Ordner: datasets/training/{wildart}/{altersklasse}/
                save_dir = os.path.join(
                    os.path.dirname(__file__),
                    f"../../../datasets/training/{wildart}/{altersklasse}"
                )
                os.makedirs(save_dir, exist_ok=True)
                
                # Foto speichern
                img_path = os.path.join(save_dir, f"{ts}_{h}.jpg")
                with open(img_path, "wb") as f:
                    f.write(image_bytes)
                
                # Metadaten speichern
                import json as _json
                meta_path = os.path.join(save_dir, f"{ts}_{h}.json")
                with open(meta_path, "w") as f:
                    _json.dump({
                        "wildart": wildart,
                        "altersklasse": altersklasse,
                        "alter_jahre": result.get("alter_jahre"),
                        "geschlecht": geschlecht,
                        "confidence": result.get("confidence"),
                        "scoring": result.get("scoring", {}),
                        "region": region,
                        "timestamp": ts,
                        "label": label
                    }, f, indent=2)
                
                result["_training_saved"] = True
            except Exception as e:
                result["_training_saved"] = False

        return result

    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"JSON Parse Fehler: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analyse-Fehler: {str(e)}")


# Flutter Web App NACH allen API-Routen mounten (sonst werden API-Routen überschrieben)
if os.path.exists(FLUTTER_WEB_DIR):
    app.mount("/", StaticFiles(directory=FLUTTER_WEB_DIR, html=True), name="flutter")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8900))
    uvicorn.run(app, host="0.0.0.0", port=port)
