import 'package:flutter/material.dart';
import '../services/photo_quality_service.dart';

/// Kompakter Qualitäts-Indikator mit ausklappbaren Details.
class PhotoQualityIndicator extends StatefulWidget {
  final PhotoQualityResult result;

  const PhotoQualityIndicator({super.key, required this.result});

  @override
  State<PhotoQualityIndicator> createState() => _PhotoQualityIndicatorState();
}

class _PhotoQualityIndicatorState extends State<PhotoQualityIndicator> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: result.verdictColor.withValues(alpha: 0.5)),
      ),
      color: result.verdictColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Kompakt-Zeile: Sterne + Verdict + Score ──────────────────────
            Row(
              children: [
                _StarRow(stars: result.stars, color: result.verdictColor),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: result.verdictColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.verdict,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: result.verdictColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${result.scorePercent}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: result.verdictColor,
                  ),
                ),
                const Spacer(),
                // Toggle-Button
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Text(
                        _expanded ? 'Details' : 'Details',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Tipp ────────────────────────────────────────────────────────
            if (result.tips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result.tips.first,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            // ── Expandable Detail-Scores ─────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: _expanded ? null : 0,
              child: _expanded
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        _ScoreBar(
                          label: '📸 Schärfe',
                          value: result.sharpnessScore,
                          color: result.verdictColor,
                        ),
                        const SizedBox(height: 6),
                        _ScoreBar(
                          label: '🔍 Tier-Größe',
                          value: result.sizeScore,
                          color: result.verdictColor,
                        ),
                        const SizedBox(height: 6),
                        _ScoreBar(
                          label: '☀️ Helligkeit',
                          value: result.brightnessScore,
                          color: result.verdictColor,
                        ),
                        const SizedBox(height: 6),
                        _ScoreBar(
                          label: '📐 Perspektive',
                          value: result.angleScore,
                          color: result.verdictColor,
                        ),
                        // Alle Tipps anzeigen
                        if (result.tips.length > 1) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ...result.tips
                              .skip(1)
                              .map(
                                (tip) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    tip,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color:
                                                Colors.grey.shade700),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeigt 1–5 Sterne
class _StarRow extends StatelessWidget {
  final int stars;
  final Color color;

  const _StarRow({required this.stars, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i < stars ? color : Colors.grey.shade400,
        );
      }),
    );
  }
}

/// Einzelner Score-Balken mit Label und Prozent
class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation(color),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}
