import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Cabecera de marca: bloque profundo selva → río con luces internas, logo de vidrio
/// color borojó y las tres promesas de seguridad de la app.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle = 'Domicilios seguros de los restaurantes de tu barrio.'});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(color: Color(0x401B5E3F), blurRadius: 40, offset: Offset(0, 22), spreadRadius: -14),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: Stack(
            children: [
              const Positioned(right: -70, bottom: -90, child: _Glow(size: 260, color: AppColors.borojo, alpha: 0.45)),
              const Positioned(left: -60, top: -80, child: _Glow(size: 220, color: Color(0xFF7FE0AE), alpha: 0.28)),
              Positioned(
                right: -24,
                top: 18,
                child: Icon(Icons.eco_rounded, size: 150, color: Colors.white.withValues(alpha: 0.06)),
              ),
              // Reflejo superior del vidrio.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LogoTile(),
                    const SizedBox(height: 22),
                    Text('DomiQuibdó', style: text.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.86))),
                    const SizedBox(height: 18),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TrustPill(icon: Icons.verified_user_rounded, label: 'Código de entrega'),
                        _TrustPill(icon: Icons.sos_rounded, label: 'Botón SOS'),
                        _TrustPill(icon: Icons.lock_rounded, label: 'Pago seguro'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4A15D), AppColors.borojo, Color(0xFFC25E1C)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      boxShadow: const [BoxShadow(color: Color(0x66E07A2E), blurRadius: 22, offset: Offset(0, 10))],
    ),
    child: Stack(
      children: [
        Positioned(
          left: 4,
          right: 4,
          top: 3,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        const Center(child: Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 32)),
      ],
    ),
  );
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}
