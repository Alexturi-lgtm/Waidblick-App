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

  const GamsIndividual({
    required this.id,
    required this.name,
    required this.revier,
    required this.firstSeen,
    required this.lastSeen,
    required this.currentEstimate,
    required this.sightings,
  });

  /// Menschenlesbare Beschreibung der aktuellen Altersschätzung
  String get ageDescription {
    final label = currentEstimate.dominantAgeLabel;
    final confidence = currentEstimate.confidenceLabel;
    return '$label ($confidence)';
  }

  /// Gibt eine Kopie mit geänderten Feldern zurück
  GamsIndividual copyWith({
    String? name,
    String? revier,
    DateTime? lastSeen,
    AgeEstimate? currentEstimate,
    List<Sighting>? sightings,
  }) {
    return GamsIndividual(
      id: id,
      name: name ?? this.name,
      revier: revier ?? this.revier,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      currentEstimate: currentEstimate ?? this.currentEstimate,
      sightings: sightings ?? this.sightings,
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
      );
}
