import 'package:shared_preferences/shared_preferences.dart';

/// Freemium-Limits für Analysen und Lookbook-Einträge.
/// - 5 Analysen pro Monat (gratis)
/// - 3 Lookbook-Einträge (gratis)
class FreemiumService {
  static const String _keyCount = 'analysen_diesen_monat';
  static const String _keyResetDate = 'analysen_reset_datum';
  static const int _maxAnalysenGratis = 5;
  static const int _maxLookbookGratis = 3;

  /// Premium-Status — aktuell hardcoded false (In-App-Purchase TODO)
  static bool get isPremium => false;

  /// Gibt die aktuelle Anzahl der Analysen diesen Monat zurück.
  static Future<int> getAnalysenCount() async {
    await _resetIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCount) ?? 0;
  }

  /// Prüft ob eine weitere Analyse erlaubt ist.
  static Future<bool> canAnalyze() async {
    if (isPremium) return true;
    final count = await getAnalysenCount();
    return count < _maxAnalysenGratis;
  }

  /// Erhöht den Analyse-Counter nach erfolgreicher Analyse.
  static Future<void> incrementAnalyseCount() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNeeded();
    final current = prefs.getInt(_keyCount) ?? 0;
    await prefs.setInt(_keyCount, current + 1);
  }

  /// Prüft ob das Speichern im Lookbook erlaubt ist.
  static Future<bool> canSaveToLookbook(int currentCount) async {
    if (isPremium) return true;
    return currentCount < _maxLookbookGratis;
  }

  /// Verbleibende Analysen diesen Monat.
  static Future<int> remainingAnalysen() async {
    if (isPremium) return 999;
    final count = await getAnalysenCount();
    return (_maxAnalysenGratis - count).clamp(0, _maxAnalysenGratis);
  }

  /// Setzt Counter zurück wenn neuer Monat begonnen hat.
  static Future<void> _resetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final resetDateStr = prefs.getString(_keyResetDate);
    final now = DateTime.now();

    if (resetDateStr == null) {
      // Erstmaliger Start: Reset-Datum auf nächsten Monatsersten setzen
      final nextReset = DateTime(now.year, now.month + 1, 1);
      await prefs.setString(_keyResetDate, nextReset.toIso8601String());
      await prefs.setInt(_keyCount, 0);
      return;
    }

    final resetDate = DateTime.parse(resetDateStr);
    if (now.isAfter(resetDate)) {
      // Neuer Monat: zurücksetzen
      final nextReset = DateTime(now.year, now.month + 1, 1);
      await prefs.setString(_keyResetDate, nextReset.toIso8601String());
      await prefs.setInt(_keyCount, 0);
    }
  }

  static int get maxLookbook => _maxLookbookGratis;
}
