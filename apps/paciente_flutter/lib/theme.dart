import 'package:flutter/material.dart';

abstract final class MedColors {
  static const primary = Color(0xFF123A52);
  static const secondary = Color(0xFF76B8B1);
  static const accent = Color(0xFF5EA8D6);
  static const background = Color(0xFFF2F7F8);
}

ThemeData medTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: MedColors.primary).copyWith(
    primary: MedColors.primary,
    secondary: MedColors.secondary,
    tertiary: MedColors.accent,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: MedColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: MedColors.background,
    foregroundColor: MedColors.primary,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD7E4E8)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
      color: MedColors.primary,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: MedColors.primary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: MedColors.primary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: MedColors.primary,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: MedColors.primary),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: MedColors.primary),
  ),
);
