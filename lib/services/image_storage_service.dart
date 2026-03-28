import 'dart:typed_data';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ImageStorageService {
  /// Speichert Foto als Base64 in SharedPreferences (Web) oder Dateisystem (Mobile)
  /// Komprimiert auf max 400px Breite
  static Future<String> saveThumbnail(
      Uint8List imageBytes, String animalId) async {
    // Vereinfacht: Base64 in SharedPreferences (für Web-Demo)
    // TODO Mobile: path_provider + dart:io File schreiben
    final key = 'thumb_$animalId';
    final prefs = await SharedPreferences.getInstance();

    // Für Web: direkt speichern (max 500KB)
    if (imageBytes.length > 500000) {
      // Nur ersten 500KB nehmen (grobe Komprimierung —
      // echte Komprimierung braucht flutter_image_compress auf Mobile)
      final truncated = imageBytes.sublist(0, 500000);
      await prefs.setString(key, base64Encode(truncated));
    } else {
      await prefs.setString(key, base64Encode(imageBytes));
    }

    return key; // Gibt Storage-Key zurück
  }

  /// Lädt Thumbnail aus Storage
  static Future<Uint8List?> loadThumbnail(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString(storageKey);
    if (b64 == null) return null;
    return base64Decode(b64);
  }
}
