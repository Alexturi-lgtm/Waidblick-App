# Datenakquise-Strategie — Gamssinn (Waidblick)

**Datum:** 2026-06-09
**Autor:** Daten-/Produktstrategie (Claude)
**Kernfrage (Alex' Auftrag):** Wie kommen wir an *bessere* Ansprechdaten — verifizierte Wildbilder mit echtem Alter/Geschlecht — und schaffen dabei kreativen Mehrwert für den Jäger?
**Strategische These:** Der Burggraben ist NICHT das Modell (jeder kann Gemini/GPT aufrufen), sondern ein **proprietärer, über echte Nutzung wachsender Datensatz mit verifiziertem Ground Truth**. Frei verfügbare Wildbilder gibt es viele — aber fast keine mit korrektem Alters-Label. Genau diese Lücke ist unser Burggraben.

---

## 0. Ausgangslage — verifizierter Ist-Stand im Repo

Vor der Strategie der ehrliche Code-Stand (Quelle: `docs/data_flywheel_audit.md`, eigene Code-Sichtung):

**Schon vorhanden (✅ verifiziert im Code):**
- **Opt-in-Training-Pipeline:** `/analyze` speichert Bild + komplettes KI-Ergebnis bei `training_consent=true` (`backend/main.py`).
- **Feedback-Schleife end-to-end:** `/feedback`-Endpoint nimmt `is_correct` + Korrekturwerte UND eine **`methode`-Qualifizierung `zahnschliff | erleger | sicht`** entgegen (`backend/main.py:1012`). Das ist der Goldstandard-Hook — er existiert bereits. App-seitig: Feedback-Card "War das richtig?" (`analysis_screen.dart:1455 ff.`).
- **Sightings mit Supabase:** `sightings_service.dart` schreibt Sichtung (Wildart/Alter/Geschlecht/Score/GPS/Revier/Notizen) in Postgres; `getCommunitySightings()` (shared=true) + `profiles(username, revier)` existieren bereits → Community-Layer ist angelegt.
- **GamsBook (Lookbook-Keim):** `gamsbook_screen.dart` + `GamsIndividual`-Modell + `database_service.dart` (lokal via SharedPreferences) — Individuen anlegen, benennen, Revier zuordnen, mehrere Sichtungen.
- **Streckenblatt-Sharing:** `streckenblatt_service.dart` rendert teilbares PNG-Streckenblatt → viraler Kanal existiert schon.

**Lücken, die den Datenwert mindern (aus Audit, P1):**
- Keine `model_version`/`prompt_version` am Sample → bei Modellwechsel nicht rekonstruierbar.
- Nur grobe `region` statt GPS am Trainings-Sample (GPS wird erhoben, aber nicht an `/analyze` durchgereicht).
- Komprimiertes Bild (max 1200px) statt Original gespeichert.
- Zwei getrennte Persistenzwelten: Trainings-Samples = lose Dateien (Backend-Filesystem); Sightings/Community = Supabase. **Nicht gejoint.**
- P0-DSGVO offen (Datenschutzerklärung, Löschrecht, USA-Transfer) — blockiert *legales* Sammeln im Maßstab.

**Fazit Ist-Stand:** Die Mechanik für das Flywheel ist zu ~60 % verdrahtet. Es fehlt weniger Neubau als **Verbindung, Anreiz und Ground-Truth-Einsammlung**. Das ist die gute Nachricht — die Hebel unten sind großteils Aktivierung, nicht Greenfield.

---

## 1. Community-Daten-Flywheel — Ground Truth systematisch einsammeln

**Das Kernproblem präzise:** Eine Sichtbestimmung ("sieht aus wie alter Bock") ist KEIN Ground Truth — sie ist nur eine zweite Schätzung. Echtes Alter gibt es nur **nach Erlegung**: Zahnschliff (Dentinringe, laborgenau), Kieferbeurteilung (Zahnwechsel/Abkauung), bei Gams zusätzlich **Krucken-Jahresringe (Schübe)** — die sind am erlegten Stück direkt zählbar und für Gams der praktikabelste Goldstandard. Der Flow muss den Jäger genau in diesem Moment abholen.

### 1.1 Der "Nachtrag nach Erlegung"-Flow (HÖCHSTE PRIORITÄT)

Die wertvollste einzelne Mechanik. Ablauf:

1. Jäger fotografiert lebendes Tier vor dem Schuss → KI-Ansprache (das ist die Kern-App heute).
2. Tier erlegt → App-Prompt (Push/Banner): **"Stück erlegt? Trag das verifizierte Alter nach — und mach Gamssinn für alle besser."**
3. Eingabemaske mit **Methoden-Qualifizierung** (Hook existiert schon: `methode`):
   - **Krucken-Schübe gezählt** (Gams) / **Geweih-/Zahnbeurteilung** → hoch
   - **Zahnschliff (Labor)** → Goldstandard, höchstes Gewicht
   - **Kiefer/Abkauung geschätzt** → mittel
   - **reine Sicht** → niedrig (kein echter GT, nur Zweitmeinung)
4. Optional: Foto des Kiefers/der Krucke/des erlegten Stücks nachladen → zweites, anders gelabeltes Bild *desselben Individuums* mit bekanntem Alter.
5. Das Live-Foto-Sample wird damit von `verified=false` auf `verified=true` mit echtem Alter + Vertrauensgewicht hochgestuft.

**Warum das den Burggraben baut:** Jedes nachgetragene erlegte Stück erzeugt ein **Paar (Live-Bild → verifiziertes Alter)** — exakt die Trainingsdaten, die es frei nicht gibt. Selbst wenige hundert solcher Paare pro Saison sind wertvoller als zehntausende ungelabelte Camera-Trap-Bilder.

- **Aufwand:** Mittel (~3-5 Tage). Eingabemaske + `methode`-Gewichtung + Sample-Upgrade-Logik. Backend-Hook (`/feedback` mit `methode`) existiert bereits.
- **Wirkung:** Sehr hoch — das ist *der* Ground-Truth-Kanal.

### 1.2 Erleger-/Streckendaten als Pflichtfeld light

Beim Streckeneintrag (Feature existiert als Sharing schon) ohnehin abgefragte Felder mitnehmen: Wildart, geschätztes/verifiziertes Alter, Geschlecht, Gewicht (aufgebrochen), Datum, grobe Region. Gewicht + Datum + Geschlecht sind selbst ohne Zahnschliff schwache Alters-Priors (z.B. Kitz vs. Schmaltier vs. führend). → Niedrigschwelliger GT-Beitrag, der nebenbei anfällt.

### 1.3 Gamification — aber jagdlich seriös, nicht "Candy Crush"

Jäger sind status- und hegeorientiert, nicht spielsüchtig. Anreize müssen *waidgerecht* framen:

- **"Verifiziert"-Badge & Beitrags-Score:** Nicht "du hast 50 Bilder hochgeladen", sondern **"Du hast 12 Stück mit Zahnschliff/Schüben verifiziert — du gehörst zu den Top-Hege-Beitragenden deiner Region."** Status über Datenqualität, nicht Menge.
- **Revier-/Saison-Statistik (echter Eigennutzen):** Automatisch generiertes Revierbuch — Strecke nach Wildart/Alter/Geschlecht/Monat, Altersklassenverteilung vs. Abschussplan-Soll. Das ist ohnehin Pflichtarbeit (Streckenliste) → wir nehmen sie ab UND bekommen strukturierte Daten.
- **Hegegemeinschafts-Bestenliste (anonymisiert/aggregiert):** "Reviere mit ausgeglichenster Altersstruktur" statt "wer schießt am meisten". Belohnt Hege, nicht Strecke — das ist politisch anschlussfähig und vermeidet den "Abschuss-Wettbewerb"-Vorwurf.
- **Lookbook/GamsBook ausbauen:** Wiedererkennung von Individuen über Saisons ("Braunl, erstmals 2024 als Jährling, jetzt 3. Schub") ist ein *starker* intrinsischer Anreiz (Reviergeschichte) UND erzeugt longitudinale Bilddaten desselben Tiers mit fortschreitendem bekanntem Alter — ein Datenschatz, den selbst Forschung selten hat.

- **Aufwand:** Lookbook-Ausbau + Revier-Statistik je mittel (~4-6 Tage); Bestenliste klein (~2 Tage), setzt aber Nutzerbasis voraus.
- **Wirkung:** Mittel-hoch (Retention + Datenqualität), aber wirkt erst mit Nutzerbasis.

### 1.4 Annahme-Kennzeichnung
- Krucken-Schübe als praktikabelster Gams-Goldstandard: **etablierte jagdliche Praxis** (Allgemeinwissen Gamsansprache), nicht laborverifiziert wie Zahnschliff. [verifiziert als gängige Methode / Genauigkeitsgrad = Annahme]
- Jäger-Motivation primär Status/Hege statt Spiel-Gamification: **Annahme** (plausibel, mit Zielgruppe testen).

---

## 2. Datenpartnerschaften — konkret, mit Recherche-Stand

> **Wichtig:** Unten ist sauber getrennt, was per WebSearch **verifiziert** ist und was **Annahme/Hypothese** für die Ansprache bleibt. Keine erfundenen Fakten über die Institutionen.

### 2.1 LWF Bayern (Bayerische Landesanstalt für Wald und Forstwirtschaft)

**Verifiziert (Recherche 2026-06):**
- LWF betreibt **aktiv KI-Wildtiermonitoring** — Projekt **AI4Wildlife** ("Automatisierte räumliche und zeitliche Erfassung von Wildtier- und Besucheraktivitäten mittels KI") und KI-Klassifikation von Wildkamera-Bildern (Kooperation Uni Bayreuth / LMU München / LWF).
- **Schalenwildprojekt** "Integrales Schalenwildmanagement im Bergwald" (JA14) — Bergwald-Fokus = Gams-Habitat.
- LWF gibt an, **bereits umfangreiche Daten** zum Training/Optimieren von KI-Systemen zu besitzen.
- **Kooperationsvertrag mit dem Thünen-Institut** (Bund) zur Wildtierforschung (Sept. 2025) → LWF ist kooperationsoffen auf institutioneller Ebene.

**Strategische Lesart:** LWF ist gleichzeitig **potenzieller Partner UND potenzieller "Konkurrent"** (sie bauen selbst KI-Wildtiererkennung). Aber: ihr Fokus ist *Monitoring/Spezies-Klassifikation aus Camera-Traps*, NICHT *individuelle Alters-/Geschlechtsansprache als Jäger-Entscheidungshilfe*. Andere Achse → komplementär.

**Wir bieten:** anonymisierte, regional aggregierte Strecken-/Altersstruktur-Auswertungen aus echter Jägernutzung (Daten, die LWF aus Camera-Traps *nicht* bekommt, weil dort der Erleger-Ground-Truth fehlt); ein Praxis-Tool für Schalenwildprojekt-Reviere; Reichweite in die Jägerschaft.
**Wir bekommen:** ggf. gelabelte Bergwald-Schalenwild-Bilder, wissenschaftliche Validierung der Altersklassen-Logik, Glaubwürdigkeit ("in Kooperation mit der LWF") als Marketing- und Vertrauens-Asset.
**Ansprache:** Fachlich, nicht kommerziell. Erstkontakt über das Sachgebiet Wildtierbiologie/Wildtierforschung; Aufhänger = Schalenwildprojekt + AI4Wildlife. Nicht als "Startup will eure Daten", sondern "Praxis-Datenrückfluss aus der Jägerschaft für euer Monitoring".

### 2.2 BOKU Wien — Institut für Wildbiologie und Jagdwirtschaft (IWJ)

**Verifiziert:** IWJ existiert (Dept. Ökosystemmanagement, Klima & Biodiversität), forscht zu Habitatwahl, Populationsdynamik, nachhaltiger Jagd, Monitoring; es gibt Gams-Arbeiten (u.a. Publikation zu Gams in Österreich, Reiner 2020) und "BOKU Berichte zur Wildtierforschung". Kontakt: iwj@boku.ac.at, Gregor-Mendel-Str. 33, 1180 Wien.
**Nicht gefunden / nicht belegt:** ein offener, alters-gelabelter Gams-Bilddatensatz. [→ keine Annahme, dass er existiert]

**Wir bieten:** Master-/Bachelor-Arbeits-Andockpunkt (Studierende validieren KI-Ansprache gegen Zahnschliff-Referenz), Praxisdaten aus AT-Reviern (Steiermark-Region taucht im Code schon auf), Co-Autorenschaft bei Validierungs-Paper.
**Wir bekommen:** wissenschaftliche Methodik für Alters-Validierung, ggf. Zugang zu Referenz-Kiefersammlungen/Schliffdaten, akademische Glaubwürdigkeit im DACH-Raum.
**Ansprache:** über konkretes Studienprojekt-Angebot — Unis nehmen ein "fertiges, finanziert-freies Praxis-Tool als Forschungsgegenstand" eher als reine Datenanfrage.

### 2.3 DeerAI — direkt relevant, prüfen ob Partner oder Vorbild

**Verifiziert:** **DeerAI ist ein FFG-gefördertes Projekt** (Österreich, projekte.ffg.at/projekt/4352932) zur KI-gestützten Detektion, Kategorisierung und **Re-Identifikation** von Wild aus Wildkamera-Massendaten — **explizit inkl. Gams**, Rotwild, Reh, Schwarzwild, Wolf, Luchs, Bär, Fuchs, Dachs. Methodisch: adaptive/Transfer-Learning, Domain Adaptation.
**Lesart:** Überlappt in der Bildverarbeitung, aber Fokus = Re-ID/Monitoring aus Camera-Traps, nicht Alters-/Geschlechts-Ansprache für die Erleger-Entscheidung. **Potenzieller Datenpartner ODER methodischer Benchmark.** Klären, ob ihr Datensatz/Modell zugänglich ist.

### 2.4 Rotwild-ID (LJV Schleswig-Holstein) — Open-Source-Hebel SOFORT prüfbar

**Verifiziert:** Projekt "Rotwild-ID" des LJV Schleswig-Holstein — KI erkennt Rothirsche am Gesicht, **Code UND Datensatz wurden Open Source veröffentlicht**, "damit Wissenschaft und Praxis darauf aufbauen können".
**Quick-Action:** Lizenz + Inhalt prüfen — falls Rotwild-Bilder mit Individuen-/Alters-Annotation enthalten sind, ist das ein *sofort nutzbarer* externer Datenzufluss für den Rotwild-Zweig (ohne Verhandlung). Selbst ohne Alters-Label nützlich als Vortraining/Spezies-Robustheit.

### 2.5 Hegegemeinschaften, Forstbetriebe, Jagdschulen, Landesjagdverbände

**Verifiziert (allgemein, kein Einzel-Claim):** Es gibt kommerzielle Jäger-KI-Apps mit "Training macht Trefferquote besser"-Mechanik (Revierwelt/Deermapper) — d.h. das Flywheel-Konzept ist im Markt validiert; wir sind nicht allein, aber Alters-/Geschlechts-Ansprache als Schärfe ist eine Differenzierung. [Wettbewerbslage = verifiziert vorhanden; deren genaue Datenqualität = unbekannt]
**Annahme/Hypothese für Ansprache (NICHT verifiziert):**
- **Hegegemeinschaften** führen ohnehin Streckenlisten + Altersstrukturauswertung → unser digitales Hegebuch nimmt Arbeit ab, wir bekommen aggregierte verifizierte Altersdaten. *Stärkster organischer Partner-Hebel*, weil Interessen deckungsgleich (Hege = Altersstruktur).
- **Forstbetriebe (z.B. Bayerische Staatsforsten)**: Eigenjagden mit Abschussplan-Druck → Tool-Mehrwert; liefern strukturierte Erlegerdaten. (Ob Daten teilbar = zu klären.)
- **Jagdschulen**: ideal für *Sicht*-Trainingsdaten + Reichweite (jeder Jungjäger lernt Ansprache) — aber Sicht ≠ Ground Truth, daher Reichweiten-, kein GT-Hebel.

- **Aufwand Partnerschaften gesamt:** hoch (Beziehungsarbeit, Monate, teils Alex persönlich/Gate). Pilotansprache je Stelle aber klein.
- **Wirkung:** hoch und nachhaltig, aber langsam. Nicht launch-kritisch.

---

## 3. Mehrwert-Features, die NEBENBEI Daten erzeugen

Leitidee: Features, die der Jäger **ohnehin nutzen würde**, und bei denen das Datenlabel als Nebenprodukt anfällt. So entsteht GT ohne "bitte trag Daten für unsere KI ein"-Reibung.

| Feature | Eigennutzen für Jäger | Daten-Nebenprodukt | Aufwand | Status im Repo |
|---|---|---|---|---|
| **Digitales Revierbuch / Streckenliste** | Pflicht-Doku abgenommen, gesetzeskonform, exportierbar | strukturierte Erleger-Datensätze (Art/Alter/Geschlecht/Datum/Ort) | mittel | Streckenblatt-Share existiert, Streckenliste als Datenobjekt fehlt |
| **Abschussplan-/Hege-Management** | Soll/Ist je Altersklasse, Restabschuss-Übersicht | Altersklassen-Verteilung pro Revier = verifizierte Labels | mittel-hoch | nicht vorhanden |
| **GamsBook/Lookbook (Individuen über Saisons)** | Reviergeschichte, Wiedererkennung, "kennt seine Stücke" | longitudinale Bilder desselben Tiers mit fortschreitendem Alter | klein (Ausbau) | Keim vorhanden (`gamsbook_screen.dart`) |
| **Trophäenbewertung (CIC-Formel)** | Medaillen-Einschätzung sofort am Stück | Maße/Gewicht/Alter-Korrelate, oft mit Alter assoziiert | klein-mittel | nicht vorhanden |
| **Wildkamera-Integration / Bild-Import** | Massen-Sichtung durchsuchbar, Auto-Tagging | großes Bildvolumen (Spezies/Geschlecht, selten Alter) | hoch | nicht vorhanden |
| **Erleger-Foto-Doku (Kiefer/Krucke)** | digitale Trophäen-/Nachweis-Ablage | zweites Bild + verifiziertes Alter desselben Individuums | klein | Foto-Upload-Infra teils da |

**Priorität innerhalb (3):** Digitales **Revierbuch + Abschussplan-Management** ist der größte Doppelnutzen — es ist der Grund, warum der Jäger die App *außerhalb* der Ansprache öffnet (Retention) UND es liefert genau die verifizierte Altersstruktur. Trophäenbewertung (CIC) ist ein billiger, attraktiver Lock-In mit Alters-Korrelation. Wildkamera-Integration ist mächtig fürs Volumen, aber teuer und liefert kaum *Alters*-Label → später.

---

## 4. Quick-Wins (<2 Wochen) vs. mittelfristig

### Quick-Wins (≤2 Wochen, größtenteils selbst umsetzbar)

| # | Maßnahme | Aufwand | Wirkung | Abhängigkeit |
|---|---|---|---|---|
| Q1 | **"Alter nachtragen nach Erlegung"-Flow** (1.1) — App-Banner + Eingabemaske + `methode`-Gewichtung; Sample auf `verified=true` upgraden. Backend-Hook `/feedback`+`methode` existiert. | 3-5 d | **sehr hoch** (DER GT-Kanal) | — |
| Q2 | **GPS + `app_version` + `model/prompt_version` an `/analyze` durchreichen & persistieren** (Audit P1 #5/#6). Macht *jedes* Sample ab sofort trainingswertvoll. | 1-2 d | hoch | — |
| Q3 | **Original-/höhere Auflösung für eingewilligte Samples speichern** (Audit P1 #7). | 0,5 d | mittel-hoch | — |
| Q4 | **Rotwild-ID Open-Source-Datensatz prüfen & ggf. einbinden** (2.4) — Lizenz + Alters-Annotation checken. | 0,5-1 d | mittel (externer Gratis-Zufluss) | rechtlich prüfen |
| Q5 | **Trainings-Samples ↔ Sightings über `pseudonym_id` verknüpfbar machen** (Audit C.2) — schließt zugleich DSGVO-Löschrecht. | 2 d | hoch (Datenwert + P0-DSGVO) | — |
| Q6 | **DSGVO-Minimum** (Datenschutzerklärung real anlegen, USA-Transfer-Consent, Löschrecht) — **GATE/Recht, blockiert legales Skalieren.** | extern/Recht | P0 (legal) | Alex/Recht |

### Mittelfristig (Wochen–Monate)

- **M1 — Digitales Revierbuch + Abschussplan-Management** (Abschnitt 3): größter Retention+Daten-Doppelnutzen.
- **M2 — Lookbook/GamsBook-Ausbau** auf Supabase (longitudinale Individuen, geteilte Reviergeschichte) + Hege-Bestenliste.
- **M3 — Persistenz konsolidieren:** Trainings-Samples von losen Dateien → Supabase Postgres+Storage (EU), gejoint mit Sightings (Audit C.1). Burggraben-Kern.
- **M4 — Partnerschafts-Pilots:** LWF (Schalenwildprojekt/AI4Wildlife-Andockung), BOKU (Studienprojekt-Validierung), 1-2 Hegegemeinschaften als Leuchtturm. Teils Alex persönlich (Gate).
- **M5 — Trophäenbewertung (CIC)** + Erleger-Kiefer/Krucken-Foto-Doku als billiger Daten-Nebenprodukt-Lock-In.

---

## 5. Risiken / ehrliche Einordnung

- **GT-Volumen bleibt der Flaschenhals:** Selbst mit perfektem Flow tragen nur wenige Jäger erlegtes Alter nach. Rechnung: realistisch erzeugt jede aktive Hege-Region pro Saison vielleicht Dutzende bis wenige Hundert verifizierte Paare. Das ist *qualitativ* Gold, aber *quantitativ* klein → Few-Shot/Modell-Feintuning-Strategie, nicht "Big Data von Tag 1".
- **Wettbewerb existiert** (Revierwelt, Deermapper, DeerAI, LWF-eigene KI) — verifiziert. Differenzierung muss die **Alters-/Geschlechts-Ansprache + Erleger-Ground-Truth-Loop** sein, nicht "noch eine Wilderkennung".
- **Camera-Trap-Datensätze (iWildCam, LILA BC, Wildlife Insights, GBIF/iNaturalist) sind verfügbar, aber praktisch ohne Alters-Label** — verifiziert. Nützlich für Spezies-Robustheit/Vortraining, NICHT für den Alters-Burggraben. Nicht als Alters-GT-Quelle einplanen.
- **DSGVO ist ein hartes Tor** (Abschnitt 4/Q6): ohne Datenschutzerklärung + Löschrecht + USA-Transfer-Consent ist *legales* Sammeln im Maßstab blockiert. Erst lösen, dann skalieren.

---

## 6. Quellen (Recherche-Stand 2026-06)

- LWF AI4Wildlife: https://www.lwf.bayern.de/wildtierbiologie/wildtierforschung/343312/index.php
- LWF KI-Wildtiermonitoring: https://www.lwf.bayern.de/service/presse/327057/index.php
- LWF Schalenwildprojekt JA14: https://www.lwf.bayern.de/schalenwildprojekt
- LWF–Thünen Kooperation: https://www.lwf.bayern.de/service/presse/384812/index.php
- BOKU IWJ: https://boku.ac.at/en/oekb/wild
- BOKU Berichte zur Wildtierforschung: https://boku.ac.at/oekb/wild/berichte-und-gutachten/boku-berichte-zur-wildtierforschung
- DeerAI (FFG): https://projekte.ffg.at/projekt/4352932
- Rotwild-ID (LJV-SH, Open Source): https://ljv-sh.de/kuenstliche-intelligenz-erkennt-rothirsche-am-gesicht-ljv-stellt-ergebnisse-von-rotwild-id-vor/
- Camera-Trap-Datensätze: https://lila.science/otherdatasets/ , https://www.wildlifeinsights.org/get-started/data-download/public

**Kennzeichnung:** Institutionelle Fakten oben sind per WebSearch verifiziert; Ansprache-Hypothesen (was Partner geben/wollen) und Jäger-Motivationsannahmen sind als **Annahme** markiert und vor Umsetzung mit der jeweiligen Stelle / Zielgruppe zu validieren. Keine erfundenen Datensätze oder Zusagen unterstellt.
