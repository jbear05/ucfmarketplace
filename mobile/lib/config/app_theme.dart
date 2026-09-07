import 'package:flutter/material.dart';

class AppTheme {
  // ── Black & Gold palette ──────────────────────────────────────────────────
  static const Color bgDark        = Color(0xFF0A0A0B); // main scaffold — true black
  static const Color bgCard        = Color(0xFF16151A); // cards, panels, AppBar
  static const Color bgInput       = Color(0xFF1D1B1F); // input fields
  static const Color bgElevated    = Color(0xFF262329); // hover/elevated

  // Brand — gold
  static const Color primary       = Color(0xFFD4AF37); // gold
  static const Color primaryDark   = Color(0xFFB8952E);
  static const Color primaryLight  = Color(0xFF2A230F); // dark gold tint for bg

  // Status
  static const Color error         = Color(0xFFFF6B6B);
  static const Color success       = Color(0xFF34C759);
  static const Color warning       = Color(0xFFFFE66D);
  static const Color accent        = Color(0xFFE8C766); // pale gold accent

  // Text
  static const Color textPrimary   = Color(0xFFF5F1E6);
  static const Color textSecondary = Color(0xFFA8A29E);
  static const Color textMuted     = Color(0xFF71716E);
  static const Color textLight     = Color(0xFF71716E);

  // Borders / dividers
  static const Color border        = Color(0xFF2C2A26);
  static const Color divider       = Color(0xFF2C2A26);
  static const Color surface       = Color(0xFF0A0A0B); // alias for bgDark

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary:   primary,
      secondary: primary,
      surface:   bgCard,
      error:     error,
    ),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: bgDark,

    appBarTheme: const AppBarTheme(
      backgroundColor: bgCard,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        disabledBackgroundColor: bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    ),

    cardTheme: const CardThemeData(
      elevation: 0,
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border),
      ),
    ),

    dividerTheme: const DividerThemeData(color: divider, space: 1),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgCard,
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: bgCard,
      titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter'),
      contentTextStyle: TextStyle(color: textSecondary, fontFamily: 'Inter'),
    ),

    popupMenuTheme: const PopupMenuThemeData(
      color: bgCard,
      textStyle: TextStyle(color: textPrimary, fontFamily: 'Inter'),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: bgElevated,
      contentTextStyle: TextStyle(color: textPrimary, fontFamily: 'Inter'),
    ),
  );
}
