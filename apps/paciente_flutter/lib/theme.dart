import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data.dart';

/// Med Box tokens, shared with the web panel (apps/panel_web/src/app/globals.css).
abstract final class MedColors {
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF5B6475);
  static const line = Color(0xFFE5E9F0);
  static const brand = Color(0xFF2457D6);
  static const brandDeep = Color(0xFF1A3FA3);
  static const brandSoft = Color(0xFFEEF3FF);
  static const warnSoft = Color(0xFFFFFBEB);
  static const warn = Color(0xFF8A5300);
  static const danger = Color(0xFFD93D3D);

  // Legacy names still used by older screens.
  static const primary = ink;
  static const secondary = Color(0xFF9ED9CF);
  static const accent = brand;
  static const background = Color(0xFFF5F7FA);
}

/// Specialty accents: identical to the panel (`barColors` in specialty-workspace.tsx).
extension SpecialtyColors on Specialty {
  Color get accent => switch (this) {
    Specialty.physio => const Color(0xFF0F766E),
    Specialty.skin => const Color(0xFFBE3A5A),
    Specialty.eyes => const Color(0xFF2457D6),
    Specialty.mind => const Color(0xFF6D4AB8),
  };
  Color get accentDeep => switch (this) {
    Specialty.physio => const Color(0xFF0B5E57),
    Specialty.skin => const Color(0xFF9A2C47),
    Specialty.eyes => const Color(0xFF1A3FA3),
    Specialty.mind => const Color(0xFF55388F),
  };
  Color get soft => switch (this) {
    Specialty.physio => const Color(0xFFE8F6F3),
    Specialty.skin => const Color(0xFFFBE7EC),
    Specialty.eyes => const Color(0xFFEEF3FF),
    Specialty.mind => const Color(0xFFF1ECFA),
  };
  Color get faded => switch (this) {
    Specialty.physio => const Color(0xFF9ED9CF),
    Specialty.skin => const Color(0xFFF2BCC9),
    Specialty.eyes => const Color(0xFFB9CBF5),
    Specialty.mind => const Color(0xFFD3C6EF),
  };
}

/// Headings use Manrope; body uses Inter (same pair as the panel).
TextStyle heading(
  double size, {
  Color color = MedColors.ink,
  FontWeight weight = FontWeight.w800,
}) => GoogleFonts.manrope(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: size >= 22 ? -0.4 : 0,
);

ThemeData medTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  final inter = base.textTheme.apply(
    bodyColor: MedColors.ink,
    displayColor: MedColors.ink,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: MedColors.brand).copyWith(
      primary: MedColors.brand,
      secondary: const Color(0xFF0F766E),
      tertiary: MedColors.brand,
      surface: Colors.white,
      onSurface: MedColors.ink,
    ),
    scaffoldBackgroundColor: MedColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: MedColors.background,
      foregroundColor: MedColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: heading(18),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DCE7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: MedColors.ink,
        side: const BorderSide(color: Color(0xFFD5DCE7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => GoogleFonts.inter(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
    ),
    textTheme: inter.copyWith(
      headlineLarge: heading(32),
      headlineSmall: heading(24),
      titleLarge: heading(20, weight: FontWeight.w700),
      titleMedium: heading(16, weight: FontWeight.w700),
      bodyLarge: inter.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
    ),
  );
}
