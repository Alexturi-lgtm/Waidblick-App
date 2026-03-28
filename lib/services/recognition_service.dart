import '../models/gams_individual.dart';
import '../models/age_estimate.dart';
import 'location_service.dart';

class RecognitionMatch {
  final GamsIndividual individual;
  final double score; // 0–100
  final String reason; // z.B. "Gleiche Region, passendes Alter, ähnliches Geschlecht"
  final bool isProbable; // score > 70
  final bool isAlmostCertain; // score > 85

  const RecognitionMatch({
    required this.individual,
    required this.score,
    required this.reason,
    required this.isProbable,
    required this.isAlmostCertain,
  });

  String get confidenceLabel {
    if (isAlmostCertain) return 'Fast sicher dieselbe Gams';
    if (isProbable) return 'Wahrscheinlich dieselbe Gams';
    return 'Möglicherweise dieselbe Gams';
  }
}

class RecognitionService {
  static const double _maxDistanceKm = 5.0;

  /// Vergleicht neue Schätzung mit allen bekannten Individuen.
  /// Gibt sortierte Matches zurück (beste zuerst).
  static List<RecognitionMatch> findMatches({
    required AgeEstimate newEstimate,
    required List<GamsIndividual> individuals,
    double? newLat,
    double? newLon,
  }) {
    final matches = <RecognitionMatch>[];

    for (final ind in individuals) {
      double score = 0;
      final reasons = <String>[];

      // 1. Geo-Check (k.o.-Kriterium bei >5km)
      if (newLat != null && newLon != null) {
        final lastSighting = ind.sightings.isNotEmpty ? ind.sightings.last : null;
        if (lastSighting?.latitude != null && lastSighting?.longitude != null) {
          final dist = LocationService.distanceKm(
            newLat,
            newLon,
            lastSighting!.latitude!,
            lastSighting.longitude!,
          );
          if (dist > _maxDistanceKm) continue; // Zu weit weg — ausschließen
          score += 20;
          reasons.add('Gleiche Region (${dist.toStringAsFixed(1)}km)');
        }
      }

      // 2. Altersplausibilität — Alter kann nur steigen
      final existingMeanAge = ind.currentEstimate.meanAge;
      final newMeanAge = newEstimate.meanAge;
      final daysSinceLastSeen = DateTime.now().difference(ind.lastSeen).inDays;
      final yearsElapsed = daysSinceLastSeen / 365.0;

      final expectedMinAge = existingMeanAge + yearsElapsed - 1.5;
      final expectedMaxAge = existingMeanAge + yearsElapsed + 1.5;

      if (newMeanAge >= expectedMinAge && newMeanAge <= expectedMaxAge) {
        score += 30;
        reasons.add(
            'Alter passt zeitlich (${newMeanAge.round()}J. erwartet ~${(existingMeanAge + yearsElapsed).round()}J.)');
      } else if (newMeanAge < existingMeanAge - 0.5) {
        continue; // Tier kann nicht jünger werden — ausschließen
      }

      // 3. Geschlecht
      final sameSex = (newEstimate.pBock > newEstimate.pGeis) ==
          (ind.currentEstimate.pBock > ind.currentEstimate.pGeis);
      if (newEstimate.pUnsicher < 0.4 && ind.currentEstimate.pUnsicher < 0.4) {
        if (sameSex) {
          score += 20;
          reasons.add('Gleiches Geschlecht');
        } else {
          continue; // Geschlecht stimmt nicht — ausschließen
        }
      }

      // 4. Ähnliche Altersklasse (Gauss-Überlappung)
      final ageDiff = (newMeanAge - (existingMeanAge + yearsElapsed)).abs();
      if (ageDiff < 1.0) {
        score += 30;
        reasons.add('Sehr ähnliches Alter');
      } else if (ageDiff < 2.5) {
        score += 15;
        reasons.add('Ähnliches Alter');
      }

      if (score > 40) {
        matches.add(RecognitionMatch(
          individual: ind,
          score: score.clamp(0, 100),
          reason: reasons.join(' · '),
          isProbable: score > 70,
          isAlmostCertain: score > 85,
        ));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(3).toList();
  }
}
