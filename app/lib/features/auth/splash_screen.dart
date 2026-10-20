import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bienvenida animada. Arranca con el mismo verde y la misma figura del splash
/// nativo de Android, así el paso al primer cuadro de Flutter no se nota; luego
/// la figura crece con un halo, pasa un brillo y aparecen el nombre y el eslogan.
/// El router sale de aquí cuando termina de restaurar la sesión (mínimo
/// `AuthController.splashMinimum`), con un fundido hacia el login o el inicio.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  // Tramos de la animación (0 → 1 en 1,5 s).
  late final _logo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeInOut),
  );
  late final _glow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
  );
  late final _shine = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.85, curve: Curves.easeInOut),
  );
  late final _title = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
  );
  late final _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final glyphHeight = math.min(150.0, shortest * 0.34);

    return Scaffold(
      backgroundColor: const Color(0xFF14522F),
      body: DecoratedBox(
        // Mismo degradado del ícono: arriba-izquierda más claro, abajo-derecha más oscuro.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF26653B), Color(0xFF14522F), Color(0xFF023E23)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // Halo cálido detrás de la figura.
              Center(
                child: Opacity(
                  opacity: _glow.value,
                  child: Transform.scale(
                    scale: 0.6 + 0.6 * _glow.value,
                    child: Container(
                      width: glyphHeight * 2.6,
                      height: glyphHeight * 2.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF7FE0AE).withValues(alpha: 0.30),
                            const Color(0xFFE07A2E).withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                // Empieza con la figura justo en el centro (como el splash nativo) y sube a
                // medida que aparecen el nombre y el eslogan debajo.
                child: Transform.translate(
                  offset: Offset(0, (glyphHeight * 0.28 + 76) / 2 * (1 - _title.value)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 1 + 0.06 * math.sin(math.pi * _logo.value),
                        child: _ShiningGlyph(height: glyphHeight, shine: _shine.value),
                      ),
                      SizedBox(height: glyphHeight * 0.28),
                      _Reveal(
                        progress: _title.value,
                        child: Text(
                          'DomiQuibdó',
                          style: text.displaySmall?.copyWith(color: Colors.white, letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Reveal(
                        progress: _tagline.value,
                        child: Text(
                          'Llegamos a donde nos necesites',
                          style: text.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Pie discreto, como las apps grandes.
              Positioned(
                left: 0,
                right: 0,
                bottom: 40 + MediaQuery.paddingOf(context).bottom,
                child: _Reveal(
                  progress: _tagline.value,
                  child: Text(
                    'Hecho en el Chocó',
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La figura del logo con una franja de brillo que la cruza en diagonal una vez.
class _ShiningGlyph extends StatelessWidget {
  const _ShiningGlyph({required this.height, required this.shine});

  final double height;
  final double shine;

  @override
  Widget build(BuildContext context) {
    final glyph = Image.asset('assets/branding/glyph.png', height: height, filterQuality: FilterQuality.medium);
    if (shine <= 0 || shine >= 1) return glyph;

    final center = -1.6 + 3.2 * shine;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.65), Colors.transparent],
        stops: [
          ((center - 0.25 + 1) / 2).clamp(0, 1),
          ((center + 1) / 2).clamp(0, 1),
          ((center + 0.25 + 1) / 2).clamp(0, 1),
        ],
      ).createShader(bounds),
      child: glyph,
    );
  }
}

/// Aparece subiendo y desvaneciéndose hacia adentro.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress.clamp(0, 1),
    child: Transform.translate(offset: Offset(0, 14 * (1 - progress)), child: child),
  );
}
