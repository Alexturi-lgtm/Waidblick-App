/// TEMPLATE 1: PORSCHE — Edel, Reduziert, Dunkel-Premium
/// Inspiriert von: https://designsystem.porsche.com
///
/// Merkmale:
/// - Scharfe Kanten (kein BorderRadius auf Buttons)
/// - Gold als einziger Akzent — sparsam eingesetzt
/// - Viel Weißraum / Luft
/// - Typografie: groß, bold, klar
/// - Cards: hauchdünner Border, kein Schatten
///
/// WAIDBLICK-Analyse-Screen Mockup

import 'package:flutter/material.dart';

// ─── FARBEN ──────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0A);          // Fast-Schwarz (Porsche: #000)
const _surface = Color(0xFF141414);     // Karten-Hintergrund
const _gold = Color(0xFFC8A84B);        // Gold-Akzent (Porsche: Goldmetallisch)
const _white = Color(0xFFFFFFFF);
const _grey = Color(0xFF6B6B6B);
const _border = Color(0xFF2A2A2A);      // Hauchdünne Trennlinie

// ─── TYPOGRAFIE ──────────────────────────────────────────────────────────────
// Porsche nutzt "Porsche Next" — wir nehmen den iOS-Äquivalent
// Headlines: groß, bold, viel Tracking
// Body: klein, leicht, viel Luft

class DesignTemplatePorsche extends StatelessWidget {
  const DesignTemplatePorsche({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // ── APP BAR: kein Schatten, hauchdünne Linie ──
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        title: const Text(
          'WAIDBLICK',
          style: TextStyle(
            color: _white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.0,   // ← Porsche-Merkmal: viel Spacing
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.settings_outlined, color: _grey, size: 20),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),   // ← Großzügige Abstände
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── SECTION LABEL: klein, gold, gesperrt ──
            const Text(
              'ANALYSE',
              style: TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 12),

            // ── HAUPT-CTA: scharf, gold, kein Radius ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _bg,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,  // ← KEIN Radius = Porsche
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'FOTO AUFNEHMEN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── SEKUNDÄR-BUTTON: Outline, kein Radius ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _white,
                  side: const BorderSide(color: _border, width: 1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'AUS GALERIE WÄHLEN',
                  style: TextStyle(fontSize: 13, letterSpacing: 2.0),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ── ERGEBNIS-CARD: hauchdünner Border ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: _border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold-Akzentlinie oben (Porsche-typisch)
                  Container(height: 3, color: _gold),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ERGEBNIS',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 10,
                            letterSpacing: 3.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'REHWILD',
                          style: TextStyle(
                            color: _white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Text(
                          'Bock · Klasse I',
                          style: TextStyle(
                            color: _grey,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(height: 1, color: _border),
                        const SizedBox(height: 24),

                        // ── Merkmale: zweispaltig ──
                        _PorscheDataRow('ALTER', 'ca. 6 Jahre'),
                        const SizedBox(height: 12),
                        _PorscheDataRow('GEHÖRN', 'Sechsender'),
                        const SizedBox(height: 12),
                        _PorscheDataRow('REGION', 'Bayern'),
                        const SizedBox(height: 24),

                        // ── Freigabe-Status ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _gold, width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, color: _gold, size: 16),
                              SizedBox(width: 12),
                              Text(
                                'FREIGEGEBEN — KLASSE I',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PorscheDataRow extends StatelessWidget {
  final String label;
  final String value;
  const _PorscheDataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: _grey, fontSize: 11, letterSpacing: 2.0)),
        Text(value,
            style: const TextStyle(
                color: _white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
