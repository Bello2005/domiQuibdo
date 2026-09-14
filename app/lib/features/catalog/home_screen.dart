import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/skeleton.dart';
import '../addresses/address_repository.dart';
import '../auth/auth_controller.dart';
import 'catalog_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 460,
    mainAxisExtent: 232,
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final category = ref.watch(selectedCategoryProvider);
    final restaurants = ref.watch(restaurantsProvider(category));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(restaurantsProvider);
          await ref.read(restaurantsProvider(category).future);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              toolbarHeight: 76,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${user?.firstName ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                  const _DeliveryAddressPill(),
                ],
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _SafetyBanner()),
            ),
            const SliverToBoxAdapter(child: _CategoryChips()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: restaurants.when(
                data: (list) => list.isEmpty
                    ? const SliverToBoxAdapter(
                        child: EmptyView(
                          icon: Icons.storefront_outlined,
                          title: 'Sin restaurantes',
                          message: 'No hay restaurantes activos en esta categoría.',
                        ),
                      )
                    : SliverGrid.builder(
                        gridDelegate: _grid,
                        itemCount: list.length,
                        itemBuilder: (_, i) => RestaurantCard(restaurant: list[i]),
                      ),
                loading: () => SliverGrid.builder(
                  gridDelegate: _grid,
                  itemCount: 4,
                  itemBuilder: (_, _) => const RestaurantCardSkeleton(),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: ErrorView(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(restaurantsProvider(category)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAddressPill extends ConsumerWidget {
  const _DeliveryAddressPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(defaultAddressProvider).valueOrNull;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/profile/addresses'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                address == null ? 'Agrega tu dirección de entrega' : 'Entregar en ${address.title}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InfoBanner(
      icon: Icons.verified_user_outlined,
      text: 'Entregas con código de verificación, botón SOS y ubicación compartida en cada pedido.',
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <String>[];
    final selected = ref.watch(selectedCategoryProvider);

    void select(String? value) => ref.read(selectedCategoryProvider.notifier).state = value;

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        children: [
          ChoiceChip(label: const Text('Todos'), selected: selected == null, onSelected: (_) => select(null)),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(CategoryStyle.of(category).icon, size: 18),
              label: Text(category),
              selected: selected == category,
              onSelected: (_) => select(category),
            ),
          ],
        ],
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: InkWell(
        onTap: () => context.go('/home/restaurant/${restaurant.id}', extra: restaurant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'restaurant-cover-${restaurant.id}',
              child: GeneratedCover(category: restaurant.category, height: 140, seed: restaurant.id),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(child: Text(restaurant.category, style: muted, overflow: TextOverflow.ellipsis)),
                      Text('  ·  ', style: muted),
                      Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 2),
                      Text(restaurant.rating.toStringAsFixed(1), style: muted),
                      Text('  ·  ', style: muted),
                      Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(restaurant.etaLabel, style: muted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
