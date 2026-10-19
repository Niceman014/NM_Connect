import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color bg = Color(0xFF0F1419);
  static const Color surface = Color(0xFF1A1F28);
  static const Color primary = Color(0xFF2E7DFF);
  static const Color accent = Color(0xFF00C8A0);
  static const Color danger = Color(0xFFE53935);

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}