import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks light/dark mode and notifies the whole app to rebuild when it
/// changes. AppTheme's color fields are getters that read `isDark` here —
/// that's what lets hundreds of existing `AppTheme.textPrimary`-style
/// references throughout the app stay exactly as they are instead of every
/// call site needing a BuildContext.
class ThemeController extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _key = 'dark_mode';

  bool _isDark = true; // matches the app's original single (dark) theme
  bool get isDark => _isDark;

  Future<void> load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      _isDark = saved == 'true';
      notifyListeners();
    }
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    AppTheme._isDark = value;
    notifyListeners();
    await _storage.write(key: _key, value: value.toString());
  }
}

class AppTheme {
  // Set by ThemeController; AppTheme itself has no BuildContext, so this is
  // the one piece of mutable global state that every color getter reads.
  static bool _isDark = true;

  // ── Black & Gold palette — dark (original) ──────────────────────────────────
  static const Color _bgDarkDark      = Color(0xFF0A0A0B);
  static const Color _bgCardDark      = Color(0xFF16151A);
  static const Color _bgInputDark     = Color(0xFF1D1B1F);
  static const Color _bgElevatedDark  = Color(0xFF262329);
  static const Color _primaryDark_    = Color(0xFFD4AF37);
  static const Color _primaryDarkDark = Color(0xFFB8952E);
  static const Color _primaryLightDark = Color(0xFF2A230F);
  static const Color _errorDark       = Color(0xFFFF6B6B);
  static const Color _successDark     = Color(0xFF34C759);
  static const Color _warningDark     = Color(0xFFFFE66D);
  static const Color _accentDark      = Color(0xFFE8C766);
  static const Color _textPrimaryDark   = Color(0xFFF5F1E6);
  static const Color _textSecondaryDark = Color(0xFFA8A29E);
  static const Color _textMutedDark     = Color(0xFF71716E);
  static const Color _borderDark      = Color(0xFF2C2A26);

  // ── Black & Gold palette — light (new, same brand, not a naive invert) ──────
  static const Color _bgDarkLight      = Color(0xFFFAF9F6);
  static const Color _bgCardLight      = Color(0xFFFFFFFF);
  static const Color _bgInputLight     = Color(0xFFF3F1EC);
  static const Color _bgElevatedLight  = Color(0xFFEDEAE2);
  static const Color _primaryLight_    = Color(0xFFA8790A);
  static const Color _primaryDarkLight = Color(0xFF8F660A);
  static const Color _primaryLightLight = Color(0xFFFBF0D3);
  static const Color _errorLight       = Color(0xFFC5362E);
  static const Color _successLight     = Color(0xFF1F9C4C);
  static const Color _warningLight     = Color(0xFFB07A0A);
  static const Color _accentLight      = Color(0xFFA8790A);
  static const Color _textPrimaryLight   = Color(0xFF1A1815);
  static const Color _textSecondaryLight = Color(0xFF5C574E);
  static const Color _textMutedLight     = Color(0xFF8A8378);
  static const Color _borderLight      = Color(0xFFE4E0D8);

  // ── Public getters — every existing AppTheme.xxx call site is unchanged ─────
  static Color get bgDark        => _isDark ? _bgDarkDark      : _bgDarkLight;
  static Color get bgCard        => _isDark ? _bgCardDark      : _bgCardLight;
  static Color get bgInput       => _isDark ? _bgInputDark     : _bgInputLight;
  static Color get bgElevated    => _isDark ? _bgElevatedDark  : _bgElevatedLight;

  static Color get primary       => _isDark ? _primaryDark_    : _primaryLight_;
  static Color get primaryDark   => _isDark ? _primaryDarkDark : _primaryDarkLight;
  static Color get primaryLight  => _isDark ? _primaryLightDark: _primaryLightLight;

  static Color get error         => _isDark ? _errorDark   : _errorLight;
  static Color get success       => _isDark ? _successDark : _successLight;
  static Color get warning       => _isDark ? _warningDark : _warningLight;
  static Color get accent        => _isDark ? _accentDark  : _accentLight;

  static Color get textPrimary   => _isDark ? _textPrimaryDark   : _textPrimaryLight;
  static Color get textSecondary => _isDark ? _textSecondaryDark : _textSecondaryLight;
  static Color get textMuted     => _isDark ? _textMutedDark     : _textMutedLight;
  static Color get textLight     => _isDark ? _textMutedDark     : _textMutedLight;

  static Color get border        => _isDark ? _borderDark : _borderLight;
  static Color get divider       => _isDark ? _borderDark : _borderLight;
  static Color get surface       => bgDark;

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: _isDark ? Brightness.dark : Brightness.light,
    colorScheme: _isDark
        ? const ColorScheme.dark(primary: _primaryDark_, secondary: _primaryDark_, surface: _bgCardDark, error: _errorDark)
        : const ColorScheme.light(primary: _primaryLight_, secondary: _primaryLight_, surface: _bgCardLight, error: _errorLight),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: bgDark,

    appBarTheme: AppBarTheme(
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
        side: BorderSide(color: primary),
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
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textMuted),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border),
      ),
    ),

    dividerTheme: DividerThemeData(color: divider, space: 1),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: bgCard,
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: bgCard,
      titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter'),
      contentTextStyle: TextStyle(color: textSecondary, fontFamily: 'Inter'),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: bgCard,
      textStyle: TextStyle(color: textPrimary, fontFamily: 'Inter'),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgElevated,
      contentTextStyle: TextStyle(color: textPrimary, fontFamily: 'Inter'),
    ),
  );
}
