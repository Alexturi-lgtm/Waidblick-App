# Gamssinn — App-Launch-Checkliste (iOS + Android)

> Wiederverwendbarer Launch-Rahmen für das Flutter-Projekt **Gamssinn** (KI-Wildtier-Erkennung für Jäger).
> Stand: 2026-06. Orientiert an App-Store-Review-Guidelines & Google-Play-Policy (2026).
>
> **Identitäten (unveränderlich):**
> - iOS Bundle-ID: `de.waidblick.app` (Apple-Profil dafür ausgestellt — NICHT ändern)
> - Android applicationId: `de.gamssinn.app`
> - Anzeigename überall: **Gamssinn**
> - Apple Team-ID: `J4JZ2DQC77`
>
> **Legende:**
> - ✅ ERLEDIGT — fertig, verifiziert
> - ⏳ OFFEN — noch zu tun
> - **[ALEX]** — nur Alex kann das (Konten, Zahlung, Login, Ausweis/Verifizierung, Anwalt)
> - **[CLAUDE]** — automatisierbar (Builds, API-Uploads, Metadaten, Screenshots, TLS)

---

## Phase 1 — Vorbereitung

- [x] ✅ Flutter-Projekt baut sauber (`flutter analyze` grün in CI)
- [x] ✅ Anzeigename "Gamssinn" gesetzt (iOS + Android)
- [x] ✅ iOS Bundle-ID `de.waidblick.app` fixiert
- [x] ✅ Android applicationId `de.gamssinn.app` fixiert
- [x] ✅ Lern-/Feedback-Funktion in der App eingebaut
- [ ] ⏳ **[ALEX]** Apple Developer Account aktiv & bezahlt (99 USD/Jahr) — Voraussetzung für Store-Release (TestFlight läuft bereits, App-Store-Listing braucht aktives Programm)
- [ ] ⏳ **[ALEX]** Google Play Developer-Konto-Verifizierung abgeschlossen (Ausweis/Adresse, D-U-N-S falls Organisation) — *läuft*
- [ ] ⏳ **[CLAUDE]** Domain `gamssinn.de` registrieren + DNS einrichten
- [ ] ⏳ **[CLAUDE]** Echtes TLS-Zertifikat für `gamssinn.de` (Let's Encrypt / Hetzner) live
- [ ] ⏳ **[ALEX]** Markenrecherche/DPMA-Check für "Gamssinn" final bestätigen

---

## Phase 2 — Build & Signing

### iOS
- [x] ✅ iOS-Build grün in CI (`.github/workflows/ios_testflight.yml`)
- [x] ✅ Erfolgreicher TestFlight-Upload (App Store Connect API Key `GVYK3VM779`)
- [x] ✅ Distribution-Zertifikat + Provisioning-Profil als GitHub-Secrets hinterlegt (`DISTRIBUTION_CERTIFICATE_P12`, `PROVISIONING_PROFILE`)
- [x] ✅ App Store Connect API Key als Secret (`APP_STORE_CONNECT_API_KEY_*`)
- [x] ✅ `ExportOptions.plist` korrekt (method=app-store, manual signing, Profil "Waidblick AppStore")
- [x] ✅ Build-Nummer automatisch aus `$GITHUB_RUN_NUMBER` (nie rückwärts)

### Android
- [x] ✅ Signiertes AAB baut grün in CI (`.github/workflows/android_release.yml`)
- [x] ✅ Upload-Keystore vorhanden + als Base64-Secret (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`)
- [x] ✅ Signing-Wiring in `android/app/build.gradle.kts` (release signingConfig aus `key.properties`)
- [x] ✅ Build-Nummer automatisch aus `$GITHUB_RUN_NUMBER`
- [ ] ⏳ **[ALEX]** Play App Signing aktivieren / Upload-Key bei Google registrieren (beim ersten Play-Console-Upload)
- [ ] ⏳ **[CLAUDE]** Direkter Play-Upload automatisieren (fastlane `supply` / Service-Account) — Gerüst liegt jetzt unter `android/fastlane/`

---

## Phase 3 — Store-Assets

- [ ] ⏳ **[CLAUDE]** App-Icon in allen erforderlichen Größen (iOS Asset-Catalog, Android adaptive icon) verifizieren
- [ ] ⏳ **[CLAUDE]** iOS Screenshots: 6.7"/6.9" iPhone (Pflicht), 12.9"/13" iPad (falls iPad unterstützt)
- [ ] ⏳ **[CLAUDE]** Android Screenshots: min. 2 Phone (16:9 / 9:16), optional Tablet (7"/10")
- [ ] ⏳ **[CLAUDE]** Play Feature-Grafik 1024×500 px
- [ ] ⏳ **[CLAUDE]** Play App-Icon 512×512 px (hi-res)
- [ ] ⏳ **[CLAUDE]** Optionales App-Preview-Video (kann nachgereicht werden)

---

## Phase 4 — Metadaten

- [x] ✅ Store-Texte App Store vorhanden (`store/appstore_de.md`)
- [x] ✅ Store-Texte Play Store vorhanden (`store/playstore_de.md`)
- [ ] ⏳ **[CLAUDE]** Texte in `fastlane/metadata` (iOS) bzw. `fastlane/metadata/android` einpflegen (für automatisierten Upload via deliver/supply)
- [ ] ⏳ **[CLAUDE]** Keywords iOS (100 Zeichen) + Play-Kurzbeschreibung (80 Zeichen) finalisieren
- [ ] ⏳ **[CLAUDE]** Kategorie wählen (z.B. Utilities/Lifestyle) — beide Stores
- [ ] ⏳ **[ALEX]** Support-URL / Kontakt-E-Mail (`waidblick@proton.me`) bestätigen
- [ ] ⏳ **[CLAUDE]** Marketing-/Datenschutz-URL auf `gamssinn.de` in beiden Store-Listings eintragen (sobald Domain live)

---

## Phase 5 — Legal & Compliance

- [x] ✅ Datenschutz-Entwurf vorhanden (`store/legal/datenschutz_entwurf.md`)
- [x] ✅ Impressum-Entwurf vorhanden (`store/legal/impressum_entwurf.md`)
- [ ] ⏳ **[ALEX]** Rechtstexte (Datenschutz + Impressum + ggf. AGB/Nutzungsbedingungen) final vom Anwalt prüfen lassen
- [ ] ⏳ **[CLAUDE]** Datenschutzerklärung unter öffentlicher URL live (`https://gamssinn.de/datenschutz`) — Pflicht für beide Stores
- [ ] ⏳ **[CLAUDE]** iOS App-Privacy-Label (App Store Connect: Datennutzung deklarieren — Kamera/Fotos, evtl. Standort/Diagnose)
- [ ] ⏳ **[CLAUDE]** Play Data-Safety-Formular ausfüllen (Datenerhebung/-weitergabe, Verschlüsselung)
- [ ] ⏳ **[CLAUDE]** Age-Rating / Altersfreigabe (Apple Age Rating Questionnaire + Google IARC-Fragebogen)
- [ ] ⏳ **[ALEX]** Account-Löschung-Mechanismus bestätigen (falls Login existiert — Apple & Play Pflicht)
- [ ] ⏳ **[CLAUDE]** Berechtigungs-Begründungen prüfen (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` in Info.plist)

---

## Phase 6 — Testing

- [x] ✅ TestFlight-Build verteilbar (interne Tester)
- [ ] ⏳ **[ALEX]** Apple Review: Demo-Account / Test-Zugang bereitstellen (falls Login/Paywall) + Review-Notes
- [ ] ⏳ **[CLAUDE]** Play Internal-Testing-Track befüllen (AAB hochladen, Tester einladen)
- [ ] ⏳ **[CLAUDE]** Crash-/Smoke-Test auf realem Gerät beide Plattformen
- [ ] ⏳ **[CLAUDE]** Backend-Erreichbarkeit aus Release-Build verifizieren (Prod-URL, nicht ngrok-dev)

---

## Phase 7 — Release

- [ ] ⏳ **[ALEX]** Pricing/Verfügbarkeit setzen (kostenlos / IAP) + Länderauswahl
- [ ] ⏳ **[ALEX]** RevenueCat/Paywall einrichten + IAP-Produkte in beiden Stores anlegen (falls monetarisiert)
- [ ] ⏳ **[ALEX]** App zur Apple-Review einreichen (nach grünem TestFlight-Build)
- [ ] ⏳ **[ALEX]** Play-Production-Release einreichen (nach Internal-Testing)
- [ ] ⏳ **[CLAUDE]** Release-Build via fastlane `release`-Lane pushen (iOS: deliver, Android: supply track:production)

---

## Phase 8 — Post-Launch

- [ ] ⏳ **[CLAUDE]** Crash-/Performance-Monitoring aktiv (Crashlytics / Sentry / Xcode Organizer)
- [ ] ⏳ **[CLAUDE]** Store-Bewertungen & Reviews beobachten
- [ ] ⏳ **[ALEX]** Erste Nutzer-Feedback-Runde auswerten (Lern-Feedback der App)
- [ ] ⏳ **[CLAUDE]** Update-Pipeline dokumentiert (Versionsbump in `pubspec.yaml`, Build-Nummer via CI)
- [ ] ⏳ **[CLAUDE]** Backup von Keystore + API-Keys verifizieren (sicher, nie in Git/Cloud-Klartext)

---

## Offene Punkte — Zusammenfassung

| Verantwortung | Anzahl offen |
|---|---|
| **[ALEX]** | 13 |
| **[CLAUDE]** | 20 |
| **gesamt offen** | 33 |
| **erledigt** | 17 |

### Was nur Alex liefern/tun kann ([ALEX])
1. Apple Developer Account aktiv/bezahlt
2. Play Developer-Konto-Verifizierung abschließen
3. Markenrecherche/DPMA "Gamssinn" final
4. Play App Signing / Upload-Key registrieren
5. Support-URL/Kontakt bestätigen
6. Rechtstexte final vom Anwalt
7. Account-Löschung-Mechanismus bestätigen
8. Apple Review: Demo-Account + Review-Notes
9. Pricing/Verfügbarkeit/Länder
10. RevenueCat/Paywall + IAP-Produkte
11. App zur Apple-Review einreichen
12. Play-Production-Release einreichen
13. Nutzer-Feedback auswerten

### Was Claude automatisieren kann ([CLAUDE])
Domain + TLS, Screenshots-Generierung, Metadaten in fastlane einpflegen, Privacy-Label/Data-Safety/Age-Rating vorbereiten, Internal-Testing befüllen, fastlane release-Lanes, Monitoring, Update-Pipeline-Doku, Backup-Verifizierung.

---

## Verweise

- iOS-Workflow: `.github/workflows/ios_testflight.yml` (NICHT ändern — grün)
- Android-Workflow: `.github/workflows/android_release.yml` (NICHT ändern — grün)
- fastlane iOS: `ios/fastlane/Fastfile`, `ios/fastlane/Appfile`
- fastlane Android: `android/fastlane/Fastfile`, `android/fastlane/Appfile`
- Store-Texte: `store/appstore_de.md`, `store/playstore_de.md`
- Rechtstexte: `store/legal/datenschutz_entwurf.md`, `store/legal/impressum_entwurf.md`
