// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w900,
        fontSize: 57,
        letterSpacing: -1.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w900,
        fontSize: 32,
        letterSpacing: -1.0,
      ),
      headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        letterSpacing: -0.5,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        letterSpacing: 0.2,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
    );
  }

  // --- THÈME CLAIR (Dominante Bleue) ---
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB), // Bleu vibrant (Action/Focus)
        onPrimary: Color(0xFFFFFFFF), // Blanc pur
        surface: Color(0xFFFFFFFF), // Blanc pour les cartes
        onSurface: Color(0xFF0F172A), // Slate 900 (Texte principal)
        surfaceContainerHighest: Color(
          0xFFE2E8F0,
        ), // Slate 200 (Bordures/Fonds subtils)
        onSurfaceVariant: Color(0xFF64748B), // Slate 500 (Texte secondaire)
        secondary: Color(0xFF3B82F6), // Bleu plus clair
        error: Color(0xFFEF4444), // Rouge erreur standard
      ),
      scaffoldBackgroundColor: const Color(
        0xFFF8FAFC,
      ), // Slate 50 (Fond très clair, doux)
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
    );
  }

  // --- THÈME SOMBRE (Dominante Rouge) ---
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE11D48), // Rouge intense (Puissance/Énergie)
        onPrimary: Color(0xFFFFFFFF), // Blanc pur
        surface: Color(0xFF18181B), // Zinc 900 (Cartes sombres)
        onSurface: Color(0xFFF8FAFC), // Blanc cassé (Texte principal)
        surfaceContainerHighest: Color(0xFF27272A), // Zinc 800 (Bordures)
        onSurfaceVariant: Color(0xFFA1A1AA), // Zinc 400 (Texte secondaire)
        secondary: Color(0xFFF43F5E), // Rouge vibrant
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(
        0xFF09090B,
      ), // Zinc 950 (Fond très noir)
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF09090B),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      ),
    );
  }
}
