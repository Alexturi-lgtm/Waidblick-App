import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import 'impressum_screen.dart';

/// Info-Screen: Wildtier-Steckbriefe, Ansprache-Tipps, Abschussklassen
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaidblickColors.background,
      appBar: AppBar(
        backgroundColor: WaidblickColors.background,
        elevation: 0,
        title: const Text(
          'WILDTIER-INFO',
          style: TextStyle(
            color: WaidblickColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: WaidblickColors.primary,
          indicatorWeight: 3,
          labelColor: WaidblickColors.primary,
          unselectedLabelColor: WaidblickColors.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Gams'),
            Tab(text: 'Rehwild'),
            Tab(text: 'Rotwild'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _GamsInfoTab(),
                _RehwildInfoTab(),
                _RotwildInfoTab(),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _version.isNotEmpty ? 'v$_version  •  ' : '',
                  style: const TextStyle(
                      fontSize: 11, color: WaidblickColors.textSecondary),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImpressumScreen()),
                  ),
                  child: const Text(
                    'Impressum',
                    style: TextStyle(
                      fontSize: 11,
                      color: WaidblickColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GAMS TAB ────────────────────────────────────────────────────────────────

class _GamsInfoTab extends StatelessWidget {
  const _GamsInfoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero-Container
        _HeroContainer(
          color: const Color(0xFFF5A623),
          label: 'GAMSWILD',
          subtitle: 'Rupicapra rupicapra',
          emoji: '🦌',
        ),
        const SizedBox(height: 16),

        // Steckbrief
        _InfoCard(
          title: '🐾 Steckbrief',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _FactRow('Gewicht', 'Bock bis 40 kg, Geiß bis 35 kg'),
              _FactRow('Hörner', 'Krucken (NICHT Geweih!) — hakig beim Alttier'),
              _FactRow('Besonderes', 'Gamsbart = lange Rückenhaare am Widerrist'),
              _FactRow('Schutz', 'Geiß mit Kitz — niemals erlegen!'),
              _FactRow('Waidmannssprache', 'Windfang (Nase), Krucken (Hörner), Gamsbart'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Abschussklassen
        _InfoCard(
          title: '📋 Abschussklassen (BayJG)',
          child: _AgeClassTable(
            headers: const ['Klasse', 'Alter', 'Merkmal'],
            rows: const [
              _AgeClassRow(
                cells: ['Kl. I', '1. LJ — Kitze', 'Keine Krucken'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Kl. II', '2. LJ — Jährlinge', 'Kurze gerade Krucken'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Kl. III', '3–7 J — Mittlere Gams', 'Jahresringe erkennbar — SCHONEN!'],
                color: _ageColorMid,
              ),
              _AgeClassRow(
                cells: ['Kl. IV ♂', 'ab 8 J — Erntebock', 'Starke Hakenkrucken'],
                color: _ageColorOld,
              ),
              _AgeClassRow(
                cells: ['Kl. IV ♀', 'ab 10 J — Erntegeiß', 'Hakenkrucken freigegeben'],
                color: _ageColorOld,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ansprache-Tipps
        _InfoCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _NumberedTip(1, 'Krucken (PRIMÄR): Jahresringe, Hakenstärke, Länge'),
              _NumberedTip(2, 'Windfang: jung = schmal/spitz, alt = breit/hängend'),
              _NumberedTip(3, 'Gesichtszügel: jung = schwarz-scharf, alt = verwaschen'),
              _NumberedTip(4, 'Rückenlinie: gerade = jung, Senkrücken + Hüfthöcker = alt'),
              _NumberedTip(5, 'Flanken: prall = jung, eingefallen = alt'),
              _NumberedTip(6, 'Achtung: Hakelung allein unzuverlässig!'),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── REHWILD TAB ─────────────────────────────────────────────────────────────

class _RehwildInfoTab extends StatelessWidget {
  const _RehwildInfoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero-Container
        _HeroContainer(
          color: const Color(0xFF5D9E6E),
          label: 'REHWILD',
          subtitle: 'Capreolus capreolus',
          emoji: '🦌',
        ),
        const SizedBox(height: 16),

        // Steckbrief
        _InfoCard(
          title: '🦌 Steckbrief',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _FactRow('Gewicht', 'Bock 15–35 kg, Ricke kleiner'),
              _FactRow('Gehörn', 'Bock trägt Gehörn (NICHT Geweih!) — bis 6 Enden'),
              _FactRow('Fell', 'Sommer: rotbraun, Winter: graubraun'),
              _FactRow('Spiegel', 'Weiß, herzförmig — Ricke mit Schnürze'),
              _FactRow('Waidmannssprache', 'Träger (Hals), Geheimgang (Hinterläufe), Pürzel (Schwanz)'),
              _FactRow('Achtung', 'Blume = NUR beim Hasen, NICHT beim Reh!'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Abschussklassen
        _InfoCard(
          title: '📋 Abschussklassen',
          child: _AgeClassTable(
            headers: const ['Klasse', 'Bezeichnung', 'Alter', 'Merkmal'],
            rows: const [
              _AgeClassRow(
                cells: ['Kitz', 'Kitz', 'bis 1 J', 'Kein Gehörn, Mutterschutz'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Jährl. ♂', 'Spießer', '1–2 J', 'Gerade Spieße, hochläufig'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Jährl. ♀', 'Schmalreh', '1–2 J', 'Kein Gehörn, hochläufig'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Kl. II', 'Mittelbock', '2–5 J', 'Entwickeltes Gehörn — SCHONEN!'],
                color: _ageColorMid,
              ),
              _AgeClassRow(
                cells: ['Kl. I', 'Alter Bock', 'ab 5 J', 'Starkes Gehörn, Perlung, Senkrücken'],
                color: _ageColorOld,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ansprache-Tipps
        _InfoCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _NumberedTip(1, 'Körperbau (PRIMÄR): Senkrücken, eingefallene Flanken = alt'),
              _NumberedTip(2, 'Geheimgang (Hinterläufe): weit gestellt = alt'),
              _NumberedTip(3, 'Bauchlinie: hängend = alter Bock'),
              _NumberedTip(4, 'Träger (Hals): kurz/dick = alt, lang/schlank = jung'),
              _NumberedTip(5, 'Gehörn: Perlung + unregelmäßige Enden = älter'),
              _NumberedTip(6, 'Ricke erkennen: Schnürze unter Spiegel, Pürzel sichtbar'),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── ROTWILD TAB ─────────────────────────────────────────────────────────────

class _RotwildInfoTab extends StatelessWidget {
  const _RotwildInfoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero-Container
        _HeroContainer(
          color: const Color(0xFFB5451B),
          label: 'ROTWILD',
          subtitle: 'Cervus elaphus',
          emoji: '🦌',
        ),
        const SizedBox(height: 16),

        // Steckbrief
        _InfoCard(
          title: '🦌 Steckbrief',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _FactRow('Gewicht', 'Hirsch bis 250 kg, Tier bis 120 kg'),
              _FactRow('Geweih', 'Stangen, Sprossen, Krone — (NICHT Hörner!)'),
              _FactRow('Alter', 'Nach Köpfen: 1. Kopf = 2. Lebensjahr'),
              _FactRow('Besonderes', 'Brunftmähne, Wamme beim Hirsch sichtbar'),
              _FactRow('Waidmannssprache', 'Geweih, Stangen, Enden, Brunft'),
              _FactRow('Achtung', 'Alttier ≠ Rehwild! Groß, Wamme, langer Kopf'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Abschussklassen
        _InfoCard(
          title: '📋 Abschussklassen',
          child: _AgeClassTable(
            headers: const ['Klasse', 'Alter / Kopf', 'Merkmal'],
            rows: const [
              _AgeClassRow(
                cells: ['Kalb/Schmaltier', '0–1 J (Kl. III)', 'Fleckenkleid, Mutterschutz'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Schmalspießer', '3–5 J, 2.–4. Kopf (Kl. III)', 'Erste Geweihstangen — SCHONEN!'],
                color: _ageColorYoung,
              ),
              _AgeClassRow(
                cells: ['Mittelhirsch', '6–9 J, 5.–8. Kopf (Kl. II)', 'Gutes Geweih — SCHONEN!'],
                color: _ageColorMid,
              ),
              _AgeClassRow(
                cells: ['Althirsch', 'ab 10 J, ab 9. Kopf (Kl. I)', 'Reifer Hirsch — Ernte'],
                color: _ageColorOld,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ansprache-Tipps
        _InfoCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _NumberedTip(1, 'Körperprofil (PRIMÄR): Wamme, Senkrücken = alt'),
              _NumberedTip(2, 'Kopf: Grau, wulstige Augenbrauen = reifer Hirsch'),
              _NumberedTip(3, 'Geweih: Starke Basis, Perlen, Krone = Althirsch'),
              _NumberedTip(4, 'Kalb immer eng bei Tier — nie Tier mit Kalb erlegen!'),
              _NumberedTip(5, 'Tiefland-Hirsche deutlich größer als Alpenraum'),
              _NumberedTip(6, 'Alttier ≠ Rehwild: Größe, Wamme, langer Kopf'),
            ],
          ),
        ),

        // Info-Box
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFF5A623).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Color(0xFFF5A623).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFF5A623), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tipp: Tiefland-Hirsche deutlich größer als im Alpenraum — immer Revier-Kontext beachten!',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFF5A623)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _HeroContainer extends StatelessWidget {
  final Color color;
  final String label;
  final String subtitle;
  final String emoji;

  const _HeroContainer({
    required this.color,
    required this.label,
    required this.subtitle,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Stack(
        children: [
          // Background emoji (subtle)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: 80,
                  color: color.withOpacity(0.15),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: WaidblickColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WaidblickColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x14FFFFFF), // rgba(255,255,255,0.08)
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: WaidblickColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WaidblickColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: WaidblickColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Age color constants
const Color _ageColorYoung = Color(0xFF4CAF50);
const Color _ageColorMid = Color(0xFFFFC107);
const Color _ageColorOld = Color(0xFFF44336);

class _AgeClassRow {
  final List<String> cells;
  final Color color;
  const _AgeClassRow({required this.cells, required this.color});
}

class _AgeClassTable extends StatelessWidget {
  final List<String> headers;
  final List<_AgeClassRow> rows;

  const _AgeClassTable({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: WaidblickColors.surfaceVariant,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: headers.map((h) {
              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: WaidblickColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Data rows
        ...rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Container(
            decoration: BoxDecoration(
              color: row.color.withOpacity(0.06),
              border: Border(
                top: const BorderSide(
                    color: Color(0x14FFFFFF), width: 1),
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(
                        color: Color(0x0AFFFFFF), width: 1),
              ),
              borderRadius: isLast
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(8))
                  : BorderRadius.zero,
            ),
            child: Row(
              children: row.cells.asMap().entries.map((cellEntry) {
                final isFirst = cellEntry.key == 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    child: Row(
                      children: [
                        if (isFirst) ...[
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: row.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            cellEntry.value,
                            style: TextStyle(
                              fontSize: 11,
                              color: isFirst
                                  ? row.color.withOpacity(0.9)
                                  : WaidblickColors.textPrimary,
                              fontWeight: isFirst
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

class _NumberedTip extends StatelessWidget {
  final int number;
  final String text;

  const _NumberedTip(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: WaidblickColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: WaidblickColors.primary.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: WaidblickColors.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: WaidblickColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
