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
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
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

  // --- THÈME CLAIR (Monochrome Sharp) ---
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF09090B), // Zinc 950 (Noir profond)
        onPrimary: Color(0xFFFAFAFA), // Zinc 50
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF09090B),
        surfaceContainerHighest: Color(
          0xFFE4E4E7,
        ), // Zinc 200 (Bordures subtiles)
        onSurfaceVariant: Color(0xFF71717A), // Zinc 500 (Texte secondaire)
        secondary: Color(0xFF2563EB), // Blue 600 (Accent tech)
        error: Color(0xFFDC2626),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F4F5), // Zinc 100
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F4F5),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  // --- THÈME SOMBRE (Monochrome Sharp) ---
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFAFAFA), // Zinc 50 (Blanc éclatant)
        onPrimary: Color(0xFF09090B), // Zinc 950
        surface: Color(0xFF18181B), // Zinc 900
        onSurface: Color(0xFFFAFAFA),
        surfaceContainerHighest: Color(0xFF27272A), // Zinc 800
        onSurfaceVariant: Color(0xFFA1A1AA), // Zinc 400
        secondary: Color(0xFF3B82F6), // Blue 500
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(
        0xFF09090B,
      ), // Zinc 950 (Fond très sombre)
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF09090B),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
