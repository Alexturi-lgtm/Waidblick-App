import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gams_individual.dart';
import '../models/sighting.dart';

/// Persistenz-Service für GamsBook-Daten via SharedPreferences.
/// Singleton-Pattern: DatabaseService.instance verwenden.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String _storageKey = 'gamsscope_individuals';

  List<GamsIndividual> _individuals = [];

  /// Alle bekannten Gams-Individuen (read-only view)
  List<GamsIndividual> get individuals => List.unmodifiable(_individuals);

  /// Lädt alle Individuen aus SharedPreferences.
  /// Wird beim App-Start aufgerufen.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) {
      _individuals = [];
      return;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      _individuals = jsonList
          .map((e) => GamsIndividual.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Bei Korruption: sauberer Neustart
      _individuals = [];
    }
  }

  /// Speichert alle Individuen in SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_individuals.map((i) => i.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  /// Fügt ein neues Individuum hinzu und speichert.
  Future<void> addIndividual(GamsIndividual ind) async {
    _individuals.add(ind);
    await save();
  }

  /// Aktualisiert ein bestehendes Individuum (per ID) und speichert.
  /// Wirft [ArgumentError] wenn die ID nicht gefunden wird.
  Future<void> updateIndividual(GamsIndividual ind) async {
    final idx = _individuals.indexWhere((i) => i.id == ind.id);
    if (idx == -1) {
      throw ArgumentError('Individuum mit ID ${ind.id} nicht gefunden.');
    }
    _individuals[idx] = ind;
    await save();
  }

  /// Löscht ein Individuum per ID und speichert.
  Future<void> deleteIndividual(String id) async {
    _individuals.removeWhere((i) => i.id == id);
    await save();
  }

  /// Fügt eine Sichtung zu einem bestehenden Individuum hinzu.
  /// Aktualisiert auch lastSeen und currentEstimate des Individuums.
  Future<void> addSighting(String individualId, Sighting sighting) async {
    final idx = _individuals.indexWhere((i) => i.id == individualId);
    if (idx == -1) {
      throw ArgumentError('Individuum mit ID $individualId nicht gefunden.');
    }

    final old = _individuals[idx];
    final updatedSightings = List<Sighting>.from(old.sightings)..add(sighting);

    // Neuestes Datum der letzten Sichtung
    final lastSeen = sighting.timestamp.isAfter(old.lastSeen)
        ? sighting.timestamp
        : old.lastSeen;

    _individuals[idx] = old.copyWith(
      sightings: updatedSightings,
      lastSeen: lastSeen,
      currentEstimate: sighting.estimate,
    );
    await save();
  }
}
