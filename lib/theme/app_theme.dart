import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Clean White Theme with Warm Tea Amber Accents
  static const Color whiteBg = Colors.white;
  static const Color cardBg = Colors.white;
  static const Color cardSurface = Color(0xFFF8F6F1);
  static const Color primaryAmber = Color(0xFFD48D3B);
  static const Color primaryLightAmber = Color(0xFFECA752);
  static const Color matchaGreen = Color(0xFF437A52);
  static const Color textPrimary = Color(0xFF1E140E);
  static const Color textSecondary = Color(0xFF6E5F54);
  static const Color dividerColor = Color(0xFFE8E2D9);
  static const Color accentRed = Color(0xFFD94848);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: whiteBg,
      primaryColor: primaryAmber,
      colorScheme: const ColorScheme.light(
        primary: primaryAmber,
        secondary: primaryLightAmber,
        surface: cardBg,
        error: accentRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.copyWith(
              bodyLarge: const TextStyle(color: textPrimary),
              bodyMedium: const TextStyle(color: textSecondary),
              titleLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: whiteBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: whiteBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAmber, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}
