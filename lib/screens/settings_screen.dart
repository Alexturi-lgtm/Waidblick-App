import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/hunting_regulations.dart';
import '../theme/app_theme.dart';
import 'impressum_screen.dart';

/// Einstellungs-Screen: Abschussklassen je Wildart und Region
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  HuntingRegion _selectedRegion = HuntingRegion.other;
  String _gamsRegion = 'Bayern';
  bool _loading = true;
  bool _learningEnabled = false;

  static const List<String> _gamsRegions = [
    'Bayern',
    'Tirol',
    'Salzburg',
    'Steiermark',
    'Vorarlberg',
    'Kärnten',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final region = await SettingsService.getRegion();
    final learning = await SettingsService.getLearningEnabled();
    if (mounted) {
      setState(() {
        _selectedRegion = region;
        _learningEnabled = learning;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gamswild'),
            Tab(text: 'Rehwild'),
            Tab(text: 'Rotwild'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _GamsTab(
                        selectedRegion: _gamsRegion,
                        regions: _gamsRegions,
                        onRegionChanged: (r) =>
                            setState(() => _gamsRegion = r!),
                      ),
                      const _RehwildTab(),
                      const _RotwildTab(),
                    ],
                  ),
                ),
                // Learning Toggle + Impressum Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Card(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text(
                        '🧠 Fotos zum Learning bereitstellen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Anonyme Fotos helfen das KI-Modell zu verbessern.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _learningEnabled,
                      onChanged: (v) async {
                        await SettingsService.setLearningEnabled(v);
                        if (mounted) setState(() => _learningEnabled = v);
                      },
                      activeColor: WaidblickColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ImpressumScreen()),
                    ),
                    child: Text(
                      'Impressum',
                      style: TextStyle(
                        fontSize: 12,
                        color: WaidblickColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── GAMSWILD TAB ─────────────────────────────────────────────────────────────

class _GamsTab extends StatelessWidget {
  final String selectedRegion;
  final List<String> regions;
  final ValueChanged<String?> onRegionChanged;

  const _GamsTab({
    required this.selectedRegion,
    required this.regions,
    required this.onRegionChanged,
  });

  // Returns rows [Klasse, Geschlecht, Alter, Bedeutung]
  List<List<String>> _getRows() {
    switch (selectedRegion) {
      case 'Bayern':
        return [
          ['Kl. II', 'Bock', '1–7 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 8 J', 'Ernteklasse'],
        ];
      case 'Tirol':
        return [
          ['Kl. III', 'Bock', '1–3 J', 'Jugend'],
          ['Kl. II', 'Bock', '4–7 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 8 J', 'Ernteklasse'],
          ['Kl. III', 'Geiß', '1–3 J', 'Jugend'],
          ['Kl. II', 'Geiß', '4–9 J', 'Schonklasse'],
          ['Kl. I', 'Geiß', 'ab 10 J', 'Ernteklasse'],
        ];
      case 'Salzburg':
        return [
          ['Kl. III', 'Bock', '1–4 J', 'Jugend'],
          ['Kl. II', 'Bock', '5–9 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 10 J', 'Ernteklasse'],
          ['Kl. III', 'Geiß', '1–4 J', 'Jugend'],
          ['Kl. II', 'Geiß', '5–11 J', 'Schonklasse'],
          ['Kl. I', 'Geiß', 'ab 12 J', 'Ernteklasse'],
        ];
      case 'Steiermark':
        return [
          ['Kl. III', 'Bock', '1–3 J', 'Jugend'],
          ['Kl. II', 'Bock', '4–8 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 9 J', 'Ernteklasse'],
          ['Kl. III', 'Geiß', '1–3 J', 'Jugend'],
          ['Kl. II', 'Geiß', '4–10 J', 'Schonklasse'],
          ['Kl. I', 'Geiß', 'ab 11 J', 'Ernteklasse'],
        ];
      case 'Vorarlberg':
        return [
          ['Kitz', 'Bock', '0–1 J', 'Kitz'],
          ['Kl. III', 'Bock', '2–3 J', 'Jugend'],
          ['Kl. II', 'Bock', '4–8 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 9 J', 'Ernteklasse'],
          ['Kitz', 'Geiß', '0–1 J', 'Kitz'],
          ['Kl. III', 'Geiß', '2–3 J', 'Jugend'],
          ['Kl. II', 'Geiß', '4–12 J', 'Schonklasse'],
          ['Kl. I', 'Geiß', 'ab 13 J', 'Ernteklasse'],
        ];
      case 'Kärnten':
        return [
          ['Kl. III', 'Bock', '1–2 J', 'Jugend'],
          ['Kl. II', 'Bock', '3–7 J', 'Schonklasse'],
          ['Kl. I', 'Bock', 'ab 8 J', 'Ernteklasse'],
          ['Kl. III', 'Geiß', '1–3 J', 'Jugend'],
          ['Kl. II', 'Geiß', '4–11 J', 'Schonklasse'],
          ['Kl. I', 'Geiß', 'ab 12 J', 'Ernteklasse'],
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _getRows();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Region-Dropdown
        DropdownButtonFormField<String>(
          value: selectedRegion,
          decoration: InputDecoration(
            labelText: 'Region wählen',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: regions
              .map((r) =>
                  DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: onRegionChanged,
        ),
        const SizedBox(height: 12),
        // Abschussklassen-Tabelle
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📋 Abschussklassen — $selectedRegion',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _ClassTable(
                  headers: const ['Klasse', 'Geschlecht', 'Alter', 'Typ'],
                  rows: rows,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokale Abschusspläne und Reviervorschriften gehen immer vor.',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Abschussklassen Rehwild',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _ClassTable(
                  headers: const ['Klasse', 'Bezeichnung', 'Alter', 'Merkmal'],
                  rows: const [
                    ['Kitz', 'Kitz', '0–1 J', 'Fleckenkleid'],
                    ['Jährling', 'Schmalreh', '1–2 J', 'Hochläufig'],
                    ['Kl. II', 'Mittelbock', '2–5 J', 'Schonklasse'],
                    ['Kl. I', 'Alter Bock', '5+ J', 'Senkrücken'],
                  ],
                ),
              ],
            ),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Abschussklassen Rotwild',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _ClassTable(
                  headers: const ['Klasse', 'Alter', 'Merkmal'],
                  rows: const [
                    ['Kalb', '0–1 J', 'Fleckenkleid'],
                    ['Spießer/Schmaltier', '1–2 J', 'Erste Entwicklung'],
                    ['Kl. III', '2–4 J', 'Jugendhirsch'],
                    ['Kl. II', '4–8 J', 'Mittelalter (Schon)'],
                    ['Kl. I', 'ab 8 J', 'Reifer Hirsch'],
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '💡 Tiefland-Hirsche deutlich größer als Alpenraum!',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── HELPER ───────────────────────────────────────────────────────────────────

class _ClassTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _ClassTable({required this.headers, required this.rows});

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
