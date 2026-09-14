import 'package:flutter/material.dart';

import '../../core/theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle = 'Domicilios seguros de los restaurantes de tu barrio.'});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.selva, AppColors.rio],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: Icon(Icons.eco, size: 180, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.borojo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text('DomiQuibdó', style: text.headlineMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
