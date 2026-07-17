import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ink = Color(0xFF1B2A4A);
  static const inkDark = Color(0xFF10192E);
  static const slate = Color(0xFF5B6472);
  static const paper = Color(0xFFFAFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const brass = Color(0xFFB08152);
  static const line = Color(0xFFD8D3C9);
  static const error = Color(0xFFB3261E);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.ink,
        secondary: AppColors.brass,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      textTheme: TextTheme(
        displaySmall: GoogleFonts.fraunces(
          fontSize: 34, fontWeight: FontWeight.w600,
          color: AppColors.ink, letterSpacing: -0.5,
        ),
        headlineSmall: GoogleFonts.fraunces(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: AppColors.inkDark),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.slate),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.slate),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: GoogleFonts.inter(color: AppColors.slate, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: AppColors.brass, fontSize: 13),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.line, width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.brass, width: 1.6),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.line, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brass,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}