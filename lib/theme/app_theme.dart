import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colors that look the same in light and dark mode.
class AppColors {
  static const accent = Color(0xFF6FCF5B);

  /// Dark text and icons that sit on top of [accent].
  static const onAccent = Color(0xFF111111);
}

/// Colors that change between light and dark mode.
/// Read them anywhere with `context.colors.ink`, `context.colors.surface`, ...
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color accentSoft;
  final Color error;

  /// Background of the dark "workout in progress" card on Home.
  final Color heroBg;

  /// Color of past-week bars in the Progress charts.
  final Color barPast;

  /// Faded placeholder text inside input fields.
  final Color hint;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accentSoft,
    required this.error,
    required this.heroBg,
    required this.barPast,
    required this.hint,
  });

  static const light = AppPalette(
    bg: Color(0xFFF7F7F5),
    surface: Colors.white,
    ink: Color(0xFF111111),
    muted: Color(0xFF737373),
    border: Color(0xFFE6E6E1),
    accentSoft: Color(0xFFE3F5DE),
    error: Color(0xFFD32F2F),
    heroBg: Color(0xFF111111),
    barPast: Color(0xFFCBEBC3),
    hint: Color(0xFFB8B8B2),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0E0E0D),
    surface: Color(0xFF1A1A18),
    ink: Color(0xFFF2F2EE),
    muted: Color(0xFF9A9A94),
    border: Color(0xFF2B2B28),
    accentSoft: Color(0xFF22381F),
    error: Color(0xFFEF6B6B),
    heroBg: Color(0xFF272724),
    barPast: Color(0xFF34502E),
    hint: Color(0xFF5C5C57),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? border,
    Color? accentSoft,
    Color? error,
    Color? heroBg,
    Color? barPast,
    Color? hint,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      accentSoft: accentSoft ?? this.accentSoft,
      error: error ?? this.error,
      heroBg: heroBg ?? this.heroBg,
      barPast: barPast ?? this.barPast,
      hint: hint ?? this.hint,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      heroBg: Color.lerp(heroBg, other.heroBg, t)!,
      barPast: Color.lerp(barPast, other.barPast, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      surface: p.surface,
      onSurface: p.ink,
      error: p.error,
    );

    // Build on Flutter's default text theme so every style keeps the same
    // "inherit" setting (a bare const TextTheme causes interpolation errors).
    final baseText = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;

    final overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      dividerColor: p.border,
      extensions: [p],

      // Type scale: 28 / 20 / 16 / 14 / 12
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: p.ink,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 16,
          color: p.ink,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          color: p.ink,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
          color: p.muted,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: p.muted,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: overlay,
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: p.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.ink : p.muted,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.ink : p.muted,
          );
        }),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
      ),
    );
  }
}