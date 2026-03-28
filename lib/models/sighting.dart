import 'age_estimate.dart';

/// Eine einzelne Sichtung einer Gams mit Foto(s) und Schätzung.
class Sighting {
  final String id;
  final DateTime timestamp;
  final String notes;

  /// Absolute Dateipfade der gespeicherten Fotos
  final List<String> photos;

  /// Altersschätzung aus dieser Sichtung
  final AgeEstimate estimate;

  /// GPS-Koordinaten der Sichtung (optional)
  final double? latitude;
  final double? longitude;

  const Sighting({
    required this.id,
    required this.timestamp,
    required this.notes,
    required this.photos,
    required this.estimate,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
        'photos': photos,
        'estimate': estimate.toJson(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory Sighting.fromJson(Map<String, dynamic> json) => Sighting(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        notes: json['notes'] as String,
        photos: List<String>.from(json['photos'] as List),
        estimate: AgeEstimate.fromJson(
            json['estimate'] as Map<String, dynamic>),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}
