# Strategie — Tier-Identität & revierübergreifendes Netzwerk

**Datum:** 2026-06-09
**Scope:** Konzept für zwei verbundene Zukunfts-Features der App *Gamssinn* (KI-Wildansprache).
**Methodik:** Statische Code-Analyse (`lib/`), Abgleich mit `docs/data_flywheel_audit.md`. Ehrliche Machbarkeit, kein Wunschdenken.
**Adressiert:** Alex-Frage 4 (individuelle Wiedererkennung) + Frage 5 (revierübergreifende Zusammenführung).

---

## 0. IST-Zustand (was schon im Code lebt)

Wichtig vorab — Gamssinn hat hier **mehr Substanz als ein Greenfield-Konzept**. Was bereits existiert:

| Baustein | Datei | Status |
|---|---|---|
| Individuum-Modell ("bekannte Gams") | `lib/models/gams_individual.dart` | ✅ inkl. `firstSeen`/`lastSeen`/`sightings`/`region`/`wildart`/`geburtsjahrgang`/`tatsaechlichesAlter` |
| Sichtung mit Foto + GPS | `lib/models/sighting.dart` | ✅ `latitude`/`longitude`/`photos[]`/`estimate` |
| Heuristische Re-ID-Engine | `lib/services/recognition_service.dart` | ✅ Geo (≤5 km) + Alters-Plausibilität (Alter kann nur steigen) + Geschlecht + Altersklassen-Überlappung → Score 0–100 |
| Human-in-the-loop-Dialog "Bekannte Gams?" | `lib/screens/analysis_screen.dart:568-644` | ✅ schlägt Top-3-Matches vor, Jäger bestätigt |
| Lokale Persistenz GamsBuch | `lib/services/database_service.dart` | ✅ SharedPreferences (lokal, pro Gerät) |
| Cloud-Sichtungen + Community | `lib/services/sightings_service.dart` | ✅ Supabase-Tabelle `sightings` mit `shared`-Flag + `getCommunitySightings()` |
| Auth / Pseudonym-Träger | `lib/services/auth_service.dart` | ✅ Supabase Auth, `profiles(username, revier, region)` |

**Konsequenz:** Feature A ist **kein Neubau, sondern ein Upgrade** der vorhandenen `RecognitionService`-Heuristik um (a) stabile visuelle Anker und (b) Cloud-Sync. Feature B ist die **Hochskalierung** des bereits existierenden `shared`-Sichtungs-Mechanismus zu einem echten Tier-Graphen — mit dem Datenschutz-Sprung als Kernaufgabe.

Die Re-ID-Heuristik macht heute schon das fachlich Richtige: Sie nutzt **keine** Geweih-Form als Primärschlüssel, sondern Geo + monotones Alter + Geschlecht. Das ist die korrekte Antwort auf das Abwurf-Problem (s. A.2).

---

# FEATURE A — Individuelle Tier-Wiedererkennung / Re-ID

> *„Ein Hirsch, ein Jahr später erneut fotografiert, soll als bekannter Hirsch X erkannt werden."*

## A.1 Das Kernproblem ehrlich benannt

Wildtier-Re-ID ist **nicht** Gesichtserkennung. Drei harte Wahrheiten:

1. **Das auffälligste Merkmal ist das instabilste.** Geweih/Krucken sind das, was der Jäger zuerst sieht — und genau das, was sich am stärksten ändert (Rotwild: jährlicher Abwurf; Gams: Krucken wachsen lebenslang weiter, ändern aber Länge/Hakung). Ein naiver „Geweih-Fingerprint" matcht denselben Hirsch über zwei Jahre **nicht**.
2. **Verifizierbare Ground Truth ist extrem rar.** Wir wissen fast nie objektiv, dass Foto A (2024) und Foto B (2025) dasselbe Tier zeigen — außer das Tier wurde erlegt und der Jäger bestätigt es. Ohne gelabelte Same/Different-Paare kann man Re-ID-Genauigkeit nicht sauber messen und kein Modell sauber trainieren.
3. **Die Basisrate killt die Präzision.** In einem Revier mit 40 Stück Rotwild und einem ähnlich aussehenden Alterssegment ist „sieht ähnlich aus" fast wertlos. Re-ID ist nur dort stark, wo der Suchraum klein ist (= ein Revier, ein Geschlecht, eine Altersklasse, ein geografischer Cluster).

**Fazit der Wahrheit:** Vollautomatische, hochpräzise Re-ID über Jahre ist **Vision, nicht MVP**. Realistisch ist ein **Vorschlagssystem mit Mensch-in-der-Schleife** — und genau das ist bereits angelegt.

## A.2 Optionen — ehrliche Bewertung

### Option 1 — Geweih/Krucken-Morphologie als Fingerprint
- **Idee:** Enden zählen, Form/Asymmetrie/Hakung als Merkmalsvektor.
- **Pro:** Für den Jäger intuitiv; bei Rotwild-Abnormitäten (z.B. markante Auslage, Eissprosse, Perückenbildung) sehr aussagekräftig *innerhalb einer Saison*.
- **Contra / Genauigkeitsgrenze:**
  - **Rotwild:** Geweih wird jährlich neu aufgesetzt → als Cross-Year-Schlüssel **unbrauchbar**. Form korreliert nur lose über Jahre (Veranlagung), nicht 1:1.
  - **Gams:** Krucken sind stabiler (kein Abwurf), wachsen aber weiter; Jahrringe („Schieben") sind eher Alters- als Identitätsmerkmal.
  - 2D-Foto-Geometrie ist perspektiv- und blickwinkelabhängig → Form-Features schwanken stark mit dem Aufnahmewinkel.
- **Verdikt:** Taugt als **Within-Season-Signal** und als **Veranlagungs-Hinweis** ("kapitaler Ungerader") — **nicht** als jahresübergreifender Primärschlüssel.

### Option 2 — Visuelle Embeddings + Vektor-Ähnlichkeitssuche (Re-ID-Modell)
- **Idee:** Ein CNN/ViT erzeugt pro Tierbild einen Embedding-Vektor; Wiedererkennung = Nearest-Neighbour in einem Vektorindex (pgvector / Qdrant), eingeschränkt auf Revier+Wildart.
- **Pro:** State of the art für Wildlife-Re-ID (vgl. WildlifeReID/MegaDescriptor-Ansätze); lernt **Fell-/Körper-/Musterzeichnung**, also stabilere Anker als Geweih.
- **Contra / Genauigkeitsgrenze:**
  - Braucht entweder ein vortrainiertes Wildlife-Re-ID-Backbone (allgemein, nicht art-spezifisch fein) **oder** eigene gelabelte Paare (haben wir nicht → Henne-Ei).
  - Embeddings sind **blickwinkel-, jahreszeit- (Sommer-/Winterdecke!) und beleuchtungssensibel**. Derselbe Gamsbock im roten Sommerhaar vs. schwarzem Winterhaar liegt im Embedding-Raum weit auseinander.
  - Läuft serverseitig (Backend hat Bild bereits) → passt zur Architektur, kostet aber GPU/Inferenz.
- **Verdikt:** **Das richtige Mittel-/Langfrist-Ziel.** Kurzfristig als *zusätzliches* Score-Signal in die bestehende Heuristik einspeisbar, nicht als Alleinentscheider.

### Option 3 — Nutzergestützte Identität ("das ist mein Platzhirsch")
- **Idee:** Der Jäger legt Individuen selbst an und tagged neue Fotos manuell.
- **Pro:** **Sofort verfügbar, 100 % im Code vorhanden** (`addIndividual`/`addSighting`). Liefert nebenbei genau die **gelabelten Same-Tier-Paare**, die Option 2 zum Training braucht → Daten-Flywheel.
- **Contra:** Manuelle Arbeit; Verzerrung durch menschlichen Irrtum (Jäger ist sich auch nicht immer sicher).
- **Verdikt:** **Das Fundament.** Jede automatische Re-ID baut auf diesem von Menschen kuratierten Label-Bestand auf.

### Option 4 — Hybrid mit Mensch-in-der-Schleife (Empfehlung)
- **Idee:** System **schlägt vor**, Mensch **entscheidet** — „Ist das Hirsch X?" Bestätigung/Ablehnung fließt als Label zurück.
- **Pro:** Vereint alle drei Signale (Geo, monotones Alter, Embedding) zu einem Score; jede Antwort verbessert das Modell; rechtlich/UX-sicher (kein falscher Auto-Match).
- **Contra:** Keiner relevant — das ist der etablierte Weg in Wildlife-Re-ID-Produkten.
- **Verdikt:** **Zielarchitektur.** Genau das tut `analysis_screen.dart:568` heute schon — nur ohne Embedding-Signal und ohne Cloud-Sync.

## A.3 Umgang mit dem Abwurf-Problem (explizit)

Die Re-ID darf sich **nie primär auf das Geweih stützen**. Stabilitäts-Hierarchie der Anker (von stabil → instabil):

1. **Permanente Körpermerkmale** — Narben, Schalenbrüche, fehlendes Auge, Fellwirbel, Pigmentflecken, Ohr-/Lauschereinrisse. Stabilster Anker, aber selten markant genug.
2. **Körperstatur & Proportionen** — Rumpflänge, Trägerstärke, Widerristhöhe (perspektivabhängig, aber über Embeddings teils erfassbar).
3. **Fell-/Decken-Zeichnung** — bei Gams Gesichtsmaske/Aalstrich, bei Reh-/Rotwild individuelle Tönung. **Achtung Saisonalität:** Sommer- vs. Winterdecke → Embedding muss saisonrobust sein oder Saison als Kontext mitführen.
4. **Geo + monotones Alter** (kein Bildmerkmal, sondern Plausibilität) — *bereits implementiert*, der zuverlässigste „weiche" Filter.
5. **Geweih/Krucken** — nur **Within-Season** als starkes Signal; cross-year nur als schwacher Veranlagungs-Hinweis.

→ Praktisch: Geweih-Features bekommen ein **Zeitfenster-Gating**. Liegt die letzte Sichtung in derselben Brunft-/Saison-Periode, darf Geweih-Ähnlichkeit hoch gewichten; über einen Abwurf hinweg wird sie auto-abgewertet.

## A.4 Machbarkeit (zeitlich)

- **Kurzfristig (vorhanden → härten):** Heuristik (Geo + monotones Alter + Geschlecht) + manuelles Tagging + Vorschlagsdialog. **Steht im Code.** To-do: Cloud-Sync des GamsBuchs (heute nur lokal in SharedPreferences → bei Geräteverlust weg), Markieren permanenter Merkmale, Saison-/Within-Season-Gating für Geweih.
- **Mittelfristig:** Server-Embedding-Modell (vortrainiertes Wildlife-Re-ID-Backbone) als **zusätzliches Score-Signal**; Vektorindex pro `(revier, wildart)`; jede Mensch-Bestätigung wird Trainingslabel.
- **Langfristig:** Fein-getuntes art-spezifisches Re-ID-Modell (Gams/Reh/Rotwild getrennt) auf dem **selbst kuratierten** Same/Different-Bestand; saisonrobuste Embeddings; optional Multi-Foto-Galerie pro Individuum für robusteren Match.

## A.5 MVP-Vorschlag (Feature A)

**„Bestätigtes GamsBuch mit Cloud-Sync + Merkmals-Tags"** — baut nur auf Vorhandenem auf:

1. **GamsBuch in die Cloud** — `GamsIndividual` + `Sighting` von SharedPreferences (`database_service.dart`) nach Supabase spiegeln (Tabellen `individuals`, `individual_sightings`), an `pseudonym_id`/`user_id` gebunden. Behebt nebenbei die im Audit notierte Datenverlust-Lücke.
2. **Merkmals-Tags** — beim Anlegen/Bestätigen eines Individuums optionale Checkbox-Anker: „Narbe", „Lauscher-Einriss", „auffällige Decke", Freitext. Diese fließen mit hohem Gewicht in `RecognitionService`.
3. **Geweih-Gating** — `RecognitionService` um Saison-Logik erweitern: Geweih-Ähnlichkeit nur innerhalb derselben Saison hoch gewichten.
4. **Vorschlag → Label** — bestehender „Bekannte Gams?"-Dialog: jede Ja/Nein-Antwort als `match_label` (same/different) persistieren → Trainingsbestand für späteres Embedding-Modell.
5. **(Optional, Mittelfrist-Vorbereitung)** Embedding pro Sichtungsfoto serverseitig berechnen und in `pgvector` ablegen — als reines Zusatz-Signal, vorerst ohne UI.

**Bewusst NICHT im MVP:** automatischer Cross-Year-Match ohne Bestätigung; Geweih-als-Primärschlüssel; eigenes trainiertes Modell.

## A.6 Architektur-Skizze (Feature A)

```
[App: neues Foto + GPS + Datum]
        │
        ▼
[Vision-Analyse /analyze]  ──►  estimate (Wildart/Alter/Geschlecht/Scoring)
        │
        ▼
[RecognitionService.findMatches]      Kandidaten = Individuen in (Revier, Wildart)
   Signal 1: Geo ≤ 5 km                                  (✅ vorhanden)
   Signal 2: Alter monoton + zeitplausibel               (✅ vorhanden)
   Signal 3: Geschlecht                                  (✅ vorhanden)
   Signal 4: permanente Merkmals-Tags                    (NEU, hohes Gewicht)
   Signal 5: Geweih-Ähnlichkeit × Saison-Gate            (NEU, konditional)
   Signal 6: Bild-Embedding-Distanz (pgvector)           (Mittelfrist, Zusatz)
        │  Score 0–100
        ▼
[Dialog "Ist das Hirsch X?"]  ── Ja/Nein ──►  match_label (same/different)
        │                                            │
        ▼                                            ▼
[GamsBuch: Sichtung an Individuum]          [Trainingsbestand für Re-ID-Modell]
        │
        ▼
[Supabase: individuals / individual_sightings  @ pseudonym_id]
```

## A.7 Top-3-Risiken (Feature A)

1. **Falsch-positive Matches untergraben Vertrauen.** Ein falsch zusammengeführter „Hirsch X" verfälscht den Lebenslauf und ärgert den Jäger. → Gegenmittel: nie auto-mergen, immer bestätigen lassen; konservative Schwelle; Merge **rückgängig machbar**.
2. **Saisonale Decke + Blickwinkel sprengen Embeddings.** Sommer-/Winterhaar = großer Embedding-Abstand beim selben Tier. → Saison als Kontext mitführen, Embedding nur als Zusatzsignal, Schwellen pro Saisonpaar kalibrieren.
3. **Kein objektives Ground Truth → Genauigkeit unbelegbar.** Ohne Zahnschliff/Erleger-Bestätigung bleibt „same" eine Jäger-Meinung. → die bereits vorhandene `methode`-Qualifizierung (`zahnschliff`/`erleger`/`sicht`, s. Audit A.3) als Vertrauensgewicht der Labels nutzen.

---

# FEATURE B — Globale, revierübergreifende Tier-Zusammenführung

> *„Dasselbe Tier, fotografiert von verschiedenen Nutzern in (angrenzenden) Revieren — Lebenslauf zusammenführen, OHNE exakte Standorte zu verraten."*

## B.1 Das Spannungsfeld ehrlich benannt

Der Mehrwert (ein Tier = viele Sichtungen vieler Jäger = echter Lebenslauf, „dein Bock wurde 8 km weiter gesehen") **kollidiert frontal mit der Jäger-Kultur**:

- **Standort = Tabu.** Wo „mein" Hirsch steht, teilt kein Jäger freiwillig — Wilderei-Risiko, Reviereifersucht, Pacht-Konkurrenz. Exakte Koordinaten sind die roteste Linie.
- **Reviergrenzen sind sensibel** (Pacht, Nachbarschaftsstreit). Schon das Offenlegen, *dass* zwei Reviere dasselbe Tier teilen, kann Konflikt erzeugen.
- **Asymmetrie:** Der Beitragende trägt das ganze Risiko (verrät Info), der Nutzen (Netzwerk-Effekt) entsteht erst bei vielen Teilnehmern → klassisches Kaltstart-/Trittbrettfahrer-Problem.

**Designprinzip daraus:** *Aggregat-Mehrwert ohne Standort-Preisgabe.* Nie exakte Koordinaten, nie Reviergrenzen, nie „User Y hat es hier gesehen" — sondern unscharfe, aggregierte, opt-in, pseudonyme Signale.

## B.2 Datenmodell (ein Tier = viele Sichtungen vieler Nutzer)

Zwei Ebenen strikt trennen:

- **Privat (Default, niemals geteilt):** alles aus Feature A — exakte GPS, GamsBuch-Namen, Fotos. Bleibt an `user_id`/`pseudonym_id` gebunden, RLS-geschützt.
- **Netzwerk (nur opt-in, unscharf):** ein **`network_animal`** = Cluster aus Sichtungen, der von mehreren Nutzern als „dasselbe Tier" geteilt wurde.

```
network_animal
  ├─ network_animal_id (UUID, pseudonym — kein Klarname)
  ├─ wildart, geschlecht, alterssegment (grob: "mittelalt", nicht "7,3 J.")
  ├─ merkmale[] (nur grob/anonym: "kapital ungerade", "Narbe re. Träger")
  ├─ geohash_prefix  ← UNSCHARF: nur 5-stelliger Geohash (~±2,4 km Zelle),
  │                     NIE exakte lat/lon. Ggf. nur 4-stellig (~±20 km).
  ├─ sichtungs_zeitfenster (Monat/Saison, nicht Tag)
  └─ confidence (Cross-User-Match-Güte)

network_animal_link  (welche privaten Sichtungen hängen am Cluster)
  ├─ network_animal_id
  ├─ private_sighting_id  (nur serverseitig / RLS, nie an andere User ausgespielt)
  ├─ pseudonym_id (Beitragender, pseudonym)
  └─ shared_at
```

**Kernregel:** Andere Nutzer sehen **nur** das `network_animal`-Aggregat (Wildart, grobes Alterssegment, grobe Merkmale, **Geohash-Zelle**, **Saison**). Sie sehen **nie** die exakte Position, **nie** den Klarnamen des Reviers, **nie** wer beigetragen hat.

## B.3 Matching-Logik (Cross-User)

1. **Kandidatensuche** nur über grobe Filter: gleiche Wildart, kompatibles Geschlecht, plausibles Alterssegment (monoton!), **benachbarte Geohash-Zellen** (Streifgebiet wechselt Reviere meist nur lokal).
2. **Merkmals-Match** über die groben, anonymen Merkmals-Tags + (mittelfristig) Embedding-Distanz — **alles serverseitig**, das rohe Bild verlässt nie die Privat-Ebene.
3. **Schwellen-Gating:** Cross-User-Merge ist riskanter als Eigen-Merge → **höhere Schwelle**, und **immer beidseitige Bestätigung** ("Ein anderer Jäger meldet ein Tier, das deinem ähnelt — verbinden?"). Kein stiller Auto-Merge über Reviergrenzen.
4. **Konfliktauflösung** (zwei Nutzer, widersprüchliche Angaben — z.B. unterschiedliches Alter/Geschlecht):
   - **Vertrauensgewicht nach Methode:** `zahnschliff` > `erleger` > `sicht` (Feld existiert bereits, Audit A.3).
   - **Aktualität:** jüngste Sichtung gewinnt für „aktueller Status", Historie bleibt als Zeitreihe erhalten (kein Überschreiben).
   - **Erleger-Endknoten:** Wird ein Tier als erlegt gemeldet, wird der Lebenslauf **geschlossen** — spätere „Sichtungen" desselben Clusters sind dann Fehl-Matches und werden geflaggt.
   - **Mehrheits-/Konsens-Logik** nur als schwaches Signal; nie Standort-Konflikte automatisch auflösen.

## B.4 Datenschutz-Architektur (der eigentliche Kern)

Nicht-verhandelbare Schutzschichten:

1. **Opt-in, granular, pro Tier.** Default = nichts geteilt. Teilen passiert **bewusst pro Individuum** („Diesen Bock zum Netzwerk beitragen"), nicht global per Settings-Schalter. Baut auf vorhandenem `shared`-Flag (`sightings_service.dart`) auf, aber als bewusste Einzelaktion.
2. **Geo-Unschärfe by design.** Ausgespielt wird **nur ein Geohash-Präfix** (Zellengröße konfigurierbar, Default grob ~ Gemeinde-/Talschaft-Ebene, nicht Revier). Exakte lat/lon bleiben serverseitig RLS-geschützt und werden **nie** an andere User serialisiert. Optional: Jäger wählt selbst die Unschärfe-Stufe.
3. **Pseudonymität.** Beiträge tragen `pseudonym_id`, nie Klarname/Revier. Andere sehen „ein anderer Jäger in der Region", nie wer.
4. **k-Anonymität / Aggregations-Schwelle.** Ein `network_animal` wird anderen erst sichtbar, wenn ≥ k unabhängige Sichtungen/Nutzer beigetragen haben (k ≥ 3), damit kein Einzel-Standort rekonstruierbar ist. Solo-Cluster bleiben unsichtbar.
5. **Kein Heatmap-/Live-Standort.** Keine Karte mit Pins. Mehrwert wird **textuell/aggregiert** kommuniziert („zuletzt im Spätherbst, eine Talschaft weiter, mittelalt"), nicht kartografisch punktgenau.
6. **Reviergrenzen sind tabu** — werden weder erhoben noch angezeigt. Nur Geohash-Zellen, die bewusst **nicht** auf Reviere gemappt sind.

## B.5 Anreizmodell (warum trägt ein Jäger bei?)

Ohne Anreiz tragen die wenigsten bei (Risiko-Asymmetrie). Hebel, in Reihenfolge der Stärke:

1. **Reziprozität / Gating:** Lebenslauf-Aggregate anderer sehen nur, wer selbst (opt-in) beiträgt. „Gib unscharf, sieh unscharf." Stärkster Hebel, fair.
2. **Persönlicher Lebenslauf-Mehrwert:** „Dein Bock wurde nach deiner letzten Sichtung noch lebend bestätigt" / „taucht seit 2 Jahren nicht mehr auf" — Wissen, das der Einzeljäger allein nie hätte. Das ist der emotionale Kern.
3. **Hege-/Bewirtschaftungsnutzen:** revierübergreifende, anonyme Alters-/Geschlechterstruktur als Hege-Argument (Hegegemeinschaften denken ohnehin revierübergreifend).
4. **Gamification (dezent):** „verifizierter Beobachter", Beitrag zur Wissenschaft/Citizen-Science — **ohne** Standort-Wettbewerb (kein „wer hat den Kapitalen", das befeuert genau die falsche Eifersucht).

## B.6 Missbrauchsschutz

- **De-Anonymisierung verhindern:** k-Anonymität + Geohash-Unschärfe + Rate-Limiting der Netzwerk-Abfragen (kein Scrapen vieler Zellen, um einen Standort zu triangulieren).
- **Wilderei-Schutz:** nie aktueller/präziser Standort; Saison-statt-Datum; Erleger-Endknoten schließt Tier. Frische + Präzision werden bewusst gegen Schutz eingetauscht.
- **Sybil/Fake-Sichtungen:** Beitrag an authentifizierten Account + Foto-Provenienz (EXIF/Server-Timestamp) koppeln; Massen-Fake-Cluster über Plausibilitäts-/Rate-Checks flaggen.
- **Recht auf Vergessen greift durch:** Zieht ein Nutzer Beitrag/Account zurück (Audit-`DELETE /my-data`), werden seine `network_animal_link`s entfernt; fällt ein Cluster dadurch unter k, wird er wieder unsichtbar.

## B.7 Machbarkeit (zeitlich)

- **Kurzfristig:** **Bewusst NICHT bauen.** Erst Feature A (Eigen-Re-ID + Cloud-GamsBuch + Datenschutz-Basis aus dem Audit: Pseudonym-ID, Löschrecht, Datenschutzerklärung) muss stehen. Netzwerk ohne saubere Privacy-Basis = Reputations-/Rechts-GAU.
- **Mittelfristig:** opt-in-Teilen **pro Individuum** + Geohash-Unschärfe + `network_animal`-Aggregat mit k-Anonymität + beidseitig bestätigter Cross-User-Merge. Rein heuristisch (Geo-Zelle + Alter + grobe Merkmale), noch ohne Embedding.
- **Langfristig:** Embedding-gestütztes Cross-User-Matching, Hegegemeinschafts-Features, anonyme Bestandsstatistik. Skaliert nur mit Nutzerdichte (Netzwerk-Effekt → Kaltstart-Problem real).

## B.8 MVP-Vorschlag (Feature B)

**„Unscharfes Lebenszeichen, opt-in, pro Tier" (frühestens nach Feature A + Audit-P0):**

1. Pro GamsBuch-Individuum Schalter „Zum anonymen Netzwerk beitragen" (Default aus).
2. Beim Beitrag wird **nur** geteilt: Wildart, grobes Alterssegment, grobe Merkmale, **Geohash-Präfix** (grob), **Saison**, `pseudonym_id`. **Nie** exakte GPS/Fotos/Revier.
3. Server bildet `network_animal`-Cluster; **erst ab k ≥ 3** für andere sichtbar.
4. Reziprozitäts-Gate: Aggregate sehen nur Beitragende.
5. Einziger Rück-Mehrwert im MVP: textuelles „Lebenszeichen" („ein ähnliches Tier wurde diese Saison eine Zelle weiter gemeldet") — **keine Karte, keine Pins, kein Klarname**.

## B.9 Architektur-Skizze (Feature B)

```
        PRIVAT-EBENE (RLS, nie geteilt)
  individuals / individual_sightings  ── exakte GPS, Fotos, Namen
        │  (Nutzer wählt bewusst: "beitragen")
        ▼
  ┌─ Anonymisierungs-Gateway (serverseitig) ─────────────────┐
  │  lat/lon  → geohash_prefix (grob)                         │
  │  alter    → alterssegment (grob)                          │
  │  datum    → saison                                        │
  │  user     → pseudonym_id                                  │
  │  Foto     → BLEIBT privat (nur Embedding optional)        │
  └───────────────────────────────────────────────────────────┘
        ▼
  network_animal_link ──► Cross-User-Matching (Geohash-Nachbarn
        │                  + monotones Alter + grobe Merkmale)
        ▼
  network_animal (Aggregat)
        │  Sichtbarkeits-Gate: nur ab k ≥ 3 Beiträge
        │  + Reziprozitäts-Gate: nur für Beitragende
        ▼
  [App: "Lebenszeichen" — textuell, unscharf, ohne Karte]
        ▲
  Cross-User-Merge nur mit BEIDSEITIGER Bestätigung
```

## B.10 Top-3-Risiken (Feature B)

1. **Datenschutz-/Vertrauens-GAU.** Eine einzige wahrgenommene Standort-Leakage zerstört die Akzeptanz in der Jägerschaft dauerhaft (enge, vernetzte Community). → Privacy-by-Design hart erzwingen: nie exakte Koordinaten serialisieren, k-Anonymität, Unschärfe als nicht-abschaltbarer Default, externes Datenschutz-Review vor Launch.
2. **Kaltstart / Netzwerk-Effekt fehlt.** Ohne kritische Nutzerdichte pro Region gibt es keine Cross-User-Matches → kein Mehrwert → keine Beiträge (Henne-Ei). → Erst Eigen-Mehrwert (Feature A) liefern, der ohne Netzwerk trägt; Netzwerk regional ausrollen (Hegegemeinschaft als Keimzelle), nicht global.
3. **Falsche Cross-User-Merges + Konflikte.** Reviereifersucht eskaliert, wenn das System fälschlich „euer gemeinsames Tier" behauptet. → hohe Merge-Schwelle, beidseitige Bestätigung, methodengewichtete Konfliktauflösung, Erleger-Endknoten, jederzeit auflösbar.

---

# GESAMT-FAZIT (6 Zeilen)

1. **Re-ID ist kein Greenfield:** GamsBuch, `RecognitionService` (Geo + monotones Alter + Geschlecht) und der Mensch-in-der-Schleife-Dialog „Bekannte Gams?" existieren bereits — das ist der MVP-Kern.
2. **Realistischer MVP (Feature A):** vorhandene Heuristik härten + GamsBuch in die Cloud (Datenverlust-Lücke schließen) + permanente Merkmals-Tags + Geweih-Saison-Gating; jede Ja/Nein-Bestätigung als Label sammeln.
3. **Vision (Feature A):** server-seitige Bild-Embeddings (pgvector) als Zusatzsignal, später ein art-spezifisch fein-getuntes Re-ID-Modell — Geweih bleibt bewusst Nebensignal, Körper/Narben/Decke sind die stabilen Anker.
4. **Abwurf-Antwort:** Geweih nie als Primärschlüssel; cross-year zählt monotones Alter + Geo + permanente Merkmale; Geweih-Ähnlichkeit nur within-season hochgewichtet.
5. **Feature B ist Vision, nicht MVP:** das revierübergreifende Tier-Netz steht und fällt mit Datenschutz — frühestens nach Feature A und den Audit-P0-Fixes (Pseudonym-ID, Löschrecht, Datenschutzerklärung).
6. **B-Designkern:** opt-in pro Tier, Geohash-Unschärfe statt Koordinaten, k-Anonymität (k≥3), Pseudonymität, Reziprozitäts-Anreiz, beidseitig bestätigte Merges — Mehrwert als unscharfes „Lebenszeichen", niemals als Karte mit Pins.
