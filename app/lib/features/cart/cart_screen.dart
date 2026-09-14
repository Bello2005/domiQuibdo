import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import 'cart_controller.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu carrito')),
        body: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: 'Tu carrito está vacío',
          message: 'Explora los restaurantes de Quibdó y agrega tus platos favoritos.',
          action: FilledButton.tonal(onPressed: () => context.go('/home'), child: const Text('Ver restaurantes')),
        ),
      );
    }

    final restaurant = cart.restaurant!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu carrito'),
        actions: [
          TextButton(onPressed: () => ref.read(cartProvider.notifier).clear(), child: const Text('Vaciar')),
        ],
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: GeneratedCover(
                    category: restaurant.category,
                    iconSize: 18,
                    seed: restaurant.id,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.name, style: theme.textTheme.titleMedium),
                      Text(restaurant.category, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final line in cart.lines.values) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.dish.name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text('${formatCop(line.dish.price)} c/u', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(formatCop(line.subtotal), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                      QuantityStepper(
                        quantity: line.quantity,
                        onIncrement: () => ref.read(cartProvider.notifier).add(restaurant, line.dish),
                        onDecrement: () => ref.read(cartProvider.notifier).decrement(line.dish.id),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            SummaryRow(label: 'Subtotal', value: formatCop(cart.subtotal), emphasize: true),
            const SizedBox(height: 4),
            Text(
              'El domicilio se calcula en el siguiente paso según la distancia a tu dirección.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: () => context.push('/cart/checkout'),
            child: Text('Continuar · ${formatCop(cart.subtotal)}'),
          ),
        ),
      ),
    );
  }
}
