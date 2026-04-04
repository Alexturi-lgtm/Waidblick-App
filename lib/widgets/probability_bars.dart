import 'package:flutter/material.dart';
import '../models/age_estimate.dart';
import '../theme/app_theme.dart';

/// Zeigt Alters- und Geschlechtsschätzung in drei Sektionen:
/// 1. Hauptergebnis-Karte
/// 2. Gaußsche Alterskurve (0–20 Jahre)
/// 3. Geschlechts-Balken
class ProbabilityBars extends StatelessWidget {
  final AgeEstimate estimate;
  final bool animated;

  const ProbabilityBars({
    super.key,
    required this.estimate,
    this.animated = true,
  });

  /// Geschlecht als lesbaren String
  static String _sexLabel(double pBock, double pGeis, double pUnsicher, String geschlechtSicherheit) {
    // Geschlecht unbestimmbar: Sicherheit niedrig oder alle Werte ähnlich (~33%)
    final maxProb = [pBock, pGeis, pUnsicher].reduce((a, b) => a > b ? a : b);
    if (geschlechtSicherheit == 'niedrig' || maxProb < 0.45) return 'Geschlecht unbekannt';
    if (pUnsicher > 0.5) return 'Unbekannt';
    if (pBock > pGeis) return 'Männlich (Bock)';
    return 'Weiblich (Geiß)';
  }

  static double _dominantSexProb(double pBock, double pGeis, double pUnsicher, String geschlechtSicherheit) {
    final maxProb = [pBock, pGeis, pUnsicher].reduce((a, b) => a > b ? a : b);
    if (geschlechtSicherheit == 'niedrig' || maxProb < 0.45) return maxProb;
    if (pUnsicher > 0.5) return pUnsicher;
    return pBock > pGeis ? pBock : pGeis;
  }

  /// Amber-Farbverlauf für Waidblick-Theme
  static Color _colorForAge(int age) {
    return WaidblickColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    // ── Hauptergebnis ──────────────────────────────────────────────
    final domProb = estimate.dominantProbability;
    final sexLabel = _sexLabel(
        estimate.pBock, estimate.pGeis, estimate.pUnsicher, estimate.geschlechtSicherheit);
    final sexProb = _dominantSexProb(
        estimate.pBock, estimate.pGeis, estimate.pUnsicher, estimate.geschlechtSicherheit);
    final meanAge = estimate.meanAge;
    final stdDev = estimate.stdDev;
    final meanAgeRounded = meanAge.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── SEKTION 1: Hauptkarte — Waidblick Amber ──────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WaidblickColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: const BorderSide(
                  color: WaidblickColors.primary, width: 4),
              top: const BorderSide(
                  color: WaidblickColors.border, width: 1),
              right: const BorderSide(
                  color: WaidblickColors.border, width: 1),
              bottom: const BorderSide(
                  color: WaidblickColors.border, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tierart + Geschlecht in Amber
              Row(
                children: [
                  const Icon(Icons.pets,
                      color: WaidblickColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Gams, $sexLabel',
                    style: const TextStyle(
                      color: WaidblickColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  // Geschlecht-Sicherheit Badge
                  Builder(builder: (context) {
                    final maxP = [estimate.pBock, estimate.pGeis, estimate.pUnsicher].reduce((a, b) => a > b ? a : b);
                    final isUnknown = estimate.geschlechtSicherheit == 'niedrig' || maxP < 0.45;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: WaidblickColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isUnknown ? '?' : '${(sexProb * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WaidblickColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),

              // Alter + Hauptwahrscheinlichkeit
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alter',
                          style: TextStyle(
                              color: WaidblickColors.textSecondary,
                              fontSize: 11)),
                      Text(
                        '~$meanAgeRounded Jahre (${estimate.confidenceInterval})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: WaidblickColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Altersklasse-Match',
                          style: TextStyle(
                              color: WaidblickColors.textSecondary,
                              fontSize: 11)),
                      Text(
                        '${(domProb * 100).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: WaidblickColors.primary,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Haupt-Balken in Amber
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: animated
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: domProb),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 16,
                          backgroundColor: WaidblickColors.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation(
                              WaidblickColors.primary),
                        ),
                      )
                    : LinearProgressIndicator(
                        value: domProb,
                        minHeight: 16,
                        backgroundColor: WaidblickColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation(
                            WaidblickColors.primary),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── SEKTION 2: Gaußsche Alterskurve — Waidblick ───────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: WaidblickColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WaidblickColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Überschrift
              Row(
                children: [
                  const Icon(Icons.bar_chart,
                      size: 16, color: WaidblickColors.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'Altersverteilung',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: WaidblickColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Schätzung: ~$meanAgeRounded Jahre ± ${stdDev.round()} Jahre',
                    style: const TextStyle(
                      color: WaidblickColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Balkendiagramm 0–20 Jahre
              _GaussianBarChart(
                estimate: estimate,
                animated: animated,
                colorForAge: _colorForAge,
              ),

              const SizedBox(height: 4),
              // X-Achse Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in ['0', '5', '10', '15', '20'])
                    Text(
                      label,
                      style: const TextStyle(
                        color: WaidblickColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              const Center(
                child: Text(
                  'Jahre',
                  style: TextStyle(
                    color: WaidblickColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── SEKTION 3: Geschlecht-Balken ──────────────────────────
        const Text(
          'Geschlecht',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: WaidblickColors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _sexBar(context, 'Männlich (Bock)', estimate.pBock,
            const Color(0xFF4A9EFF)),
        _sexBar(context, 'Weiblich (Geiß)', estimate.pGeis,
            const Color(0xFFE879A0)),
        _sexBar(context, 'Unbekannt', estimate.pUnsicher,
            WaidblickColors.textSecondary),
      ],
    );
  }

  Widget _sexBar(
      BuildContext context, String label, double prob, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: WaidblickColors.textSecondary),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: animated
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: prob),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: WaidblickColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    )
                  : LinearProgressIndicator(
                      value: prob,
                      minHeight: 8,
                      backgroundColor: WaidblickColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(prob * 100).round()}%',
              style: const TextStyle(
                  fontSize: 12, color: WaidblickColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gaußsches Balkendiagramm mit Animation
class _GaussianBarChart extends StatelessWidget {
  final AgeEstimate estimate;
  final bool animated;
  final Color Function(int age) colorForAge;

  const _GaussianBarChart({
    required this.estimate,
    required this.animated,
    required this.colorForAge,
  });

  @override
  Widget build(BuildContext context) {
    final bars = estimate.gaussianBars;
    final meanAgeRounded = estimate.meanAge.round().clamp(0, 20);
    const maxBarHeight = 120.0;
    final maxVal = bars.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 140, // Container-Höhe für sichtbare Kurve
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(21, (year) {
          final height = maxVal > 0 ? (bars[year] / maxVal) * maxBarHeight : 0.0;
          final isMean = year == meanAgeRounded;
          final color = colorForAge(year);

          return Expanded(
            child: animated
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: height),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, h, __) => _BarColumn(
                      height: h,
                      isMean: isMean,
                      year: year,
                      color: color,
                      maxHeight: maxBarHeight,
                    ),
                  )
                : _BarColumn(
                    height: height,
                    isMean: isMean,
                    year: year,
                    color: color,
                    maxHeight: maxBarHeight,
                  ),
          );
        }),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final double height;
  final bool isMean;
  final int year;
  final Color color;
  final double maxHeight;

  const _BarColumn({
    required this.height,
    required this.isMean,
    required this.year,
    required this.color,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Jahr-Label unter jedem Balken (klein, weiß)
        Text(
          year % 5 == 0 || isMean ? '$year' : '',
          style: TextStyle(
            fontSize: 8,
            fontWeight: isMean ? FontWeight.bold : FontWeight.normal,
            color: isMean
                ? WaidblickColors.primary
                : WaidblickColors.textSecondary,
          ),
        ),
        Container(
          height: height.clamp(1.0, maxHeight),
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: isMean
                ? WaidblickColors.primary
                : WaidblickColors.primary.withOpacity(0.4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
            boxShadow: isMean
                ? [
                    BoxShadow(
                        color: WaidblickColors.primary.withOpacity(0.5),
                        blurRadius: 4)
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}
