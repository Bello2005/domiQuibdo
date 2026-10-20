import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Cabecera de marca: el logo grande y centrado, como en la tienda de apps, con
/// un halo suave detrás, el nombre y el eslogan. El fondo queda claro para que
/// el logo sea lo único verde intenso de la pantalla.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.logoSize = 112});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(logoSize * 0.24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize * 2,
          height: logoSize * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Glow(size: logoSize * 2, color: AppColors.selvaBright, alpha: isDark ? 0.30 : 0.22),
              Positioned(
                right: logoSize * 0.18,
                bottom: 0,
                child: _Glow(size: logoSize * 1.1, color: AppColors.borojo, alpha: isDark ? 0.22 : 0.16),
              ),
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.selvaDeep.withValues(alpha: isDark ? 0.6 : 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Image.asset('assets/branding/logo.png', fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'DomiQuibdó',
          textAlign: TextAlign.center,
          style: text.displaySmall?.copyWith(color: isDark ? Colors.white : AppColors.selvaDeep),
        ),
        const SizedBox(height: 6),
        Text(
          'Llegamos a donde nos necesites',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Las tres promesas de seguridad, en una línea discreta bajo el formulario.
class TrustRow extends StatelessWidget {
  const TrustRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final (icon, label) in const [
          (Icons.verified_user_rounded, 'Código de entrega'),
          (Icons.sos_rounded, 'Botón SOS'),
          (Icons.lock_rounded, 'Pago seguro'),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
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
