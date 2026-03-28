import 'package:flutter/material.dart';
import '../models/age_estimate.dart';

/// Wiederverwendbares Badge-Widget für Altersklassen.
/// Farbkodierung: kitz=hellgrün, jung=grün, mittel=gelb, alt=orange, sehrAlt=rot
class AgeClassBadge extends StatelessWidget {
  final AgeClass ageClass;
  final bool showIcon;
  final double fontSize;

  const AgeClassBadge({
    super.key,
    required this.ageClass,
    this.showIcon = true,
    this.fontSize = 13.0,
  });

  static Color colorFor(AgeClass ac) {
    switch (ac) {
      case AgeClass.kitz:
        return const Color(0xFF8BC34A); // hellgrün
      case AgeClass.jung:
        return const Color(0xFF4CAF50); // grün
      case AgeClass.mittel:
        return const Color(0xFFFFC107); // gelb
      case AgeClass.alt:
        return const Color(0xFFFF9800); // orange
      case AgeClass.sehrAlt:
        return const Color(0xFFF44336); // rot
    }
  }

  static IconData iconFor(AgeClass ac) {
    switch (ac) {
      case AgeClass.kitz:
        return Icons.child_care;
      case AgeClass.jung:
        return Icons.directions_run;
      case AgeClass.mittel:
        return Icons.person;
      case AgeClass.alt:
        return Icons.elderly;
      case AgeClass.sehrAlt:
        return Icons.elderly_woman;
    }
  }

  static String labelFor(AgeClass ac) {
    switch (ac) {
      case AgeClass.kitz:
        return 'Kitz';
      case AgeClass.jung:
        return 'Jährling';
      case AgeClass.mittel:
        return 'Mittelalter';
      case AgeClass.alt:
        return 'Alt';
      case AgeClass.sehrAlt:
        return 'Sehr alt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(ageClass);
    final label = labelFor(ageClass);
    final icon = iconFor(ageClass);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
