import 'package:flutter/material.dart';

import '../theme.dart';

/// Portada generada por categoría (degradado + ícono). Evita depender de fotos
/// externas o con derechos de autor, y nunca "se rompe" sin internet.
class CategoryStyle {
  const CategoryStyle(this.colors, this.icon);

  final List<Color> colors;
  final IconData icon;

  static CategoryStyle of(String category) => switch (category) {
        'Gama alta' => const CategoryStyle([Color(0xFF0F3B2A), AppColors.rio], Icons.wine_bar),
        'Chocoana' => const CategoryStyle([AppColors.rio, AppColors.selva], Icons.set_meal),
        'Típica' => const CategoryStyle([AppColors.borojo, Color(0xFFA63D23)], Icons.rice_bowl),
        'Parrilla' => const CategoryStyle([Color(0xFF7A2716), AppColors.borojo], Icons.outdoor_grill),
        'Pollo' => const CategoryStyle([Color(0xFFF2A33A), Color(0xFFC8561E)], Icons.dinner_dining),
        'Heladería' => const CategoryStyle([Color(0xFFD9577F), Color(0xFFF2A65A)], Icons.icecream),
        'Panadería' => const CategoryStyle([Color(0xFFB9824F), Color(0xFF6E4527)], Icons.bakery_dining),
        'Comida rápida' => const CategoryStyle([Color(0xFFE9A800), Color(0xFFD45B1F)], Icons.lunch_dining),
        _ => const CategoryStyle([AppColors.selva, AppColors.rio], Icons.storefront),
      };
}

class GeneratedCover extends StatelessWidget {
  const GeneratedCover({
    super.key,
    required this.category,
    this.height,
    this.iconSize = 40,
    this.borderRadius = BorderRadius.zero,
    this.seed = 0,
  });

  final String category;
  final double? height;
  final double iconSize;
  final BorderRadius borderRadius;

  /// Varía levemente la composición para que dos portadas iguales no se vean idénticas.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final shift = (seed % 5) * 0.08;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1, -1 + shift),
              end: Alignment(1, 1 - shift),
              colors: style.colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -iconSize * 0.9,
                top: -iconSize * 0.9,
                child: _Blob(size: iconSize * 3, opacity: 0.10),
              ),
              Positioned(
                right: -iconSize * 0.6,
                bottom: -iconSize * 0.8,
                child: Transform.rotate(
                  angle: -0.35 + shift,
                  child: Icon(style.icon, size: iconSize * 3.2, color: Colors.white.withValues(alpha: 0.14)),
                ),
              ),
              Center(
                child: Container(
                  padding: EdgeInsets.all(iconSize * 0.3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: iconSize, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: opacity), shape: BoxShape.circle),
      );
}
