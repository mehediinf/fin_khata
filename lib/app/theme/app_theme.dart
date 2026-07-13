import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF0B6B53);
  static const ink = Color(0xFF14211D);
  static const canvas = Color(0xFFF4F7F5);

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF17221F),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? canvas
          : const Color(0xFF0E1714),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: .45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
