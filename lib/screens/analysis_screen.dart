import 'dart:math';
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
// settings_screen.dart used via HomeScreen tab

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
  String _wildartHint = 'auto'; // 'auto', 'gams', 'rehwild', 'rotwild'
  // _multiPhotoCount entfernt (wird nur intern gezählt, kein UI-Feedback nötig)

  // Zufallsname-System: 40 Adjektive × 40 Namen = 1600 Kombinationen
  static const _adjektive = [
    'Alter', 'Wilder', 'Flinker', 'Sturer', 'Junger', 'Großer', 'Kleiner', 'Starker',
    'Schlauer', 'Frecher', 'Grauer', 'Schwarzer', 'Weißer', 'Brauner', 'Stolzer',
    'Fetter', 'Müder', 'Wacher', 'Schneller', 'Langsamer', 'Einsamer', 'Kluger',
    'Mutiger', 'Scheuer', 'Ruhiger', 'Lauter', 'Stiller', 'Listiger', 'Treuer',
    'Wilder', 'Zotteliger', 'Struppiger', 'Flinker', 'Tapsiger', 'Würdiger',
    'Grimmiger', 'Sanfter', 'Neugieriger', 'Edler', 'Alter',
  ];

  static const _namen = [
    'Harry', 'Emma', 'Bruno', 'Liesl', 'Franz', 'Gretl', 'Hubert', 'Berta',
    'Wastl', 'Vroni', 'Klaus', 'Rosl', 'Sepp', 'Hilde', 'Hansl', 'Frieda',
    'Max', 'Paula', 'Georg', 'Maria', 'Konrad', 'Trudi', 'Wilhelm', 'Hedwig',
    'Anton', 'Erna', 'Ludwig', 'Ilse', 'Rudolf', 'Gerda', 'Baldur', 'Waltraud',
    'Egon', 'Elfriede', 'Horst', 'Ingrid', 'Günter', 'Sieglinde', 'Oskar', 'Mathilde',
  ];

  String _randomGamsName() {
    final rng = Random();
    final adj = _adjektive[rng.nextInt(_adjektive.length)];
    final name = _namen[rng.nextInt(_namen.length)];
    return '$adj $name';
  }

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

  /// Mehrere Fotos aus der Galerie auswählen
  Future<void> _pickMultiplePhotos() async {
    final List<XFile> pickedList = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedList.isEmpty) return;
    // Anzahl der ausgewählten Fotos
    for (final file in pickedList) {
      await _analyzeXFile(file);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _analyzeXFile(picked);
  }

  Future<void> _analyzeXFile(XFile picked) async {
    final imageBytes = await picked.readAsBytes();
    if (mounted) setState(() => _isAnalyzing = true);

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
          wildartHint: _wildartHint,
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

      if (mounted) setState(() {
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
              title: const Text('Galerie (1 Foto)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Mehrere Fotos auswählen'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMultiplePhotos();
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
    DateTime capturedDate = DateTime.now();
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
        title: const Text('Wildtier speichern'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      hintText: 'z.B. "Braunl" oder "Unbekanntes Tier 1"',
                    ),
                    onChanged: (v) => name = v,
                  ),
                ),
                IconButton(
                  tooltip: 'Zufallsname',
                  icon: const Text('🎲', style: TextStyle(fontSize: 20)),
                  onPressed: () {
                    final n = _randomGamsName();
                    nameController.text = n;
                    name = n;
                    setS(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Revier',
                hintText: 'z.B. "Karwendel Süd"',
              ),
              onChanged: (v) => revier = v,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx2,
                  initialDate: capturedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setS(() => capturedDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Aufnahmedatum',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text('${capturedDate.day.toString().padLeft(2, '0')}.${capturedDate.month.toString().padLeft(2, '0')}.${capturedDate.year}'),
                  ],
                ),
              ),
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
        )),
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
          content: Text('"${individual.name}" ins Lookbook gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
      _resetSession();
    }
  }

  /// Wildart-Auswahl Button
  /// Scoring-Matrix Card: zeigt die 6 Alters-Merkmale mit 1–5 Pkt Bewertung
  Widget _buildScoringCard(AgeEstimate estimate) {
    final scoring = estimate.scoring!;

    // Merkmal-Definitionen: Key → (Icon, Anzeigename, Gewicht)
    // Wildart-spezifische Scoring-Keys passend zum Backend
    final wildart = estimate.wildart;
    final List<(String, IconData, String, String)> merkmale;
    if (wildart == 'rehwild') {
      merkmale = [
        ('koerperbau', Icons.straighten_outlined, 'Körperbau', '25%'),
        ('traeger_hals', Icons.height_rounded, 'Träger/Hals', '20%'),
        ('kopf', Icons.face_outlined, 'Kopf', '20%'),
        ('decke_fell', Icons.palette_outlined, 'Decke/Fell', '15%'),
        ('spiegel_schnuerze', Icons.filter_center_focus_outlined, 'Spiegel/Schnürze', '10%'),
        ('gehoern', Icons.park_outlined, 'Gehörn', '10%'),
      ];
    } else if (wildart == 'rotwild') {
      merkmale = [
        ('koerperprofil', Icons.straighten_outlined, 'Körperprofil', '25%'),
        ('haupt_kopf', Icons.face_outlined, 'Haupt/Kopf', '20%'),
        ('wamme', Icons.linear_scale_outlined, 'Wamme', '20%'),
        ('ruecken_widerrist', Icons.show_chart_outlined, 'Rücken/Widerrist', '15%'),
        ('traeger', Icons.height_rounded, 'Träger', '10%'),
        ('maehne_fell', Icons.texture_outlined, 'Mähne/Fell', '10%'),
      ];
    } else {
      // Gams (default) — exakte Backend-Keys
      merkmale = [
        ('windfang', Icons.air_rounded, 'Windfang', '25%'),
        ('gesichtszuegel', Icons.face_outlined, 'Gesichtszügel', '20%'),
        ('ruecken_flanken', Icons.straighten_outlined, 'Rücken/Flanken', '20%'),
        ('schrank', Icons.compare_arrows_rounded, 'Schrank', '15%'),
        ('augenbogen', Icons.remove_red_eye_outlined, 'Augenbogen', '10%'),
        ('hochlaeufigkeit', Icons.height_rounded, 'Hochläufigkeit', '10%'),
      ];
    }

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

  /// Wildart-Hintergrundbild je nach Auswahl
  String _wildartBg() {
    switch (_wildartHint) {
      case 'gams':    return 'assets/images/gams_bg.jpg';
      case 'rehwild': return 'assets/images/rehwild_bg.jpg';
      case 'rotwild': return 'assets/images/waidblick-bg.jpg';
      default:        return 'assets/images/gams_bg.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _photos.isNotEmpty;
    final estimate = _latestVisionEstimate ?? _engine.current;
    final theme = Theme.of(context);
    final accent = _wildartAccent();

    return Scaffold(
      backgroundColor: WaidblickColors.background,
      body: _isAnalyzing
          ? _buildAnalyzingState()
          : Stack(
              children: [
                // ── Vollbild-Hintergrund ──────────────────────────────
                Positioned.fill(
                  child: Image.asset(
                    _wildartBg(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0A0A0A),
                    ),
                  ),
                ),
                // Gradient overlay (oben transparent → unten fast schwarz)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.3, 0.55, 0.78, 1.0],
                        colors: [
                          Color(0x800A0A0A),
                          Color(0x1A0A0A0A),
                          Color(0x330A0A0A),
                          Color(0xE50A0A0A),
                          Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Haupt-Content ─────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // TopBar: WAIDBLICK + Wildart-Tabs
                      _buildTopBar(accent),

                      // Body
                      Expanded(
                        child: !hasPhotos
                            ? _buildEmptyState()
                            : _buildResultScrollable(estimate, theme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      // FAB nur im Result-View (nicht im Empty State)
      floatingActionButton: (!_isAnalyzing && hasPhotos)
          ? FloatingActionButton.extended(
              onPressed: _showPickerDialog,
              backgroundColor: WaidblickColors.primary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_a_photo),
              label: const Text(
                'WEITERES FOTO',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  /// TopBar: Logo + Subtitle + Wildart-Tabs (wie Web-Version)
  Widget _buildTopBar(Color accent) {
    return Container(
      color: const Color(0x8C141414),
      child: ClipRect(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo-Zeile
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WAIDBLICK',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: accent,
                          ),
                        ),
                        Text(
                          'WILDTIER-ANALYSE',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFFF5F0E8).withOpacity(0.3),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_currentPosition != null)
                      const Icon(Icons.location_on, color: Color(0xFF4ade80), size: 18),
                    IconButton(
                      icon: Icon(Icons.refresh,
                          color: const Color(0xFFF5F0E8).withOpacity(0.5),
                          size: 20),
                      tooltip: 'Neue Session',
                      onPressed: _resetSession,
                    ),
                  ],
                ),
              ),
              // Wildart-Tabs Zeile
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    _wildartTabWeb('auto', null, '🔍', 'Auto'),
                    const SizedBox(width: 6),
                    _wildartTabWeb('gams', 'assets/icons/gams.jpg', null, 'Gams'),
                    const SizedBox(width: 6),
                    _wildartTabWeb('rehwild', 'assets/icons/rehwild.jpg', null, 'Rehwild'),
                    const SizedBox(width: 6),
                    _wildartTabWeb('rotwild', 'assets/icons/rotwild.jpg', null, 'Rotwild'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Einzelner Wildart-Tab (Web-Style: Icon/Bild oben, Label unten)
  Widget _wildartTabWeb(String value, String? imagePath, String? emoji, String label) {
    final isSelected = _wildartHint == value;
    final accent = _wildartAccentFor(value);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _wildartHint = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.12) : const Color(0xFF252525),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                Opacity(
                  opacity: isSelected ? 1.0 : 0.45,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      imagePath,
                      width: 30, height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.terrain,
                        size: 22,
                        color: isSelected ? accent : const Color(0xFFF5F0E8).withOpacity(0.45),
                      ),
                    ),
                  ),
                )
              else
                Opacity(
                  opacity: isSelected ? 1.0 : 0.45,
                  child: Text(emoji!, style: const TextStyle(fontSize: 22, height: 1.2)),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected ? accent : const Color(0xFFF5F0E8).withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _wildartAccentFor(String value) {
    switch (value) {
      case 'gams':    return const Color(0xFFF5A623);
      case 'rehwild': return const Color(0xFF5D9E6E);
      case 'rotwild': return const Color(0xFFB5451B);
      default:        return const Color(0xFFAAAAAA);
    }
  }

  /// Result-View als scrollbarer Container (ohne eigene AppBar)
  Widget _buildResultScrollable(AgeEstimate estimate, ThemeData theme) {
    return _buildResultView(estimate, theme);
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

  /// Wildart-Farbe basierend auf Auswahl
  Color _wildartAccent() {
    switch (_wildartHint) {
      case 'gams':    return const Color(0xFFF5A623);
      case 'rehwild': return const Color(0xFF5D9E6E);
      case 'rotwild': return const Color(0xFFB5451B);
      default:        return const Color(0xFFAAAAAA);
    }
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const Spacer(),
        // Zwei Buttons direkt auf dem Hintergrund, unten
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ghostButton(
                icon: Icons.photo_camera_outlined,
                label: '📷 Kamera',
                onTap: _showPickerDialog,
              ),
              const SizedBox(width: 10),
              _ghostButton(
                icon: Icons.menu_book_outlined,
                label: '📋 Anleitung',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PhotoGuideScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ghostButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFF5F0E8).withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFF5F0E8).withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
              'Im Lookbook speichern',
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


