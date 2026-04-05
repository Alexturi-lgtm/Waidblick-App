import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ProfileService: Supabase-Profil, Premium-Status und Analyse-Quotas verwalten.
/// Fallback auf SharedPreferences wenn Supabase-RPC nicht verfügbar.
class ProfileService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _localCountKey = 'analyses_this_month_local';
  static const String _localMonthKey = 'analyses_month_local';

  // ─── Profil laden ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      // Profil noch nicht angelegt oder kein Netz — null zurückgeben
      return null;
    }
  }

  // ─── Analyse zählen (RPC mit lokalem Fallback) ───────────────────────────────

  static Future<Map<String, dynamic>> incrementAnalysis() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    try {
      final response = await _client
          .rpc('increment_analysis', params: {'user_id': user.id});
      if (response is Map<String, dynamic>) {
        return response;
      }
      // RPC gibt ggf. null zurück wenn Funktion leer ist
      return {'success': true};
    } catch (_) {
      // Supabase-RPC nicht verfügbar → lokaler Fallback mit SharedPreferences
      await _incrementLocalCount();
      return {'success': true, 'local_fallback': true};
    }
  }

  /// Lokalen Monatszähler in SharedPreferences erhöhen (RPC-Fallback)
  static Future<void> _incrementLocalCount() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final savedMonth = prefs.getString(_localMonthKey) ?? '';

    if (savedMonth != currentMonth) {
      // Neuer Monat → Reset
      await prefs.setString(_localMonthKey, currentMonth);
      await prefs.setInt(_localCountKey, 1);
    } else {
      final count = prefs.getInt(_localCountKey) ?? 0;
      await prefs.setInt(_localCountKey, count + 1);
    }
  }

  /// Lokalen Monatszähler lesen (RPC-Fallback)
  static Future<int> _getLocalCount() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final savedMonth = prefs.getString(_localMonthKey) ?? '';

    if (savedMonth != currentMonth) {
      return 0; // Neuer Monat, Reset
    }
    return prefs.getInt(_localCountKey) ?? 0;
  }

  // ─── Premium-Status prüfen ───────────────────────────────────────────────────

  static Future<bool> isPremium() async {
    final profile = await getProfile();
    if (profile == null) return false;

    final status = profile['subscription_status'] as String? ?? 'free';
    if (status == 'free') return false;
    if (status == 'lifetime') return true;

    final expires = profile['subscription_expires'];
    if (expires != null) {
      return DateTime.parse(expires.toString()).isAfter(DateTime.now());
    }
    return false;
  }

  // ─── Monatslimit prüfen (5 für free) ────────────────────────────────────────

  static Future<bool> hasAnalysisQuota() async {
    final premium = await isPremium();
    if (premium) return true;

    final profile = await getProfile();
    if (profile != null) {
      final count = profile['analyses_this_month'] as int? ?? 0;
      return count < 5;
    }

    // Kein Profil (offline/nicht eingeloggt) → lokalen Fallback nutzen
    final localCount = await _getLocalCount();
    return localCount < 5;
  }
}
