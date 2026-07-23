import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Paleta Premium ────────────────────────────────────────
  static const Color background    = Color(0xFF080808);
  static const Color surface       = Color(0xFF111111);
  static const Color surfaceAlt    = Color(0xFF1A1A1A);
  static const Color card          = Color(0xFF141414);
  static const Color cardBorder    = Color(0xFF242424);

  static const Color gold          = Color(0xFFD4A843);
  static const Color goldLight     = Color(0xFFE8C06A);
  static const Color goldDark      = Color(0xFFA07830);

  static const Color textPrimary   = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF8A8580);
  static const Color textMuted     = Color(0xFF4A4540);

  static const Color success       = Color(0xFF2ECC71);
  static const Color warning       = Color(0xFFF39C12);
  static const Color error         = Color(0xFFE74C3C);
  static const Color info          = Color(0xFF3498DB);

  // Status de obra
  static const Color statusPlanning   = Color(0xFF3498DB);
  static const Color statusActive     = Color(0xFFD4A843);
  static const Color statusPaused     = Color(0xFF8A8580);
  static const Color statusDone       = Color(0xFF2ECC71);
  static const Color statusCancelled  = Color(0xFFE74C3C);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Color(0xFF080808),
        secondary: goldLight,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ),
      textTheme: GoogleFonts.syneTextTheme().copyWith(
        displayLarge: GoogleFonts.syne(
          fontSize: 48, fontWeight: FontWeight.w800,
          color: textPrimary, letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.syne(
          fontSize: 36, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -1.0,
        ),
        headlineLarge: GoogleFonts.syne(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.syne(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.syne(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.syne(
          fontSize: 15, fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, color: textSecondary,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, color: textMuted,
        ),
        labelLarge: GoogleFonts.syne(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.syne(
            fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        labelStyle: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder, thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: gold,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'planejamento': return statusPlanning;
      case 'em_andamento': return statusActive;
      case 'pausada':      return statusPaused;
      case 'concluida':    return statusDone;
      case 'cancelada':    return statusCancelled;
      default:             return textMuted;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'planejamento': return 'Planejamento';
      case 'em_andamento': return 'Em Andamento';
      case 'pausada':      return 'Pausada';
      case 'concluida':    return 'Concluída';
      case 'cancelada':    return 'Cancelada';
      default:             return status;
    }
  }

  // Gradiente dourado
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, gold, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradiente card premium
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1810), Color(0xFF141410)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
