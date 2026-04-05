import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/streckenblatt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/age_class_badge.dart';
import '../widgets/photo_quality_indicator.dart';
import '../widgets/probability_bars.dart';
import 'photo_guide_screen.dart';
import 'paywall_screen.dart';
import '../services/freemium_service.dart';
import '../services/profile_service.dart';
import '../services/regional_data.dart';
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
  int _loadingMessageIndex = 0;
  Timer? _loadingTimer;
  int _analysisCount = 0;
  bool _isPremiumUser = false;

  static const _loadingMessages = [
    'KI analysiert Wildtier...',
    'Merkmale werden ausgewertet...',
    'Ergebnis wird erstellt...',
  ];
  HuntingRegion _huntingRegion = HuntingRegion.other;
  Position? _currentPosition;
  AgeEstimate? _latestVisionEstimate; // Letzte Vision-API Schätzung
  String _wildartHint = 'auto'; // 'auto', 'gams', 'rehwild', 'rotwild'
  String _detectedRegion = 'Bayern'; // GPS-bestimmte Region
  bool _erlegerbild = false; // Erlegerbild erkannt
  DateTime? _exifDate; // EXIF-Datum aus hochgeladenem Foto
  String? _exifDateHint; // Hinweis-Text für UI
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
    _loadAnalysisCount();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAnalysisCount() async {
    try {
      final premium = await ProfileService.isPremium();
      final profile = await ProfileService.getProfile();
      final count = profile?['analyses_this_month'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _isPremiumUser = premium;
          _analysisCount = count;
        });
      }
    } catch (_) {}
  }

  void _startLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingMessageIndex = 0;
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  Future<void> _loadRegion() async {
    final region = await SettingsService.getRegion();
    if (mounted) setState(() => _huntingRegion = region);
  }

  /// Konvertiert den String aus detectRegion() in HuntingRegion-Enum
  HuntingRegion _regionStringToEnum(String region) {
    switch (region.toLowerCase()) {
      case 'tirol':
      case 'vorarlberg': // Vorarlberg nutzt ähnliches Jagdrecht wie Tirol
        return HuntingRegion.tirol;
      case 'steiermark':
        return HuntingRegion.steiermark;
      case 'salzburg':
        return HuntingRegion.salzburg;
      case 'bayern':
        return HuntingRegion.bayern;
      default:
        return HuntingRegion.other;
    }
  }

  void _resetSession() {
    setState(() {
      _photos = [];
      _photoPaths.clear();
      _photoQualities.clear();
      _engine.reset();
      _currentPosition = null;
      _latestVisionEstimate = null;
      _erlegerbild = false;
      _exifDate = null;
      _exifDateHint = null;
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
      await _analyzeXFile(file, fromGallery: true);
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
    await _analyzeXFile(picked, fromGallery: source == ImageSource.gallery);
  }


  /// Liest das EXIF-Datum (DateTimeOriginal) aus einem Bild-Dateipfad.
  Future<DateTime?> _readExifDate(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final data = await readExifFromBytes(bytes);
      final tag = data['EXIF DateTimeOriginal'] ?? data['Image DateTime'];
      if (tag == null) return null;
      final raw = tag.printable; // Format: '2024:03:15 10:30:00'
      final parts = raw.trim().split(' ');
      if (parts.length < 2) return null;
      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');
      if (dateParts.length < 3) return null;
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0,
        timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Dialog: Aufnahmeort bei hochgeladenem Foto abfragen
  Future<void> _showLocationDialog() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('📍', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Aufnahmeort'),
          ],
        ),
        content: const Text('Wo wurde dieses Foto aufgenommen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'gps'),
            child: const Text('Aktueller Standort'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'manual'),
            child: const Text('Region wählen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'unknown'),
            child: const Text('Unbekannt'),
          ),
        ],
      ),
    );

    if (result == 'gps') {
      final position = await LocationService.getCurrentPosition();
      if (mounted && position != null) {
        setState(() {
          _currentPosition = position;
          _detectedRegion = RegionalData.detectRegion(
              position.latitude, position.longitude);
          _huntingRegion = _regionStringToEnum(_detectedRegion);
        });
      }
    } else if (result == 'manual') {
      const regions = ['Bayern', 'Tirol', 'Steiermark', 'Salzburg', 'Vorarlberg', 'Schweiz', 'Sonstige'];
      if (!mounted) return;
      final chosen = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Region wählen'),
          children: regions
              .map((r) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r, style: const TextStyle(fontSize: 16)),
                    ),
                  ))
              .toList(),
        ),
      );
      if (chosen != null && mounted) {
        setState(() {
          _detectedRegion = chosen;
          _huntingRegion = _regionStringToEnum(chosen);
          _currentPosition = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _detectedRegion = 'Unbekannt';
          _huntingRegion = HuntingRegion.other;
        });
      }
    }
  }

  /// Prüft ob Gast-Modus aktiv
  Future<bool> _isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guest_mode') ?? false;
  }

  Future<void> _analyzeXFile(XFile picked, {bool fromGallery = false}) async {
    // Freemium-Check: Analyse-Limit
    final canAnalyze = await FreemiumService.canAnalyze();
    if (!canAnalyze && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    final imageBytes = await picked.readAsBytes();
    if (mounted) {
      setState(() => _isAnalyzing = true);
      _startLoadingAnimation();
    }

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

      // GPS/Geo-Logik: Bei Galerie-Upload -> Dialog, bei Kamera -> automatisch GPS
      if (_photos.isEmpty) {
        if (fromGallery) {
          // Bug 3 Fix: Geo-Dialog bei hochgeladenem Foto
          setState(() => _isAnalyzing = false);
          await _showLocationDialog();
          setState(() => _isAnalyzing = true);

          // Bug 4 Fix: EXIF-Datum lesen
          final exifDate = await _readExifDate(picked.path);
          if (mounted) {
            if (exifDate != null) {
              setState(() {
                _exifDate = exifDate;
                final d = exifDate;
                _exifDateHint = '📅 Aufnahme: ${d.day.toString().padLeft(2, "0")}.${d.month.toString().padLeft(2, "0")}.${d.year} (aus Foto-Metadaten)';
              });
            } else {
              // Kein EXIF: DatePicker zeigen
              setState(() => _isAnalyzing = false);
              if (mounted) {
                final pickedDate = await showDatePicker(
                  context: context,
                  helpText: 'Wann wurde dieses Foto aufgenommen?',
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() => _exifDate = pickedDate);
                }
              }
              setState(() => _isAnalyzing = true);
            }
          }
        } else {
          // Kamera: automatisch GPS
          final position = await LocationService.getCurrentPosition();
          if (mounted) {
            setState(() {
              _currentPosition = position;
              if (position != null) {
                _detectedRegion = RegionalData.detectRegion(
                    position.latitude, position.longitude);
                // HuntingRegion mit GPS-erkannter Region synchronisieren
                _huntingRegion = _regionStringToEnum(_detectedRegion);
              }
            });
          }
        }
      }

      // NEUER FLOW: Vision API ist primary, kein Mock
      try {
        // Vision API aufrufen (echte KI-Analyse)
        final visionEstimate = await VisionApiService.analyze(
          imageBytes: imageBytes,
          wildartHint: _wildartHint,
          region: _detectedRegion,
          photoCount: _photos.length + 1,
          previousEstimate: _latestVisionEstimate,
        );
        // Vision-Ergebnis direkt in die Bayes-Engine laden (kein Mock-Overlay)
        _engine.setFromVision(visionEstimate);
        _latestVisionEstimate = visionEstimate;

        // Erlegerbild-Erkennung
        final begr = visionEstimate.begruendung.toLowerCase();
        final isErlegerbild = visionEstimate.confidence < 0.4 ||
            begr.contains('liegend') ||
            begr.contains('erlegerbild') ||
            begr.contains('körper nicht');
        if (mounted) setState(() => _erlegerbild = isErlegerbild);

        // Freemium-Counter + Supabase-Counter erhöhen
        await FreemiumService.incrementAnalyseCount();
        await _incrementAndCheckQuota();
      } catch (e) {
        // Nur bei echtem Fehler: Mock als Fallback
        final mockResult = await _mlService.analyze(imageBytes);
        _engine.processScores(
            mockResult.scores, mockResult.quality, mockResult.perspective);
        await FreemiumService.incrementAnalyseCount();
        await _incrementAndCheckQuota();
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
        final errorStr = e.toString().toLowerCase();
        final isNetworkError = errorStr.contains('socket') ||
            errorStr.contains('network') ||
            errorStr.contains('connection') ||
            errorStr.contains('host') ||
            errorStr.contains('http') ||
            errorStr.contains('timeout') ||
            errorStr.contains('unreachable');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNetworkError
                  ? 'Keine Verbindung zum Server. Bitte WLAN prüfen.'
                  : 'Analysefehler: $e',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _stopLoadingAnimation();
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

  /// Supabase-Analyse-Counter erhöhen + Quota prüfen; bei Überschreitung Paywall oder Anmelde-Hinweis
  Future<void> _incrementAndCheckQuota() async {
    try {
      await ProfileService.incrementAnalysis();
    } catch (_) {
      // Fehler beim Zählen nicht propagieren (kein Analysefehler)
    }

    // Quota-Prüfung: false = Limit überschritten
    try {
      final hasQuota = await ProfileService.hasAnalysisQuota();
      if (!hasQuota && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      }
    } catch (_) {
      // Quota-Fehler nicht propagieren
    }

    // Counter aktualisieren
    _loadAnalysisCount();
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
    // Freemium-Check: Lookbook-Limit
    final currentCount = DatabaseService.instance.individuals.length;
    final canSave = await FreemiumService.canSaveToLookbook(currentCount);
    if (!canSave && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen(isLookbookLimit: true)),
      );
      return;
    }

    final estimate = _engine.current;
    String name = '';
    String revier = '';
    DateTime capturedDate = _exifDate ?? DateTime.now();
    int? geburtsjahrgang;
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
            const SizedBox(height: 8),
            // Geburtsjahr-Picker
            InkWell(
              onTap: () async {
                final currentYear = DateTime.now().year;
                final initialYear = geburtsjahrgang ?? currentYear - (estimate.meanAge.round());
                final picked = await showDialog<int>(
                  context: ctx2,
                  builder: (yearCtx) {
                    int selectedYear = initialYear.clamp(currentYear - 25, currentYear);
                    return AlertDialog(
                      title: const Text('Geburtsjahrgang'),
                      content: StatefulBuilder(
                        builder: (yCtx, ySetS) => SizedBox(
                          width: 200,
                          height: 160,
                          child: ListWheelScrollView(
                            itemExtent: 40,
                            onSelectedItemChanged: (i) {
                              selectedYear = currentYear - i;
                              ySetS(() {});
                            },
                            children: List.generate(26, (i) {
                              final y = currentYear - i;
                              return Center(
                                child: Text(
                                  '$y',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: y == selectedYear
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(yearCtx),
                          child: const Text('Abbrechen'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(yearCtx, selectedYear),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
                if (picked != null) setS(() => geburtsjahrgang = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Geburtsjahrgang (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(geburtsjahrgang != null
                        ? 'Jahrgang $geburtsjahrgang'
                        : 'Nicht angegeben'),
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
                  Expanded(
                    child: Text(
                      'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}°, '
                      '${_currentPosition!.longitude.toStringAsFixed(4)}° • $_detectedRegion',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
      geburtsjahrgang: geburtsjahrgang,
      region: _detectedRegion,
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

  /// Streckenblatt als PNG teilen
  Future<void> _shareStreckenblatt(AgeEstimate estimate) async {
    try {
      await StreckenblattService.share(
        context: context,
        estimate: estimate,
        region: _currentPosition != null ? _detectedRegion : null,
        date: _exifDate ?? DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teilen fehlgeschlagen: $e')),
        );
      }
    }
  }

  /// Wildart-Auswahl Button
  /// Scoring-Matrix Card: zeigt die 6 Alters-Merkmale mit 1-5 Pkt Bewertung
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
      // Gams (default) - exakte Backend-Keys
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
                            '-',
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
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: WaidblickColors.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _loadingMessages[_loadingMessageIndex],
                    key: ValueKey(_loadingMessageIndex),
                    style: const TextStyle(
                      color: WaidblickColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bitte warten...',
                  style: TextStyle(
                    fontSize: 13,
                    color: WaidblickColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _loadingMessages.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _loadingMessageIndex ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _loadingMessageIndex
                            ? WaidblickColors.primary
                            : WaidblickColors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
        _buildAnalysisCounterBanner(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAnalysisCounterBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPremiumUser
                ? WaidblickColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPremiumUser ? Icons.all_inclusive : Icons.analytics_outlined,
              size: 15,
              color: _isPremiumUser
                  ? WaidblickColors.primary
                  : const Color(0xFFF5F0E8).withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              _isPremiumUser
                  ? 'Premium: Unbegrenzte Analysen ✓'
                  : '$_analysisCount von 5 Analysen diesen Monat verwendet',
              style: TextStyle(
                fontSize: 12,
                color: _isPremiumUser
                    ? WaidblickColors.primary
                    : const Color(0xFFF5F0E8).withOpacity(0.7),
                fontWeight:
                    _isPremiumUser ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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

          // Erlegerbild-Warning
          if (_erlegerbild && !estimate.isNotGams) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFC107), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF57F17), size: 20),
                        SizedBox(width: 8),
                        Text(
                          '⚠️ Eingeschränkte Analyse',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF57F17),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Liegend/Erlegerbild erkannt. Nur Trophäe auswertbar.\n'
                      'Körpermerkmale nicht sichtbar - Schätzung ungenau.',
                      style: TextStyle(
                          color: Color(0xFF5D4037), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                        'Konfidenz niedrig - bitte weitere Fotos aus anderer Perspektive hinzufügen.',
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

          // Dominante Altersklasse - Waidblick Premium Card
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
                    // Region-Badge anzeigen wenn GPS verfügbar
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: WaidblickColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: WaidblickColors.primary.withOpacity(0.4)),
                          ),
                          child: Text(
                            '📍 $_detectedRegion',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: WaidblickColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    // EXIF-Datum-Hinweis anzeigen wenn vorhanden
                    if (_exifDateHint != null) ...[  
                      const SizedBox(height: 4),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 12,
                                color: WaidblickColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _exifDateHint!,
                              style: const TextStyle(
                                  color: WaidblickColors.primary,
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
                        geschlechtSicherheit: estimate.geschlechtSicherheit,
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

          // Wahrscheinlichkeits-Balken - nur anzeigen wenn Schalenwild erkannt
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _shareStreckenblatt(estimate),
            icon: const Icon(Icons.share, color: WaidblickColors.primary),
            label: const Text(
              'Streckenblatt teilen',
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


