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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Info & Wildtiere'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gämse'),
            Tab(text: 'Rehwild'),
            Tab(text: 'Rotwild'),
          ],
        ),
      ),
      body: Column(
        children: [
          // App-Beschreibung (2 Sätze)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'WAIDBLICK erkennt Gämse, Rehwild und Rotwild per KI-Bildanalyse. '
              'Altersklasse, Geschlecht und Abschussfreigabe auf einen Blick.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: WaidblickColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _GamseTab(),
                _RehwildTab(),
                _RotwildTab(),
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImpressumScreen()),
                  ),
                  child: Text(
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

// ─── GÄMSE TAB ───────────────────────────────────────────────────────────────

class _GamseTab extends StatelessWidget {
  const _GamseTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionCard(
          title: '🐾 Steckbrief',
          child: const Text(
            'Gämse (Rupicapra rupicapra) — Hochgebirgsbewohner der Alpen.\n'
            'Bock: bis 40 kg, Krucken nach hinten gebogen.\n'
            'Geiß: kleiner, Krucken feiner. Saisonales Haarkleid.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bullet('Krucken-Form: jung = gerade, alt = stark gebogen'),
              _Bullet('Rückenlinie: gerade = jung, konkav = alt'),
              _Bullet('Flanken: prall = jung, eingefallen = alt'),
              _Bullet('Zügel-Kontrast: scharf = jung, verwaschen = alt'),
              _Bullet('Bewegunssteifheit: sichtbar = hohes Alter'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '📋 Abschussklassen (Bayern)',
          child: _buildGamsTable(context),
        ),
      ],
    );
  }

  Widget _buildGamsTable(BuildContext context) {
    return _CompactTable(
      headers: const ['Klasse', 'Geschlecht', 'Alter'],
      rows: const [
        ['Kl. II', 'Bock', '1–7 J (Schon)'],
        ['Kl. I', 'Bock', 'ab 8 J (Ernte)'],
      ],
    );
  }
}

// ─── REHWILD TAB ─────────────────────────────────────────────────────────────

class _RehwildTab extends StatelessWidget {
  const _RehwildTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionCard(
          title: '🦌 Steckbrief',
          child: const Text(
            'Rehwild (Capreolus capreolus) — häufigstes Schalenwild.\n'
            'Bock: Geweih mit 3–6 Enden, Schmalreh ohne Gehörn.\n'
            'Sommerfell: rotbraun. Winterfell: graubraun.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bullet('Kitz: Fleckenkleid bis Herbst, hochläufig'),
              _Bullet('Jährling: schlank, Geweih klein/einfach'),
              _Bullet('Kl.II: Mittelbock, normale Proportionen'),
              _Bullet('Kl.I: Senkrücken, starkes Blatt, Gamsbart'),
              _Bullet('Schmalreh: weiblich, kein Gehörn'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '📋 Abschussklassen',
          child: _CompactTable(
            headers: const ['Klasse', 'Bezeichnung', 'Alter', 'Merkmal'],
            rows: const [
              ['Kitz', 'Kitz', '0–1 J', 'Fleckenkleid'],
              ['Jährling', 'Schmalreh', '1–2 J', 'Hochläufig'],
              ['Kl. II', 'Mittelbock', '2–5 J', 'Schonklasse'],
              ['Kl. I', 'Alter Bock', '5+ J', 'Senkrücken'],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ROTWILD TAB ─────────────────────────────────────────────────────────────

class _RotwildTab extends StatelessWidget {
  const _RotwildTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionCard(
          title: '🦌 Steckbrief',
          child: const Text(
            'Rotwild (Cervus elaphus) — größtes heimisches Schalenwild.\n'
            'Hirsch: imposantes Geweih, Brunftmähne. Tiefland > Alpenraum.\n'
            'Kalb: Fleckenkleid, Schmaltier: erste Brunftbeteiligung.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '🎯 Ansprache-Tipps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bullet('Kalb: Fleckenkleid, klein, eng bei Tier'),
              _Bullet('Spießer: erste Geweihstangen ohne Enden'),
              _Bullet('Kl.III: junger Hirsch, Geweih im Aufbau'),
              _Bullet('Kl.II: mittlerer Hirsch, gute Masse'),
              _Bullet('Kl.I: reifer Hirsch, breite Stangen, Perlen'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: '📋 Abschussklassen',
          child: _CompactTable(
            headers: const ['Klasse', 'Alter', 'Merkmal'],
            rows: const [
              ['Kalb', '0–1 J', 'Fleckenkleid'],
              ['Spießer', '1–2 J', 'Erste Entwicklung'],
              ['Kl. III', '2–4 J', 'Jugendhirsch'],
              ['Kl. II', '4–8 J', 'Mittelalter (Schon)'],
              ['Kl. I', 'ab 8 J', 'Ernte, reifer Hirsch'],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tipp: Tiefland-Hirsche deutlich größer als Alpenraum!',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _CompactTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _CompactTable({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
          children: headers
              .map((h) => _cell(h, bold: true, header: true))
              .toList(),
        ),
        ...rows.map(
          (row) => TableRow(
            children: row.map((c) => _cell(c)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false, bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: header ? 11 : 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: header ? Colors.grey.shade600 : null,
        ),
      ),
    );
  }
}
