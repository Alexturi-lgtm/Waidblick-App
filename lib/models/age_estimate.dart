import 'dart:math';

/// Repräsentiert eine bayesianische Altersschätzung einer Gams.
/// Die fünf Altersklassen-Wahrscheinlichkeiten summieren sich auf 1.0,
/// ebenso die drei Geschlechts-Wahrscheinlichkeiten.
enum AgeClass { kitz, jung, mittel, alt, sehrAlt }

class AgeEstimate {
  /// Altersklassen-Wahrscheinlichkeiten (summieren zu 1.0)
  final double pKitz;
  final double pJung;
  final double pMittel;
  final double pAlt;
  final double pSehrAlt;

  /// Geschlechts-Wahrscheinlichkeiten (summieren zu 1.0)
  final double pBock;
  final double pGeis;
  final double pUnsicher;

  /// Gesamtkonfidenz (0.0 – 1.0), steigt mit mehr Fotos
  final double confidence;

  /// Anzahl der bisher verarbeiteten Fotos
  final int photoCount;

  /// Gaußsche Schätzung: Mittleres Alter in Jahren
  final double meanAge; // Start: 8.0

  /// Standardabweichung — wird mit jedem Foto kleiner
  final double stdDev; // Start: 5.0 (breit), nach 5 Fotos ~1.5 (schmal)

  /// Ob das Tier männlich ist (Bock) — aus Vision API
  final bool isMale;

  /// Wildart aus Vision API: 'gams', 'rehwild', 'rotwild', 'unbekannt', 'kein_wild'
  final String wildart;

  /// Begründung der KI-Analyse
  final String begruendung;

  /// Erkannte Merkmale aus der KI-Analyse
  final List<String> merkmale;

  /// Wissenschaftliches Scoring (optional, null wenn nicht verfügbar)
  /// Format: {"hakenkruemmung": {"wert": 4, "beobachtung": "..."}, ...}
  final Map<String, dynamic>? scoring;

  /// Gewichteter Score aus dem Scoring-System (1.0–5.0, null wenn nicht verfügbar)
  final double? gewichteterScore;

  /// Geschlecht-Bestimmungs-Merkmal (primär oder sekundär)
  final String geschlechtMerkmal;

  /// Sicherheit der Geschlechtsbestimmung
  final String geschlechtSicherheit;

  const AgeEstimate({
    required this.pKitz,
    required this.pJung,
    required this.pMittel,
    required this.pAlt,
    required this.pSehrAlt,
    required this.pBock,
    required this.pGeis,
    required this.pUnsicher,
    required this.confidence,
    required this.photoCount,
    this.meanAge = 8.0,
    this.stdDev = 5.0,
    this.isMale = false,
    this.wildart = 'gams',
    this.begruendung = '',
    this.merkmale = const [],
    this.scoring,
    this.gewichteterScore,
    this.geschlechtMerkmal = '',
    this.geschlechtSicherheit = 'niedrig',
  });

  /// Mock-Schätzung für Fallback/Tests
  static AgeEstimate mock({int photoCount = 0}) => AgeEstimate(
        pKitz: 0.05,
        pJung: 0.15,
        pMittel: 0.45,
        pAlt: 0.25,
        pSehrAlt: 0.10,
        pBock: 1 / 3,
        pGeis: 1 / 3,
        pUnsicher: 1 / 3,
        confidence: 0.6,
        photoCount: photoCount,
        meanAge: 7.0,
        stdDev: 3.0,
        isMale: false,
        wildart: 'gams',
        begruendung: 'Mock-Schätzung (kein echtes Modell aktiv)',
        merkmale: const [],
        scoring: null,
        gewichteterScore: null,
        geschlechtMerkmal: '',
        geschlechtSicherheit: 'niedrig',
      );

  /// Gleichverteilter Prior – Ausgangspunkt vor jeder Analyse
  factory AgeEstimate.uniform() {
    return const AgeEstimate(
      pKitz: 0.2,
      pJung: 0.2,
      pMittel: 0.2,
      pAlt: 0.2,
      pSehrAlt: 0.2,
      pBock: 1 / 3,
      pGeis: 1 / 3,
      pUnsicher: 1 / 3,
      confidence: 0.0,
      photoCount: 0,
      meanAge: 8.0,
      stdDev: 5.0,
    );
  }

  /// Gaußsche Wahrscheinlichkeitsdichte für ein bestimmtes Alter
  double gaussianAt(int age) {
    final x = age.toDouble();
    final exponent = -0.5 * pow((x - meanAge) / stdDev, 2);
    return (1 / (stdDev * sqrt(2 * pi))) * exp(exponent);
  }

  /// Normalisierte Balken-Höhen für Jahre 0-20 (summieren zu 1.0)
  List<double> get gaussianBars {
    final raw = List.generate(21, (i) => gaussianAt(i));
    final sum = raw.reduce((a, b) => a + b);
    if (sum == 0) return List.filled(21, 1.0 / 21);
    return raw.map((v) => v / sum).toList();
  }

  /// Konfidenzintervall als String, z.B. "10–14 Jahre"
  String get confidenceInterval {
    final lower = (meanAge - stdDev).clamp(0.0, 20.0).round();
    final upper = (meanAge + stdDev).clamp(0.0, 20.0).round();
    return '$lower–$upper Jahre';
  }

  /// Die dominante Altersklasse (höchste Wahrscheinlichkeit)
  AgeClass get dominantAgeClass {
    final probs = {
      AgeClass.kitz: pKitz,
      AgeClass.jung: pJung,
      AgeClass.mittel: pMittel,
      AgeClass.alt: pAlt,
      AgeClass.sehrAlt: pSehrAlt,
    };
    return probs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Deutsches Label für die dominante Altersklasse
  String get dominantAgeLabel {
    switch (dominantAgeClass) {
      case AgeClass.kitz:
        return 'Kitz (<1 Jahr)';
      case AgeClass.jung:
        return 'Jung (1–3 Jahre)';
      case AgeClass.mittel:
        return 'Mittelalt (4–8 Jahre)';
      case AgeClass.alt:
        return 'Alt (9–12 Jahre)';
      case AgeClass.sehrAlt:
        return 'Sehr alt (13+ Jahre)';
    }
  }

  /// Jagdrechtliche Freigabe-Information (statisch, Fallback)
  String get huntingInfo {
    switch (dominantAgeClass) {
      case AgeClass.kitz:
        return '⛔ Nicht bejagbar – Jahrgang';
      case AgeClass.jung:
        return '⛔ Nicht bejagbar – Aufwachsphase';
      case AgeClass.mittel:
        return '⚠️ Nicht freigegeben – noch kein Abschussalter';
      case AgeClass.alt:
        return '🦌 Bock ab 12 J. freigegeben\n⛔ Geiß noch nicht freigegeben';
      case AgeClass.sehrAlt:
        return '✅ Bock freigegeben (≥12 J.)\n✅ Geiß freigegeben (≥15 J.)';
    }
  }

  /// Beschreibung der typischen Merkmale dieser Altersklasse
  String get ageDescription {
    switch (dominantAgeClass) {
      case AgeClass.kitz:
        return 'Kleines Tier, helles Fell, noch keine ausgeprägten Hörner. Bleibt bei der Mutter.';
      case AgeClass.jung:
        return 'Schlanker Körperbau, heller Zügelstreif, kurze gerade Hörner. Lebhaft und wenig scheu.';
      case AgeClass.mittel:
        return 'Vollentwickelter Körper, deutlicher Zügel, Hörner mit beginnender Krümmung. Gute Körperkondition.';
      case AgeClass.alt:
        return 'Massiger Träger und Hals, eingefallene Flanken, Hornhaken deutlich ausgebildet. Rücken leicht durchgebogen.';
      case AgeClass.sehrAlt:
        return 'Stark eingefallene Flanken, ausgeprägter Höcker, grobe Hornhaken, Bewegung etwas steifer. Seneszenzzeichen sichtbar.';
    }
  }

  /// Wahrscheinlichkeit der dominanten Altersklasse
  double get dominantProbability {
    switch (dominantAgeClass) {
      case AgeClass.kitz:    return pKitz;
      case AgeClass.jung:    return pJung;
      case AgeClass.mittel:  return pMittel;
      case AgeClass.alt:     return pAlt;
      case AgeClass.sehrAlt: return pSehrAlt;
    }
  }

  /// True wenn Konfidenz zu niedrig für verlässliche Aussage
  bool get isUncertain => confidence < 0.35 && photoCount > 0;

  /// True wenn Tier sehr wahrscheinlich kein Schalenwild
  // TODO: aktivieren wenn TFLite-Modell erkennt ob Schalenwild im Bild
  bool get isNotGams => false;

  /// Lesbare Konfidenz-Anzeige, z.B. "87% sicher"
  String get confidenceLabel {
    final pct = (confidence * 100).round();
    if (photoCount == 0) return 'Noch keine Analyse';
    return '$pct% sicher';
  }

  /// Bayesianisches Update: multipliziert aktuelle Priors mit neuen Likelihoods
  /// und normalisiert. [ageLikelihoods] und [sexLikelihoods] sind unnormalisiert.
  AgeEstimate updated({
    required Map<AgeClass, double> ageLikelihoods,
    Map<String, double>? sexLikelihoods,
    double qualityFactor = 1.0,
    double? newMeanAge,
    double? newStdDev,
  }) {
    // --- Altersklassen-Update ---
    double newKitz = pKitz * (ageLikelihoods[AgeClass.kitz] ?? 1.0);
    double newJung = pJung * (ageLikelihoods[AgeClass.jung] ?? 1.0);
    double newMittel = pMittel * (ageLikelihoods[AgeClass.mittel] ?? 1.0);
    double newAlt = pAlt * (ageLikelihoods[AgeClass.alt] ?? 1.0);
    double newSehrAlt = pSehrAlt * (ageLikelihoods[AgeClass.sehrAlt] ?? 1.0);

    final ageSum = newKitz + newJung + newMittel + newAlt + newSehrAlt;
    if (ageSum > 0) {
      newKitz /= ageSum;
      newJung /= ageSum;
      newMittel /= ageSum;
      newAlt /= ageSum;
      newSehrAlt /= ageSum;
    }

    // --- Geschlechts-Update ---
    double newBock = pBock * (sexLikelihoods?['bock'] ?? 1.0);
    double newGeis = pGeis * (sexLikelihoods?['geis'] ?? 1.0);
    double newUnsicher = pUnsicher * (sexLikelihoods?['unsicher'] ?? 1.0);

    final sexSum = newBock + newGeis + newUnsicher;
    if (sexSum > 0) {
      newBock /= sexSum;
      newGeis /= sexSum;
      newUnsicher /= sexSum;
    }

    // --- Konfidenz berechnen ---
    final maxAge = [newKitz, newJung, newMittel, newAlt, newSehrAlt]
        .reduce((a, b) => a > b ? a : b);
    final rawConfidence = (maxAge - 0.2) / 0.8 * qualityFactor;
    final newConfidence = max(0.0, min(1.0, rawConfidence));

    return AgeEstimate(
      pKitz: newKitz,
      pJung: newJung,
      pMittel: newMittel,
      pAlt: newAlt,
      pSehrAlt: newSehrAlt,
      pBock: newBock,
      pGeis: newGeis,
      pUnsicher: newUnsicher,
      confidence: newConfidence,
      photoCount: photoCount + 1,
      meanAge: newMeanAge ?? meanAge,
      stdDev: newStdDev ?? stdDev,
      isMale: isMale,
      wildart: wildart,
      begruendung: begruendung,
      merkmale: merkmale,
      scoring: scoring,
      gewichteterScore: gewichteterScore,
      geschlechtMerkmal: geschlechtMerkmal,
      geschlechtSicherheit: geschlechtSicherheit,
    );
  }

  Map<String, dynamic> toJson() => {
        'pKitz': pKitz,
        'pJung': pJung,
        'pMittel': pMittel,
        'pAlt': pAlt,
        'pSehrAlt': pSehrAlt,
        'pBock': pBock,
        'pGeis': pGeis,
        'pUnsicher': pUnsicher,
        'confidence': confidence,
        'photoCount': photoCount,
        'meanAge': meanAge,
        'stdDev': stdDev,
        'isMale': isMale,
        'wildart': wildart,
        'begruendung': begruendung,
        'merkmale': merkmale,
        if (scoring != null) 'scoring': scoring,
        if (gewichteterScore != null) 'gewichteter_score': gewichteterScore,
        if (geschlechtMerkmal.isNotEmpty) 'geschlecht_merkmal': geschlechtMerkmal,
        if (geschlechtSicherheit.isNotEmpty) 'geschlecht_sicherheit': geschlechtSicherheit,
      };

  factory AgeEstimate.fromJson(Map<String, dynamic> json) => AgeEstimate(
        pKitz: (json['pKitz'] as num).toDouble(),
        pJung: (json['pJung'] as num).toDouble(),
        pMittel: (json['pMittel'] as num).toDouble(),
        pAlt: (json['pAlt'] as num).toDouble(),
        pSehrAlt: (json['pSehrAlt'] as num).toDouble(),
        pBock: (json['pBock'] as num).toDouble(),
        pGeis: (json['pGeis'] as num).toDouble(),
        pUnsicher: (json['pUnsicher'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        photoCount: json['photoCount'] as int,
        meanAge: (json['meanAge'] as num? ?? 8.0).toDouble(),
        stdDev: (json['stdDev'] as num? ?? 5.0).toDouble(),
        isMale: json['isMale'] as bool? ?? false,
        wildart: json['wildart'] as String? ?? 'gams',
        begruendung: json['begruendung'] as String? ?? '',
        merkmale: (json['merkmale'] as List<dynamic>?)?.cast<String>() ?? [],
        scoring: json['scoring'] as Map<String, dynamic>?,
        gewichteterScore: (json['gewichteter_score'] as num?)?.toDouble(),
        geschlechtMerkmal: json['geschlecht_merkmal'] as String? ?? '',
        geschlechtSicherheit: json['geschlecht_sicherheit'] as String? ?? 'niedrig',
      );
}
