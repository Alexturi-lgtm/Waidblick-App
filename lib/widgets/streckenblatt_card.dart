import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/age_estimate.dart';
import '../theme/app_theme.dart';

/// Streckenblatt-Widget — wird via RepaintBoundary als PNG gespeichert und geteilt.
class StreckenblattCard extends StatelessWidget {
  final AgeEstimate estimate;
  final String? region;
  final DateTime? date;

  const StreckenblattCard({
    super.key,
    required this.estimate,
    this.region,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(date ?? DateTime.now());
    final confPct = (estimate.confidence * 100).round();
    final wildartLabel = _wildartLabel(estimate.wildart);
    final geschlecht = _geschlechtLabel(estimate);
    final top3Merkmale = estimate.merkmale.take(3).toList();

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFc9a84c), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFc9a84c).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0A1A0F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFc9a84c), width: 1.5),
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Color(0xFFc9a84c),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'WAIDBLICK',
                      style: TextStyle(
                        color: Color(0xFFc9a84c),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'STRECKENBLATT',
                      style: TextStyle(
                        color: Color(0xFFF5F0E8),
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFFF5F0E8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wildart + Geschlecht Row
                Row(
                  children: [
                    _infoChip(wildartLabel, const Color(0xFF1B5E20)),
                    const SizedBox(width: 8),
                    _infoChip(geschlecht, const Color(0xFF1A3A5C)),
                    if (region != null && region!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _infoChip('📍 $region', const Color(0xFF2A2A2A)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Big age display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '~${estimate.meanAge.round()}',
                      style: const TextStyle(
                        color: Color(0xFFc9a84c),
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jahre',
                          style: TextStyle(
                            color: WaidblickColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          estimate.confidenceInterval,
                          style: const TextStyle(
                            color: WaidblickColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Confidence bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Konfidenz',
                          style: TextStyle(
                            color: WaidblickColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '$confPct%',
                          style: const TextStyle(
                            color: Color(0xFFc9a84c),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: estimate.confidence,
                        minHeight: 8,
                        backgroundColor: WaidblickColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFc9a84c)),
                      ),
                    ),
                  ],
                ),

                // Top-3 Merkmale
                if (top3Merkmale.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Entscheidende Merkmale',
                    style: TextStyle(
                      color: WaidblickColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...top3Merkmale.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFc9a84c)
                                    .withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFc9a84c)
                                        .withOpacity(0.5)),
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFFc9a84c),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  color: WaidblickColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                // KI Begründung (kurz)
                if (estimate.begruendung.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: WaidblickColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: WaidblickColors.border, width: 1),
                    ),
                    child: Text(
                      estimate.begruendung.length > 200
                          ? '${estimate.begruendung.substring(0, 200)}…'
                          : estimate.begruendung,
                      style: const TextStyle(
                        color: WaidblickColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: WaidblickColors.border, height: 1),
                const SizedBox(height: 10),

                // Disclaimer
                const Text(
                  '⚠️ KI-gestützte Einschätzung — kein Ersatz für jagdliche Erfahrung',
                  style: TextStyle(
                    color: WaidblickColors.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: bgColor.withOpacity(0.8).withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF5F0E8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _wildartLabel(String wildart) {
    switch (wildart) {
      case 'rehwild':
        return '🦌 Rehwild';
      case 'rotwild':
        return '🦌 Rotwild';
      case 'gams':
        return '🐐 Gams';
      default:
        return '🦌 Wild';
    }
  }

  String _geschlechtLabel(AgeEstimate est) {
    if (est.pBock > 0.6) return '♂ Bock';
    if (est.pGeis > 0.6) return '♀ Geis';
    return '⚥ Unbestimmt';
  }
}
