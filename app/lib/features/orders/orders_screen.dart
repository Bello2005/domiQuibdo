import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/skeleton.dart';
import 'order_repository.dart';
import 'order_widgets.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: PeriodicRefresh(
        interval: const Duration(seconds: 8),
        onTick: (ref) => ref.invalidate(ordersProvider),
        child: orders.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, _) => const ListTileSkeleton(),
          ),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(ordersProvider)),
          data: (list) => list.isEmpty
              ? EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aún no tienes pedidos',
                  message: 'Cuando hagas tu primer pedido podrás seguirlo aquí en tiempo real.',
                  action: FilledButton.tonal(onPressed: () => context.go('/home'), child: const Text('Pedir ahora')),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(ordersProvider.future),
                  child: ResponsiveCenter(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _OrderCard(order: list[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restaurant = order.restaurant;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: GeneratedCover(
                  category: restaurant?.category ?? '',
                  iconSize: 20,
                  seed: restaurant?.id ?? 0,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant?.name ?? 'Pedido', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Pedido #${order.id} · ${order.itemsCount ?? order.items.length} productos', style: muted),
                    Text(formatDateTime(order.createdAt), style: muted),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(status: order.status),
                  const SizedBox(height: 8),
                  Text(formatCop(order.total), style: theme.textTheme.titleSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
