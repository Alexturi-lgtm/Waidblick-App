import 'package:flutter/material.dart';

class WaidblickColors {
  static const Color background = Color(0xFF141414);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color primary = Color(0xFFF5A623);
  static const Color primaryDark = Color(0xFFC17D0E);
  static const Color success = Color(0xFF1E5631);
  static const Color successLight = Color(0xFF2D7A47);
  static const Color danger = Color(0xFFB91C1C);
  static const Color warning = Color(0xFFD97706);
  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color border = Color(0xFF333333);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: WaidblickColors.background,
        colorScheme: const ColorScheme.dark(
          primary: WaidblickColors.primary,
          secondary: WaidblickColors.success,
          surface: WaidblickColors.surface,
          onPrimary: Colors.black,
          onSurface: WaidblickColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: WaidblickColors.background,
          foregroundColor: WaidblickColors.textPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: WaidblickColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        cardTheme: CardTheme(
          color: WaidblickColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: WaidblickColors.border, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: WaidblickColors.primary,
            foregroundColor: Colors.black,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: WaidblickColors.surfaceVariant,
          labelStyle: const TextStyle(
              color: WaidblickColors.textSecondary, fontSize: 11),
          side: const BorderSide(color: WaidblickColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        dividerTheme: const DividerThemeData(color: WaidblickColors.border),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: WaidblickColors.textPrimary,
              fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(
              color: WaidblickColors.textPrimary,
              fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              color: WaidblickColors.textPrimary,
              fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              color: WaidblickColors.textPrimary,
              fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: WaidblickColors.textPrimary),
          bodyMedium: TextStyle(color: WaidblickColors.textSecondary),
          labelLarge: TextStyle(
              color: WaidblickColors.primary, fontWeight: FontWeight.w700),
        ),
      );
}
