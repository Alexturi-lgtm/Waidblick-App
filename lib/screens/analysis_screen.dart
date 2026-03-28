import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/age_estimate.dart';
import '../models/gams_individual.dart';
import '../models/hunting_regulations.dart';
import '../models/sighting.dart';
import '../services/bayesian_engine.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/ml_service.dart';
import '../services/vision_api_service.dart';
import '../services/photo_quality_service.dart';
import '../services/recognition_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/age_class_badge.dart';
import '../widgets/photo_quality_indicator.dart';
import '../widgets/probability_bars.dart';
import 'photo_guide_screen.dart';
import 'settings_screen.dart';

/// Analyse-Screen: Foto aufnehmen/auswählen → ML → Bayes → Ergebnis anzeigen
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  final MLService _mlService = MLService();
  final BayesianEngine _engine = BayesianEngine();
  final _uuid = const Uuid();

  List<Uint8List> _photos = [];
  final List<String> _photoPaths = [];
  final List<PhotoQualityResult> _photoQualities = [];
  bool _isAnalyzing = false;
  HuntingRegion _huntingRegion = HuntingRegion.other;
  Position? _currentPosition;
  AgeEstimate? _latestVisionEstimate; // Letzte Vision-API Schätzung

  @override
  void initState() {
    super.initState();
    _loadRegion();
  }

  Future<void> _loadRegion() async {
    final region = await SettingsService.getRegion();
    if (mounted) setState(() => _huntingRegion = region);
  }

  void _resetSession() {
    setState(() {
      _photos = [];
      _photoPaths.clear();
      _photoQualities.clear();
      _engine.reset();
      _currentPosition = null;
      _latestVisionEstimate = null;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    final imageBytes = await picked.readAsBytes();
    setState(() => _isAnalyzing = true);

    try {
      // ── Foto-Qualitäts-Check ──────────────────────────────────────────
      final quality = await PhotoQualityService.analyze(imageBytes);

      if (!quality.isUsable) {
        if (mounted) {
          final retry = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Foto zu schlecht'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Die Foto-Qualität ist zu gering für eine zuverlässige Analyse (${quality.scorePercent}%).',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...quality.tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(tip, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Trotzdem verwenden'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Neues Foto'),
                ),
              ],
            ),
          );
          if (retry == true) {
            setState(() => _isAnalyzing = false);
            return;
          }
        }
      }

      // NEUER FLOW: Vision API ist primary, kein Mock
      try {
        // Vision API aufrufen (echte KI-Analyse)
        final visionEstimate = await VisionApiService.analyze(
          imageBytes: imageBytes,
          wildartHint: 'auto',
          region: _huntingRegion.name,
          photoCount: _photos.length + 1,
          previousEstimate: _latestVisionEstimate,
        );
        // Vision-Ergebnis direkt in die Bayes-Engine laden (kein Mock-Overlay)
        _engine.setFromVision(visionEstimate);
        _latestVisionEstimate = visionEstimate;
      } catch (e) {
        // Nur bei echtem Fehler: Mock als Fallback
        final mockResult = await _mlService.analyze(imageBytes);
        _engine.processScores(
            mockResult.scores, mockResult.quality, mockResult.perspective);
      }

      // GPS automatisch holen (erstes Foto setzt die Position)
      if (_photos.isEmpty) {
        final position = await LocationService.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      }

      setState(() {
        _photos.add(imageBytes);
        _photoPaths.add(picked.path);
        _photoQualities.add(quality);
      });

      // Wiedererkennung nur beim ersten Foto
      if (_photos.length == 1) {
        final matches = RecognitionService.findMatches(
          newEstimate: _engine.current,
          individuals: DatabaseService.instance.individuals,
          newLat: _currentPosition?.latitude,
          newLon: _currentPosition?.longitude,
        );
        if (matches.isNotEmpty && matches.first.isProbable && mounted) {
          await _showRecognitionDialog(matches);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysefehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _showRecognitionDialog(List<RecognitionMatch> matches) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search, color: Colors.green),
            SizedBox(width: 8),
            Text('Bekannte Gams?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diese Gams könnte bereits in deinem GamsBuch sein:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...matches.map((match) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: match.isAlmostCertain
                            ? Colors.green
                            : Colors.orange,
                        child: Text(
                          '${match.score.round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        match.individual.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.individual.ageDescription,
                              style: const TextStyle(fontSize: 12)),
                          Text(match.reason,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(
                            match.confidenceLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: match.isAlmostCertain
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _addSightingToExisting(match.individual);
                      },
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _addSightingToExisting(match.individual);
                        },
                        child: const Text('Ja!'),
                      ),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Überspringen'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Neue Gams'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSightingToExisting(GamsIndividual individual) async {
    final now = DateTime.now();
    final sighting = Sighting(
      id: _uuid.v4(),
      timestamp: now,
      notes: 'Sichtung via Wiedererkennung',
      photos: List<String>.from(_photoPaths),
      estimate: _engine.current,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    final updated = individual.copyWith(
      lastSeen: now,
      currentEstimate: _engine.current,
      sightings: [...individual.sightings, sighting],
    );

    await DatabaseService.instance.updateIndividual(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sichtung zu "${individual.name}" hinzugefügt!'),
          backgroundColor: Colors.green,
        ),
      );
      _resetSession();
    }
  }

  Future<void> _showPickerDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGams() async {
    final estimate = _engine.current;
    String name = '';
    String revier = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gams speichern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'z.B. "Braunl" oder "Unbekannte Gams 1"',
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
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}°, '
                    '${_currentPosition!.longitude.toStringAsFixed(4)}°',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
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

    if (confirmed != true) return;

    final now = DateTime.now();
    final sighting = Sighting(
      id: _uuid.v4(),
      timestamp: now,
      notes: 'Aus Analyse-Screen erstellt',
      photos: List<String>.from(_photoPaths),
      estimate: estimate,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    final individual = GamsIndividual(
      id: _uuid.v4(),
      name: name.isEmpty ? 'Unbenannte Gams' : name,
      revier: revier.isEmpty ? 'Unbekannt' : revier,
      firstSeen: now,
      lastSeen: now,
      currentEstimate: estimate,
      sightings: [sighting],
    );

    await DatabaseService.instance.addIndividual(individual);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${individual.name}" ins GamsBook gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
      _resetSession();
    }
  }

  /// Scoring-Matrix Card: zeigt die 6 Alters-Merkmale mit 1–5 Pkt Bewertung
  Widget _buildScoringCard(AgeEstimate estimate) {
    final scoring = estimate.scoring!;

    // Merkmal-Definitionen: Key → (Icon, Anzeigename, Gewicht)
    const merkmale = [
      ('hakenkruemmung', Icons.rotate_right_rounded, 'Hakenkrümmung', '25%'),
      ('jahresringe', Icons.settings_outlined, 'Jahresringe', '20%'),
      ('gesichtszuegel', Icons.face_outlined, 'Gesichtszügel', '20%'),
      ('fellfarbe', Icons.palette_outlined, 'Fellfarbe', '15%'),
      ('ruecken_flanken', Icons.straighten_outlined, 'Rücken/Flanken', '10%'),
      ('augen', Icons.visibility_outlined, 'Augen', '10%'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: WaidblickColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WaidblickColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '📊 Scoring-Matrix',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WaidblickColors.primary,
                  ),
                ),
                const Spacer(),
                if (estimate.gewichteterScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: WaidblickColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: WaidblickColors.primary.withOpacity(0.5)),
                    ),
                    child: Text(
                      'Ø ${estimate.gewichteterScore!.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: WaidblickColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...merkmale.map((m) {
              final key = m.$1;
              final icon = m.$2;
              final name = m.$3;
              final weight = m.$4;

              final data = scoring[key] as Map<String, dynamic>?;
              final wert = (data?['wert'] as num?)?.toInt() ?? 0;
              final beobachtung = data?['beobachtung'] as String? ?? '';
              final isAvailable = wert > 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: WaidblickColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WaidblickColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          weight,
                          style: const TextStyle(
                            fontSize: 10,
                            color: WaidblickColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (isAvailable)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (i) {
                              final filled = i < wert;
                              return Icon(
                                filled ? Icons.circle : Icons.circle_outlined,
                                size: 10,
                                color: filled
                                    ? _scoringColor(wert)
                                    : WaidblickColors.border,
                              );
                            }),
                          )
                        else
                          const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 11,
                              color: WaidblickColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (beobachtung.isNotEmpty && beobachtung != 'nicht beurteilbar')
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 2),
                        child: Text(
                          beobachtung,
                          style: const TextStyle(
                            fontSize: 11,
                            color: WaidblickColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Farbe basierend auf Scoring-Wert (1=grün → 5=rot)
  Color _scoringColor(int wert) {
    switch (wert) {
      case 1: return const Color(0xFF4CAF50); // grün = jung
      case 2: return const Color(0xFF8BC34A);
      case 3: return const Color(0xFFFFC107); // gelb = mittel
      case 4: return const Color(0xFFFF9800);
      case 5: return const Color(0xFFF44336); // rot = alt
      default: return WaidblickColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _photos.isNotEmpty;
    // Vision-API Schätzung hat Vorrang wenn verfügbar (echte KI statt Mock)
    final estimate = _latestVisionEstimate ?? _engine.current;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: WaidblickColors.background,
      body: _isAnalyzing
          ? _buildAnalyzingState()
          : CustomScrollView(
              slivers: [
                // ── Hero SliverAppBar ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: WaidblickColors.background,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Hintergrundbild
                        Image.asset(
                          'assets/images/waidblick-bg.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0A1A0F),
                                  Color(0xFF1A1200),
                                  Color(0xFF141414),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.75),
                              ],
                            ),
                          ),
                        ),
                        // Titel unten
                        const Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                'WAIDBLICK',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: WaidblickColors.primary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Wildtier-Analyse',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: WaidblickColors.textPrimary,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (_currentPosition != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        child: Icon(Icons.location_on, color: Colors.green, size: 20),
                      ),
                    if (hasPhotos)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Neue Session',
                        onPressed: _resetSession,
                      ),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded),
                      tooltip: 'Foto-Anleitung',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhotoGuideScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: 'Einstellungen',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                        _loadRegion();
                      },
                    ),
                  ],
                ),

                // ── Content ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: !hasPhotos
                      ? _buildEmptyState()
                      : _buildResultView(estimate, theme),
                ),
              ],
            ),
      floatingActionButton: !_isAnalyzing
          ? FloatingActionButton.extended(
              onPressed: _showPickerDialog,
              backgroundColor: WaidblickColors.primary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_a_photo),
              label: Text(
                hasPhotos ? 'WEITERES FOTO' : 'FOTO ANALYSIEREN',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildAnalyzingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/waidblick-bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: WaidblickColors.background),
        ),
        Container(color: Colors.black.withOpacity(0.80)),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: WaidblickColors.primary,
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'KI analysiert Foto...',
                style: TextStyle(
                  color: WaidblickColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Bitte warten…',
                style: TextStyle(
                  fontSize: 13,
                  color: WaidblickColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Premium Upload-CTA
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: WaidblickColors.primary.withOpacity(0.5),
                width: 1.5,
              ),
              color: WaidblickColors.surface,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showPickerDialog,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: WaidblickColors.primary,
                      size: 52,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'WILDTIER FOTOGRAFIEREN',
                      style: TextStyle(
                        color: WaidblickColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'oder Foto aus Galerie wählen',
                      style: TextStyle(
                        color: WaidblickColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mehr Fotos = höhere Genauigkeit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: WaidblickColors.textSecondary.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResultView(AgeEstimate estimate, ThemeData theme) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Foto-Grid
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i == _photos.length - 1
                        ? WaidblickColors.primary
                        : WaidblickColors.border,
                    width: i == _photos.length - 1 ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(
                    _photos[i],
                    width: 160,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Nicht-Gams Warnung
          if (estimate.isNotGams) ...[
            Container(
              decoration: BoxDecoration(
                color: WaidblickColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: WaidblickColors.danger, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: WaidblickColors.danger, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kein Schalenwild erkannt',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: WaidblickColors.danger,
                                  fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                            'Bitte lade ein Foto einer Gams hoch. Das Bild zeigt vermutlich kein Schalenwild oder die Bildqualität ist zu gering.',
                            style: TextStyle(
                                color: WaidblickColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Unsicher-Hinweis
          if (estimate.isUncertain && !estimate.isNotGams) ...[
            Container(
              decoration: BoxDecoration(
                color: WaidblickColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: WaidblickColors.warning, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline,
                        color: WaidblickColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Konfidenz niedrig — bitte weitere Fotos aus anderer Perspektive hinzufügen.',
                        style:
                            TextStyle(color: WaidblickColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Dominante Altersklasse — Waidblick Premium Card
          if (!estimate.isNotGams)
            Container(
              decoration: BoxDecoration(
                color: WaidblickColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  top: const BorderSide(
                      color: WaidblickColors.primary, width: 4),
                  left: const BorderSide(
                      color: WaidblickColors.border, width: 1),
                  right: const BorderSide(
                      color: WaidblickColors.border, width: 1),
                  bottom: const BorderSide(
                      color: WaidblickColors.border, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: WaidblickColors.primary.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Wildart-Label + Badge oben rechts
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            estimate.dominantAgeLabel,
                            style: const TextStyle(
                              color: WaidblickColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: WaidblickColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: WaidblickColors.primary.withOpacity(0.6),
                                width: 1),
                          ),
                          child: const Text(
                            'GAMS',
                            style: TextStyle(
                              color: WaidblickColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AgeClassBadge(ageClass: estimate.dominantAgeClass),
                    const SizedBox(height: 20),
                    // Großes Alters-Display: 72sp Amber + "Jahre" cream
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '~${estimate.meanAge.round()}',
                            style: const TextStyle(
                              color: WaidblickColors.primary,
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Jahre',
                            style: TextStyle(
                              color: WaidblickColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        estimate.confidenceInterval,
                        style: const TextStyle(
                          color: WaidblickColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Confidence-Balken in Amber
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: estimate.confidence,
                              minHeight: 10,
                              backgroundColor: WaidblickColors.surfaceVariant,
                              valueColor: const AlwaysStoppedAnimation(
                                  WaidblickColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          estimate.confidenceLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WaidblickColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '${estimate.photoCount} Foto(s) analysiert',
                        style: const TextStyle(
                          color: WaidblickColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // GPS-Info anzeigen wenn vorhanden
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                size: 12,
                                color: WaidblickColors.successLight),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(4)}°, '
                              '${_currentPosition!.longitude.toStringAsFixed(4)}°',
                              style: const TextStyle(
                                  color: WaidblickColors.successLight,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24, color: WaidblickColors.border),
                    // Merkmals-Beschreibung
                    const Text(
                      'Typische Merkmale:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WaidblickColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estimate.ageDescription,
                      style: const TextStyle(
                          color: WaidblickColors.textSecondary,
                          fontSize: 13),
                    ),
                    const Divider(height: 24, color: WaidblickColors.border),
                    // Jagdrechtliche Info
                    const Text(
                      'Jagdrecht:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WaidblickColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      HuntingRegulation(_huntingRegion).freigabeText(
                        estimate.meanAge,
                        estimate.pBock,
                        estimate.pGeis,
                      ),
                      style: const TextStyle(
                          color: WaidblickColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // KI-Analyse: Begründung und Merkmale (aus VisionApiService)
          if (estimate.begruendung.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: WaidblickColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: WaidblickColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 KI-Analyse',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WaidblickColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estimate.begruendung,
                      style: const TextStyle(
                          color: WaidblickColors.textSecondary),
                    ),
                    if (estimate.merkmale.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: estimate.merkmale
                            .map((m) => Chip(
                                  label: Text(m,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: WaidblickColors.textSecondary)),
                                  backgroundColor:
                                      WaidblickColors.surfaceVariant,
                                  side: const BorderSide(
                                      color: WaidblickColors.border),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Scoring-Matrix: Merkmal-Scores anzeigen wenn vorhanden
          if (estimate.scoring != null && estimate.scoring!.isNotEmpty) ...[
            _buildScoringCard(estimate),
            const SizedBox(height: 8),
          ],

          // Foto-Qualitäts-Indikator (letztes Foto)
          if (_photoQualities.isNotEmpty) ...[
            PhotoQualityIndicator(result: _photoQualities.last),
            const SizedBox(height: 8),
          ],

          // Wahrscheinlichkeits-Balken — nur anzeigen wenn Schalenwild erkannt
          if (!estimate.isNotGams)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Altersklassen-Verteilung',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ProbabilityBars(estimate: estimate),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Aktions-Buttons
          ElevatedButton.icon(
            onPressed: _showPickerDialog,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('WEITERES FOTO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WaidblickColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saveGams,
            icon: const Icon(Icons.bookmark_add,
                color: WaidblickColors.primary),
            label: const Text(
              'Als Gams speichern',
              style: TextStyle(color: WaidblickColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: WaidblickColors.primary),
            ),
          ),
          const SizedBox(height: 80), // FAB-Abstand
        ],
      ),
    );
  }
}
