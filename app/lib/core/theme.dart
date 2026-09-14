import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta inspirada en el Chocó: selva, río Atrato y borojó.
abstract final class AppColors {
  static const selva = Color(0xFF1B5E3F);
  static const rio = Color(0xFF1F6F8B);
  static const borojo = Color(0xFFE07A2E);
  static const sos = Color(0xFFD32F2F);
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Escala tipográfica única para toda la app (Manrope).
  static const _scale = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.selva, brightness: brightness).copyWith(
      primary: isDark ? const Color(0xFF7FD4A4) : AppColors.selva,
      onPrimary: isDark ? const Color(0xFF00391F) : Colors.white,
      secondary: isDark ? const Color(0xFF8BCFE8) : AppColors.rio,
      onSecondary: isDark ? const Color(0xFF003545) : Colors.white,
      tertiary: isDark ? const Color(0xFFFFB783) : AppColors.borojo,
      onTertiary: isDark ? const Color(0xFF4F2500) : Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF6B3A12) : const Color(0xFFFFE3CC),
      onTertiaryContainer: isDark ? const Color(0xFFFFDCC2) : const Color(0xFF4A2300),
      surface: isDark ? const Color(0xFF101412) : const Color(0xFFFBF8F3),
    );

    final textTheme = GoogleFonts.manropeTextTheme(_scale).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final rounded16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded16,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: rounded16,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }
}
