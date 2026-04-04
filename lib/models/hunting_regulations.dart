/// Jagdregelungen für verschiedene Regionen (Österreich & Bayern)
enum HuntingRegion { steiermark, tirol, bayern, salzburg, other }

class HuntingRegulation {
  final HuntingRegion region;

  const HuntingRegulation(this.region);

  String get regionName {
    switch (region) {
      case HuntingRegion.steiermark:
        return 'Steiermark';
      case HuntingRegion.tirol:
        return 'Tirol';
      case HuntingRegion.bayern:
        return 'Bayern';
      case HuntingRegion.salzburg:
        return 'Salzburg';
      case HuntingRegion.other:
        return 'Allgemein';
    }
  }

  /// Ist dieser Bock freigegeben bei gegebenem Alter?
  bool isBockFreigegeben(int ageYears) {
    switch (region) {
      case HuntingRegion.steiermark:
        return ageYears >= 12; // Klasse I: ab 12J
      case HuntingRegion.tirol:
        return ageYears >= 8; // Klasse I Bock: ab 8J
      case HuntingRegion.bayern:
        return ageYears >= 8; // Obere Klasse: ab 8J
      case HuntingRegion.salzburg:
        return ageYears >= 10;
      case HuntingRegion.other:
        return ageYears >= 10;
    }
  }

  /// Ist diese Geiß freigegeben bei gegebenem Alter?
  bool isGeisFreigegeben(int ageYears) {
    switch (region) {
      case HuntingRegion.steiermark:
        return ageYears >= 12;
      case HuntingRegion.tirol:
        return ageYears >= 10; // Klasse I Geiß: ab 10J
      case HuntingRegion.bayern:
        return ageYears >= 8;
      case HuntingRegion.salzburg:
        return ageYears >= 12;
      case HuntingRegion.other:
        return ageYears >= 12;
    }
  }

  /// Mindestabschussalter Bock (in Jahren)
  int get minBockAlter {
    switch (region) {
      case HuntingRegion.steiermark:
        return 12;
      case HuntingRegion.tirol:
        return 8;
      case HuntingRegion.bayern:
        return 8;
      case HuntingRegion.salzburg:
        return 10;
      case HuntingRegion.other:
        return 10;
    }
  }

  /// Mindestabschussalter Geiß (in Jahren)
  int get minGeisAlter {
    switch (region) {
      case HuntingRegion.steiermark:
        return 12;
      case HuntingRegion.tirol:
        return 10;
      case HuntingRegion.bayern:
        return 8;
      case HuntingRegion.salzburg:
        return 12;
      case HuntingRegion.other:
        return 12;
    }
  }

  /// Vollständige Klassenstruktur als Text
  String get classDescription {
    switch (region) {
      case HuntingRegion.steiermark:
        return 'Klasse I (≥12 J.): Bock & Geiß freigegeben\n'
            'Klasse II (8–11 J.): Bestandspflege nach Abschussplan\n'
            'Klasse III (<8 J.): Nicht freigegeben';
      case HuntingRegion.tirol:
        return 'Klasse I Bock (≥8 J.): freigegeben\n'
            'Klasse I Geiß (≥10 J.): freigegeben\n'
            'Klasse II/III: Bestandspflege';
      case HuntingRegion.bayern:
        return 'Obere Klasse (≥8 J.): Bock & Geiß freigegeben\n'
            'Mittlere Klasse (4–7 J.): eingeschränkt\n'
            'Untere Klasse (<4 J.): Nicht freigegeben';
      case HuntingRegion.salzburg:
        return 'Klasse I Bock (≥10 J.): freigegeben\n'
            'Klasse I Geiß (≥12 J.): freigegeben\n'
            'Jüngere Tiere: nach Abschussplan';
      case HuntingRegion.other:
        return 'Allgemeine Richtwerte:\n'
            'Bock freigegeben ab 10 Jahren\n'
            'Geiß freigegeben ab 12 Jahren';
    }
  }

  /// Freigabe-Text für gegebene Schätzung
  String freigabeText(double meanAge, double pBock, double pGeis) {
    final age = meanAge.round();
    final isBock = pBock > pGeis;
    if (isBock) {
      if (isBockFreigegeben(age)) {
        return '✅ Freigegeben – Bock Klasse I, ca. $age Jahre ($regionName)';
      }
      // Tirol: Klasse II (Bock 4–7 J.) nach Abschussplan möglich
      if (region == HuntingRegion.tirol && age >= 4) {
        return '⚠️ Klasse II-Bock, ca. $age Jahre ($regionName) – nach Abschussplan prüfen';
      }
      return '⛔ Nicht freigegeben – Bock unter Mindestabschussalter ($regionName)';
    } else {
      if (isGeisFreigegeben(age)) {
        return '✅ Freigegeben – Geiß Klasse I, ca. $age Jahre ($regionName)';
      }
      // Tirol: Klasse II (Geiß 4–9 J.) nach Abschussplan möglich, Schusszeit 1.8–15.12
      if (region == HuntingRegion.tirol && age >= 4) {
        return '⚠️ Klasse II-Geiß, ca. $age Jahre ($regionName) – nach Abschussplan prüfen (Schusszeit 1.8–15.12)';
      }
      return '⛔ Nicht freigegeben – Geiß unter Mindestabschussalter ($regionName)';
    }
  }
}
