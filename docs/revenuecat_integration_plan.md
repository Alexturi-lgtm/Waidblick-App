# RevenueCat-Integrationsplan — Gamssinn (de.gamssinn.app)

> Stand der Analyse: 2026-06-09. Erstellt durch Code-Lesung (kein Raten).
> Ziel: EIN Abo gilt auf iOS+Android; das FastAPI-Backend prüft das Entitlement
> **serverseitig**, BEVOR ein Gemini/OpenAI-Vision-Call ausgelöst wird (Kostenschutz).
> Entscheidung steht fest: RevenueCat (Free-Tier), `purchases_flutter` bereits in `pubspec.yaml` (`^9.16.0`).

---

## 0. IST-Zustand (was der echte Code zeigt)

### Client (Flutter)
| Datei | Status |
|---|---|
| `lib/services/payment_service.dart` | RevenueCat-Wrapper **fast vollständig**: `initialize()`, `logIn/logOut`, `getProducts()`, `purchaseMonthly/Yearly()`, `restorePurchases()`, `isPremium()`. |
| `lib/screens/paywall_screen.dart` | UI fertig: Monats/Jahres-Button, Restore, dynamische Preise, zusätzlich Beta-E-Mail-Whitelist (`/check-beta`). |
| `lib/services/profile_service.dart` | `isPremium()` → primär `PaymentService.isPremium()` (RevenueCat), Fallback Supabase-Profil `subscription_status/_expires`. |
| `lib/services/freemium_service.dart` | 5 Analysen/Monat + 3 Lookbook gratis; `canAnalyze()` ruft `ProfileService.isPremium()`. |
| `lib/screens/analysis_screen.dart` | Gate **client-seitig**: `FreemiumService.canAnalyze()` → sonst `PaywallScreen`. Dann `VisionApiService.analyze(...)`. |
| `lib/services/vision_api_service.dart` | POST `https://178.104.159.28/analyze` mit `wildart_hint`, `region`, `training_consent` — **sendet KEINE user_id / kein JWT / kein Entitlement-Token**. |
| `lib/main.dart` | ruft `PaymentService.initialize()` beim Start. |

### Kritische Befunde (Blocker / Inkonsistenzen)
1. **`PaymentService.isPremium()` ist hart auf `return true` gepatcht** (TestFlight-Modus, Zeile 54 mit `// TODO: Vor App Store Launch entfernen!`). → Aktuell ist JEDER „premium". Muss vor Launch raus.
2. **Produkt-ID-Chaos** — drei verschiedene Schreibweisen im Code:
   - `payment_service.dart`: kauft per **Package-Identifier** `monthly` / `yearly` (RevenueCat-Package-IDs, **nicht** Store-Produkt-IDs).
   - `paywall_screen.dart` (Preisanzeige): matcht auf **Store-Produkt-IDs** `de.waidblick.premium.monthly` / `.yearly`.
   - Backend `validate-receipt`: `duration_map` mit `de.waidblick.premium.monthly/.yearly/.lifetime`.
   → Diese müssen vereinheitlicht werden (siehe Abschnitt A).
3. **Entitlement-Key heißt `"Waidblick Premium"`** (mit Leerzeichen) — an 3 Stellen hartkodiert (`payment_service.dart` x3). Muss exakt mit dem RevenueCat-Dashboard-Entitlement-Identifier übereinstimmen.
4. **Backend `/analyze` hat KEIN Entitlement-Gate** — nur SlowAPI-Rate-Limit (10/min, 100/h). Hier sitzt die eigentliche Kostenlücke: Ein Free-User (oder Bot) kann unbegrenzt teure Vision-Calls auslösen, solange er das Client-Gate umgeht.
5. **`/check-beta` existiert im aktuellen `backend/main.py` NICHT** (kein `@app.post("/check-beta")`). Der Paywall-Beta-Flow ruft ins Leere → 404 → „Verbindungsfehler". Alt-Pfad, beim Aufräumen berücksichtigen.
6. **`/validate-receipt` validiert NICHT wirklich** bei Apple/Google — setzt nur blind `subscription_status=premium` in Supabase. Mit RevenueCat wird dieser Endpoint durch den RevenueCat-Webhook ersetzt (siehe C).
7. RevenueCat-API-Key im Client ist ein **iOS-Public-Key** (`appl_...`, hardcoded Default in `payment_service.dart`). Für Android wird zusätzlich ein **Google-Public-Key** (`goog_...`) gebraucht — fehlt noch.
8. Bundle-ID ist überall sauber auf **`de.gamssinn.app`** migriert (iOS pbxproj, Android `build.gradle.kts` + `applicationId` + Kotlin-Package, fastlane Appfiles, codemagic.yaml). Nur die alten `de.waidblick.*`-**Produkt**-IDs sind noch im Code.

---

## A. RevenueCat-Dashboard- & Store-Setup

### A.1 Store-Produkt-IDs — Empfehlung: **produktneutral, ohne `waidblick`**
Da das Produkt jetzt „Gamssinn" heißt und Store-Produkt-IDs **nach Anlage unveränderlich** sind, neue, neutrale IDs anlegen. Empfehlung — **identische IDs auf beiden Stores** (vereinfacht Mapping, RevenueCat erlaubt das):

| Zweck | Empfohlene Store-Produkt-ID (iOS = Android) | Typ |
|---|---|---|
| Monatsabo | `gamssinn_premium_monthly` | Auto-renewable subscription |
| Jahresabo | `gamssinn_premium_yearly` | Auto-renewable subscription |

> Bewusst **nicht** `de.gamssinn.premium.monthly`: App Store Connect Produkt-IDs sind frei wählbar; reverse-DNS schafft nur Verwechslungsgefahr mit der Bundle-ID. Snake_case ist üblich und kollidiert nicht.
>
> ⚠️ Falls bereits `de.waidblick.premium.*` in App Store Connect / Play Console **angelegt und je „Ready to Submit"/genehmigt** wurden: Produkt-IDs sind dort **nicht löschbar/umbenennbar**. Dann zwei Optionen:
> - **(empfohlen)** neue `gamssinn_premium_*`-Produkte anlegen, alte ignorieren (nie referenzieren).
> - alte `de.waidblick.*` weiterverwenden (funktioniert technisch, nur kosmetisch unschön). RevenueCat kapselt den Namen ohnehin.
>
> **Empfehlung an Alex zur Entscheidung:** Wenn noch KEINE IAP-Produkte in den Stores angelegt sind → neue neutrale IDs. Wenn schon angelegt → alte behalten, kein Risiko.

iOS und Android: **gleiche Subscription-Group** „Gamssinn Premium" (iOS) bzw. dasselbe Base-Plan-Konstrukt (Android), damit Up/Downgrade monthly↔yearly sauber läuft.

### A.2 RevenueCat-Dashboard — anzulegen

**Project:** „Gamssinn"

**Apps (2):**
- iOS-App → Bundle `de.gamssinn.app` → liefert Public-Key `appl_…`
- Android-App → Package `de.gamssinn.app` → liefert Public-Key `goog_…`

**Entitlement (1):**
- Identifier: **`premium`** (kleingeschrieben, neutral).
  > Achtung: Der Code prüft aktuell `"Waidblick Premium"`. **Empfehlung: Entitlement im Dashboard `premium` nennen UND den Code auf `premium` umstellen** (3 Stellen in `payment_service.dart` + Backend-Check). Konstante zentralisieren (siehe B). Falls Alex Aufwand minimieren will, ginge auch Dashboard-Entitlement exakt `Waidblick Premium` — aber neutral+zentralisiert ist sauberer.

**Products (im RevenueCat „Products"-Tab je Store verknüpfen):**
- `gamssinn_premium_monthly` (iOS + Android)
- `gamssinn_premium_yearly` (iOS + Android)
- beide dem Entitlement `premium` zuordnen.

**Offering (1):** Identifier **`default`** (RevenueCat-Standard, `offerings.current`).
Packages darin:
| Package-Identifier | verknüpftes Produkt |
|---|---|
| `$rc_monthly` (Standard-Package „Monthly") | `gamssinn_premium_monthly` |
| `$rc_annual` (Standard-Package „Annual") | `gamssinn_premium_yearly` |

> `payment_service.dart` sucht aktuell Packages per `storeProduct.identifier == 'monthly'/'yearly'`. Das ist **falsch** — das matcht weder die RC-Package-IDs (`$rc_monthly`) noch die Store-Produkt-IDs. Beim Umbau (B) auf die **RC-Standard-Packages** umstellen: `current.monthly` / `current.annual` (typsichere Getter von `purchases_flutter`).

---

## B. Client-Code-Änderungen (Dateien + Funktionen konkret)

### B.1 `lib/services/payment_service.dart`
1. **API-Keys plattformspezifisch** statt einem Default:
   ```
   // Pseudocode-Skizze (keine Implementierung hier)
   final apiKey = Platform.isIOS ? _iosKey : _androidKey;
   await Purchases.configure(PurchasesConfiguration(apiKey));
   ```
   `_iosKey` = `appl_…`, `_androidKey` = `goog_…` (beide aus Dashboard A.2). Keys über `--dart-define` (`REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY`) injizieren, Default leer.
2. **Entitlement-Konstante zentralisieren:** `static const entitlementId = 'premium';` und überall `entitlements.active.containsKey(entitlementId)` nutzen (ersetzt die 3× `'Waidblick Premium'`).
3. **`isPremium()`: TestFlight-Hack (`return true`) entfernen** (Zeile 52-55). Echten Pfad scharf schalten.
4. **Kauf auf RC-Standard-Packages umstellen:**
   - `purchaseMonthly()` → `current.monthly` (statt Suche nach `identifier == 'monthly'`).
   - `purchaseYearly()` → `current.annual`.
   - Fehlerfall „Package null" sauber behandeln.
5. **`getProducts()`**: bleibt; in der Paywall-Preisanzeige (B.3) auf neue Produkt-IDs matchen.

### B.2 `lib/main.dart`
- `PaymentService.initialize()` bleibt vor `runApp`. Sicherstellen, dass `Purchases.logIn(user.id)` **nach** Supabase-Login passiert (ist via `initialize()` + `loginUser()` in `login_screen`/`auth_service` abgedeckt — prüfen, dass `loginUser` nach jedem Login/Signup aufgerufen wird, damit RevenueCat-AppUserID == Supabase-`user.id`). **Diese Kopplung ist die Voraussetzung für das Server-Gate** (C): Das Backend identifiziert den User über die Supabase-`user.id`, die == RevenueCat-AppUserID ist.

### B.3 `lib/screens/paywall_screen.dart`
- Preis-Match in `_loadDynamicPrices()` von `de.waidblick.premium.monthly/.yearly` auf die neuen IDs (`gamssinn_premium_monthly/_yearly`) umstellen — ODER besser über die Package-Getter (`offering.monthly?.storeProduct.priceString`) lesen, dann ID-unabhängig.
- Beta-E-Mail-Block (`/check-beta`): da Endpoint serverseitig fehlt → entweder Endpoint nachrüsten (Abschnitt C-Anhang) oder Block ausblenden. **Entscheidung von Alex nötig** (Beta-Whitelist noch gewünscht?).

### B.4 Entitlement-Check beim App-Start / nach Kauf
- `ProfileService.isPremium()` bleibt der zentrale Client-Getter (nutzt `PaymentService.isPremium()`). Kein Umbau nötig außer dass darunter der echte RC-Status kommt.
- **Empfehlung:** `Purchases.addCustomerInfoUpdateListener` in `PaymentService.initialize()` registrieren, um den Premium-Status live zu aktualisieren (z.B. nach Restore/Renewal), statt nur on-demand zu pollen.

### B.5 Restore
- `restorePurchases()` ist vorhanden und korrekt (`Purchases.restorePurchases()` → Entitlement-Check). Nur Entitlement-Konstante anpassen.

---

## C. Server-Side-Entitlement-Check (FastAPI) — der Kostenschutz

**Designentscheidung: Hybrid „Webhook → Supabase-Cache", Gate liest aus Supabase.**
Begründung: `/analyze` darf **nicht** bei jedem Call synchron die RevenueCat-REST-API abfragen (Latenz + RC-Rate-Limits + Single-Point-of-Failure auf dem heißen Pfad). Stattdessen:

```
RevenueCat  ──(Webhook: INITIAL_PURCHASE/RENEWAL/CANCELLATION/EXPIRATION)──▶  FastAPI /revenuecat-webhook
                                                                                    │
                                                                                    ▼
                                                                 Supabase profiles.subscription_status/_expires
                                                                                    ▲
Client /analyze (mit Supabase-JWT)  ──────────────────────────────────────────────┘  (Gate liest hier)
```

### C.1 Neuer Endpoint `@app.post("/revenuecat-webhook")` in `backend/main.py`
- **Auth:** RevenueCat sendet einen frei konfigurierbaren `Authorization`-Header (im RC-Dashboard → Integrations → Webhooks gesetzt). Backend prüft `Header(authorization)` gegen `os.environ["REVENUECAT_WEBHOOK_SECRET"]`. Sonst 401.
- **Payload:** RC-Event-JSON. Relevante Felder: `event.app_user_id` (== Supabase `user.id`, dank B.2), `event.type`, `event.expiration_at_ms`, `event.entitlement_ids`.
- **Aktion:** Supabase `profiles`-Row des `app_user_id` patchen:
  - bei `INITIAL_PURCHASE`/`RENEWAL`/`UNCANCELLATION`/`PRODUCT_CHANGE` → `subscription_status='premium'`, `subscription_expires=<expiration_at_ms→ISO>`.
  - bei `CANCELLATION` → Status bleibt premium bis `expiration` (Cancellation ≠ sofortiger Entzug).
  - bei `EXPIRATION` → `subscription_status='free'`, `subscription_expires=null`.
  - Reuse: die **vorhandene** Supabase-PATCH-Logik aus `validate-receipt` (Zeilen 1157-1169) wiederverwenden.
- Damit wird `/validate-receipt` (das nur blind premium setzt) **obsolet** → entfernen oder auf no-op/deprecated setzen.

### C.2 Gate in `@app.post("/analyze")` einbauen
- **Client-Änderung (Voraussetzung):** `vision_api_service.dart` muss den **Supabase-JWT** als `Authorization: Bearer <access_token>` mitschicken (Token via `Supabase.instance.client.auth.currentSession?.accessToken`).
- **Server:** neuer Header-Param `authorization: str = Header(None)` in `analyze_photo(...)`. Ablauf am Funktionsanfang (vor dem GEMINI-Key-Check / vor dem teuren Call):
  1. JWT → Supabase `GET /auth/v1/user` (Pattern existiert bereits in `redeem-voucher`, Zeilen 1052-1064) → `user_id`.
  2. `profiles`-Row laden (Service-Key), `subscription_status` + `subscription_expires` lesen.
  3. **Entitlement-Logik:**
     - premium/lifetime und (kein expires ODER expires in Zukunft) → **erlauben**.
     - sonst (free): Monatszähler `analyses_this_month` prüfen. `< 5` → erlauben + Zähler erhöhen (RPC `increment_analysis` existiert bereits). `>= 5` → **HTTP 402 / 403** mit `{"error":"quota_exceeded"}`.
  4. Erst NACH bestandenem Gate → Vision-Call (OpenAI/Gemini).
- **Wichtig — Server ist Source of Truth fürs Free-Limit:** Aktuell zählt nur der Client (`FreemiumService` lokal + `ProfileService.incrementAnalysis` best-effort). Das Server-Gate macht das Free-Limit fälschungssicher und schützt Gemini-Kosten auch bei manipuliertem Client.
- **Gast-Modus / kein JWT:** Entscheidung nötig — entweder (a) anonyme Calls weiterhin mit hartem IP-basiertem Tageslimit erlauben (für „ausprobieren ohne Login"), oder (b) `/analyze` ohne JWT komplett ablehnen (401). Empfehlung: (a) mit niedrigem IP-Limit (z.B. 3/Tag via SlowAPI key_func) plus das bestehende 10/min-Limit, damit Onboarding nicht kaputtgeht.

### C.3 Optional als Fallback: synchroner RC-REST-Check
- Falls der Webhook mal nicht angekommen ist, kann `/analyze` bei „free, aber Limit erreicht" **einmalig** `GET https://api.revenuecat.com/v1/subscribers/{app_user_id}` (Header `Authorization: Bearer <RC_SECRET_API_KEY>`) abfragen und `subscriber.entitlements.premium.expires_date` prüfen, bevor es 402 wirft. Verhindert False-Negatives bei Webhook-Lag. Nur im Limit-Fall, nicht auf jedem Call (Kosten/Latenz).

### C.4 Env-Variablen (Backend, in `/opt/waidblick/.env`)
- `REVENUECAT_WEBHOOK_SECRET` (frei wählbar, im RC-Dashboard identisch setzen)
- `REVENUECAT_SECRET_API_KEY` (`sk_…`, NUR Server; **nie** in den Client!) — für C.3.
- `SUPABASE_SERVICE_KEY` (existiert bereits, muss gesetzt sein — aktuell Default `""`).

---

## D. Umsetzungs-Reihenfolge & Zuständigkeit

| # | Schritt | Wer | Code/Manuell |
|---|---|---|---|
| 1 | **Paid-Applications-Agreement** in App Store Connect aktiv + Banking/Tax ausgefüllt | **Alex** (rechtlich/Bank) | Manuell — **Gate, sonst keine IAPs** |
| 2 | **Play Console:** Händlerkonto/Auszahlungsprofil anlegen | **Alex** | Manuell |
| 3 | IAP-Produkte anlegen: `gamssinn_premium_monthly` + `_yearly` (ASC + Play, gleiche IDs, Preise 12,99€/99€) | **Alex** (Code-Agent kann Werte/Anleitung vorbereiten) | Manuell in Store-Konsolen |
| 4 | RevenueCat-Projekt + 2 Apps + Entitlement `premium` + Offering `default` + Produkte verknüpfen | **Alex** (1× Dashboard), Code-Agent liefert exakte Werte | Manuell (Dashboard) |
| 5 | RC-Public-Keys (`appl_…`, `goog_…`) + Secret-Key + Webhook-Secret an Alex → in CI-Secrets / `.env` | **Alex** legt Secrets, Code-Agent baut Verdrahtung | gemischt |
| 6 | Client-Umbau B.1–B.5 (Keys, Entitlement-Konstante, RC-Packages, TestFlight-Hack raus, JWT in `/analyze`-Call) | **Code-Agent** | Code |
| 7 | Backend: `/revenuecat-webhook` + Gate in `/analyze` + JWT-Parsing + Env | **Code-Agent** | Code |
| 8 | RC-Dashboard → Webhook-URL auf `https://<backend>/revenuecat-webhook` + Secret setzen | **Alex** (1 Eingabe) | Manuell |
| 9 | **Sandbox-Test** iOS (Sandbox-Tester) + Android (Lizenz-Tester): Kauf→Entitlement→Gate erlaubt; Free→6. Call→402 | beide | Test |
| 10 | TestFlight/Internal-Track Beta-Build (Build-Nr. via `$GITHUB_RUN_NUMBER`) | **Code-Agent** stößt an | Build |

> **Reihenfolge-Logik:** 1–5 sind Voraussetzung; ohne angelegte Store-Produkte liefert `getOfferings()` leer und der Kauf schlägt fehl. Webhook (8) erst nach Backend-Deploy (7). Sandbox-Test (9) braucht nur Sandbox-Tester, **kein** Live-Release.

---

## E. Risiken & Fallstricke

1. **Produkt-ID-Unveränderlichkeit:** Store-Produkt-IDs lassen sich nach Anlage NICHT umbenennen/löschen (nur deaktivieren). Daher IDs **einmal richtig** wählen (A.1). Tippfehler = neues Produkt nötig.
2. **Bundle-ID-Migration:** Bundle ist sauber `de.gamssinn.app`. RevenueCat-Apps MÜSSEN exakt diese Bundle-/Package-ID tragen, sonst werden Käufe nicht erkannt. Die alten `de.waidblick.*`-**Produkt**-IDs im Code (`paywall_screen.dart`, `validate-receipt`-`duration_map`) sind die einzige verbleibende Migrations-Altlast → mit-anpassen.
3. **Entitlement-Key-Mismatch:** Code prüft `"Waidblick Premium"`. Wenn das Dashboard-Entitlement `premium` heißt → Käufe schlagen still als „nicht premium" durch. Konstante zentralisieren und mit Dashboard 1:1 abgleichen (B.1/B.3).
4. **`return true`-Hack:** Solange `isPremium()` hart `true` liefert, ist JEDE Paywall/Gate-Logik wirkungslos. Vor jedem Nicht-Beta-Build entfernen.
5. **AppUserID-Kopplung:** Wenn `Purchases.logIn(user.id)` nicht zuverlässig nach Login läuft, weicht die RC-AppUserID (anonyme `$RCAnonymousID`) von der Supabase-`user.id` ab → Webhook-`app_user_id` matcht keine Supabase-Row → Server-Gate erkennt Premium nicht. **Kritischster Integrationspunkt.** Vor Login getätigte Käufe via `logIn` (alias-Merge) zusammenführen.
6. **Sandbox-Testing-Eigenheiten:** iOS-Sandbox-Abos renewen extrem schnell (Monat ≈ 5 Min) und verhalten sich teils anders als Prod; Android braucht **Lizenz-Tester** + App über internen Track installiert. Webhook feuert in Sandbox → Test-Events sauber von Prod trennen (RC-Dashboard zeigt Environment).
7. **Self-signed TLS am Backend:** `vision_api_service.dart` akzeptiert jedes Zertifikat (`badCertificateCallback => true`). Der RevenueCat-Webhook (von RC-Servern) kann ein **self-signed Cert NICHT** akzeptieren → Webhook-Zustellung schlägt fehl. **Für den Webhook-Endpoint ist ein gültiges TLS-Zertifikat (Let's Encrypt / über ngrok-Domain) zwingend.** Aktuell läuft Prod über `https://178.104.159.28` (IP, self-signed). → Webhook über die ngrok-Domain `crinal-pervertible-colette.ngrok-free.dev` ODER echtes Cert auf Hetzner.
8. **Webhook-Lag / Ausfall:** Zwischen Kauf und Webhook-Eintreffen kann der Server-Cache veraltet sein → C.3 (synchroner RC-REST-Fallback) gegen False-Negatives.
9. **Free-Limit doppelt gezählt:** Aktuell zählen Client (`FreemiumService` + `ProfileService.incrementAnalysis`) UND künftig der Server. Nach Server-Gate sollte der Client den Zähler nicht mehr autoritativ führen, sonst Doppelzählung/Drift. Client-Zähler auf reine UI-Anzeige reduzieren, Server zählt verbindlich.
10. **`/check-beta` 404:** Beta-E-Mail-Flow im Paywall ruft einen nicht existierenden Endpoint → immer „Verbindungsfehler". Entweder Endpoint nachrüsten oder Block entfernen (Entscheidung Alex).
11. **Kosten ohne Login:** Solange `/analyze` ohne JWT erlaubt ist, schützt nur das IP-Rate-Limit vor Gemini-Kosten. Anonymes Tageslimit definieren (C.2, Gast-Modus).

---

## Konkrete Datei-/Funktions-Checkliste für den Umsetzungs-Agenten

**Client:**
- `lib/services/payment_service.dart`: plattform-Keys; `entitlementId='premium'` Konstante (3 Stellen); `return true` entfernen; `purchaseMonthly/Yearly` → `current.monthly/annual`; CustomerInfo-Listener.
- `lib/services/vision_api_service.dart`: `analyze()` + `submitFeedback()` → `Authorization: Bearer <supabase access_token>` Header mitschicken.
- `lib/screens/paywall_screen.dart`: Preis-Match auf neue Produkt-IDs / Package-Getter; Beta-Block-Entscheidung.
- `lib/screens/analysis_screen.dart`: 402/quota_exceeded-Response von `/analyze` abfangen → `PaywallScreen` öffnen (statt nur Client-Gate).
- `lib/main.dart` / `auth_service.dart` / `login_screen.dart`: sicherstellen `PaymentService.loginUser(user.id)` nach jedem Login/Signup.

**Backend (`backend/main.py`):**
- neu: `@app.post("/revenuecat-webhook")` (Auth via Secret, Supabase-PATCH reuse).
- `@app.post("/analyze")`: `authorization`-Header, JWT→user_id (Pattern aus `redeem-voucher`), Supabase-Entitlement+Quota-Gate VOR Vision-Call, 402 bei Limit.
- `validate-receipt` deprecaten/entfernen; `duration_map`-IDs anpassen oder löschen.
- Env: `REVENUECAT_WEBHOOK_SECRET`, `REVENUECAT_SECRET_API_KEY`, `SUPABASE_SERVICE_KEY` setzen.
- TLS: gültiges Cert für Webhook-Endpoint.
