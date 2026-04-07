/// TEMPLATE 2: IBM CARBON — Industriell, Präzise, Datenreich
/// Inspiriert von: https://www.carbondesignsystem.com
///
/// Merkmale:
/// - Leicht abgerundete Ecken (4px) — nicht rund, nicht eckig
/// - Status-Farben: klar und konsequent (Grün/Orange/Rot)
/// - Dichte Informationsdarstellung — viel auf wenig Platz
/// - Trennlinien statt Karten
/// - Tabellarisch, wie ein Zeiss-Fernglas-Datenblatt
///
/// WAIDBLICK-Analyse-Screen Mockup

import 'package:flutter/material.dart';

// ─── FARBEN (Carbon Dark) ─────────────────────────────────────────────────────
const _bg = Color(0xFF161616);          // Carbon: Gray 100
const _surface = Color(0xFF262626);     // Carbon: Gray 90
const _surface2 = Color(0xFF393939);    // Carbon: Gray 80
const _gold = Color(0xFFC8A84B);        // WAIDBLICK Gold
const _white = Color(0xFFF4F4F4);       // Carbon: Gray 10
const _grey = Color(0xFF8D8D8D);        // Carbon: Gray 50
const _blue = Color(0xFF4589FF);        // Carbon: Blue 50 (Info)
const _green = Color(0xFF42BE65);       // Carbon: Green 40 (Freigabe)
const _orange = Color(0xFFFF832B);      // Carbon: Orange 40 (Warnung)
const _red = Color(0xFFFF8389);         // Carbon: Red 40 (Schonen)

class DesignTemplateCarbon extends StatelessWidget {
  const DesignTemplateCarbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 4, height: 20,
              color: _gold,
              margin: const EdgeInsets.only(right: 12),
            ),
            const Text(
              'WAIDBLICK',
              style: TextStyle(
                color: _white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none, color: _grey),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── NOTIFICATION BANNER (Carbon-typisch) ──
          Container(
            width: double.infinity,
            color: _blue.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _blue, size: 16),
                SizedBox(width: 8),
                Text(
                  'Foto für beste Ergebnisse: seitlich, gutes Licht',
                  style: TextStyle(color: _blue, fontSize: 12),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── UPLOAD AREA ──
                  Container(
                    margin: const EdgeInsets.all(16),
                    height: 180,
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(
                        color: _grey.withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: _gold, size: 40),
                        const SizedBox(height: 12),
                        const Text('Foto aufnehmen oder auswählen',
                            style: TextStyle(color: _white, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('JPG, PNG · max. 10 MB',
                            style: TextStyle(color: _grey, fontSize: 12)),
                      ],
                    ),
                  ),

                  // ── WILDART FILTER (Carbon: Tab-Bar) ──
                  Container(
                    color: _surface,
                    child: Row(
                      children: ['Gamswild', 'Rehwild', 'Rotwild'].map((art) {
                        final isActive = art == 'Rehwild';
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isActive ? _gold : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              art,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isActive ? _gold : _grey,
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── ERGEBNIS: CARBON DATA TABLE ──
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surface2,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          child: Row(
                            children: [
                              const Text('ANALYSEERGEBNIS',
                                  style: TextStyle(
                                      color: _white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  '● FREIGEGEBEN',
                                  style: TextStyle(
                                      color: _green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Data rows
                        _CarbonRow('Wildart', 'Rehwild (Capreolus capreolus)',
                            isAlt: false),
                        _CarbonRow('Geschlecht', 'Bock', isAlt: true),
                        _CarbonRow('Altersklasse', 'Klasse I — Alter Bock',
                            isAlt: false, highlight: true),
                        _CarbonRow('Geschätztes Alter', '5–7 Jahre',
                            isAlt: true),
                        _CarbonRow('Gehörn', 'Sechsender, starkes Blatt',
                            isAlt: false),
                        _CarbonRow('Region', 'Bayern', isAlt: true),
                        _CarbonRow('Konfidenz', '87 %',
                            isAlt: false, highlight: true),
                      ],
                    ),
                  ),

                  // ── AKTIONS-BUTTONS (Carbon-Stil) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: _bg,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () {},
                              child: const Text('Speichern',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _white,
                                side: const BorderSide(color: _grey),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () {},
                              child: const Text('Neue Analyse'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarbonRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlt;
  final bool highlight;

  const _CarbonRow(this.label, this.value,
      {required this.isAlt, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isAlt ? _surface2.withValues(alpha: 0.5) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: _grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  color: highlight ? _gold : _white,
                  fontSize: 13,
                  fontWeight:
                      highlight ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ],
      ),
    );
  }
}
