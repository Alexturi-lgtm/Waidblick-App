import 'age_estimate.dart';
import 'sighting.dart';

/// Repräsentiert eine bekannte Gams im GamsBook.
class GamsIndividual {
  final String id;
  final String name;
  final String revier;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final AgeEstimate currentEstimate;
  final List<Sighting> sightings;
  // Sprint 2 Erweiterungen
  final String wildart; // 'gams', 'rehwild', 'rotwild'
  final DateTime? capturedDate; // Aufnahmedatum
  final DateTime? erlegtAt; // Erlegungsdatum
  final int? tatsaechlichesAlter; // Tatsächliches Alter in Jahren

  const GamsIndividual({
    required this.id,
    required this.name,
    required this.revier,
    required this.firstSeen,
    required this.lastSeen,
    required this.currentEstimate,
    required this.sightings,
    this.wildart = 'gams',
    this.capturedDate,
    this.erlegtAt,
    this.tatsaechlichesAlter,
  });

  /// Menschenlesbare Beschreibung der aktuellen Altersschätzung
  String get ageDescription {
    final label = currentEstimate.dominantAgeLabel;
    final confidence = currentEstimate.confidenceLabel;
    return '$label ($confidence)';
  }

  /// Pfad zum ersten Foto (für Thumbnail)
  String? get firstPhotoPath {
    for (final s in sightings) {
      if (s.photos.isNotEmpty) return s.photos.first;
    }
    return null;
  }

  /// Gibt eine Kopie mit geänderten Feldern zurück
  GamsIndividual copyWith({
    String? name,
    String? revier,
    DateTime? lastSeen,
    AgeEstimate? currentEstimate,
    List<Sighting>? sightings,
    String? wildart,
    DateTime? capturedDate,
    DateTime? erlegtAt,
    bool clearErlegtAt = false,
    int? tatsaechlichesAlter,
    bool clearTatsaechlichesAlter = false,
  }) {
    return GamsIndividual(
      id: id,
      name: name ?? this.name,
      revier: revier ?? this.revier,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      currentEstimate: currentEstimate ?? this.currentEstimate,
      sightings: sightings ?? this.sightings,
      wildart: wildart ?? this.wildart,
      capturedDate: capturedDate ?? this.capturedDate,
      erlegtAt: clearErlegtAt ? null : (erlegtAt ?? this.erlegtAt),
      tatsaechlichesAlter: clearTatsaechlichesAlter
          ? null
          : (tatsaechlichesAlter ?? this.tatsaechlichesAlter),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'revier': revier,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'currentEstimate': currentEstimate.toJson(),
        'sightings': sightings.map((s) => s.toJson()).toList(),
        'wildart': wildart,
        if (capturedDate != null) 'capturedDate': capturedDate!.toIso8601String(),
        if (erlegtAt != null) 'erlegtAt': erlegtAt!.toIso8601String(),
        if (tatsaechlichesAlter != null) 'tatsaechlichesAlter': tatsaechlichesAlter,
      };

  factory GamsIndividual.fromJson(Map<String, dynamic> json) => GamsIndividual(
        id: json['id'] as String,
        name: json['name'] as String,
        revier: json['revier'] as String,
        firstSeen: DateTime.parse(json['firstSeen'] as String),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        currentEstimate: AgeEstimate.fromJson(
            json['currentEstimate'] as Map<String, dynamic>),
        sightings: (json['sightings'] as List)
            .map((s) => Sighting.fromJson(s as Map<String, dynamic>))
            .toList(),
        wildart: (json['wildart'] as String?) ?? 'gams',
        capturedDate: json['capturedDate'] != null
            ? DateTime.parse(json['capturedDate'] as String)
            : null,
        erlegtAt: json['erlegtAt'] != null
            ? DateTime.parse(json['erlegtAt'] as String)
            : null,
        tatsaechlichesAlter: json['tatsaechlichesAlter'] as int?,
      );
}
