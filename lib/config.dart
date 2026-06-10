/// Zentrale, leicht umschaltbare Feature-Flags fuer GAMSSINN.
///
/// Diese Datei buendelt globale An/Aus-Schalter. Aenderung = eine Zeile flippen,
/// danach neu bauen. Keine weitere Logik hier.
library;

/// Community-Standortweitergabe zwischen Nutzern.
///
/// FALSE = AUS (Launch-Entscheidung): Sichtungen bleiben privat, es wird
/// niemals `shared=true` an den Server gesendet und jegliche Sharing-UI
/// (Teilen-Toggle/Community-Optionen) wird ausgeblendet.
/// Spaeter aktivierbar durch Umstellen auf `true`.
const bool kSharingEnabled = false;
