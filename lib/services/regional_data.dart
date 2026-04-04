/// Regionale Altersklassen-Daten für Gämse, Reh und Rotwild.
/// Komprimiert aus altersklassen_regional.md
class RegionalData {
  /// GPS-Bounding-Box → Region bestimmen
  static String detectRegion(double lat, double lon) {
    // Reihenfolge wichtig: spezifischere Regionen zuerst, breite Boxen zuletzt
    // Vorarlberg (kleine Box, westlichstes Bundesland)
    if (lat >= 47.0 && lat <= 47.6 && lon >= 9.5 && lon <= 10.2) return 'Vorarlberg';
    // Tirol (vor Bayern, da Bayern-Box Tirol überlappt!)
    if (lat >= 46.4 && lat <= 48.0 && lon >= 10.0 && lon <= 13.0) return 'Tirol';
    // Steiermark
    if (lat >= 46.6 && lat <= 47.8 && lon >= 13.0 && lon <= 16.1) return 'Steiermark';
    // Salzburg
    if (lat >= 47.0 && lat <= 48.0 && lon >= 12.2 && lon <= 13.8) return 'Salzburg';
    // Schweiz (vor Bayern, da Westschweiz/Wallis mit Bayern-Box überlappen kann)
    if (lat >= 45.8 && lat <= 47.9 && lon >= 5.9 && lon <= 10.5) return 'Schweiz';
    // Bayern (breite Box — erst nach Österreich-Bundesländern prüfen)
    if (lat >= 47.2 && lat <= 50.6 && lon >= 8.9 && lon <= 13.8) return 'Bayern';
    // Österreich allgemein
    if (lat >= 46.4 && lat <= 49.0 && lon >= 9.5 && lon <= 17.2) return 'Österreich';
    return 'Bayern'; // Default
  }

  /// Altersklassen-Info für Gamswild nach Region
  static Map<String, RegionInfo> get gamsAltersklassen => {
    'Bayern': RegionInfo(
      klassen: [
        AltersklasseInfo('Kitz', '0–1 Jahr', 'Kitz (Jugendklasse)'),
        AltersklasseInfo('Klasse III', '1–3 Jahre', 'Jugendklasse — ~50% Abschussanteil'),
        AltersklasseInfo('Klasse II', '4–9 Jahre', 'Mittelklasse — weitestgehend schonen'),
        AltersklasseInfo('Klasse I', 'ab 10 Jahre', 'Obere Altersklasse — Erntereife'),
      ],
      jagdzeit: 'Keine einheitliche Schonzeit in Oberbayern',
      besonderheit: 'Schwache Kümmerer in Klasse III priorisieren',
    ),
    'Tirol': RegionInfo(
      klassen: [
        AltersklasseInfo('Klasse III', 'Kitze + 1–3 J.', 'Jugendklasse — Führende Geißen schützen'),
        AltersklasseInfo('Klasse II', 'Bock 4–7 J., Geiß 4–9 J.', 'Mittelklasse — maßvolle Bejagung'),
        AltersklasseInfo('Klasse I', 'Bock ab 8 J., Geiß ab 10 J.', 'Ernteklasse — Bock früher reif'),
      ],
      jagdzeit: '1. August – 15. Dezember',
      besonderheit: 'Böcke früher erntereif als Geißen',
    ),
    'Steiermark': RegionInfo(
      klassen: [
        AltersklasseInfo('Kitz', '0–1 Jahr', 'Hohe Abschusspriorität'),
        AltersklasseInfo('Klasse III', '1–2 Jahre', 'Jugendklasse — Schwache/kranke Tiere'),
        AltersklasseInfo('Klasse II', 'variiert', 'Hauptbestand'),
        AltersklasseInfo('Klasse I', 'Erntereife', 'Nach Gesundheit/Alter entscheiden'),
      ],
      jagdzeit: 'Klassenwechsel 31. März',
      besonderheit: 'Führende Geißen grundsätzlich schonen',
    ),
    'Salzburg': RegionInfo(
      klassen: [
        AltersklasseInfo('Klasse III', 'Kitze + Jährlinge', 'Jugendklasse'),
        AltersklasseInfo('Klasse II', 'Mittlere Stücke', 'Mittelklasse'),
        AltersklasseInfo('Klasse I', 'Reife Tiere', 'Ernteklasse'),
      ],
      jagdzeit: 'Klassenwechsel 1. April',
      besonderheit: 'Mindestabschüsse per Verordnung',
    ),
    'Österreich': RegionInfo(
      klassen: [
        AltersklasseInfo('Klasse III', '1–3 Jahre', 'Jugendklasse'),
        AltersklasseInfo('Klasse II', '4–9 Jahre', 'Mittelklasse'),
        AltersklasseInfo('Klasse I', 'ab 10 Jahre', 'Ernteklasse'),
      ],
      jagdzeit: 'Klassenwechsel 1. April',
      besonderheit: 'Je nach Bundesland unterschiedlich',
    ),
    'Schweiz': RegionInfo(
      klassen: [
        AltersklasseInfo('Jugendklasse', 'Bock 1–4 J., Geiß 1–3 J.', 'Kantonal variierend'),
        AltersklasseInfo('Mittelklasse', 'Bock 5–10 J., Geiß 4–10 J.', 'Adulte Mitte'),
        AltersklasseInfo('Älterenklasse', 'ab 11 Jahre', 'Böcke selten >12 J.'),
      ],
      jagdzeit: 'Kantonal unterschiedlich',
      besonderheit: 'Altersbestimmung über Jahresringe an Krucken',
    ),
  };

  /// Passende Info für Region + Wildart ermitteln
  static RegionInfo? getInfo(String region, String wildart) {
    // Aktuell nur Gams vollständig — für andere Wildarten gleiche Struktur nutzbar
    return gamsAltersklassen[region];
  }
}

class RegionInfo {
  final List<AltersklasseInfo> klassen;
  final String jagdzeit;
  final String besonderheit;

  const RegionInfo({
    required this.klassen,
    required this.jagdzeit,
    required this.besonderheit,
  });
}

class AltersklasseInfo {
  final String name;
  final String alter;
  final String beschreibung;

  const AltersklasseInfo(this.name, this.alter, this.beschreibung);
}
