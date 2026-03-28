import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Ergebnis der Foto-Qualitäts-Analyse
class PhotoQualityResult {
  final double overallScore; // 0.0 – 1.0 (Gesamt)
  final double sharpnessScore; // Schärfe
  final double sizeScore; // Tier-Größe im Bild (geschätzt)
  final double brightnessScore; // Helligkeit
  final double angleScore; // Perspektive (Seite am besten)

  final String verdict; // "Perfekt", "Gut", "Ausreichend", "Schlecht"
  final Color verdictColor;
  final List<String> tips; // Konkrete Verbesserungshinweise
  final bool isUsable; // false = Analyse verweigern

  const PhotoQualityResult({
    required this.overallScore,
    required this.sharpnessScore,
    required this.sizeScore,
    required this.brightnessScore,
    required this.angleScore,
    required this.verdict,
    required this.verdictColor,
    required this.tips,
    required this.isUsable,
  });

  /// Score als Prozent
  int get scorePercent => (overallScore * 100).round();

  /// Sterne 1-5
  int get stars => (overallScore * 5).ceil().clamp(1, 5);
}

class PhotoQualityService {
  /// Analysiert Foto-Qualität (vereinfacht, ohne TFLite)
  /// Nutzt Bildgröße, Datei-Größe und Heuristiken
  static Future<PhotoQualityResult> analyze(Uint8List imageBytes) async {
    final bytes = imageBytes;
    final fileSizeKB = bytes.length / 1024;

    // Helligkeit: Durchschnitt der Pixel-Helligkeit (vereinfacht via Dateigröße-Heuristik)
    // Echte Implementierung: image package (aber web-inkompatibel)
    // Heuristik: JPEG <50KB → wahrscheinlich sehr dunkel oder sehr klein

    final double sharpness = _estimateSharpness(bytes.length, fileSizeKB);
    final double brightness = _estimateBrightness(bytes);
    final double sizeInFrame = _estimateSubjectSize(fileSizeKB);
    const double angle = 0.7; // Default "Halbprofil" — ohne CV nicht besser schätzbar

    final overall =
        (sharpness * 0.35 + sizeInFrame * 0.35 + brightness * 0.20 + angle * 0.10);

    final tips = <String>[];
    if (sharpness < 0.6) tips.add('📸 Foto ist unscharf — ruhig halten oder Stativ nutzen');
    if (sizeInFrame < 0.5) tips.add('🔍 Tier zu klein im Bild — näher heran oder Zoom nutzen');
    if (sizeInFrame < 0.3) {
      tips.add('⚠️ Tier nimmt weniger als 20% des Bildes ein — Analyse sehr ungenau');
    }
    if (brightness < 0.4) tips.add('☀️ Bild zu dunkel — bessere Lichtverhältnisse wählen');
    if (brightness > 0.9) tips.add('🌟 Bild überbelichtet — Gegenlicht vermeiden');
    if (tips.isEmpty) tips.add('✅ Foto-Qualität ist gut für die Analyse');

    String verdict;
    Color color;
    if (overall >= 0.75) {
      verdict = 'Perfekt';
      color = Colors.green;
    } else if (overall >= 0.55) {
      verdict = 'Gut';
      color = Colors.lightGreen;
    } else if (overall >= 0.35) {
      verdict = 'Ausreichend';
      color = Colors.orange;
    } else {
      verdict = 'Schlecht';
      color = Colors.red;
    }

    return PhotoQualityResult(
      overallScore: overall,
      sharpnessScore: sharpness,
      sizeScore: sizeInFrame,
      brightnessScore: brightness,
      angleScore: angle,
      verdict: verdict,
      verdictColor: color,
      tips: tips,
      isUsable: overall >= 0.25,
    );
  }

  static double _estimateSharpness(int byteLength, double fileSizeKB) {
    // JPEG-Kompression: schärfere Bilder = mehr Details = größere Datei
    if (fileSizeKB > 800) return 0.95;
    if (fileSizeKB > 400) return 0.85;
    if (fileSizeKB > 200) return 0.70;
    if (fileSizeKB > 100) return 0.55;
    if (fileSizeKB > 50) return 0.40;
    return 0.20;
  }

  static double _estimateBrightness(List<int> bytes) {
    // Sample erste 1000 Bytes nach JPEG-Header für grobe Helligkeits-Schätzung
    // Einfache Heuristik: Byte-Durchschnitt im mittleren Bereich
    if (bytes.length < 100) return 0.5;
    final sample = bytes.skip(100).take(500).toList();
    final avg = sample.reduce((a, b) => a + b) / sample.length;
    // JPEG-komprimierte Daten: avg ~100-180 = normales Foto
    if (avg < 50) return 0.2; // Sehr dunkel
    if (avg < 80) return 0.45;
    if (avg < 150) return 0.75;
    if (avg < 200) return 0.90;
    return 0.6; // Sehr hell = möglicherweise überbelichtet
  }

  static double _estimateSubjectSize(double fileSizeKB) {
    // Grobe Heuristik: Größere Dateien = mehr Detailinhalt = Tier näher
    if (fileSizeKB > 1500) return 0.90;
    if (fileSizeKB > 800) return 0.75;
    if (fileSizeKB > 400) return 0.60;
    if (fileSizeKB > 150) return 0.45;
    if (fileSizeKB > 80) return 0.30;
    return 0.15;
  }
}
