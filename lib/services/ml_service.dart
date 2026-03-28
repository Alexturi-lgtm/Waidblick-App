import 'dart:math';
import 'dart:typed_data';
import '../models/age_estimate.dart';
import 'vision_api_service.dart';

/// Ergebnis einer ML-Analyse eines Gams-Fotos.
class MLResult {
  final Map<String, double> scores;
  final double quality;
  final String perspective;
  final double pBock;
  final double pGeis;
  final double pJung;

  const MLResult({
    required this.scores,
    required this.quality,
    required this.perspective,
    required this.pBock,
    required this.pGeis,
    required this.pJung,
  });
}

/// ML-Service für Gams-Klassifikation.
/// Ruft VisionApiService auf (Backend-API mit Fallback auf Mock).
class MLService {
  bool get isLoaded => false; // Web-Build: kein TFLite → immer false

  Future<void> loadModel() async {
    // Mobile: hier TFLite-Interpreter laden
    // Web: kein TFLite verfügbar, bleibt bei VisionApiService
  }

  /// Analysiert ein Foto via VisionApiService (Backend-API).
  /// Gibt AgeEstimate zurück — bei Fehler wird Mock verwendet.
  static Future<AgeEstimate> analyzeWithEstimate(
    Uint8List imageBytes, {
    String wildartHint = 'auto',
    String region = 'steiermark',
    int photoCount = 1,
    AgeEstimate? previousEstimate,
  }) async {
    return VisionApiService.analyze(
      imageBytes: imageBytes,
      wildartHint: wildartHint,
      region: region,
      photoCount: photoCount,
      previousEstimate: previousEstimate,
    );
  }

  /// Legacy-Methode für BayesianEngine-Kompatibilität.
  /// Gibt MLResult zurück (Mock-basiert für lokale Bayes-Engine).
  Future<MLResult> analyze(Uint8List imageBytes) async {
    return _mockResult();
  }

  MLResult _buildResult(double pBock, double pGeis, double pJung) {
    final quality = [pBock, pGeis, pJung].reduce((a, b) => a > b ? a : b);
    final scores = <String, double>{
      'zuegel_kontrast': 0.5 + pJung * 0.4 - pBock * 0.2,
      'flanken_eingefallen': pBock * 0.3 + pGeis * 0.1,
      'rueckenlinie_konkav': pBock * 0.3,
      'traeger_masse': pBock * 0.6 + pGeis * 0.2,
      'krucken_hakel': pBock * 0.8 + pGeis * 0.15,
      'koerper_schwerpunkt_vorne': pBock * 0.4 + pGeis * 0.2,
      'fell_glanz': 0.3 + pJung * 0.6,
      'bewegung_steifheit': pBock * 0.2,
      'p_bock': pBock,
      'p_geis': pGeis,
      'p_jung': pJung,
    };
    return MLResult(
      scores: scores,
      quality: quality.clamp(0.5, 1.0),
      perspective: 'halb',
      pBock: pBock,
      pGeis: pGeis,
      pJung: pJung,
    );
  }

  MLResult _mockResult() {
    final rng = Random();
    final pBock = 0.3 + rng.nextDouble() * 0.4;
    final pGeis = rng.nextDouble() * (1 - pBock);
    final pJung = 1 - pBock - pGeis;
    return _buildResult(pBock, pGeis.clamp(0, 1), pJung.clamp(0, 1));
  }

  void dispose() {}
}
