import 'package:flutter/material.dart';

abstract final class AscendColors {
  static const background = Color(0xFF0B0C0D);
  static const surface = Color(0xFF151719);
  static const surfaceRaised = Color(0xFF1D2022);
  static const border = Color(0xFF303437);
  static const textPrimary = Color(0xFFF4F2EC);
  static const textSecondary = Color(0xFFA3A6A5);
  static const gold = Color(0xFFC5A45D);
  static const error = Color(0xFFE47B73);
}

abstract final class AscendSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AscendRadii {
  static const card = 18.0;
  static const control = 12.0;
  static const pill = 999.0;
}

abstract final class AscendTheme {
  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: AscendColors.gold,
      onPrimary: AscendColors.background,
      secondary: AscendColors.gold,
      surface: AscendColors.surface,
      onSurface: AscendColors.textPrimary,
      error: AscendColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AscendColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AscendColors.background,
        foregroundColor: AscendColors.textPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AscendColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AscendRadii.card),
          side: const BorderSide(color: AscendColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AscendColors.surface,
        indicatorColor: AscendColors.gold.withValues(alpha: 0.16),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AscendColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AscendRadii.control),
          borderSide: const BorderSide(color: AscendColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AscendRadii.control),
          borderSide: const BorderSide(color: AscendColors.border),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AscendColors.textPrimary,
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: AscendColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AscendColors.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: AscendColors.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}
