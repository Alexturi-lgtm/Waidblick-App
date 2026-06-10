import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/age_estimate.dart';

/// Wird geworfen, wenn das Backend ein Limit meldet (HTTP 429 = zu viele
/// Anfragen / Tageslimit, HTTP 402 = Kontingent/Quota erreicht). Traegt eine
/// fertige, nutzerfreundliche deutsche Meldung. Wird im UI separat behandelt
/// (klare Meldung statt irrefuehrender Mock-Schaetzung).
class RateLimitException implements Exception {
  final int statusCode;
  final String userMessage;
  RateLimitException(this.statusCode, this.userMessage);
  @override
  String toString() => userMessage;
}

class VisionApiService {
  // Backend URL — Hetzner Production Server
  static String backendUrl = 'https://178.104.159.28';

  static Future<AgeEstimate> analyze({
    required Uint8List imageBytes,
    required String wildartHint, // 'gams', 'rehwild', 'auto'
    required String region, // 'steiermark', 'tirol', 'bayern', etc.
    required int photoCount,
    AgeEstimate? previousEstimate, // für Bayes-Update
    bool trainingConsent = false, // Nutzer hat KI-Training freigegeben
  }) async {
    try {
      // Self-signed SSL: badCertificateCallback erlauben
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);
      final request = http.MultipartRequest(
          'POST', Uri.parse('$backendUrl/analyze'));
      request.headers.addAll({'Content-Type': 'multipart/form-data'});
      request.fields['wildart_hint'] = wildartHint;
      request.fields['region'] = region;
      if (trainingConsent) {
        // Nur mit Einwilligung: Backend gibt dann eine sample_id zurück
        request.fields['training_consent'] = 'true';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'photo.jpg',
      ));

      final response =
          await ioClient.send(request).timeout(const Duration(seconds: 90));
      final body = await response.stream.bytesToString();

      // Limit-/Quota-Status separat behandeln (freundliche Meldung statt Mock).
      if (response.statusCode == 429 || response.statusCode == 402) {
        throw RateLimitException(
          response.statusCode,
          _rateLimitMessage(response.statusCode, body),
        );
      }

      if (response.statusCode != 200) {
        throw Exception('API Fehler ${response.statusCode}: $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      return _parseApiResponse(json, photoCount, previousEstimate);
    } on RateLimitException {
      rethrow; // nicht in Mock-Fallback umwandeln
    } catch (e) {
      // Fallback: Mock wenn API nicht erreichbar — Fehlertext sichtbar machen
      final errorText = e.toString();
      final mock = AgeEstimate.mock(photoCount: photoCount);
      return AgeEstimate(
        pKitz: mock.pKitz,
        pJung: mock.pJung,
        pMittel: mock.pMittel,
        pAlt: mock.pAlt,
        pSehrAlt: mock.pSehrAlt,
        pBock: mock.pBock,
        pGeis: mock.pGeis,
        pUnsicher: mock.pUnsicher,
        confidence: mock.confidence,
        photoCount: mock.photoCount,
        meanAge: mock.meanAge,
        stdDev: mock.stdDev,
        isMale: mock.isMale,
        wildart: mock.wildart,
        begruendung: '⚠️ Mock-Schätzung (kein echtes Modell aktiv) — Fehler: $errorText',
        merkmale: mock.merkmale,
        scoring: mock.scoring,
        gewichteterScore: mock.gewichteterScore,
        geschlechtMerkmal: mock.geschlechtMerkmal,
        geschlechtSicherheit: mock.geschlechtSicherheit,
      );
    }
  }

  /// Baut eine nutzerfreundliche dt. Meldung fuer Limit-Antworten. Nutzt die
  /// Backend-Meldung (detail.message) falls vorhanden, sonst Standardtext.
  static String _rateLimitMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Body kein JSON — Standardtext nutzen.
    }
    if (statusCode == 429) {
      return 'Zu viele Anfragen. Bitte einen Moment warten und erneut versuchen.';
    }
    return 'Limit erreicht. Mit Premium kannst du mehr analysieren.';
  }

  static AgeEstimate _parseApiResponse(
    Map<String, dynamic> json,
    int photoCount,
    AgeEstimate? previous,
  ) {
    final alterJahre = (json['alter_jahre'] as num?)?.toDouble() ?? 5.0;
    final alterStddev = (json['alter_stddev'] as num?)?.toDouble() ?? 3.0;
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
    final geschlecht = json['geschlecht'] as String? ?? 'unbekannt';
    final wildart = json['wildart'] as String? ?? 'unbekannt';
    final begruendung = json['begruendung'] as String? ?? '';
    final merkmale =
        (json['merkmale'] as List<dynamic>?)?.cast<String>() ?? [];
    final scoring = json['scoring'] as Map<String, dynamic>?;
    final gewichteterScore = (json['gewichteter_score'] as num?)?.toDouble();
    final geschlechtMerkmal = json['geschlecht_merkmal'] as String? ?? '';
    final geschlechtSicherheit = json['geschlecht_sicherheit'] as String? ?? 'niedrig';
    // Nur vorhanden, wenn training_consent=true gesendet wurde
    final sampleId = json['sample_id'] as String?;

    // Bayes-Update: wenn vorherige Schätzung vorhanden, gewichtet zusammenführen
    double finalMean = alterJahre;
    double finalStd = alterStddev;

    if (previous != null && previous.photoCount > 0) {
      // Gewichtetes Mittel: mehr Fotos = mehr Gewicht auf vorherige Schätzung
      final w1 = previous.photoCount.toDouble();
      const w2 = 1.0;
      finalMean = (previous.meanAge * w1 + alterJahre * w2) / (w1 + w2);
      finalStd = (previous.stdDev * 0.85)
          .clamp(1.0, 5.0); // stdDev sinkt mit jedem Foto
    }

    // Altersklassen-Wahrscheinlichkeiten aus Gaußscher Verteilung ableiten
    final probs = _ageClassProbsFromGaussian(finalMean, finalStd);

    // Geschlechts-Wahrscheinlichkeiten
    final bool male = geschlecht == 'maennlich';
    final double pBock = male ? 0.7 : (geschlecht == 'weiblich' ? 0.1 : 1 / 3);
    final double pGeis =
        !male ? (geschlecht == 'weiblich' ? 0.7 : 1 / 3) : 0.1;
    final double pUnsicher = 1.0 - pBock - pGeis;

    return AgeEstimate(
      pKitz: probs[AgeClass.kitz]!,
      pJung: probs[AgeClass.jung]!,
      pMittel: probs[AgeClass.mittel]!,
      pAlt: probs[AgeClass.alt]!,
      pSehrAlt: probs[AgeClass.sehrAlt]!,
      pBock: pBock,
      pGeis: pGeis,
      pUnsicher: pUnsicher.clamp(0.0, 1.0),
      confidence: confidence,
      photoCount: photoCount,
      meanAge: finalMean,
      stdDev: finalStd,
      isMale: male,
      wildart: wildart,
      begruendung: begruendung,
      merkmale: merkmale,
      scoring: scoring,
      gewichteterScore: gewichteterScore,
      geschlechtMerkmal: geschlechtMerkmal,
      geschlechtSicherheit: geschlechtSicherheit,
      sampleId: sampleId,
    );
  }

  /// Sendet Ground-Truth-Feedback zu einer analysierten Probe an das Backend.
  /// Gibt true bei Erfolg zurück, false bei jedem Fehler.
  static Future<bool> submitFeedback({
    required String sampleId,
    required bool isCorrect,
    String? wildart,
    String? geschlecht,
    double? alterJahre,
    String? altersklasse,
    String? methode,
  }) async {
    try {
      // Self-signed SSL: badCertificateCallback erlauben (wie analyze)
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);
      final request = http.MultipartRequest(
          'POST', Uri.parse('$backendUrl/feedback'));
      request.headers.addAll({'Content-Type': 'multipart/form-data'});
      request.fields['sample_id'] = sampleId;
      request.fields['is_correct'] = isCorrect ? 'true' : 'false';
      if (wildart != null) request.fields['wildart'] = wildart;
      if (geschlecht != null) request.fields['geschlecht'] = geschlecht;
      if (alterJahre != null) {
        request.fields['alter_jahre'] = alterJahre.toString();
      }
      if (altersklasse != null) request.fields['altersklasse'] = altersklasse;
      if (methode != null) request.fields['methode'] = methode;

      final response =
          await ioClient.send(request).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Leitet Altersklassen-Wahrscheinlichkeiten aus Gaußscher Verteilung ab.
  /// Klassen-Zentren: Kitz=0.5, Jung=2, Mittel=6, Alt=10.5, SehrAlt=15
  static Map<AgeClass, double> _ageClassProbsFromGaussian(
      double mean, double std) {
    const centers = {
      AgeClass.kitz: 0.5,
      AgeClass.jung: 2.0,
      AgeClass.mittel: 6.0,
      AgeClass.alt: 10.5,
      AgeClass.sehrAlt: 15.0,
    };
    final raw = centers.map(
      (k, c) => MapEntry(k, exp(-0.5 * pow((c - mean) / std, 2))),
    );
    final sum = raw.values.reduce((a, b) => a + b);
    if (sum == 0) {
      return {for (final k in AgeClass.values) k: 0.2};
    }
    return raw.map((k, v) => MapEntry(k, v / sum));
  }
}
