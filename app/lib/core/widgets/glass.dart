import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Lenguaje visual "liquid glass" de DomiQuibdó: superficies translúcidas con borde especular
/// sobre un fondo ambiental con la paleta del Chocó (selva, río Atrato y borojó).
///
/// - [AmbientBackground]: fondo de todas las pantallas (lo pone la transición de página).
/// - [Glass]: superficie de vidrio. Con `blur` desenfoca lo que hay detrás (mapas, contenido
///   que pasa por debajo); sin él es vidrio "esmerilado", más barato, para listas.
/// - [GlassCard]: reemplazo de `Card`.
/// - [GlassNavBar]: barra de navegación flotante con indicador líquido.
class GlassStyle {
  const GlassStyle._({
    required this.fillTop,
    required this.fillBottom,
    required this.edgeLight,
    required this.edgeShade,
    required this.hairline,
    required this.shadow,
    required this.blurSigma,
  });

  /// Relleno: más opaco arriba (luz) y más transparente abajo.
  final Color fillTop;
  final Color fillBottom;

  /// Borde especular: brillante arriba a la izquierda, se apaga hacia abajo.
  final Color edgeLight;
  final Color edgeShade;

  /// Contorno fino exterior que define el vidrio sobre fondos claros.
  final Color hairline;
  final List<BoxShadow> shadow;
  final double blurSigma;

  static const light = GlassStyle._(
    fillTop: Color(0xD9FFFFFF),
    fillBottom: Color(0x8CFFFFFF),
    edgeLight: Color(0xFFFFFFFF),
    edgeShade: Color(0x33FFFFFF),
    hairline: Color(0x140F3B2A),
    shadow: [
      BoxShadow(color: Color(0x1A0F3B2A), blurRadius: 32, offset: Offset(0, 16), spreadRadius: -12),
      BoxShadow(color: Color(0x0A0F3B2A), blurRadius: 6, offset: Offset(0, 2)),
    ],
    blurSigma: 22,
  );

  static const dark = GlassStyle._(
    fillTop: Color(0x26FFFFFF),
    fillBottom: Color(0x0DFFFFFF),
    edgeLight: Color(0x59FFFFFF),
    edgeShade: Color(0x0AFFFFFF),
    hairline: Color(0x33000000),
    shadow: [BoxShadow(color: Color(0x66000000), blurRadius: 36, offset: Offset(0, 18), spreadRadius: -12)],
    blurSigma: 26,
  );

  static GlassStyle of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Relleno con un tinte opcional (por ejemplo el color de un estado) mezclado en el vidrio.
  LinearGradient fill({Color? tint, double tintStrength = 0.16}) {
    Color mix(Color base) => tint == null ? base : Color.alphaBlend(tint.withValues(alpha: tintStrength), base);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [mix(fillTop), mix(fillBottom)],
    );
  }
}

/// Fondo ambiental: base cálida con manchas de luz de la paleta, muy difuminadas.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF0A110E) : const Color(0xFFF6F1E8)),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AmbientPainter(isDark: isDark)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, Color color, double alpha) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ).createShader(rect),
      );
    }

    final w = size.width;
    final h = size.height;
    final r = (w > h ? w : h) * 0.75;
    final k = isDark ? 1.9 : 1.0;

    glow(Offset(-w * 0.1, -h * 0.05), r, AppColors.selva, 0.20 * k);
    glow(Offset(w * 1.05, h * 0.32), r * 0.85, AppColors.rio, 0.15 * k);
    glow(Offset(w * 0.05, h * 1.0), r * 0.8, AppColors.borojo, 0.13 * k);
    glow(Offset(w * 0.75, h * 0.92), r * 0.55, AppColors.selva, 0.08 * k);
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Superficie de vidrio líquido.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = false,
    this.padding,
    this.tint,
    this.tintStrength = 0.16,
    this.shadow = true,
    this.solid = false,
    this.onTap,
  });

  final Widget child;
  final double radius;

  /// Superficie casi opaca del color del tema: para paneles sobre mapas o fotos, donde un vidrio
  /// translúcido deja ver demasiado y el texto pierde contraste (sobre todo en modo oscuro).
  final bool solid;

  /// Desenfoca el contenido de atrás. Usarlo donde hay algo detrás que mirar (mapa, scroll).
  final bool blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double tintStrength;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final shape = BorderRadius.circular(radius);
    final surfaceTint = solid ? Theme.of(context).colorScheme.surface : tint;
    final surfaceStrength = solid ? 0.95 : tintStrength;

    Widget content = padding == null ? child : Padding(padding: padding!, child: child);
    content = Material(
      type: MaterialType.transparency,
      child: onTap == null ? content : InkWell(onTap: onTap, borderRadius: shape, child: content),
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: style.fill(tint: surfaceTint, tintStrength: surfaceStrength),
      ),
      child: CustomPaint(
        foregroundPainter: _SpecularEdge(radius: radius, style: style),
        child: content,
      ),
    );
    if (blur) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: style.blurSigma, sigmaY: style.blurSigma),
        child: surface,
      );
    }
    surface = ClipRRect(borderRadius: shape, child: surface);

    return shadow
        ? DecoratedBox(
            decoration: BoxDecoration(borderRadius: shape, boxShadow: style.shadow),
            child: surface,
          )
        : surface;
  }
}

/// Borde de luz: una línea con degradado (reflejo arriba a la izquierda) y un contorno fino.
class _SpecularEdge extends CustomPainter {
  const _SpecularEdge({required this.radius, required this.style});

  final double radius;
  final GlassStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect.deflate(0.25), Radius.circular(radius));
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = style.hairline,
    );

    final inner = RRect.fromRectAndRadius(rect.deflate(0.9), Radius.circular(radius - 0.6));
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.edgeLight, style.edgeShade, style.edgeShade, style.edgeLight.withValues(alpha: 0.35)],
          stops: const [0, 0.38, 0.75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpecularEdge oldDelegate) => oldDelegate.radius != radius || oldDelegate.style != style;
}

/// Reemplazo de `Card` con el lenguaje de vidrio. [color] tiñe el vidrio (no lo vuelve opaco).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.color,
    this.margin,
    this.radius = 24,
    this.blur = false,
    this.solid = false,
    this.onTap,
    // Se aceptan por compatibilidad con `Card`; el vidrio siempre recorta y no usa elevación.
    Clip? clipBehavior,
    double? elevation,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool blur;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Glass(
      radius: radius,
      blur: blur,
      solid: solid,
      tint: color,
      tintStrength: 0.55,
      onTap: onTap,
      child: child,
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

class GlassNavItem {
  const GlassNavItem({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Número que se muestra sobre el ícono (0 = sin insignia).
  final int badge;
}

/// Barra de navegación flotante de vidrio con un indicador que se desliza entre pestañas.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _height = 68.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Glass(
              blur: true,
              radius: _height / 2,
              child: SizedBox(
                height: _height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slot = constraints.maxWidth / items.length;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          left: slot * currentIndex + 6,
                          top: 6,
                          bottom: 6,
                          width: slot - 12,
                          child: _LiquidIndicator(color: scheme.primary),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Expanded(
                                child: _NavButton(item: items[i], selected: i == currentIndex, onTap: () => onTap(i)),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidIndicator extends StatelessWidget {
  const _LiquidIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.10)],
      ),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Badge(
                isLabelVisible: item.badge > 0,
                label: Text('${item.badge}'),
                backgroundColor: AppColors.borojo,
                child: Icon(selected ? item.selectedIcon : item.icon, color: color, size: 24),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: theme.textTheme.labelSmall!.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondo de vidrio para barras superiores fijas (`flexibleSpace`): el contenido pasa por debajo desenfocado.
class GlassBarBackground extends StatelessWidget {
  const GlassBarBackground({super.key});

  /// Color base de la barra: casi opaco, para que el contenido que pasa por debajo no se lea.
  static Color tint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xF20A110E) : const Color(0xF2F6F1E8);

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: style.blurSigma, sigmaY: style.blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xF20A110E), Color(0xE60A110E)]
                  : const [Color(0xF5F6F1E8), Color(0xEBF6F1E8)],
            ),
            border: Border(bottom: BorderSide(color: style.hairline)),
          ),
        ),
      ),
    );
  }
}

/// Pastilla de vidrio oscuro para poner sobre imágenes o portadas (calificación, tiempo…).
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor ?? Colors.white),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
          ],
        ),
      ),
    ),
  );
}

/// Espacio extra al final de las listas para que el último elemento no quede bajo la barra flotante.
double bottomBarInset(BuildContext context) => MediaQuery.paddingOf(context).bottom;
