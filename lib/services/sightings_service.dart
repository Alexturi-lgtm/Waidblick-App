import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../models/age_estimate.dart';

class SightingsService {
  static SupabaseClient get _db => AuthService.client;

  /// Sichtung speichern
  static Future<void> saveSighting({
    required AgeEstimate estimate,
    double? lat,
    double? lng,
    String? region,
    String? revier,
    String? notes,
    bool shared = false,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    await _db.from('sightings').insert({
      'user_id': user.id,
      'wildart': estimate.wildart,
      'geschlecht': estimate.isMale ? 'maennlich' : 'weiblich',
      'alter_jahre': estimate.meanAge,
      'alter_stddev': estimate.stdDev,
      'altersklasse': estimate.dominantAgeClass.name,
      'confidence': estimate.confidence,
      'gewichteter_score': estimate.gewichteterScore,
      'begruendung': estimate.begruendung,
      'scoring': estimate.scoring,
      'lat': lat,
      'lng': lng,
      'region': region,
      'revier': revier,
      'notes': notes,
      'shared': shared,
    });
  }

  /// Eigene Sichtungen laden
  static Future<List<Map<String, dynamic>>> getMySightings({int limit = 50}) async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    return await _db
        .from('sightings')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Community-Sichtungen (shared=true)
  static Future<List<Map<String, dynamic>>> getCommunitySightings({int limit = 50}) async {
    return await _db
        .from('sightings')
        .select('*, profiles(username, revier)')
        .eq('shared', true)
        .order('created_at', ascending: false)
        .limit(limit);
  }
}
