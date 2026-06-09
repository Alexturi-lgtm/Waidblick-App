# Store-Screenshots automatisieren — Gamssinn (`de.gamssinn.app`)

Ziel: reproduzierbare Store-Screenshots in den Pflichtmaßen, ohne manuelles
Abfotografieren. Dieses Dokument beschreibt das empfohlene Verfahren, ein
Beispiel-Script und ehrlich, was **erst mit laufendem Gerät/Emulator** geht
(also noch nicht voll headless in CI machbar).

## Pflicht-Maße

| Store | Slot | Auflösung (px) | Pflicht |
|---|---|---|---|
| Google Play | Phone | min. 1080×1920 (Portrait), 2–8 Stück | ja, ≥2 |
| Google Play | Feature-Grafik | 1024×500 | ja (separat erzeugt, siehe `feature-graphic.png`) |
| Apple App Store | 6,9" iPhone | 1290×2796 (Portrait) | ja, ≥1 (deckt 6,5"/6,7" mit ab) |
| Apple App Store | 6,5" iPhone | 1242×2688 | optional, wenn 6,9" geliefert |

Apple akzeptiert für neue Apps i.d.R. **nur den 6,9"-Satz** als Pflicht;
ältere Größen werden automatisch skaliert. Play hat keine feste Pixelpflicht
außer der Untergrenze und Seitenverhältnis 16:9 / 9:16.

---

## Empfehlung (Ranking)

1. **Flutter `integration_test` + `binding.takeScreenshot()`** — *beste Wahl*.
   Screenshots entstehen aus echtem Widget-Tree, deterministisch, pixelgenau in
   Gerätemaßen, ein Script pro Plattform. Läuft mit `flutter test` gegen einen
   Emulator/Simulator. **Plus:** kann mit Mock-Daten gefüttert werden → man muss
   keine echte KI-Inferenz auslösen (Backend-Call vermeiden). **Minus:** braucht
   ein laufendes Gerät/Emulator (Android) bzw. Simulator + macOS (iOS).
2. **Maestro** (`maestro test` + `takeScreenshot`) — gut, wenn man die App als
   Blackbox per UI-Flow steuern will (kein Dart-Testcode). YAML-Flows, einfach
   zu lesen. Maße = Gerätemaße des Emulators/Simulators. Auch hier: Gerät nötig.
3. **Emulator + `adb exec-out screencap`** (Android) / `xcrun simctl io …
   screenshot` (iOS) — simpelster Fallback, aber Navigation muss man von Hand
   oder per Skript-Tap (adb input) machen → fragil. Nur als Notnagel.

`fastlane snapshot` (iOS) / `screengrab` (Android) sind die "klassische"
Lösung, basieren aber auf UITest/Espresso, nicht auf Flutter — für eine
Flutter-App ist `integration_test` der direktere Weg und wird hier empfohlen.

> **Ehrliche Einordnung (Stand jetzt):** Im Repo ist **kein** `integration_test`-
> Paket und kein Treiber-Setup vorhanden (nur `flutter_test`, Ordner `test/`).
> Es läuft auch **kein Emulator** in dieser Umgebung. Daher ist das hier ein
> **Gerüst + Anleitung**, das beim ersten Lauf mit Emulator/Simulator scharf
> geschaltet wird — nicht etwas, das jetzt schon headless durchläuft.

---

## Setup A (empfohlen): Flutter integration_test

### 1. Dev-Dependency ergänzen (`pubspec.yaml`)

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:        # NEU
    sdk: flutter
```

### 2. Screenshot-Treiber `test_driver/screenshot.dart`

```dart
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  try {
    await integrationDriver(
      onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        final dir = Directory('store/assets/screenshots/${Platform.operatingSystem}');
        await dir.create(recursive: true);
        final file = File('${dir.path}/$name.png');
        await file.writeAsBytes(bytes);
        return true;
      },
    );
  } catch (e) {
    stderr.writeln('screenshot driver error: $e');
  }
}
```

### 3. Screenshot-Test `integration_test/screenshots_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gamsscope/main.dart' as app; // ggf. Paketname aus pubspec anpassen

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- 01 Startscreen ---
    await binding.takeScreenshot('01_start');

    // --- 02 z.B. Kamera/Foto-Auswahl ---
    // await tester.tap(find.byKey(const Key('pick_photo')));
    // await tester.pumpAndSettle();
    // await binding.takeScreenshot('02_foto');

    // --- 03 z.B. Ergebnis (mit Mock-Daten, KEIN echter Backend-Call) ---
    // await binding.takeScreenshot('03_ergebnis');
  });
}
```

> **Wichtig (Constraint eingehalten):** Es wird **nichts am App-Code geändert**.
> Für stabile Screenshots empfiehlt sich später ein `--dart-define`-Flag oder ein
> Mock-Provider, um statt echter Gemini-Inferenz Beispieldaten anzuzeigen.
> Das ist eine *spätere* App-Änderung und bewusst hier nicht vorgenommen.

### 4. Ausführen

**Android (Emulator im Zielmaß starten — siehe AVD-Tipp unten):**
```bash
flutter drive \
  --driver=test_driver/screenshot.dart \
  --target=integration_test/screenshots_test.dart \
  -d emulator-5554
```

**iOS (nur auf macOS + Xcode-Simulator, z.B. iPhone 16 Pro Max = 6,9"):**
```bash
flutter drive \
  --driver=test_driver/screenshot.dart \
  --target=integration_test/screenshots_test.dart \
  -d "iPhone 16 Pro Max"
```

### AVD im richtigen Maß (Android, 1080×1920+)

```bash
# Beispiel: Pixel-artiges AVD mit 1080x1920 (xxhdpi)
avdmanager create avd -n gamssinn_phone -k "system-images;android-34;google_apis;x86_64" -d pixel_6
emulator -avd gamssinn_phone -no-snapshot -no-boot-anim &
adb wait-for-device
```

Die echte Render-Auflösung kommt vom AVD-Skin. Für **Play Phone** reicht jedes
AVD ≥1080×1920 Portrait. Für **Apple 6,9"** muss der Simulator ein iPhone 16
Pro Max (oder 15 Pro Max) sein — der liefert nativ 1290×2796.

### Nachbearbeitung / exakte Maße erzwingen

Falls ein Gerät leicht abweichende Maße liefert, hartes Resize auf Zielmaß:

```bash
python3 - <<'PY'
from PIL import Image, ImageOps
import glob, os
TARGETS = {"android": (1080,1920), "ios": (1290,2796)}
for plat,(w,h) in TARGETS.items():
    for f in glob.glob(f"store/assets/screenshots/{plat}/*.png"):
        im = Image.open(f).convert("RGB")
        im = ImageOps.fit(im, (w,h), Image.LANCZOS)  # zuschneiden statt verzerren
        im.save(f)
        print(f, im.size)
PY
```

---

## Setup B (Alternative): Maestro

`~/.maestro/bin/maestro` installieren, dann Flow `flows/screenshots.yaml`:

```yaml
appId: de.gamssinn.app
---
- launchApp
- takeScreenshot: store/assets/screenshots/01_start
# - tapOn: "Foto auswählen"
# - takeScreenshot: store/assets/screenshots/02_foto
```

Lauf: `maestro test flows/screenshots.yaml` (gegen laufenden Emulator/Simulator).
Maße = Gerätemaße; Nachbearbeitung wie oben.

---

## Setup C (Notnagel): adb / simctl

```bash
# Android, App manuell/skriptgesteuert in den gewünschten Screen bringen, dann:
adb exec-out screencap -p > store/assets/screenshots/android/01_start.png

# iOS-Simulator:
xcrun simctl io booted screenshot store/assets/screenshots/ios/01_start.png
```

Fragil, weil die Navigation nicht reproduzierbar ist — nur für Einzelschüsse.

---

## Status / Was jetzt blockiert ist

- ✅ Dokumentation + Script-Gerüst vorhanden (dieses File).
- ⏳ **Braucht laufendes Gerät/Emulator** → nicht jetzt headless ausführbar:
  - Android-Emulator-AVD muss gestartet werden (WSL: Emulator-GUI/KVM nötig).
  - iOS-Screenshots brauchen **macOS + Xcode-Simulator** (steht hier nicht
    zur Verfügung → nur über Mac-Runner / GitHub-Actions-macOS-Job machbar).
- 📦 Offen (spätere App-Änderung, bewusst nicht jetzt): Mock-/Demo-Modus per
  `--dart-define`, damit Screenshots ohne echten Gemini-Backend-Call entstehen.
