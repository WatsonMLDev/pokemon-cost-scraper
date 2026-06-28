import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Halo HUD Color Palette ─────────────────────────────────────────────────
class HaloColors {
  HaloColors._();

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A2E);
  static const Color card = Color(0xFF16162A);

  static const Color primary = Color(0xFF00BFFF); // deep sky blue
  static const Color secondary = Color(0xFF00FF99); // mint green
  static const Color gold = Color(0xFFFFD700); // gold — for prices
  static const Color warn = Color(0xFFFF6B35); // warm orange
  static const Color danger = Color(0xFFFF3C3C); // red

  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textDim = Color(0xFF888888);
  static const Color divider = Color(0xFF1A2A3A);
  static const Color border = Color(0xFF2A2A3E);
}

// ─── Theme Builder ──────────────────────────────────────────────────────────
ThemeData buildHaloTheme() {
  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HaloColors.background,
    colorScheme: const ColorScheme.dark(
      primary: HaloColors.primary,
      secondary: HaloColors.secondary,
      tertiary: HaloColors.gold,
      surface: HaloColors.surface,
      error: HaloColors.danger,
      onPrimary: HaloColors.background,
      onSecondary: HaloColors.background,
      onSurface: HaloColors.textPrimary,
      onError: Colors.white,
    ),
    textTheme: textTheme,

    // ── AppBar ──
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: HaloColors.textPrimary,
        letterSpacing: 1.2,
      ),
      iconTheme: const IconThemeData(color: HaloColors.primary),
    ),

    // ── Card ──
    cardTheme: CardThemeData(
      color: HaloColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HaloColors.border, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    // ── Elevated Button ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HaloColors.primary.withValues(alpha: 0.15),
        foregroundColor: HaloColors.primary,
        side: const BorderSide(color: HaloColors.primary, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    ),

    // ── Divider ──
    dividerTheme: const DividerThemeData(
      color: HaloColors.divider,
      thickness: 0.5,
      space: 0,
    ),

    // ── SnackBar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: HaloColors.surfaceLight,
      contentTextStyle: GoogleFonts.inter(color: HaloColors.textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Input Decoration ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HaloColors.surface.withValues(alpha: 0.5),
      labelStyle: GoogleFonts.inter(color: HaloColors.textDim, fontSize: 14),
      hintStyle: GoogleFonts.inter(color: HaloColors.textDim, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: HaloColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: HaloColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: HaloColors.primary),
      ),
    ),

    // ── List Tile ──
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: HaloColors.textPrimary,
      iconColor: HaloColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ── Expansion Tile ──
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: HaloColors.primary,
      collapsedIconColor: HaloColors.textDim,
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

// ─── Text Theme ─────────────────────────────────────────────────────────────
TextTheme _buildTextTheme() {
  return TextTheme(
    // Display — Rajdhani (tactical headers)
    displayLarge: GoogleFonts.rajdhani(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: HaloColors.textPrimary,
      letterSpacing: 1.5,
    ),
    displayMedium: GoogleFonts.rajdhani(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
      letterSpacing: 1.2,
    ),
    displaySmall: GoogleFonts.rajdhani(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
      letterSpacing: 1.0,
    ),

    // Headline — Rajdhani
    headlineLarge: GoogleFonts.rajdhani(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.rajdhani(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.rajdhani(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
    ),

    // Title — Rajdhani
    titleLarge: GoogleFonts.rajdhani(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: HaloColors.textPrimary,
      letterSpacing: 0.8,
    ),
    titleMedium: GoogleFonts.rajdhani(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: HaloColors.textPrimary,
    ),
    titleSmall: GoogleFonts.rajdhani(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: HaloColors.textSecondary,
    ),

    // Body — Inter (clean readability)
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: HaloColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: HaloColors.textSecondary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: HaloColors.textDim,
    ),

    // Label — Inter
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: HaloColors.textPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: HaloColors.textSecondary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: HaloColors.textDim,
      letterSpacing: 0.5,
    ),
  );
}
