# Data-Flywheel-Audit — Gamssinn (Waidblick)

**Datum:** 2026-06-09
**Scope:** Daten-Persistenz für den proprietären Trainings-Datensatz (Bild + KI-Ergebnis + Nutzer-Feedback) und DSGVO-Konformität.
**Methodik:** Statische Code-Analyse Backend (`backend/main.py`) + Flutter-App (`lib/`). Keine Code-Änderung.
**Kernfrage:** Entsteht ab Launch der strategische Burggraben (verifizierter Eigendatensatz), oder verbrennen wir die Daten?

---

## (A) IST-ZUSTAND — mit Belegen

### A.1 Wird das Bild serverseitig gespeichert?

**JA — aber nur bei explizitem Opt-in, und nur ins lokale Dateisystem (kein Objekt-Storage / keine DB).**

- Der `/analyze`-Endpoint nimmt einen Form-Parameter `training_consent` entgegen (Default `"false"`).
  `backend/main.py:703` — `training_consent: str = Form(default="false")`
- Speicherung passiert **nur**, wenn `training_consent == "true"` UND eine echte Wildart erkannt wurde:
  `backend/main.py:948` — `if training_consent == "true" and result.get("wildart") not in ("kein_wild", "unbekannt"):`
- Speicherort = **lokales Dateisystem**, hierarchisch nach Wildart/Altersklasse:
  `backend/main.py:959-963` — `../../../datasets/training/{wildart}/{altersklasse}`
- Bild wird als JPG geschrieben, Dateiname = `{timestamp}_{md5[:8]}.jpg`:
  `backend/main.py:966-968`
- **Kein Supabase Storage, keine Postgres/SQLite-DB, kein S3.** Persistenz = flache Dateien + JSON-Sidecar.
- Vor dem Speichern wird das Bild auf max. 1200px / JPEG q82 komprimiert (`main.py:738-750`) — d.h. **es wird die komprimierte Version gespeichert, nicht das Original** (Qualitätsverlust für späteres Training).

**Ohne Consent:** Bild wird nur an Gemini/OpenAI durchgereicht (`main.py:786-813`) und danach verworfen. Keine Persistenz.

#### Gespeicherte Metadaten (JSON-Sidecar `{ts}_{h}.json`, `main.py:972-987`)

| Feld | Vorhanden? | Beleg |
|---|---|---|
| Zeitstempel | ✅ `timestamp` | `main.py:982` |
| Wildart | ✅ | `main.py:975` |
| Altersklasse | ✅ | `main.py:976` |
| Alter (Jahre) | ✅ `alter_jahre` | `main.py:977` |
| Geschlecht | ✅ | `main.py:978` |
| Confidence | ✅ | `main.py:979` |
| Scoring (Einzelmerkmale) | ✅ | `main.py:980` |
| Region | ✅ `region` (grobe Region, z.B. "steiermark") | `main.py:981` |
| sample_id | ✅ | `main.py:984` |
| verified-Flag | ✅ `false` initial | `main.py:986` |
| **Geokoordinaten (lat/lon)** | ❌ **fehlt** — nur grobe `region`-String | — |
| **user_id / device_id** | ❌ **fehlt komplett** | kein Treffer im Backend |
| **Modell-Version** | ❌ **fehlt** — kein `model`/`provider`-Feld im Sample | — |
| **App-Version / Prompt-Version** | ❌ fehlt | — |

### A.2 Wird das KI-Ergebnis zusammen mit dem Bild gespeichert?

**JA, vollständig.** Wildart, Geschlecht, Alter, Altersklasse, Confidence und das komplette Merkmals-Scoring landen im JSON-Sidecar neben dem Bild (`main.py:974-987`). Das ist der gut umgesetzte Teil.

### A.3 Nutzer-Feedback-Schleife ("gepasst ja/nein" / Korrektur)?

**JA — end-to-end verdrahtet.** Das ist der wertvollste Teil und überraschend vollständig.

- **Backend-Endpoint** `/feedback` existiert:
  `backend/main.py:1002-1037`. Nimmt `sample_id`, `is_correct`, und Korrekturwerte (`wildart`, `geschlecht`, `alter_jahre`, `altersklasse`, `methode`).
- `methode` erlaubt **Ground-Truth-Qualifizierung**: `"zahnschliff" | "erleger" | "sicht"` (`main.py:1012`) — d.h. der Goldstandard (Zahnschliff am erlegten Stück) kann markiert werden. Konzeptionell stark.
- Feedback wird als `datasets/feedback/{sample_id}.json` mit `"verified": true` abgelegt (`main.py:1033-1036`).
- **App-Seite:** Feedback-Card "War das richtig?" mit "Ja, passt" / "Nein, korrigieren":
  `lib/screens/analysis_screen.dart:1397-1469`. Korrektur-BottomSheet ab `:1486`.
- App ruft `VisionApiService.submitFeedback(...)` auf (`analysis_screen.dart:1474`, `:1631`), implementiert in `lib/services/vision_api_service.dart:150-183`.
- Feedback-Card erscheint **nur**, wenn eine `sampleId` vorliegt — d.h. nur bei aktivem Consent (`analysis_screen.dart:2382`, `:1396`).

**Verknüpfung Bild ↔ Ergebnis ↔ Feedback:** läuft ausschließlich über die `sample_id` (`{ts}_{md5}`). Das Trainings-Bild liegt unter `datasets/training/.../{sample_id}.jpg`, das Feedback unter `datasets/feedback/{sample_id}.json`. **Es gibt keine Datenbank, die diese drei Artefakte joint** — die Verknüpfung ist rein über Dateinamens-Konvention. Ein Reconciliation-Skript existiert nicht im Repo.

### A.4 DSGVO

| Anforderung | Status | Beleg / Lücke |
|---|---|---|
| Opt-in (keine Speicherung ohne Zustimmung) | ✅ vorhanden | Default `false` (`settings_service.dart:43`), Backend speichert nur bei `"true"` (`main.py:948`) |
| Consent jederzeit abschaltbar | ✅ | Settings-Toggle "KI-Training unterstützen" (`settings_screen.dart:601-611`) |
| Consent-Text | ⚠️ dünn | "Anonyme Freigabe deiner Fotos zur Verbesserung der Erkennung. Jederzeit abschaltbar." (`settings_screen.dart:604-605`) — nennt **nicht**: was genau (Bild+Metadaten+Region), Speicherdauer, Empfänger, Trainingszweck konkret, Widerruf für bereits gespeicherte Daten |
| EU-Datenregion | ⚠️ teils | Backend-Server = Hetzner (`178.104.159.28`, `vision_api_service.dart:11`) → EU. ABER Bild wird an **Gemini (Google) und ggf. OpenAI** zur Analyse geschickt (`main.py:766-813`) — Drittland-Transfer USA, **ohne dokumentierte Rechtsgrundlage/AVV im Code/Consent**. Gilt für JEDEN Upload, auch ohne Training-Consent. |
| Löschrecht (Art. 17) | ❌ **fehlt komplett** | Kein DELETE-Endpoint, kein "meine Daten löschen"-Flow. Da Samples **anonym** ohne user_id gespeichert werden, ist ein gezieltes Löschen technisch **gar nicht möglich** — der Nutzer kann sein Sample nicht identifizieren. |
| Auskunftsrecht (Art. 15) | ❌ fehlt | kein Mechanismus |
| Datenschutzerklärung erreichbar | ⚠️ unklar | Backend-Routen `/datenschutz`, `/datenschutz.html` zeigen auf `landing/datenschutz.html` (`main.py:621,686`) — **diese Datei existiert nicht im Repo** (`backend/landing/` enthält keine HTML-Dateien). In-App-Impressum (`impressum_screen.dart`) hat **keinen** Datenschutz-Abschnitt zur Foto-/Trainingsspeicherung. |
| EXIF-Stripping (GPS/Device aus Bild entfernen) | ❌ nicht nachweisbar | Bild wird via PIL re-encodiert (`main.py:742-748`), was EXIF i.d.R. entfernt — aber nur im >500KB-Pfad; kleine Bilder werden **ungestrippt** gespeichert. Nicht als Maßnahme intendiert. |
| Anonymität wirklich gegeben? | ⚠️ | "anonym" laut Consent-Text — stimmt insofern, als keine user_id gespeichert wird. ABER: Wildfotos können Standort/Personen-Hinweise enthalten; ohne EXIF-Garantie nicht sauber. |

**Impressum-Hinweis (außerhalb Audit-Scope, aber relevant):** `impressum_screen.dart:49` nennt **"Turok GmbH"** als Anbieter. Laut User-Vorgabe darf die Holding nicht operativ verwässert werden — App-Betreiber soll Alex persönlich sein. Das ist konsistent mit dem Datenschutz-Verantwortlichen zu klären (wer ist DSGVO-Verantwortlicher für den Datensatz?).

---

## (B) PRIORISIERTE LÜCKEN

**P0 — blockiert Launch / DSGVO-Risiko:**
1. **Drittland-Transfer USA ohne Rechtsgrundlage** im Consent/Datenschutz dokumentiert. Jedes hochgeladene Bild geht an Google/OpenAI. Das ist DSGVO-relevant unabhängig vom Training-Opt-in und gehört in die Datenschutzerklärung + ggf. separates Consent.
2. **Keine Datenschutzerklärung im Repo** — die referenzierte `landing/datenschutz.html` fehlt; In-App kein Datenschutz-Screen. Pflicht vor Store-Release.
3. **Kein Löschrecht / keine Identifizierbarkeit des eigenen Samples** (Art. 17 unerfüllbar). Anonyme Speicherung ohne pseudonymen Schlüssel macht Widerruf für bereits gespeicherte Daten unmöglich.

**P1 — verbrennt Datenwert (Burggraben-Qualität):**
4. **Keine Datenbank** — Samples + Feedback liegen als lose Dateien, nur per Dateiname gejoint. Skaliert schlecht, kein Query, kein "alle verifizierten Gams alt", kein Dedup, kein Audit. Bei vielen Nutzern unwartbar.
5. **Kein `model`/`prompt_version`/`app_version` im Sample** — bei eingefrorenem GAMS-Prompt heute egal, aber sobald Prompt/Modell wechselt, ist ohne Versionsstempel **nicht rekonstruierbar**, welche Daten unter welcher Modell-Generation entstanden → mindert Trainingswert massiv.
6. **Nur grobe `region` statt Geokoordinaten** — Standort ist laut Produktvision kritisch (regionale Wildmerkmale). GPS wird in der App erhoben (`location_service.dart`, Settings-Toggle "GPS automatisch"), aber **nicht an `/analyze` übergeben** und nicht gespeichert.
7. **Komprimiertes Bild statt Original** gespeichert (max 1200px). Für späteres Eigentraining ist Auflösung wertvoll → Original (oder höhere Stufe) für eingewilligte Samples behalten.

**P2 — Robustheit:**
8. Feedback-Schreibvorgang ohne Verknüpfungs-Garantie: Wenn `sample_id`-Bild fehlt (z.B. Training-Ordner manuell aufgeräumt), entsteht ein verwaistes Feedback. Kein referenzielle Integrität.
9. Self-signed SSL mit `badCertificateCallback => true` (`vision_api_service.dart:24,162`) — akzeptiert JEDES Zertifikat → MITM-Risiko beim Bild-Upload. Sicherheit der Pipeline.

---

## (C) FIX-PLAN — konkretes Schema / Endpoints / Consent

### C.1 Persistenz auf Datenbank umstellen (P1, Burggraben-Kern)

Empfehlung: **Supabase (Postgres + Storage), EU-Region (Frankfurt)** — deckt DB, Objekt-Storage, Auth und Row-Level-Security in einem ab und ist EU-hostbar. Alternativ: bei Hetzner bleiben + Postgres + lokales/MinIO-Storage.

Vorgeschlagenes Schema:

```sql
-- Ein Eintrag pro eingewilligtem Upload
create table samples (
  sample_id        text primary key,          -- {ts}_{md5}, bleibt kompatibel
  created_at       timestamptz not null default now(),
  pseudonym_id     text not null,             -- pro Gerät/Account, ermöglicht Löschrecht OHNE Klarnamen
  image_path       text not null,             -- Pfad in Storage-Bucket (EU)
  image_sha256     text,                      -- Dedup
  -- KI-Ergebnis
  wildart          text,
  geschlecht       text,
  alter_jahre      numeric,
  altersklasse     text,
  confidence       numeric,
  scoring          jsonb,                     -- Merkmals-Einzelwerte
  -- Kontext
  region           text,
  geo_lat          double precision,          -- NEU: nur mit separatem Geo-Consent
  geo_lon          double precision,
  geo_accuracy_m   integer,
  -- Provenienz (PFLICHT für Trainingswert)
  model_provider   text,                      -- 'gemini-2.5-flash' | 'gpt-4o'
  prompt_version   text,                      -- z.B. 'gams-2026-04'
  app_version      text,
  image_original   boolean default false,     -- ob unkomprimiert gespeichert
  verified         boolean default false      -- wird durch Feedback true
);

-- Ground-Truth-Feedback, 1:n zu samples (Nutzer kann nachkorrigieren)
create table feedback (
  id               bigint generated always as identity primary key,
  sample_id        text references samples(sample_id) on delete cascade,
  created_at       timestamptz not null default now(),
  is_correct       boolean not null,
  korrektur_wildart      text,
  korrektur_geschlecht   text,
  korrektur_alter_jahre  numeric,
  korrektur_altersklasse text,
  methode          text,    -- 'zahnschliff'|'erleger'|'sicht' -> Vertrauensgewicht
  pseudonym_id     text
);

-- Consent-Ledger (DSGVO-Nachweispflicht, Art. 7 Abs. 1)
create table consents (
  id               bigint generated always as identity primary key,
  pseudonym_id     text not null,
  consent_type     text not null,   -- 'training' | 'geo' | 'thirdcountry_ai'
  granted          boolean not null,
  consent_text_version text not null, -- welcher Wortlaut wurde akzeptiert
  created_at       timestamptz not null default now()
);
```

**`on delete cascade`** macht das Löschrecht trivial: `delete from samples where pseudonym_id = ?` plus Storage-Objekte löschen.

### C.2 Fehlende Felder/Endpoints

- `/analyze`: zusätzliche Form-Felder annehmen und persistieren: `geo_lat`, `geo_lon` (nur bei `geo_consent=true`), `app_version`. `model_provider` + `prompt_version` serverseitig ergänzen (kennt das Backend bereits).
- **App `vision_api_service.dart`:** GPS-Koordinaten (liegen via `location_service.dart` vor) und App-Version mitsenden, wenn Geo-Consent aktiv.
- **Neuer Endpoint `DELETE /my-data`** (Art. 17): nimmt `pseudonym_id`, löscht Samples+Feedback+Storage. In-App-Button "Meine Trainingsdaten löschen" in Settings.
- **Neuer Endpoint `GET /my-data`** (Art. 15): Liste der eigenen Samples (über `pseudonym_id`).
- **`pseudonym_id`** in der App generieren (random UUID, in `SharedPreferences`, kein Klarname) und bei `/analyze` + `/feedback` mitsenden — schließt das Löschrecht-Loch, ohne Anonymität aufzugeben.

### C.3 Original-Auflösung behalten

Für eingewilligte Samples das Bild **vor** der Kompression in den Trainings-Bucket schreiben (oder eine höhere Stufe, z.B. 2048px). Die 1200px-Version bleibt für den Vision-Call.

### C.4 Consent-Dialoge (statt nur stillem Settings-Toggle)

1. **Onboarding-Consent** (einmalig, granular, getrennt ankreuzbar):
   - [ ] KI-Bildanalyse (Pflicht für Funktion) — inkl. Hinweis: "Bild wird zur Analyse an KI-Dienste (Google/OpenAI, USA) übermittelt."
   - [ ] Fotos zur Verbesserung der Erkennung speichern (optional, = heutiges Training-Opt-in)
   - [ ] Standort zum Foto speichern (optional)
   - Jeweils mit Versionsstempel in `consents` protokollieren.
2. **Settings-Toggle** (besteht) — Text erweitern: was, wo (EU), wie lange, Widerruf + Löschung möglich, Link zur Datenschutzerklärung.

---

## (D) DSGVO-MASSNAHMEN (Maßnahmen-Checkliste)

1. **Datenschutzerklärung erstellen** (fehlt im Repo). Muss enthalten: Verantwortlicher (klären: Alex persönlich vs. Turok GmbH — siehe Impressum-Konflikt), Verarbeitungszwecke (Analyse + Training), Rechtsgrundlage (Art. 6 Abs. 1 a — Einwilligung), **Drittland-Transfer USA** (Google/OpenAI) mit Garantien (Standardvertragsklauseln / EU-US Data Privacy Framework), Speicherdauer, Betroffenenrechte. In-App-Screen + Web-Version (`landing/datenschutz.html` real anlegen).
2. **AVV / DPA** mit Google (Gemini) und OpenAI abschließen/referenzieren — Auftragsverarbeitung dokumentieren.
3. **Drittland-Consent** explizit machen — der USA-Transfer betrifft jeden Upload, nicht nur Training.
4. **Löschrecht implementieren** (C.2) — Pseudonym-ID + DELETE-Endpoint + Settings-Button.
5. **Auskunftsrecht** (GET /my-data).
6. **Consent-Ledger** (Tabelle `consents`) für Nachweispflicht Art. 7.
7. **EXIF-Stripping garantiert** für alle gespeicherten Bilder (auch <500KB-Pfad) — Standort nur über expliziten Geo-Consent, nicht versteckt im EXIF.
8. **Speicherdauer / Retention** definieren (z.B. Training-Samples unbefristet bis Widerruf; Consent-Ledger gesetzlich).
9. **Verantwortlichen klären** — Impressum nennt Turok GmbH (Holding), User-Vorgabe will operativ = Alex persönlich. DSGVO-Verantwortlicher für den Datensatz muss dazu passen.

---

## FAZIT

Der Burggraben ist **architektonisch angelegt und end-to-end verdrahtet** — und das ist die gute Nachricht: Opt-in-Speicherung von Bild + vollständigem KI-Ergebnis + eine echte Feedback-Schleife mit Ground-Truth-Methode (Zahnschliff/Erleger/Sicht) existieren bereits im Code. Das ist mehr, als bei einem Pre-Launch-Stand üblich.

**Aber er ist noch nicht launch-fest.** Drei Dinge müssen vor dem Datensammeln gefixt werden, sonst sammeln wir entweder rechtswidrig oder minderwertig: (1) **DSGVO-Basis fehlt** — keine Datenschutzerklärung, kein Löschrecht, undokumentierter USA-Transfer; (2) **Persistenz ist nur loses Dateisystem ohne DB** und ohne `model_version`/GPS — skaliert schlecht und mindert den Trainingswert; (3) das gespeicherte Bild ist die **komprimierte** Version.

**Größte Einzellücke:** Das fehlende Löschrecht in Kombination mit anonymer Speicherung ohne Pseudonym-ID — DSGVO-Art.-17-Risiko UND gleichzeitig der Block, der eine saubere DB-Migration erzwingt. Wer das mit einer `pseudonym_id` + Postgres/Supabase (EU) löst, schlägt P0-DSGVO und P1-Datenqualität in einem Schritt.

Burggraben entsteht: **JA, im Ansatz — aber nur wenn P0/P1 vor dem Launch geschlossen werden.**
