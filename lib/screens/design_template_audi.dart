/// TEMPLATE 3: AUDI — Deutsche Tradition, Warm-Dunkel, Organisch
/// Inspiriert von: https://www.audi.com/ci/en/guides/user-interface/introduction.html
///
/// Merkmale:
/// - Warme Töne: Dunkelbraun statt Schwarz (Leder, Holz, Wald)
/// - Mittlere Rundungen (8px) — weicher als Porsche, edler als Carbon
/// - Progressive Disclosure: wichtigste Info zuerst, groß
/// - Naturfotos als Hintergrundakzent
/// - Gefühl: Jagdhaus, Holzvertäfelung, Hirschlederhose
///
/// WAIDBLICK-Analyse-Screen Mockup

import 'package:flutter/material.dart';

// ─── FARBEN (Audi-inspiriert, Jagd-angepasst) ────────────────────────────────
const _bg = Color(0xFF0F0D0B);          // Sehr dunkles Braun-Schwarz (Waldboden)
const _surface = Color(0xFF1A1714);     // Dunkles Leder-Braun
const _surface2 = Color(0xFF252119);    // Etwas heller
const _gold = Color(0xFFC8A84B);        // Waidblick Gold
const _goldWarm = Color(0xFFD4A843);    // Wärmeres Gold (Hirschgeweih)
const _white = Color(0xFFF5F0E8);       // Warmes Weiß (Papier, nicht kalt)
const _grey = Color(0xFF7A7268);        // Warmes Grau
const _border = Color(0xFF2E2920);      // Warme Trennlinie
const _green = Color(0xFF5A8A4A);       // Waldgrün (Freigabe)
const _red = Color(0xFF8A3A35);         // Gedämpftes Rot (Schonen)

class DesignTemplateAudi extends StatelessWidget {
  const DesignTemplateAudi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── HERO APP BAR mit Natur-Hintergrund ──
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: _surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Platzhalter für Naturfoto
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1a3a2a),  // Dunkelgrün
                          Color(0xFF0F0D0B),  // Fast-Schwarz
                        ],
                      ),
                    ),
                  ),
                  // Overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, _bg],
                      ),
                    ),
                  ),
                  // Logo
                  const Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WAIDBLICK',
                          style: TextStyle(
                            color: _white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          'Das Auge des erfahrenen Jägers',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── FOTO-BEREICH: warm, einladend ──
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _border, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _gold, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt_outlined,
                                color: _gold, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Foto aufnehmen',
                            style: TextStyle(
                              color: _white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'oder aus Galerie wählen',
                            style: TextStyle(color: _grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── ERGEBNIS-CARD: warm, organisch ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Column(
                      children: [
                        // ── Wildart-Header mit Goldakzent ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _border, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon-Kreis
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _goldWarm.withValues(alpha: 0.1),
                                  border: Border.all(
                                      color: _goldWarm.withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Text('🦌',
                                      style: TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rehwild',
                                    style: TextStyle(
                                      color: _white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Bock · Klasse I',
                                    style: TextStyle(
                                        color: _grey, fontSize: 13),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Konfidenz-Ring
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 44, height: 44,
                                    child: CircularProgressIndicator(
                                      value: 0.87,
                                      backgroundColor:
                                          _grey.withValues(alpha: 0.2),
                                      valueColor:
                                          const AlwaysStoppedAnimation(_gold),
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  const Text(
                                    '87%',
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Merkmale ──
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _AudiFeatureRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Alter',
                                  value: 'ca. 6 Jahre'),
                              const SizedBox(height: 12),
                              _AudiFeatureRow(
                                  icon: Icons.park_outlined,
                                  label: 'Gehörn',
                                  value: 'Sechsender'),
                              const SizedBox(height: 12),
                              _AudiFeatureRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Region',
                                  value: 'Bayern'),
                              const SizedBox(height: 20),

                              // Freigabe-Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _green.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: _green, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      'Freigegeben — Klasse I',
                                      style: TextStyle(
                                        color: _green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 16),

                  // ── CTA ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'Im Streckenblatt speichern',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudiFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AudiFeatureRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: _grey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: _white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
