import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/skeleton.dart';
import '../cart/cart_controller.dart';
import 'catalog_repository.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  const RestaurantDetailScreen({super.key, required this.id, this.initial});

  final int id;

  /// Datos de la card para que la transición Hero sea inmediata.
  final Restaurant? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(restaurantDetailProvider(id));
    final restaurant = detail.valueOrNull ?? initial;
    final cart = ref.watch(cartProvider);
    final category = restaurant?.category ?? '';
    final showCartBar = !cart.isEmpty && cart.restaurant?.id == id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 220,
            backgroundColor: CategoryStyle.of(category).colors.first,
            foregroundColor: Colors.white,
            title: Text(restaurant?.name ?? ''),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'restaurant-cover-$id',
                child: GeneratedCover(category: category, iconSize: 56, seed: id),
              ),
            ),
          ),
          if (restaurant != null) SliverToBoxAdapter(child: _RestaurantInfo(restaurant: restaurant)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: SectionTitle('Menú')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: detail.when(
              data: (r) => SliverList.separated(
                itemCount: r.menu.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => DishTile(restaurant: r, dish: r.menu[i]),
              ),
              loading: () => SliverList.separated(
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, _) => const ListTileSkeleton(),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(restaurantDetailProvider(id)),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showCartBar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () => context.go('/cart'),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Ver carrito (${cart.itemCount})')),
                      Text(formatCop(cart.subtotal)),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _RestaurantInfo extends StatelessWidget {
  const _RestaurantInfo({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(restaurant.name, style: theme.textTheme.headlineSmall),
          if (restaurant.description != null) ...[
            const SizedBox(height: 6),
            Text(restaurant.description!, style: muted),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.star_rounded, color: theme.colorScheme.tertiary),
                label: Text(restaurant.rating.toStringAsFixed(1)),
              ),
              Chip(avatar: const Icon(Icons.schedule), label: Text(restaurant.etaLabel)),
              Chip(avatar: const Icon(Icons.place_outlined), label: Text(restaurant.addressText)),
            ],
          ),
        ],
      ),
    );
  }
}

class DishTile extends ConsumerWidget {
  const DishTile({super.key, required this.restaurant, required this.dish});

  final Restaurant restaurant;
  final Dish dish;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    if (!cart.canAddFrom(restaurant)) {
      final current = ref.read(cartProvider).restaurant!.name;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Empezar un carrito nuevo?'),
          content: Text('Tu carrito tiene productos de $current. Solo puedes pedir de un restaurante a la vez.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vaciar y agregar')),
          ],
        ),
      );
      if (replace != true) return;
    }
    cart.add(restaurant, dish);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quantity = ref.watch(
      cartProvider.select((c) => c.restaurant?.id == restaurant.id ? c.quantityOf(dish.id) : 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: GeneratedCover(
                category: restaurant.category,
                iconSize: 24,
                seed: dish.id,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name, style: theme.textTheme.titleSmall),
                  if (dish.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dish.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(formatCop(dish.price), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            quantity == 0
                ? IconButton.filledTonal(
                    tooltip: 'Agregar',
                    icon: const Icon(Icons.add),
                    onPressed: () => _add(context, ref),
                  )
                : QuantityStepper(
                    quantity: quantity,
                    onIncrement: () => _add(context, ref),
                    onDecrement: () => ref.read(cartProvider.notifier).decrement(dish.id),
                  ),
          ],
        ),
      ),
    );
  }
}
