import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../orders/order_widgets.dart';
import 'restaurant_repository.dart';

/// Pedidos que le llegan al restaurante: confirmar, preparar y entregar al repartidor.
class RestaurantOrdersScreen extends ConsumerWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ownerOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [IconButton(onPressed: () => ref.invalidate(ownerOrdersProvider), icon: const Icon(Icons.refresh))],
      ),
      body: PeriodicRefresh(
        interval: const Duration(seconds: 6),
        onTick: (ref) => ref.invalidate(ownerOrdersProvider),
        child: orders.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, _) => const ListTileSkeleton(),
          ),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(ownerOrdersProvider)),
          data: (list) => list.isEmpty
              ? const EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin pedidos por ahora',
                  message: 'Cuando un cliente pida en tu restaurante aparecerá aquí.',
                )
              : ResponsiveCenter(
                  child: RefreshIndicator(
                    onRefresh: () => ref.refresh(ownerOrdersProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _OwnerOrderCard(order: list[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _OwnerOrderCard extends ConsumerStatefulWidget {
  const _OwnerOrderCard({required this.order});

  final Order order;

  @override
  ConsumerState<_OwnerOrderCard> createState() => _OwnerOrderCardState();
}

class _OwnerOrderCardState extends ConsumerState<_OwnerOrderCard> {
  bool _busy = false;

  Future<void> _run(Future<Order> Function(RestaurantOwnerRepository repo) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(restaurantOwnerRepositoryProvider));
      ref.invalidate(ownerOrdersProvider);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Cancelar el pedido #${widget.order.id}?'),
        content: const Text('El cliente verá el pedido como cancelado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed == true) await _run((repo) => repo.cancel(widget.order.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final next = order.status.next;
    // El restaurante llega hasta "en camino" (entrega al repartidor); la entrega final es del repartidor.
    final canAdvance = next != null && next != OrderStatus.entregado;
    final canCancel = order.status == OrderStatus.pendiente ||
        order.status == OrderStatus.confirmado ||
        order.status == OrderStatus.preparando;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Pedido #${order.id}', style: theme.textTheme.titleMedium)),
                StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.customer?.name ?? 'Cliente'} · ${formatDateTime(order.createdAt)}',
              style: muted,
            ),
            const SizedBox(height: 10),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${item.quantity} × ${item.name}')),
                    Text(formatCop(item.subtotal), style: muted),
                  ],
                ),
              ),
            if (order.notes != null) ...[
              const SizedBox(height: 8),
              InfoBanner(icon: Icons.sticky_note_2_outlined, text: order.notes!),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text('Total ${formatCop(order.total)} · ${order.paymentLabel}', style: theme.textTheme.titleSmall)),
              ],
            ),
            if (canAdvance || canCancel) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canCancel)
                    OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('Cancelar')),
                  if (canAdvance && canCancel) const SizedBox(width: 8),
                  if (canAdvance)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _run((repo) => repo.advance(order.id)),
                        icon: Icon(next.icon),
                        label: Text(_advanceLabel(next)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _advanceLabel(OrderStatus next) => switch (next) {
        OrderStatus.confirmado => 'Confirmar pedido',
        OrderStatus.preparando => 'Empezar a preparar',
        OrderStatus.enCamino => 'Entregar al repartidor',
        _ => 'Pasar a "${next.label}"',
      };
}
