import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/skeleton.dart';
import '../orders/order_repository.dart';
import '../orders/order_widgets.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(driverOrdersProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas'),
        actions: [
          IconButton(onPressed: () => ref.invalidate(driverOrdersProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: PeriodicRefresh(
        interval: const Duration(seconds: 6),
        onTick: (ref) => ref.invalidate(driverOrdersProvider),
        child: orders.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, _) => const ListTileSkeleton(),
          ),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(driverOrdersProvider)),
          data: (list) => ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                InfoBanner(
                  icon: Icons.verified_user_outlined,
                  text: 'Entrega cada pedido solo después de validar el código del cliente. '
                      'Si te sientes en riesgo, usa el botón SOS.',
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  const EmptyView(
                    icon: Icons.two_wheeler,
                    title: 'Sin pedidos por ahora',
                    message: 'Cuando haya pedidos disponibles aparecerán aquí.',
                  )
                else
                  for (final order in list) ...[
                    _DriverOrderCard(order: order),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverOrderCard extends StatelessWidget {
  const _DriverOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: InkWell(
        onTap: () => context.push('/driver/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: GeneratedCover(
                  category: order.restaurant?.category ?? '',
                  iconSize: 20,
                  seed: order.restaurant?.id ?? 0,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.id} · ${order.restaurant?.name}', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Entregar en ${order.address?.title ?? '—'}', style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${order.customer?.name ?? 'Cliente'} · ${formatCop(order.total)}', style: muted),
                  ],
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
        ),
      ),
    );
  }
}
