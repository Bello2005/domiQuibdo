import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/glass.dart';
import '../addresses/address_repository.dart';
import '../auth/auth_controller.dart';
import 'catalog_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 460,
    mainAxisExtent: 262,
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
              pinned: true,
              toolbarHeight: 84,
              titleSpacing: 20,
              backgroundColor: GlassBarBackground.tint(context),
              flexibleSpace: const GlassBarBackground(),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${user?.firstName ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const _DeliveryAddressPill(),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _ProfileBadge(initial: (user?.firstName ?? '?').characters.first.toUpperCase()),
                ),
              ],
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(child: _SafetyBanner()),
            ),
            const SliverToBoxAdapter(child: _CategoryChips()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomBarInset(context)),
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

    return Glass(
      radius: 20,
      shadow: false,
      tint: theme.colorScheme.primary,
      tintStrength: 0.06,
      onTap: () => context.go('/profile/addresses'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
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

    return GlassCard(
      radius: 30,
      onTap: () => context.go('/home/restaurant/${restaurant.id}', extra: restaurant),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'restaurant-cover-${restaurant.id}',
                    child: GeneratedCover(
                      category: restaurant.category,
                      seed: restaurant.id,
                      imageUrl: restaurant.coverImageUrl,
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: GlassPill(
                      icon: Icons.star_rounded,
                      label: restaurant.rating.toStringAsFixed(1),
                      iconColor: const Color(0xFFFFC86B),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: GlassPill(icon: Icons.schedule_rounded, label: restaurant.etaLabel),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${restaurant.category} · ${restaurant.addressText}',
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: theme.colorScheme.primary),
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

/// Inicial del usuario en un círculo con el degradado de marca.
class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: const CircleBorder(),
    onTap: () => context.go('/profile'),
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x331B5E3F), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
