# GamsScope Flutter App

Gams-Altersbestimmung via KI-Foto-Analyse.

## Modell

- **Architektur:** EfficientNet-B2 (TFLite, 8.3 MB)
- **Klassen:** bock (adulter Bock) | geis (adulte Geiß) | jung (Kitz/Jährling)
- **Val-Accuracy:** 76.2% (Stand: 2026-03-27)
- **Input:** 260×260 RGB, normalisiert (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])

## Build

### Voraussetzungen

```bash
# Flutter 3.x+ installiert
flutter --version

# Dependencies
flutter pub get
```

### iOS

```bash
cd ios && pod install
flutter build ios --release
```

### Android

```bash
flutter build apk --release
# oder
flutter build appbundle --release
```

### Debug auf Gerät

```bash
flutter run
```

## Projektstruktur

```
lib/
  main.dart                     ← App-Einstieg
  models/
    age_estimate.dart           ← Bayesianischer Posterior
    gams_individual.dart        ← Gams-Datensatz
    sighting.dart               ← Sichtungs-Daten
  services/
    ml_service.dart             ← TFLite-Inferenz (EfficientNet-B2)
    bayesian_engine.dart        ← Bayes-Update Logik
    database_service.dart       ← Lokale Datenspeicherung
  screens/
    home_screen.dart            ← Startseite
    analysis_screen.dart        ← Foto-Analyse
    gamsbook_screen.dart        ← Gams-Archiv
    gams_detail_screen.dart     ← Einzeltier-Detail
    info_screen.dart            ← Hilfe/Info

assets/
  models/
    gams_classifier.tflite      ← EfficientNet-B2 Modell
    model_metadata.json         ← Input-Konfiguration
```

## Modell-Update

Neues TFLite-Modell ersetzen:
```bash
cp models/gams/exports/gams_classifier.tflite \
   projects/gams/app/GamsScopeFlutter/assets/models/
```

## Trainingspipeline

Siehe `scripts/gams/`:
- `auto_label_vision.py` — GPT-4o-mini Auto-Labeling
- `train_classifier.py`  — EfficientNet-B2 Training (PyTorch)
- `export_tflite.py`     — ONNX → TFLite Export
