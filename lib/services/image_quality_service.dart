import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Client-seitiger Bild-Qualitäts-Check, der VOR dem (teuren) Backend-/Gemini-
/// Analyse-Call läuft. Ziel: aussichtslose Fotos (zu klein, zu dunkel, unscharf,
/// nahezu einfarbig) abfangen, bevor sie einen API-Call auslösen.
///
/// Es werden NUR bereits vorhandene Bordmittel genutzt (`dart:ui`); keine neue
/// Dependency. Die Pixel-Analyse läuft auf einer stark herunterskalierten Kopie
/// des Bildes, daher ist sie auch auf älteren Geräten schnell.
///
/// Schwellenwerte sind bewusst KONSERVATIV gewählt: im Zweifel das Foto
/// durchlassen (lieber analysieren als den Jäger nerven).
class ImageQualityService {
  // ── Schwellenwerte (konservativ) ───────────────────────────────────────────

  /// Kürzeste Bildkante in Pixeln, unterhalb derer gewarnt wird.
  static const int kMinEdgePx = 512;

  /// Mittlere Luminanz (0–255), unterhalb derer das Bild als „zu dunkel" gilt.
  static const double kMinBrightness = 40.0;

  /// Mittlere Luminanz, oberhalb derer das Bild als „überbelichtet" gilt.
  static const double kMaxBrightness = 245.0;

  /// Varianz des Graustufen-Laplace (Schärfe-Maß). Darunter = „unscharf".
  /// Auf 8-bit-Luminanz; typische scharfe Naturfotos liegen deutlich höher.
  static const double kMinLaplaceVariance = 35.0;

  /// Globale Luminanz-Varianz. Darunter = nahezu einfarbig / detailarm
  /// (Himmel, Wand, verschwommener Nahschuss → wahrscheinlich kein Tier).
  static const double kMinDetailVariance = 60.0;

  /// Kantenlänge der herunterskalierten Analyse-Kopie. Klein = schnell,
  /// aber groß genug für brauchbare Schärfe-/Detailmaße.
  static const int kAnalysisEdge = 256;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Analysiert die Bytes und liefert ein [ImageQualityResult].
  /// Wirft NIE — bei Decode-Fehlern wird das Bild durchgelassen (ok=true),
  /// damit der Check nie den normalen Ablauf blockiert.
  static Future<ImageQualityResult> check(Uint8List imageBytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final int origW = image.width;
      final int origH = image.height;

      final issues = <ImageQualityIssue>[];

      // 1) Auflösung anhand der ORIGINAL-Dimensionen prüfen.
      final int minEdge = origW < origH ? origW : origH;
      if (minEdge > 0 && minEdge < kMinEdgePx) {
        issues.add(ImageQualityIssue.lowResolution);
      }

      // Für die Pixel-Statistik auf eine kleine Kopie herunterskalieren.
      final _GrayStats stats = await _grayStats(image);
      image.dispose();
      codec.dispose();

      // 2) Helligkeit.
      if (stats.meanLuma < kMinBrightness) {
        issues.add(ImageQualityIssue.tooDark);
      } else if (stats.meanLuma > kMaxBrightness) {
        issues.add(ImageQualityIssue.tooBright);
      }

      // 3) Schärfe (Laplace-Varianz). Nur werten, wenn das Bild nicht
      //    ohnehin sehr dunkel ist (Rauschen verfälscht sonst die Varianz).
      if (stats.meanLuma >= kMinBrightness &&
          stats.laplaceVariance < kMinLaplaceVariance) {
        issues.add(ImageQualityIssue.blurry);
      }

      // 4) Nahezu einfarbig / detailarm.
      if (stats.detailVariance < kMinDetailVariance) {
        issues.add(ImageQualityIssue.lowDetail);
      }

      return ImageQualityResult(
        ok: issues.isEmpty,
        issues: issues,
        width: origW,
        height: origH,
        meanLuma: stats.meanLuma,
        laplaceVariance: stats.laplaceVariance,
        detailVariance: stats.detailVariance,
      );
    } catch (_) {
      // Im Fehlerfall NICHT blockieren.
      return const ImageQualityResult(
        ok: true,
        issues: [],
        width: 0,
        height: 0,
        meanLuma: 0,
        laplaceVariance: 0,
        detailVariance: 0,
      );
    }
  }

  // ── Pixel-Statistik ──────────────────────────────────────────────────────────

  /// Skaliert das Bild auf [kAnalysisEdge] (längere Kante) herunter, liest die
  /// RGBA-Pixel und berechnet mittlere Luminanz, globale Luminanz-Varianz sowie
  /// die Varianz des Laplace-Operators (Schärfe).
  static Future<_GrayStats> _grayStats(ui.Image image) async {
    final int w = image.width;
    final int h = image.height;
    if (w == 0 || h == 0) {
      return _GrayStats(meanLuma: 0, detailVariance: 0, laplaceVariance: 0);
    }

    // Zielgröße bestimmen (längste Kante = kAnalysisEdge, Seitenverhältnis halten).
    final double scale = kAnalysisEdge / (w > h ? w : h);
    final int tw = (w * scale).round().clamp(2, kAnalysisEdge);
    final int th = (h * scale).round().clamp(2, kAnalysisEdge);

    // Herunterskalieren via Canvas.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      paint,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image small = await picture.toImage(tw, th);
    picture.dispose();

    final ByteData? data =
        await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    if (data == null) {
      return _GrayStats(meanLuma: 0, detailVariance: 0, laplaceVariance: 0);
    }

    final Uint8List rgba = data.buffer.asUint8List();
    final int pixelCount = tw * th;

    // Graustufen-Puffer (Luma nach Rec. 601).
    final Uint8List gray = Uint8List(pixelCount);
    double sum = 0;
    double sumSq = 0;
    for (int i = 0, p = 0; i < pixelCount; i++, p += 4) {
      final int r = rgba[p];
      final int g = rgba[p + 1];
      final int b = rgba[p + 2];
      final int y = ((r * 299 + g * 587 + b * 114) ~/ 1000);
      gray[i] = y;
      sum += y;
      sumSq += y * y;
    }
    final double mean = sum / pixelCount;
    final double detailVar = (sumSq / pixelCount) - (mean * mean);

    // Laplace (4-Nachbarn) über den inneren Bereich; Varianz der Antwort.
    double lSum = 0;
    double lSumSq = 0;
    int lCount = 0;
    for (int y = 1; y < th - 1; y++) {
      final int row = y * tw;
      for (int x = 1; x < tw - 1; x++) {
        final int idx = row + x;
        final int lap = (gray[idx] * 4) -
            gray[idx - 1] -
            gray[idx + 1] -
            gray[idx - tw] -
            gray[idx + tw];
        lSum += lap;
        lSumSq += lap * lap;
        lCount++;
      }
    }
    double lapVar = 0;
    if (lCount > 0) {
      final double lMean = lSum / lCount;
      lapVar = (lSumSq / lCount) - (lMean * lMean);
      if (lapVar < 0) lapVar = 0;
    }

    return _GrayStats(
      meanLuma: mean,
      detailVariance: detailVar < 0 ? 0 : detailVar,
      laplaceVariance: lapVar,
    );
  }
}

/// Art des erkannten Qualitätsproblems.
enum ImageQualityIssue {
  lowResolution,
  tooDark,
  tooBright,
  blurry,
  lowDetail,
}

extension ImageQualityIssueText on ImageQualityIssue {
  /// Freundlicher, jagdlich-sachlicher Hinweis (Deutsch).
  String get message {
    switch (this) {
      case ImageQualityIssue.lowResolution:
        return 'Das Foto hat eine niedrige Auflösung – ein größeres, '
            'näheres Bild verbessert die Ansprache.';
      case ImageQualityIssue.tooDark:
        return 'Das Bild wirkt sehr dunkel – ein helleres Foto verbessert '
            'die Ansprache.';
      case ImageQualityIssue.tooBright:
        return 'Das Bild wirkt stark überbelichtet – weniger Gegenlicht '
            'bringt mehr Details aufs Wild.';
      case ImageQualityIssue.blurry:
        return 'Das Foto wirkt unscharf – ruhig halten oder auflegen schärft '
            'die Merkmale.';
      case ImageQualityIssue.lowDetail:
        return 'Auf dem Bild sind kaum Details zu erkennen – ist das Wild '
            'wirklich im Bild und groß genug?';
    }
  }
}

/// Ergebnis des Vor-Analyse-Qualitäts-Checks.
class ImageQualityResult {
  /// true = keine Beanstandung, Bild kann direkt analysiert werden.
  final bool ok;
  final List<ImageQualityIssue> issues;
  final int width;
  final int height;
  final double meanLuma;
  final double laplaceVariance;
  final double detailVariance;

  const ImageQualityResult({
    required this.ok,
    required this.issues,
    required this.width,
    required this.height,
    required this.meanLuma,
    required this.laplaceVariance,
    required this.detailVariance,
  });

  bool get hasIssues => issues.isNotEmpty;

  /// Kurzer Titel für den Hinweis-Dialog (mehrere Probleme → generisch).
  String get title {
    if (issues.length == 1) {
      switch (issues.first) {
        case ImageQualityIssue.lowResolution:
          return 'Niedrige Auflösung';
        case ImageQualityIssue.tooDark:
          return 'Bild sehr dunkel';
        case ImageQualityIssue.tooBright:
          return 'Bild überbelichtet';
        case ImageQualityIssue.blurry:
          return 'Bild unscharf';
        case ImageQualityIssue.lowDetail:
          return 'Wenig erkennbar';
      }
    }
    return 'Foto-Qualität prüfen';
  }

  /// Alle Hinweis-Texte zu den erkannten Problemen.
  List<String> get messages => issues.map((e) => e.message).toList();
}

/// Interne Graustufen-Statistik.
class _GrayStats {
  final double meanLuma;
  final double detailVariance;
  final double laplaceVariance;

  _GrayStats({
    required this.meanLuma,
    required this.detailVariance,
    required this.laplaceVariance,
  });
}
