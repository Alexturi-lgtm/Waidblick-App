import 'package:flutter/material.dart';
import '../models/hunting_regulations.dart';
import '../services/settings_service.dart';

/// Einstellungs-Screen: Jagdregion auswählen + Klassenstruktur anzeigen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HuntingRegion _selectedRegion = HuntingRegion.other;
  bool _loading = true;
  bool _learningEnabled = false;

  @override
  void initState() {
    super.initState();
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

  // keep old name for compatibility
  Future<void> _loadRegion() => _loadSettings();

  Future<void> _onRegionChanged(HuntingRegion? newRegion) async {
    if (newRegion == null) return;
    await SettingsService.setRegion(newRegion);
    if (mounted) {
      setState(() => _selectedRegion = newRegion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regulation = HuntingRegulation(_selectedRegion);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Region-Auswahl
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🗺️ Jagdregion',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bestimmt die jagdrechtliche Freigabe-Anzeige',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<HuntingRegion>(
                          value: _selectedRegion,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: HuntingRegion.values.map((region) {
                            final reg = HuntingRegulation(region);
                            return DropdownMenuItem(
                              value: region,
                              child: Text(reg.regionName),
                            );
                          }).toList(),
                          onChanged: _onRegionChanged,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Klassenstruktur-Beschreibung
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Abschussklassen – ${regulation.regionName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          regulation.classDescription,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Freigabe-Tabelle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Mindestabschussalter – ${regulation.regionName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FreigabeTable(regulation: regulation),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Learning-Toggle
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      '🧠 Fotos zum Learning bereitstellen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Anonymä Fotos helfen das KI-Modell zu verbessern.',
                    ),
                    value: _learningEnabled,
                    onChanged: (v) async {
                      await SettingsService.setLearningEnabled(v);
                      if (mounted) setState(() => _learningEnabled = v);
                    },
                    activeColor: const Color(0xFFFFB300),
                  ),
                ),

                const SizedBox(height: 16),

                // Hinweis
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Die Angaben sind Richtwerte. Lokale Abschusspläne und Reviervorschriften gehen immer vor.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
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

/// Tabelle mit Freigabe-Grenzwerten
class _FreigabeTable extends StatelessWidget {
  final HuntingRegulation regulation;

  const _FreigabeTable({required this.regulation});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.5),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
          ),
          children: [
            _cell('Tierart', bold: true, header: true),
            _cell('Ab Alter', bold: true, header: true),
            _cell('Status', bold: true, header: true),
          ],
        ),
        // Bock
        TableRow(
          children: [
            _cell('🦌 Bock'),
            _cell('≥ ${regulation.minBockAlter} Jahre'),
            _cell(
              'Freigegeben',
              color: Colors.green.shade700,
              bold: true,
            ),
          ],
        ),
        // Geiß
        TableRow(
          children: [
            _cell('🐾 Geiß'),
            _cell('≥ ${regulation.minGeisAlter} Jahre'),
            _cell(
              'Freigegeben',
              color: Colors.green.shade700,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(String text,
      {bool bold = false, bool header = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: header ? 11 : 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? (header ? Colors.grey.shade700 : null),
        ),
      ),
    );
  }
}
