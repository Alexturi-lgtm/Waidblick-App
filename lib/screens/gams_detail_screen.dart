import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/sighting.dart';
import '../services/bayesian_engine.dart';
import '../services/database_service.dart';
import '../services/ml_service.dart';
import '../models/gams_individual.dart';
import '../widgets/age_class_badge.dart';
import '../widgets/probability_bars.dart';

/// Detail-Screen für eine einzelne Gams
class GamsDetailScreen extends StatefulWidget {
  final String individualId;

  const GamsDetailScreen({super.key, required this.individualId});

  @override
  State<GamsDetailScreen> createState() => _GamsDetailScreenState();
}

class _GamsDetailScreenState extends State<GamsDetailScreen> {
  final _uuid = const Uuid();
  final _mlService = MLService();
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');
  bool _isAnalyzing = false;

  /// Lädt das aktuelle Individuum aus dem DatabaseService
  get _individual =>
      DatabaseService.instance.individuals
          .where((i) => i.id == widget.individualId)
          .firstOrNull;

  Future<void> _addSighting() async {
    final individual = _individual;
    if (individual == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final imageBytes = await picked.readAsBytes();
      final result = await _mlService.analyze(imageBytes);

      // Bayes-Update auf den aktuellen Posterior aufbauen
      final engine = BayesianEngine();
      // Starte vom aktuellen Posterior des Individuums
      engine.seedFrom(individual.currentEstimate);
      engine.processScores(result.scores, result.quality, result.perspective);

      String notes = '';
      if (mounted) {
        notes = await _showNotesDialog() ?? '';
      }

      final sighting = Sighting(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        notes: notes,
        photos: [picked.path],
        estimate: engine.current,
      );

      await DatabaseService.instance.addSighting(individual.id, sighting);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _toggleErlegt(GamsIndividual individual) async {
    if (individual.erlegtAt != null) {
      // Erlegung rücksetzen
      final updated = individual.copyWith(clearErlegtAt: true);
      await DatabaseService.instance.updateIndividual(updated);
      if (mounted) setState(() {});
    } else {
      // Erlegung eintragen
      DateTime erlegtDate = DateTime.now();
      final confirmed = await showDatePicker(
        context: context,
        initialDate: erlegtDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: 'Erlegungsdatum',
      );
      if (confirmed != null) {
        erlegtDate = confirmed;
        final updated = individual.copyWith(erlegtAt: erlegtDate);
        await DatabaseService.instance.updateIndividual(updated);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _editTatsaechlichesAlter(GamsIndividual individual) async {
    int? alter = individual.tatsaechlichesAlter;
    final controller =
        TextEditingController(text: alter != null ? '$alter' : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tatsächliches Alter'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Alter in Jahren',
            hintText: 'z.B. 7',
            suffixText: 'Jahre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final parsed = int.tryParse(controller.text.trim());
      final updated = parsed != null
          ? individual.copyWith(tatsaechlichesAlter: parsed)
          : individual.copyWith(clearTatsaechlichesAlter: true);
      await DatabaseService.instance.updateIndividual(updated);
      if (mounted) setState(() {});
    }
  }

  Future<String?> _showNotesDialog() async {
    String notes = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notiz zur Sichtung'),
        content: TextField(
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'z.B. "Sonnseite, ruhig grasend"',
          ),
          onChanged: (v) => notes = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Überspringen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, notes),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final individual = _individual;

    if (individual == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nicht gefunden')),
        body: const Center(child: Text('Gams nicht mehr vorhanden.')),
      );
    }

    final est = individual.currentEstimate;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(individual.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(individual.revier, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAnalyzing ? null : _addSighting,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo),
        label: Text(_isAnalyzing ? 'Analysiere…' : 'Neue Sichtung'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aktuelle Altersschätzung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Aktuelle Schätzung',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      AgeClassBadge(ageClass: est.dominantAgeClass),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ProbabilityBars(estimate: est),
                  const SizedBox(height: 8),
                  Text(
                    est.confidenceLabel,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${est.photoCount} Foto(s) analysiert',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (individual.tatsaechlichesAlter != null) ...[  
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Tatsächliches Alter: ${individual.tatsaechlichesAlter} Jahre',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Erlegt & Tatsächliches Alter
          Card(
            child: Column(
              children: [
                // Erlegt-Toggle
                ListTile(
                  leading: Icon(
                    individual.erlegtAt != null
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: individual.erlegtAt != null
                        ? Colors.red.shade700
                        : Colors.grey,
                  ),
                  title: Text(
                    individual.erlegtAt != null
                        ? 'Erlegt ✓'
                        : 'Erlegt eintragen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: individual.erlegtAt != null
                          ? Colors.red.shade700
                          : null,
                    ),
                  ),
                  subtitle: individual.erlegtAt != null
                      ? Text(
                          'Am ${individual.erlegtAt!.day.toString().padLeft(2, '0')}.'
                          '${individual.erlegtAt!.month.toString().padLeft(2, '0')}.'
                          '${individual.erlegtAt!.year}',
                        )
                      : null,
                  trailing: OutlinedButton(
                    onPressed: () => _toggleErlegt(individual),
                    child: Text(individual.erlegtAt != null
                        ? 'Rücksetzen'
                        : 'Eintragen'),
                  ),
                ),
                const Divider(height: 1),
                // Tatsächliches Alter
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Tatsächliches Alter',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    individual.tatsaechlichesAlter != null
                        ? '${individual.tatsaechlichesAlter} Jahre'
                        : 'Nicht eingetragen',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editTatsaechlichesAlter(individual),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sichtungen-Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Sichtungen (${individual.sightings.length})',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),

          if (individual.sightings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Noch keine Sichtungen. Tippe auf "Neue Sichtung"!',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),

          // Sichtungen (neueste zuerst)
          ...individual.sightings.reversed.map(
            (s) => _SightingCard(
              sighting: s,
              dateFormat: _dateFormat,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SightingCard extends StatelessWidget {
  final Sighting sighting;
  final DateFormat dateFormat;

  const _SightingCard({
    required this.sighting,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final est = sighting.estimate;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto-Thumbnail
            if (sighting.photos.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.photo),
                      )
                    : Image.file(
                        File(sighting.photos.first),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_not_supported,
                    color: Colors.grey),
              ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(sighting.timestamp),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  AgeClassBadge(
                    ageClass: est.dominantAgeClass,
                    fontSize: 11,
                  ),
                  const SizedBox(height: 4),
                  if (sighting.notes.isNotEmpty)
                    Text(
                      sighting.notes,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    '${est.photoCount} Foto(s) • ${est.confidenceLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
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
