import 'dart:math';
import '../models/age_estimate.dart';

/// Bayesianische Engine zur Altersklassen-Bestimmung der Gams.
///
/// Verarbeitet sukzessive ML-Scores aus mehreren Fotos und
/// aktualisiert den Posterior nach jedem Foto (sequenzielles Bayes-Update).
class BayesianEngine {
  AgeEstimate _current = AgeEstimate.uniform();

  /// Aktueller Posterior (nach allen verarbeiteten Fotos)
  AgeEstimate get current => _current;

  /// Setzt den Posterior auf den gleichverteilten Prior zurück
  void reset() {
    _current = AgeEstimate.uniform();
  }

  /// Initialisiert den Posterior mit einem bestehenden Schätzwert.
  /// Nützlich wenn man auf einem vorhandenen Individuum aufbaut.
  void seedFrom(AgeEstimate estimate) {
    _current = estimate;
  }

  /// Übernimmt Vision-API Ergebnis direkt (ersetzt interne Berechnung).
  /// Vision API ist die einzige Wahrheit — kein Mock-Overlay.
  void setFromVision(AgeEstimate estimate) {
    _current = estimate;
  }

  /// Direktes Update aus TFLite MLResult (bock/geis/jung Wahrscheinlichkeiten).
  /// Verwendet p_bock/p_geis/p_jung direkt für Geschlechts-Update
  /// und leitet Alter aus jung-Wahrscheinlichkeit ab.
  void processMLResult(dynamic mlResult) {
    final pBock = mlResult.pBock as double;
    final pGeis = mlResult.pGeis as double;
    final pJung = mlResult.pJung as double;
    final quality = mlResult.quality as double;

    // Alter: jung-Klasse → Kitz/Jung; adult → Mittel/Alt
    final ageLikelihoods = {
      AgeClass.kitz: 0.5 + pJung * 2.0,
      AgeClass.jung: 0.5 + pJung * 3.0,
      AgeClass.mittel: 0.5 + (pBock + pGeis) * 0.8,
      AgeClass.alt: 0.5 + (pBock + pGeis) * 1.2,
      AgeClass.sehrAlt: 0.5 + (pBock + pGeis) * 0.5,
    };

    final sexLikelihoods = {
      'bock': 0.3 + pBock * 2.5,
      'geis': 0.3 + pGeis * 2.5,
      'unsicher': 0.3 + pJung * 1.5,
    };

    final photoFactor = min(1.0, log(_current.photoCount + 2) / log(10));
    final qualityFactor = quality * (0.5 + 0.5 * photoFactor);

    // Gaußsche Parameter aktualisieren
    final updatedWithBayes = _current.updated(
      ageLikelihoods: ageLikelihoods,
      sexLikelihoods: sexLikelihoods,
      qualityFactor: qualityFactor,
    );
    final newMeanAge = _estimateMeanAge(updatedWithBayes);
    final newStdDev = max(1.0, _current.stdDev * 0.85);

    _current = AgeEstimate(
      pKitz: updatedWithBayes.pKitz,
      pJung: updatedWithBayes.pJung,
      pMittel: updatedWithBayes.pMittel,
      pAlt: updatedWithBayes.pAlt,
      pSehrAlt: updatedWithBayes.pSehrAlt,
      pBock: updatedWithBayes.pBock,
      pGeis: updatedWithBayes.pGeis,
      pUnsicher: updatedWithBayes.pUnsicher,
      confidence: updatedWithBayes.confidence,
      photoCount: updatedWithBayes.photoCount,
      meanAge: newMeanAge,
      stdDev: newStdDev,
    );
  }

  /// Verarbeitet ML-Scores eines Fotos und aktualisiert den Posterior.
  ///
  /// [scores] — Merkmal-Scores aus MLService (Werte 0.0–1.0)
  /// [quality] — Bildqualität (0.0–1.0), beeinflusst Stärke des Updates
  /// [perspective] — Aufnahmeperspektive:
  ///   'seite'   → volle Gewichtung (1.0)
  ///   'halb'    → 75% Gewichtung
  ///   'front'   → 50% Gewichtung
  ///   'hinten'  → 35% Gewichtung
  void processScores(
      Map<String, double> scores, double quality, String perspective) {
    final perspWeight = _perspectiveWeight(perspective);
    final effectiveWeight = quality * perspWeight;

    // --- Alter-Likelihoods aus Merkmals-Scores berechnen ---
    final ageLikelihoods = _computeAgeLikelihoods(scores, effectiveWeight);

    // --- Geschlechts-Likelihoods ---
    final sexLikelihoods = _computeSexLikelihoods(scores, effectiveWeight);

    // --- Konfidenz-Faktor: steigt logarithmisch mit Fotoanzahl ---
    final photoFactor = min(1.0, log(_current.photoCount + 2) / log(10));
    final qualityFactor = quality * perspWeight * (0.5 + 0.5 * photoFactor);

    // Erst Bayes-Update durchführen
    final updatedWithBayes = _current.updated(
      ageLikelihoods: ageLikelihoods,
      sexLikelihoods: sexLikelihoods,
      qualityFactor: qualityFactor,
    );

    // Dann Gaußsche Parameter aus den neuen Posteriors berechnen
    final newMeanAge = _estimateMeanAge(updatedWithBayes);
    final newStdDev = max(1.0, _current.stdDev * 0.85);

    _current = AgeEstimate(
      pKitz: updatedWithBayes.pKitz,
      pJung: updatedWithBayes.pJung,
      pMittel: updatedWithBayes.pMittel,
      pAlt: updatedWithBayes.pAlt,
      pSehrAlt: updatedWithBayes.pSehrAlt,
      pBock: updatedWithBayes.pBock,
      pGeis: updatedWithBayes.pGeis,
      pUnsicher: updatedWithBayes.pUnsicher,
      confidence: updatedWithBayes.confidence,
      photoCount: updatedWithBayes.photoCount,
      meanAge: newMeanAge,
      stdDev: newStdDev,
    );
  }

  /// Schätze meanAge aus den dominanten Klassenwkt.
  /// Gewichteter Durchschnitt: Kitz=0.5, Jung=2, Mittel=6, Alt=10.5, SehrAlt=15
  double _estimateMeanAge(AgeEstimate est) {
    return est.pKitz * 0.5 +
        est.pJung * 2.0 +
        est.pMittel * 6.0 +
        est.pAlt * 10.5 +
        est.pSehrAlt * 15.0;
  }

  double _perspectiveWeight(String perspective) {
    switch (perspective) {
      case 'seite':
        return 1.0;
      case 'halb':
        return 0.75;
      case 'front':
        return 0.5;
      case 'hinten':
        return 0.35;
      default:
        return 0.5;
    }
  }

  /// Berechnet Alter-Likelihoods aus den Merkmal-Scores.
  ///
  /// Likelihood-Mapping (aus Wildlife-Biologie-Literatur):
  ///
  /// zuegel_kontrast HOCH → Kitz/Jung begünstigt (helles Abzeichen = jung)
  /// zuegel_kontrast NIEDRIG → Alt/SehrAlt begünstigt
  /// flanken_eingefallen HOCH → SehrAlt begünstigt
  /// rueckenlinie_konkav HOCH → Alt/SehrAlt begünstigt
  /// traeger_masse HOCH → Alt/SehrAlt begünstigt
  /// krucken_hakel HOCH → Alt/SehrAlt begünstigt (stark gebogene Hörner)
  /// koerper_schwerpunkt_vorne HOCH → Alt begünstigt
  /// fell_glanz HOCH → Kitz/Jung begünstigt
  /// bewegung_steifheit HOCH → Alt/SehrAlt begünstigt
  Map<AgeClass, double> _computeAgeLikelihoods(
      Map<String, double> scores, double weight) {
    // Starte mit neutralen Likelihoods (1.0 = kein Einfluss)
    double lKitz = 1.0;
    double lJung = 1.0;
    double lMittel = 1.0;
    double lAlt = 1.0;
    double lSehrAlt = 1.0;

    // Hilfsfunktion: Likelihood-Multiplikator für einen Score
    // score nahe 1.0 → Merkmal stark vorhanden (Faktor > 1 für begünstigte Klassen)
    // weight skaliert den Einfluss (0 = kein Update, 1 = volles Update)
    double boost(double score, double strength) =>
        1.0 + (score - 0.5) * strength * weight * 2;
    double suppress(double score, double strength) =>
        1.0 - (score - 0.5) * strength * weight * 2;

    final z = scores['zuegel_kontrast'] ?? 0.5;
    // Hoher Zügel-Kontrast → jung/kitz
    lKitz *= boost(z, 1.2).clamp(0.1, 5.0);
    lJung *= boost(z, 0.9).clamp(0.1, 5.0);
    lMittel *= 1.0; // neutral
    lAlt *= suppress(z, 0.8).clamp(0.1, 5.0);
    lSehrAlt *= suppress(z, 1.1).clamp(0.1, 5.0);

    final f = scores['flanken_eingefallen'] ?? 0.5;
    // Eingefallene Flanken → SehrAlt
    lKitz *= suppress(f, 0.8).clamp(0.1, 5.0);
    lJung *= suppress(f, 0.6).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= boost(f, 0.7).clamp(0.1, 5.0);
    lSehrAlt *= boost(f, 1.2).clamp(0.1, 5.0);

    final r = scores['rueckenlinie_konkav'] ?? 0.5;
    // Konkave Rückenlinie → Alt/SehrAlt
    lKitz *= suppress(r, 0.7).clamp(0.1, 5.0);
    lJung *= suppress(r, 0.5).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= boost(r, 0.9).clamp(0.1, 5.0);
    lSehrAlt *= boost(r, 1.1).clamp(0.1, 5.0);

    final t = scores['traeger_masse'] ?? 0.5;
    // Große Trägermasse → Alt/SehrAlt
    lKitz *= suppress(t, 0.9).clamp(0.1, 5.0);
    lJung *= suppress(t, 0.6).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= boost(t, 1.0).clamp(0.1, 5.0);
    lSehrAlt *= boost(t, 1.0).clamp(0.1, 5.0);

    final k = scores['krucken_hakel'] ?? 0.5;
    // Krucken-Häkel → Alt/SehrAlt (Hörner biegen sich erst im Alter stark)
    lKitz *= suppress(k, 1.2).clamp(0.1, 5.0);
    lJung *= suppress(k, 1.0).clamp(0.1, 5.0);
    lMittel *= suppress(k, 0.3).clamp(0.1, 5.0);
    lAlt *= boost(k, 1.0).clamp(0.1, 5.0);
    lSehrAlt *= boost(k, 1.3).clamp(0.1, 5.0);

    final sv = scores['koerper_schwerpunkt_vorne'] ?? 0.5;
    // Schwerpunkt vorne → Alt (hängt mit Muskelschwund zusammen)
    lKitz *= suppress(sv, 0.6).clamp(0.1, 5.0);
    lJung *= suppress(sv, 0.4).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= boost(sv, 1.1).clamp(0.1, 5.0);
    lSehrAlt *= boost(sv, 0.8).clamp(0.1, 5.0);

    final fg = scores['fell_glanz'] ?? 0.5;
    // Hoher Fellglanz → jung/kitz
    lKitz *= boost(fg, 1.0).clamp(0.1, 5.0);
    lJung *= boost(fg, 0.7).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= suppress(fg, 0.6).clamp(0.1, 5.0);
    lSehrAlt *= suppress(fg, 0.9).clamp(0.1, 5.0);

    final bs = scores['bewegung_steifheit'] ?? 0.5;
    // Steife Bewegung → Alt/SehrAlt
    lKitz *= suppress(bs, 0.9).clamp(0.1, 5.0);
    lJung *= suppress(bs, 0.6).clamp(0.1, 5.0);
    lMittel *= 1.0;
    lAlt *= boost(bs, 0.9).clamp(0.1, 5.0);
    lSehrAlt *= boost(bs, 1.1).clamp(0.1, 5.0);

    return {
      AgeClass.kitz: lKitz,
      AgeClass.jung: lJung,
      AgeClass.mittel: lMittel,
      AgeClass.alt: lAlt,
      AgeClass.sehrAlt: lSehrAlt,
    };
  }

  /// Berechnet Geschlechts-Likelihoods.
  /// Starke Trägermasse + Krucken → Bock-Hinweis
  Map<String, double> _computeSexLikelihoods(
      Map<String, double> scores, double weight) {
    final t = scores['traeger_masse'] ?? 0.5;
    final k = scores['krucken_hakel'] ?? 0.5;

    // Hohe Masse + starke Hörner → eher Bock
    final bockScore = (t * 0.6 + k * 0.4);
    double lBock = 1.0 + (bockScore - 0.5) * weight * 1.5;
    double lGeis = 1.0 - (bockScore - 0.5) * weight * 1.0;
    double lUnsicher = 1.0; // immer neutral

    return {
      'bock': lBock.clamp(0.1, 5.0),
      'geis': lGeis.clamp(0.1, 5.0),
      'unsicher': lUnsicher,
    };
  }
}
