import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/age_estimate.dart';
import '../widgets/streckenblatt_card.dart';

/// Erstellt ein PNG-Streckenblatt und teilt es via System Share-Sheet.
class StreckenblattService {
  /// Rendert [StreckenblattCard] via Overlay, captured as PNG, teilt via Share-Sheet.
  static Future<void> share({
    required BuildContext context,
    required AgeEstimate estimate,
    String? region,
    DateTime? date,
  }) async {
    final repaintKey = GlobalKey();

    // Insert offstage overlay to render the widget into the real render tree
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000, // offscreen
        top: 0,
        child: RepaintBoundary(
          key: repaintKey,
          child: Material(
            color: Colors.transparent,
            child: StreckenblattCard(
              estimate: estimate,
              region: region,
              date: date,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // Wait for two frames to ensure full layout/paint
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    Uint8List? pngBytes;
    try {
      final boundary =
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        pngBytes = byteData?.buffer.asUint8List();
      }
    } finally {
      entry.remove();
    }

    if (pngBytes == null) {
      throw Exception('Streckenblatt konnte nicht gerendert werden.');
    }

    // Save to temp directory
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'waidblick_streckenblatt_'
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pngBytes);

    // Share via system share sheet
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'WAIDBLICK Streckenblatt',
      text: 'KI-Analyse: ${estimate.wildart} | ~${estimate.meanAge.round()} Jahre\n'
          '⚠️ KI-gestützte Einschätzung — kein Ersatz für jagdliche Erfahrung',
    );
  }
}
