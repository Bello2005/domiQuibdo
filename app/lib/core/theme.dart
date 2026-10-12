import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widgets/glass.dart';

/// Paleta inspirada en el Chocó: selva, río Atrato y borojó.
abstract final class AppColors {
  static const selva = Color(0xFF1B5E3F);
  static const selvaDeep = Color(0xFF0F3B2A);
  static const selvaBright = Color(0xFF2E8A5C);
  static const rio = Color(0xFF1F6F8B);
  static const borojo = Color(0xFFE07A2E);
  static const sos = Color(0xFFD32F2F);

  /// Degradado de marca: selva → río.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [selvaDeep, selva, rio],
    stops: [0, 0.45, 1],
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Escala tipográfica única para toda la app (Manrope), con titulares compactos.
  static const _scale = TextTheme(
    displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.1),
    labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2),
  );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.selva, brightness: brightness).copyWith(
      primary: isDark ? const Color(0xFF86DCAB) : AppColors.selva,
      onPrimary: isDark ? const Color(0xFF00391F) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF1D4A35) : const Color(0xFFCDEEDB),
      onPrimaryContainer: isDark ? const Color(0xFFBFF0D3) : AppColors.selvaDeep,
      secondary: isDark ? const Color(0xFF8BCFE8) : AppColors.rio,
      onSecondary: isDark ? const Color(0xFF003545) : Colors.white,
      tertiary: isDark ? const Color(0xFFFFB783) : AppColors.borojo,
      onTertiary: isDark ? const Color(0xFF4F2500) : Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF6B3A12) : const Color(0xFFFFE3CC),
      onTertiaryContainer: isDark ? const Color(0xFFFFDCC2) : const Color(0xFF4A2300),
      surface: isDark ? const Color(0xFF0E1613) : const Color(0xFFFBF8F3),
      onSurfaceVariant: isDark ? const Color(0xFFB4C2BA) : const Color(0xFF55615A),
    );

    final textTheme = GoogleFonts.manropeTextTheme(
      _scale,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final glass = isDark ? GlassStyle.dark : GlassStyle.light;
    final glassFill = isDark ? const Color(0x14FFFFFF) : const Color(0x9EFFFFFF);
    final glassEdge = isDark ? const Color(0x24FFFFFF) : const Color(0xE6FFFFFF);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: glassEdge),
    );
    // Panel opaco para hojas y diálogos (van sobre contenido variable y deben leerse siempre).
    final sheetColor = isDark ? const Color(0xF2142019) : const Color(0xF5FBF8F3);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      // El fondo ambiental lo pinta cada página (ver [_AmbientPageTransitions]).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AmbientPageTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.iOS: _AmbientPageTransitions(CupertinoPageTransitionsBuilder()),
          TargetPlatform.macOS: _AmbientPageTransitions(CupertinoPageTransitionsBuilder()),
          TargetPlatform.linux: _AmbientPageTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.windows: _AmbientPageTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.fuchsia: _AmbientPageTransitions(FadeForwardsPageTransitionsBuilder()),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: glass.fillTop,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: glassEdge),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ).copyWith(backgroundBuilder: _liquidSheen),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          backgroundColor: glassFill,
          side: BorderSide(color: isDark ? glassEdge : scheme.primary.withValues(alpha: 0.28)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder(), textStyle: textTheme.labelLarge),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: const CircleBorder())),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: field.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: field.copyWith(borderSide: BorderSide(color: scheme.error, width: 1.6)),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: isDark ? 0.30 : 0.16)
              : glassFill,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.45) : glassEdge,
            width: states.contains(WidgetState.selected) ? 1.4 : 1,
          ),
        ),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        checkmarkColor: scheme.primary,
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xF2E8F1EC) : const Color(0xF20F1F18),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.selvaDeep : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
      listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: textTheme.labelMedium,
          backgroundColor: glassFill,
          selectedBackgroundColor: scheme.primary.withValues(alpha: isDark ? 0.30 : 0.16),
          selectedForegroundColor: scheme.primary,
          side: BorderSide(color: glassEdge),
          visualDensity: VisualDensity.compact,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColors.borojo),
    );
  }

  /// Brillo de vidrio líquido sobre botones: reflejo arriba y borde de luz, sobre su color.
  static Widget _liquidSheen(BuildContext context, Set<WidgetState> states, Widget? child) {
    if (states.contains(WidgetState.disabled)) return child!;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.04),
            Colors.black.withValues(alpha: 0.06),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Envuelve cada página en el fondo ambiental para que las pantallas (transparentes)
/// muestren la misma luz de fondo y las transiciones no dejen ver la página anterior.
class _AmbientPageTransitions extends PageTransitionsBuilder {
  const _AmbientPageTransitions(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(route, context, animation, secondaryAnimation, AmbientBackground(child: child));
}
