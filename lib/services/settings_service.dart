import 'package:shared_preferences/shared_preferences.dart';
import '../models/hunting_regulations.dart';

/// Service für persistente App-Einstellungen via SharedPreferences
class SettingsService {
  static const _keyRegion = 'hunting_region';

  /// Liest die gespeicherte Jagdregion. Standard: other (Allgemein)
  static Future<HuntingRegion> getRegion() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyRegion);
    if (value == null) return HuntingRegion.other;
    try {
      return HuntingRegion.values.firstWhere((r) => r.name == value);
    } catch (_) {
      return HuntingRegion.other;
    }
  }

  /// Speichert die gewählte Jagdregion
  static Future<void> setRegion(HuntingRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegion, region.name);
  }
}
