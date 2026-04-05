import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/age_estimate.dart';
import '../models/gams_individual.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/age_class_badge.dart';
import 'gams_detail_screen.dart';

/// GamsBook — Liste aller bekannten Gams-Individuen
class GamsbookScreen extends StatefulWidget {
  /// Callback: navigiert zur Analyse-Seite (Tab 0 in HomeScreen)
  final VoidCallback? onNavigateToAnalysis;

  const GamsbookScreen({super.key, this.onNavigateToAnalysis});

  @override
  State<GamsbookScreen> createState() => _GamsbookScreenState();
}

class _GamsbookScreenState extends State<GamsbookScreen> {
  final _uuid = const Uuid();
  String _filterWildart = 'alle';

  static const _monthNames = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ];

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _monthNames[date.month - 1];
    return '$day. $month ${date.year}';
  }

  List<GamsIndividual> get _allIndividuals =>
      List.from(DatabaseService.instance.individuals);

  List<GamsIndividual> get _individuals {
    if (_filterWildart == 'alle') return _allIndividuals;
    return _allIndividuals.where((i) => i.wildart == _filterWildart).toList();
  }

  Future<void> _refresh() async {
    await DatabaseService.instance.load();
    if (mounted) setState(() {});
  }

  Future<void> _addNewGams() async {
    String name = '';
    String revier = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Gams anlegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z.B. "Braunl" oder "Unbekannte Gams 3"',
              ),
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Revier',
                hintText: 'z.B. "Karwendel Süd"',
              ),
              onChanged: (v) => revier = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final now = DateTime.now();
    final individual = GamsIndividual(
      id: _uuid.v4(),
      name: name.isEmpty ? 'Unbenannte Gams' : name,
      revier: revier.isEmpty ? 'Unbekannt' : revier,
      firstSeen: now,
      lastSeen: now,
      currentEstimate: AgeEstimate.uniform(),
      sightings: [],
    );

    await DatabaseService.instance.addIndividual(individual);
    if (mounted) setState(() {});
  }

  Future<void> _deleteGams(GamsIndividual ind) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gams löschen?'),
        content: Text(
            '"${ind.name}" und alle ${ind.sightings.length} Sichtungen werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.deleteIndividual(ind.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final individuals = _individuals;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LOOKBOOK',
          style: TextStyle(
            color: WaidblickColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter-Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('alle', 'Alle'),
                const SizedBox(width: 8),
                _filterChip('gams', 'Gämse'),
                const SizedBox(width: 8),
                _filterChip('rehwild', 'Reh'),
                const SizedBox(width: 8),
                _filterChip('rotwild', 'Rotwild'),
              ],
            ),
          ),
          Expanded(
            child: individuals.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: individuals.length,
                    itemBuilder: (context, index) {
                      final ind = individuals[index];
                      return _GamsCard(
                        individual: ind,
                        formatDate: _formatDate,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GamsDetailScreen(individualId: ind.id),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        onDelete: () => _deleteGams(ind),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewGams,
        tooltip: 'Neue Gams',
        backgroundColor: WaidblickColors.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filterWildart == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterWildart = value),
      selectedColor: WaidblickColors.primary.withOpacity(0.2),
      checkmarkColor: WaidblickColors.primary,
      labelStyle: TextStyle(
        color: selected ? WaidblickColors.primary : WaidblickColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? WaidblickColors.primary : WaidblickColors.border,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦌', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text(
              'Noch keine Analysen gespeichert',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WaidblickColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Fotografiere ein Wildtier, lass es von der KI analysieren und speichere es hier.',
              style: TextStyle(
                  fontSize: 13, color: WaidblickColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onNavigateToAnalysis,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Mach deine erste Analyse!'),
              style: FilledButton.styleFrom(
                backgroundColor: WaidblickColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamsCard extends StatelessWidget {
  final GamsIndividual individual;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GamsCard({
    required this.individual,
    required this.formatDate,
    required this.onTap,
    required this.onDelete,
  });

  Widget _buildLeading(GamsIndividual ind) {
    final photoPath = ind.firstPhotoPath;
    if (photoPath != null && !kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photoPath),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconAvatar(ind),
        ),
      );
    }
    return _iconAvatar(ind);
  }

  Widget _iconAvatar(GamsIndividual ind) {
    final est = ind.currentEstimate;
    return CircleAvatar(
      backgroundColor: WaidblickColors.primary.withOpacity(0.15),
      child: Icon(
        AgeClassBadge.iconFor(est.dominantAgeClass),
        color: WaidblickColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final est = individual.currentEstimate;
    final confPct = (est.confidence * 100).round();
    final hasAnalysis = est.photoCount > 0;

    return Dismissible(
      key: Key(individual.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: WaidblickColors.danger,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Löschen wird im Dialog gehandelt
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: WaidblickColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WaidblickColors.border, width: 1),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildLeading(individual),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  individual.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WaidblickColors.textPrimary,
                  ),
                ),
              ),
              AgeClassBadge(
                ageClass: est.dominantAgeClass,
                showIcon: false,
                fontSize: 11,
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '📍 ${individual.revier}  •  🦌 ${individual.sightings.length} Sichtung(en)',
                style: const TextStyle(
                    fontSize: 12, color: WaidblickColors.textSecondary),
              ),
              Text(
                'Zuletzt: ${formatDate(individual.lastSeen)}',
                style: const TextStyle(
                    fontSize: 12, color: WaidblickColors.textSecondary),
              ),
              if (hasAnalysis) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: est.confidence,
                    minHeight: 4,
                    backgroundColor: WaidblickColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(
                        WaidblickColors.primary),
                  ),
                ),
                Text(
                  '$confPct% Konfidenz  •  ${est.photoCount} Foto(s)',
                  style: const TextStyle(
                      fontSize: 11, color: WaidblickColors.textSecondary),
                ),
              ],
            ],
          ),
          onTap: onTap,
          trailing: const Icon(Icons.chevron_right,
              color: WaidblickColors.textSecondary),
        ),
      ),
    );
  }
}
