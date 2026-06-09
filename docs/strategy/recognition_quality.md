# Gamssinn — Erkennungsqualität: Analyse & Weg Richtung 100 %

**Stand:** 2026-06-09 · **Autor:** Recognition-Audit (Claude)
**Scope:** Wildart-Gate, Merkmals-Vollständigkeit, Prompt-Strategie für Gams / Reh / Rotwild
**Codebasis verifiziert:** `backend/main.py` (kanonisch: `~/.openclaw/workspace/projects/gams/backend/main.py`; deploybar-identisch: `app/GamsScopeFlutter/backend/main.py`), `lib/screens/analysis_screen.dart`, `lib/services/vision_api_service.dart`, `.github/workflows/gams_test.yml`.

> ⚠️ **HARTE REGEL eingehalten:** Der GAMS-Prompt-Block in `SYSTEM_PROMPT` ist **eingefroren**. Dieses Dokument ändert keinen Prompt. Alle Gams-Punkte sind reine **Vorschläge**. Für Reh/Rotwild stehen konkretere Entwürfe, aber auch diese sind nicht angewandt.

---

## 0. Faktencheck: Wie wird Qualität heute überhaupt gemessen?

Die kolportierten Zahlen **82 % Pass-Rate / 96 % Wildart-Erkennung** sind **am Code nicht reproduzierbar belegt** und mit hoher Wahrscheinlichkeit **veraltet bzw. methodisch unsauber**:

1. **Der einzige automatisierte Test** (`.github/workflows/gams_test.yml`) deckt **nur Gams** ab — 12 Bilder aus der TJV-Broschüre (`uebung_01`–`12`). **Reh und Rotwild werden NICHT getestet.** Eine „96 % Wildart-Erkennung" über alle drei Arten ist damit **nicht gemessen**, sondern geschätzt.
2. **Label-Mismatch im Test-Harness (Bug):** Der Test vergleicht `ki_klasse == erwartet_klasse` mit Erwartungswerten `"jugendklasse"` / `"mittelklasse"` / `"altersklasse"`. Der Prompt gibt aber `altersklasse` ∈ `{kitz, jung, mittel, alt, sehr_alt}` aus. Diese Strings sind **nie gleich** → `klasse_ok` ist strukturell fast immer `False`. Der Test misst real also überwiegend nur noch die **Geschlechts**-Trefferquote und straft die Altersklasse pauschal ab. Die Pass-Rate-Zahl ist dadurch **verzerrt** (zu niedrig bei Alter, blind für die eigentliche Klassen-Logik).
3. **Kein Mismatch-/Negativ-Set:** Es gibt keine Testfälle „Rotwild-Foto im Gams-Modus", „Hund", „kein Tier", „Nachtbild". Genau die Fälle, die im Feld Müll-Ergebnisse erzeugen, werden nicht gemessen.

➡️ **Erste Konsequenz, vor allem anderen:** Eine belastbare Qualitäts-Aussage Richtung 100 % ist ohne einen **erweiterten, korrekt gelabelten Benchmark** unmöglich. Das ist die Grundlage für alles Weitere (siehe §4).

---

## 1. Wildart-Gate (Alex-Frage 1)

### 1.1 Was der Code HEUTE tut

**Bestimmt das Tool zuerst die Wildart?** — Im Prompt ja, im **Produktverhalten nein, nicht robust.**

- Der Prompt enthält einen sauberen Entscheidungsbaum: `SCHRITT 0 — GUARD` (kein Tier / nicht unterstützte Art → `kein_wild`), dann `SCHRITT 1 — WILDART BESTIMMEN` (Wamme→Rotwild, Größe, Kopfform, Mähne/Spiegel, Kitz-vs-Kalb). **Inhaltlich ist die Vorstufe gut.**
- **ABER:** Die Wildart-Wahl des Nutzers (`_wildartHint`: `auto/gams/rehwild/rotwild`, gesetzt per Tab in `analysis_screen.dart:67`) wird nur als weicher Text-Hint angehängt:
  ```
  if wildart_hint == "gams":    "\nHinweis: Der Nutzer vermutet eine GAMS. Fokussiere auf Gams-Merkmale."
  elif wildart_hint == "rehwild": "...REHWILD..."
  # ⚠️ KEIN Branch für "rotwild" → Rotwild-Tab erzeugt GAR KEINEN Hint-Text
  ```

### 1.2 🔴 Der kritische Bug (Müll-Ergebnis-Pfad)

`backend/main.py` (Post-Processing, ~Zeile 1060):

```python
# 2. wildart_hint Korrektur: Wenn Hint gesetzt und Confidence niedrig → Hint übernimmt
if wildart_hint in ("rotwild", "rehwild", "gams"):
    detected = result.get("wildart")
    conf = float(result.get("confidence", 1.0))
    if detected != wildart_hint and conf < 0.75:
        result["wildart"] = wildart_hint   # ← überschreibt die ECHTE Erkennung
        result["begruendung"] = "[Wildart-Korrektur: Nutzer-Hint ...] " + ...
```

**Genau das Szenario aus Alex' Frage:** Nutzer wählt „Gams", fotografiert Rotwild. Das Modell erkennt (richtig) Rotwild, ist aber bei sub-optimalem Bild < 75 % sicher → der Code **überschreibt** `wildart` zwangsweise auf `gams`. Das **Scoring-Objekt bleibt aber das, was das Modell ausgegeben hat** (auf ein Rotwild gerechnet) und wird unter dem Label „Gams" angezeigt. **= Müll-Ergebnis, das wie ein valides Gams-Ergebnis aussieht.** Schlimmer als eine ehrliche „unsicher"-Meldung.

Zusätzlich: **In der gesamten `analysis_screen.dart` gibt es KEINE Mismatch-Behandlung.** Es existiert kein Code, der „detected ≠ gewählte Wildart" erkennt und dem Nutzer einen Hinweis („Das sieht nach Rotwild aus, nicht Gams – Modus wechseln?") anbietet. Der gewünschte UX-Flow **fehlt komplett**.

### 1.3 Konzept: robuste Wildart-Klassifikations-Vorstufe

Empfohlene Architektur — **Art zuerst hart bestimmen, dann erst ansprechen**, mit dem Nutzer-Tab als *Erwartung*, nie als *Override*:

**Stufe A — dedizierter Wildart-Klassifikator (eigener, billiger Call ODER erste Sektion eines 2-stufigen Prompts):**
Gibt strikt zurück:
```json
{ "wildart": "gams|rehwild|rotwild|anderes_wild|kein_tier",
  "wildart_confidence": 0.0-1.0,
  "begruendung_art": "<welche Marker: Wamme / Kopfform / Größe / Spiegel>",
  "bild_tauglich": true|false, "bildproblem": "nacht_ir|unscharf|zu_klein|verdeckt|null" }
```
Vorteil: Die Art-Entscheidung ist von der teuren, fehleranfälligen Alters-Ansprache **entkoppelt** und kann eigene, klare Confidence liefern.

**Stufe B — Routing nach Stufe A (Backend-Logik, KEIN Prompt-Override mehr):**

| Fall | Bedingung | Verhalten |
|---|---|---|
| **Match** | `wildart == userTab` (oder Tab=`auto`) | Ansprech-Prompt der erkannten Art laufen lassen. Normal anzeigen. |
| **Mismatch, sicher** | `wildart ≠ userTab` **und** `wildart_confidence ≥ 0.6` | **NICHT** still überschreiben. UI-Dialog: „Das sieht nach **Rotwild** aus, nicht Gams. Im Rotwild-Modus auswerten? [Ja, wechseln] [Nein, trotzdem Gams]". Bei „Ja" → korrekten Ansprech-Prompt fahren. |
| **Mismatch, unsicher** | `wildart ≠ userTab` **und** `< 0.6` | Hinweis-Banner statt Hard-Switch: „Art unsicher (evtl. Rotwild). Ergebnis mit Vorsicht. Mehr/besseres Foto hilft." Ergebnis als *vorläufig* taggen, Confidence deckeln. |
| **kein_tier** | GUARD greift | Witziger Klartext (existiert im Prompt schon), **kein** Scoring, kein Speichern. |
| **anderes_wild** | Wildschwein/Fuchs/Damwild… | „Diese Wildart wird (noch) nicht unterstützt." (existiert im Prompt) — sauber durchreichen, nicht in gams/reh/rot pressen. |

**Kern-Regel:** Der Nutzer-Tab darf das Ergebnis **nie umlabeln**. Er steuert höchstens, *welcher* Ansprech-Prompt bei *Übereinstimmung* läuft, und löst bei Abweichung einen **Hinweis**, keinen stillen Switch aus. Das ist die eigentliche Antwort auf Alex' Frage 1.

**Sofort-Quick-Win (kleinster Eingriff, kein Gams-Prompt-Edit):**
1. Die Überschreib-Regel in §1.2 **entschärfen**: statt `result["wildart"] = wildart_hint` → ein Flag `wildart_mismatch: true` + `wildart_detected` mitsenden und Confidence deckeln. **Niemals** das Label gegen die Modell-Erkennung tauschen.
2. Fehlenden `rotwild`-Hint-Branch ergänzen (Reh/Rotwild sind nicht eingefroren) — sonst bekommt der Rotwild-Tab heute gar keinen Fokus-Hint.
3. In `analysis_screen.dart` das `wildart_mismatch`-Flag auswerten und den Dialog aus der Tabelle oben zeigen.

---

## 2. Merkmals-Vollständigkeit (Frage 2)

> Hinweis: Es existiert **kein** `knowledge/`-Ordner und **keine** `feature_matrix.md` im Repo (per Glob/Grep geprüft). Das gesamte Fachwissen lebt **ausschließlich im `SYSTEM_PROMPT`**. Es gibt keine externe, versionierte Wissensbasis, gegen die man Prompt-Drift prüfen könnte — das ist selbst eine Lücke (§4).

Abgleich des Prompt-Scorings gegen die jagdlich entscheidenden Ansprechmerkmale (DACH):

### 2.1 Gams — Bewertung: **inhaltlich am stärksten**, eine Inkonsistenz

Erfasst (gewichtet): `windfang 20 %`, `gesichtszuegel 25 %`, `ruecken_koerper 20 %`, `brustkern 15 %`, `augenbogen 10 %`, `hochlaeufigkeit 10 %`. Override-Regeln für ausgewaschene Zügel, Kitz-/Mutterschutz, IR/Frühjahr-Warnungen — sehr solide.

| Merkmal (Alex' Liste) | Im Prompt? | Lücke |
|---|---|---|
| Krucke: Höhe / Hakenlänge / Bast | **teilw.** | Hakenform nur als *Geschlechts*-Sekundärmerkmal + „Schrank". **Krucken-Höhe/Hakenlänge fließen NICHT ins Alters-Scoring** (bewusst, da unzuverlässig — vertretbar, aber explizit machen). Bast (verfärbtes/abgeriebenes Horn) gar nicht erwähnt. |
| Schlauch / Pinsel | ✅ | Pinsel als Geschlecht; Hinweis „im Sommerhaar nicht sichtbar" vorhanden. Gut. |
| Gesichtsmaske / Zügel | ✅✅ | Bestes Merkmal, exzellent ausgearbeitet. |
| Körperform / Senkrücken | ✅ | `ruecken_koerper` + `hochlaeufigkeit`. Gut. |
| Verhalten / führend | **teilw.** | „führende Geiß" → Mutterschutz ja. Sonstiges Verhalten (Einzelgänger alter Bock etc.) nicht als Indiz. |

🔴 **Inkonsistenz Output-Schema ↔ Scoring-Definition:** Das `scoring`-JSON im AUSGABE-Block listet `windfang, schrank, gesichtszuegel, ruecken_flanken, augenbogen, hochlaeufigkeit`. Die SCORING-Definitionen oben heißen aber `windfang, gesichtszuegel, ruecken_koerper, brustkern, augenbogen, hochlaeufigkeit`. → `brustkern` (15 % Gewicht!) und `ruecken_koerper` tauchen im Output-Schema **nicht** auf, dafür `schrank` und `ruecken_flanken`, die in den Gewichten **nicht** definiert sind. Das Modell muss raten, welche Keys es füllt → instabile `gewichteter_score`-Berechnung. **(Nur dokumentiert — Gams-Prompt eingefroren, NICHT angefasst. Empfehlung an Alex: dies ist ein lohnender Punkt, das Freeze für genau diese Schema-Angleichung einmalig aufzuheben.)**

### 2.2 Reh — Bewertung: **vollständig & sehr detailliert**, kleine Schwächen

6 gewichtete Merkmale (`koerperbau 25`, `traeger_hals 20`, `kopf 20`, `decke_fell 15`, `spiegel_schnuerze 10`, `gehoern 10`), Gewichts-Renormierung wenn Gehörn fehlt, Brunft-/Jahreszeit-Korrekturen, 8 Kalibrierungsstücke, Reh-vs-Rotwild-Verwechslungsbaum.

| Merkmal (Alex) | Im Prompt? | Lücke |
|---|---|---|
| Rosenstock / Rosen | ✅ | im `gehoern`-Merkmal sehr gut (Tellerrosen, Überhang, Perlen). |
| Geweihform / Enden | ✅ | Spieß/Gabler/Sechser, Warnung „genetisch, kein sicheres Altersmaß". Gut. |
| Träger / Haupt | ✅ | `traeger_hals` + Brunft-Warnung. |
| Körperproportionen | ✅ | Fuchs- vs. Ziegen-Prinzip — fachlich exzellent. |
| Schalenabnutzung | ❌ | **fehlt** — am lebenden Stück ohnehin nicht ansprechbar, daher ok wegzulassen; sollte aber bewusst als „nicht beurteilbar" gelten. |
| Haltung | ✅ | über `koerperbau`/Träger abgebildet. |

➡️ Reh ist **merkmalsvollständig**. Hauptrisiko ist nicht Vollständigkeit, sondern **fehlende Validierung** (kein Reh-Benchmark, §0/§4).

### 2.3 Rotwild — Bewertung: **vollständig, aber am wenigsten kalibriert/validiert**

6 Merkmale (`koerperprofil 25`, `haupt_kopf 20`, `wamme 20`, `ruecken_widerrist 15`, `traeger 10`, `maehne_fell 10`), korrekte „Kopf"-Terminologie, Kalibrierungstabelle Hirsch+Alttier.

| Merkmal (Alex) | Im Prompt? | Lücke |
|---|---|---|
| Geweih: Enden / Stangen / Krone | ❌ **als Scoring-Merkmal NICHT erfasst** | Geweih taucht nur bei Geschlecht („Geweih→Hirsch") auf. **Es gibt kein `geweih`-Merkmal** im Rotwild-Scoring — Enden/Krone/Stangenstärke fließen nicht ins Alter ein. Bei Reh gibt es ein Gehörn-Merkmal, bei Rotwild fehlt das Pendant. **Größte inhaltliche Rotwild-Lücke.** |
| Körpergröße / Träger | ✅ | `koerperprofil` + `traeger`. |
| Verhalten / Rudel | ❌ | Rudelkontext (Kahlwild-Rudel, Hirsch-Trupp, Brunftrudel) nicht als Indiz genutzt. |
| Brunftmerkmale | **teilw.** | Brunft nur als *Störfaktor* beim Träger erwähnt (gut!), aber Brunft-*Indizien* (Mähne, Brunftkörper, Suhle) nicht aktiv für Alter/Geschlecht genutzt. |

➡️ **Konkreter Entwurf** (Reh/Rotwild dürfen geändert werden — hier nur als Vorschlag-Text, nicht angewandt): Rotwild um ein 7. Merkmal **`geweih_hirsch`** ergänzen, analog zum Reh-`gehoern`, **nur beim Hirsch & saisonal** (gefegt, vor Abwurf), mit Renormierung der Gewichte wenn nicht sichtbar:
> `geweih_hirsch (10 %, NUR Hirsch, Mai–Feb): 1=Spieß/Gabler kurz, 2=ungerade 6–8 Enden, 3=kapitaler 10er ohne Krone, 4=Kronenansatz/12er, 5=mehrfache Krone/zurückgesetzt (Überalterung: Geweih wird wieder schwächer → KEIN linearer Alters-Proxy, nur in Kombination mit Haupt/Widerrist).`
> Gewichte dann: koerperprofil 25 → bleibt, traeger 10→ nur bei sichtbarem Geweih auf 5 senken, Rest renormieren.

---

## 3. Prompt-Strategie Richtung 100 % (Frage 3)

Reihenfolge = grob nach Wirkung/Aufwand.

### 3.1 Strukturierte, zweistufige Analyse (Extract → Infer) — **größter Hebel**
Heute ist alles ein Monolith-Prompt mit internem (verstecktem) CoT. Empfehlung: **Merkmals-Extraktion und Schlussfolgerung trennen.**
- **Pass 1:** Modell extrahiert NUR beobachtbare Merkmale als strukturiertes JSON (jeder Score + Beobachtungstext + *sichtbar ja/nein*). Keine Altersklasse.
- **Pass 2:** Die Score→Altersklasse-Abbildung macht **deterministisch der Backend-Code** (die Gewichtsformeln stehen ohnehin schon im Prompt!), nicht das LLM. Das eliminiert die heute beobachtbaren Inkonsistenzen (LLM rechnet `gewichteter_score` mal so, mal so; `alter_jahre` wird im Backend teils nochmal aus Score abgeleitet → Doppel-Logik, Quelle von Drift).
→ Macht Ergebnisse **reproduzierbar** und die fehlerhafte Schema/Gewichts-Diskrepanz (§2.1) irrelevant.

### 3.2 Few-Shot statt nur Text-Kalibrierung
Die Kalibrierungstabellen sind heute reine Zahlenlisten ohne Bild. **Echte Few-Shot-Beispiele mit den Broschüren-Bildern** (`datasets/training/gams/broschuere/uebung_*.jpg`) als Referenz im Prompt (oder via Vision-Embedding-Retrieval „ähnlichstes kalibriertes Stück") heben die Alters-Treffer deutlich. Für Reh/Rotwild fehlen solche kalibrierten Referenzbilder noch komplett → beschaffen (LWF Bayern / TJV / BOKU, vgl. Memory `project_waidblick_data`).

### 3.3 Unsicherheits-Kalibrierung erzwingen
- Heute deckelt der Code Confidence nur bei IR/Nacht. Besser: **pro Merkmal `sichtbar: true/false`** abfragen; `confidence` = Funktion aus *Anteil sichtbarer Merkmale* × Bildqualität. Ein Tier von hinten mit 1 sichtbaren Merkmal darf nie hohe Confidence bekommen.
- `alter_stddev` an die Sichtbarkeit koppeln (wenige Merkmale → große Streuung). Passt zur „probabilistischen Ansprech-Hilfe"-Produktvision.

### 3.4 Umgang mit schlechten Bildern
- Der `image_quality`-Vorcheck (Sättigung/Helligkeit) ist gut, deckt aber **Unschärfe/Verdeckung/zu-klein** nicht ab. Ergänzen: Laplacian-Schärfe-Maß + „Anteil Tier im Frame". Bei Verdeckung/Unschärfe: aktiv besseres Foto anfordern statt raten.
- Multi-Foto-Fusion: Die App sammelt mehrere Fotos (`photoCount`, Bayes-Engine vorhanden). Wildart sollte über mehrere Fotos **gevotet** werden (Mehrheit), Alter über die Engine gemittelt — ein einzelnes schlechtes Foto kippt dann nicht das Ergebnis.

### 3.5 Closed-Loop aus echtem Feedback
`/feedback` mit Ground Truth (Zahnschliff/Erleger) existiert bereits und schreibt `datasets/feedback/`. **Bisher fließt das in NICHTS zurück.** Das ist der eigentliche Weg Richtung 100 %: verifizierte Fälle → in den Benchmark (§4) → als Few-Shot → Prompt iterieren. Ohne diesen Loop ist „100 %" nicht erreichbar, nur behauptbar.

---

## 4. Fundament: erweiterter Benchmark (Voraussetzung für jede 100-%-Aussage)

1. **Test-Harness-Bug fixen:** Label-Mapping `jugendklasse↔jung`, `mittelklasse↔mittel`, `altersklasse↔alt/sehr_alt` (oder Erwartungswerte auf die Prompt-Klassen umstellen). Aktuell misst der Test die Altersklasse faktisch nicht.
2. **Reh- und Rotwild-Testsets** mit verifizierten Labels aufbauen (analog Gams-Broschüre). Ohne sie ist „96 % Wildart-Erkennung" eine Behauptung.
3. **Negativ-/Mismatch-Set:** Hund, Mensch, leere Landschaft, Wildschwein, Damwild, Nachtbild, **Rotwild-Foto im Gams-Modus** → testet GUARD + Wildart-Gate (§1) gezielt.
4. **Drei Metriken getrennt** ausweisen: Wildart-Accuracy · Geschlechts-Accuracy · Altersklassen-Accuracy (±1 Klasse Toleranz). Eine einzelne „Pass-Rate" verschleiert, wo es klemmt.

---

## 5. Fazit (Priorisierung)

| # | Maßnahme | Aufwand | Wirkung | Gams-Freeze? |
|---|---|---|---|---|
| 1 | Stillen Wildart-Override entschärfen → `wildart_mismatch`-Flag + Dialog | klein | **hoch** (verhindert Müll-Ergebnisse) | ✅ kein Prompt-Edit |
| 2 | Test-Harness-Label-Bug fixen + 3 Metriken trennen | klein | hoch (ehrliche Messung) | ✅ |
| 3 | Reh/Rotwild/Negativ-Benchmark aufbauen | mittel | hoch | ✅ |
| 4 | Rotwild: `geweih_hirsch`-Merkmal ergänzen | klein | mittel | ✅ (Reh/Rot frei) |
| 5 | Zweistufig Extract→Infer, Score-Mapping ins Backend | mittel | **hoch** | ⚠️ Gams nur über Freeze-Ausnahme |
| 6 | Feedback-Loop → Benchmark → Few-Shot schließen | groß | hoch (langfristig) | ✅ |
| — | Gams Output-Schema ↔ Gewichts-Keys angleichen | klein | mittel | ⛔ Freeze — Alex muss freigeben |
