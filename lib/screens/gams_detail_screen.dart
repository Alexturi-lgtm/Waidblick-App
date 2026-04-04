import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  Future<void> _editGeburtsjahrgang(GamsIndividual individual) async {
    int? jahrgang = individual.geburtsjahrgang;
    final currentYear = DateTime.now().year;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geburtsjahrgang'),
        content: SizedBox(
          width: 200,
          height: 160,
          child: ListWheelScrollView(
            itemExtent: 40,
            onSelectedItemChanged: (i) => jahrgang = currentYear - i,
            children: List.generate(26, (i) {
              final y = currentYear - i;
              return Center(
                child: Text('$y', style: const TextStyle(fontSize: 20)),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, jahrgang),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (picked != null) {
      final updated = individual.copyWith(geburtsjahrgang: picked);
      await DatabaseService.instance.updateIndividual(updated);
      if (mounted) setState(() {});
    }
  }

  Future<void> _sharePdf(GamsIndividual individual) async {
    final est = individual.currentEstimate;
    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final confPct = (est.confidence * 100).round();

    // Foto laden wenn vorhanden
    Uint8List? photoBytes;
    final photoPath = individual.firstPhotoPath;
    if (photoPath != null && !kIsWeb) {
      try {
        photoBytes = await File(photoPath).readAsBytes();
      } catch (_) {}
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('WAIDBLICK',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFF5A623))),
                  pw.Text(dateStr,
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('WILDTIER-ANALYSE',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Tier-Foto
              if (photoBytes != null) ...[  
                pw.Center(
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(
                      pw.MemoryImage(photoBytes),
                      width: 300,
                      height: 200,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              // Basis-Info Grid
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfField('Name', individual.name),
                        _pdfField('Geschlecht', est.isMale ? 'Männlich' : 'Weiblich'),
                        _pdfField('KI-Alter', '~${est.meanAge.round()} Jahre'),
                        _pdfField('Altersklasse', est.dominantAgeLabel),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfField('Wildart', individual.wildart),
                        _pdfField('Region', individual.region ?? 'Bayern'),
                        if (individual.geburtsjahrgang != null)
                          _pdfField('Geburtsjahrgang', '${individual.geburtsjahrgang}'),
                        _pdfField('Revier', individual.revier),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),

              // Analyse-Begründung
              if (est.begruendung.isNotEmpty) ...[  
                pw.Text('Analyse:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(est.begruendung,
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 8),
              ],

              // Merkmale
              if (est.merkmale.isNotEmpty) ...[  
                pw.Text('Erkannte Merkmale:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                ...est.merkmale.map((m) => pw.Text('• $m',
                    style: const pw.TextStyle(fontSize: 11))),
                pw.SizedBox(height: 8),
              ],

              // Confidence + Disclaimer
              pw.Divider(),
              pw.Text('KI-Confidence: $confPct%',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                '⚠️ Diese Schätzung ersetzt keine fachkundige Beurteilung.',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.orange800),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('WAIDBLICK — waidblick.app',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'waidblick_${individual.name.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _pdfField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'PDF teilen',
            onPressed: () => _sharePdf(individual),
          ),
        ],
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
                  if (individual.geburtsjahrgang != null) ...[  
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          'Tatsächlich: Jahrgang ${individual.geburtsjahrgang}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  if (individual.region != null) ...[  
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '📍 ${individual.region}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
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
                const Divider(height: 1),
                // Geburtsjahrgang
                ListTile(
                  leading: const Icon(Icons.today_outlined),
                  title: const Text('Geburtsjahrgang',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    individual.geburtsjahrgang != null
                        ? 'Jahrgang ${individual.geburtsjahrgang}'
                        : 'Nicht eingetragen',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editGeburtsjahrgang(individual),
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
