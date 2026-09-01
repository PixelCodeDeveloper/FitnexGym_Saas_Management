import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors (shared) ──
  static const Color primary     = Color(0xFF00C4A0); // Electric teal
  static const Color primaryDark = Color(0xFF009E82);
  static const Color primaryLight= Color(0xFF33D4B5);
  static const Color accent      = Color(0xFFFF6B2C); // Vibrant orange

  // ── Backward-compatibility aliases (for old screens — light palette values) ──
  static const Color background    = Color(0xFFF1F5F9);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceAlt    = Color(0xFFF8FAFC);
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);
  static const Color divider       = Color(0xFFE2E8F0);
  static const Color border        = Color(0xFFCBD5E1);


  // ── Semantic ──
  static const Color success   = Color(0xFF22C55E);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error     = Color(0xFFEF4444);
  static const Color errorBg   = Color(0xFFFEE2E2);

  // ── Dark Palette ──
  static const Color darkBg          = Color(0xFF0A0F1E);
  static const Color darkSurface     = Color(0xFF131929);
  static const Color darkSurfaceAlt  = Color(0xFF1A2236);
  static const Color darkCard        = Color(0xFF1E293B);
  static const Color darkBorder      = Color(0xFF2A3547);
  static const Color darkDivider     = Color(0xFF1E2D40);
  static const Color darkTextPrimary = Color(0xFFF0F6FF);
  static const Color darkTextSecondary = Color(0xFF8896B3);
  static const Color darkTextMuted   = Color(0xFF4A5975);

  // ── Light Palette ──
  static const Color lightBg          = Color(0xFFF1F5F9);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt  = Color(0xFFF8FAFC);
  static const Color lightBorder      = Color(0xFFCBD5E1);
  static const Color lightDivider     = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted   = Color(0xFF94A3B8);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C4A0), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B2C), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A2236), Color(0xFF131929)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glass decoration helper ──
  static BoxDecoration glassCard({bool isDark = true}) => BoxDecoration(
    color: isDark
        ? const Color(0xFF1E293B)
        : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark ? const Color(0xFF2A3547) : const Color(0xFFE2E8F0),
      width: 1,
    ),
  );

  // ── Neon glow box shadows ──
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ─────────────────── DARK THEME ───────────────────
  static ThemeData get darkTheme {
    final base = _buildTextTheme(isDark: true);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: darkSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: base.titleLarge?.copyWith(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
        scrimColor: Colors.black54,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkTextSecondary,
        textColor: darkTextPrimary,
      ),
      dividerTheme: const DividerThemeData(color: darkDivider, thickness: 1, space: 0),
      inputDecorationTheme: _inputTheme(isDark: true),
      elevatedButtonTheme: _elevatedBtnTheme(),
      outlinedButtonTheme: _outlinedBtnTheme(isDark: true),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceAlt,
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : darkTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.3) : darkBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: GoogleFonts.poppins(color: darkTextPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: GoogleFonts.poppins(color: darkTextSecondary, fontSize: 14),
      ),
    );
  }

  // ─────────────────── LIGHT THEME ───────────────────
  static ThemeData get lightTheme {
    final base = _buildTextTheme(isDark: false);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: base.titleLarge?.copyWith(color: lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightDivider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: lightSurface,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: lightTextSecondary,
        textColor: lightTextPrimary,
      ),
      dividerTheme: const DividerThemeData(color: lightDivider, thickness: 1, space: 0),
      inputDecorationTheme: _inputTheme(isDark: false),
      elevatedButtonTheme: _elevatedBtnTheme(),
      outlinedButtonTheme: _outlinedBtnTheme(isDark: false),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceAlt,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: lightDivider),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : lightTextMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.25) : lightBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightTextPrimary,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: GoogleFonts.poppins(color: lightTextSecondary, fontSize: 14),
      ),
    );
  }

  // ── Shared helpers ──
  static TextTheme _buildTextTheme({required bool isDark}) {
    final txt  = isDark ? darkTextPrimary   : lightTextPrimary;
    final txt2 = isDark ? darkTextSecondary : lightTextSecondary;
    final muted= isDark ? darkTextMuted     : lightTextMuted;
    return TextTheme(
      displayLarge:  GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.8),
      headlineLarge: GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w700, fontSize: 26, letterSpacing: -0.5),
      headlineMedium:GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.3),
      titleLarge:    GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium:   GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall:    GoogleFonts.poppins(color: txt,  fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge:     GoogleFonts.poppins(color: txt,  fontSize: 15, height: 1.5),
      bodyMedium:    GoogleFonts.poppins(color: txt2, fontSize: 14, height: 1.4),
      bodySmall:     GoogleFonts.poppins(color: muted, fontSize: 12),
      labelLarge:    GoogleFonts.poppins(color: txt,  fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium:   GoogleFonts.poppins(color: txt2, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:    GoogleFonts.poppins(color: muted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  static InputDecorationTheme _inputTheme({required bool isDark}) {
    final border = isDark ? darkBorder : lightBorder;
    final surface = isDark ? darkSurfaceAlt : lightSurfaceAlt;
    final txt = isDark ? darkTextPrimary : lightTextPrimary;
    final muted = isDark ? darkTextSecondary : lightTextSecondary;
    return InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(color: muted, fontSize: 14),
      floatingLabelStyle: GoogleFonts.poppins(color: txt, fontSize: 13, fontWeight: FontWeight.w600),
      hintStyle: GoogleFonts.poppins(color: muted, fontSize: 14),
      prefixIconColor: muted,
      suffixIconColor: muted,
      errorStyle: GoogleFonts.poppins(color: error, fontSize: 11),
    );
  }

  static ElevatedButtonThemeData _elevatedBtnTheme() => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );

  static OutlinedButtonThemeData _outlinedBtnTheme({required bool isDark}) => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primary,
      side: const BorderSide(color: primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}
