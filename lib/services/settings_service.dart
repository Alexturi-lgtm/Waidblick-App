import 'package:shared_preferences/shared_preferences.dart';
import '../models/hunting_regulations.dart';

/// Service für persistente App-Einstellungen via SharedPreferences
class SettingsService {
  static const _keyRegion = 'hunting_region';
  static const _keyLearningEnabled = 'learning_enabled';

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

  /// Liest den Learning-Toggle. Standard: false
  static Future<bool> getLearningEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLearningEnabled) ?? false;
  }

  /// Speichert den Learning-Toggle
  static Future<void> setLearningEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLearningEnabled, value);
  }
}
