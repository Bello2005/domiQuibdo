import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../core/widgets/common.dart';
import '../addresses/address_widgets.dart';
import 'order_repository.dart';
import 'order_widgets.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(id));
    final demoMode = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Pedido #$id')),
      body: PeriodicRefresh(
        interval: const Duration(seconds: 4),
        onTick: (ref) => ref.invalidate(orderDetailProvider(id)),
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(orderDetailProvider(id))),
          data: (order) => ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                StatusHeaderCard(order: order),
                if (order.status == OrderStatus.enCamino) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/orders/$id/tracking'),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Seguir mi pedido en el mapa'),
                  ),
                ],
                if (order.verificationCode != null && order.status != OrderStatus.cancelado) ...[
                  const SizedBox(height: 12),
                  VerificationCodeCard(
                    code: order.verificationCode!,
                    delivered: order.status == OrderStatus.entregado,
                  ),
                ],
                if (demoMode && order.status.isActive) ...[
                  const SizedBox(height: 12),
                  _DemoPanel(order: order),
                ],
                if (order.repartidor != null) ...[
                  const SizedBox(height: 12),
                  ContactCard(title: 'Tu repartidor', contact: order.repartidor!, icon: Icons.two_wheeler),
                ],
                const SizedBox(height: 12),
                const SectionTitle('Detalle del pedido'),
                OrderItemsCard(order: order),
                if (order.address != null) ...[
                  const SizedBox(height: 12),
                  const SectionTitle('Entrega'),
                  AddressCard(address: order.address!),
                ],
                if (order.notes != null) ...[
                  const SizedBox(height: 12),
                  InfoBanner(icon: Icons.sticky_note_2_outlined, text: order.notes!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Controles solo para la presentación (se ocultan desactivando "Modo demo" en Perfil).
class _DemoPanel extends ConsumerStatefulWidget {
  const _DemoPanel({required this.order});

  final Order order;

  @override
  ConsumerState<_DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends ConsumerState<_DemoPanel> {
  bool _busy = false;

  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      final updated = await ref.read(orderRepositoryProvider).demoAdvance(widget.order.id);
      ref
        ..invalidate(orderDetailProvider(widget.order.id))
        ..invalidate(ordersProvider);
      if (mounted && updated.status == OrderStatus.enCamino) {
        context.push('/orders/${updated.id}/tracking');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = widget.order.status.next;
    final canAdvance = next != null && next != OrderStatus.entregado;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text('Modo demo', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              canAdvance
                  ? 'Simula que el restaurante y el repartidor avanzan tu pedido.'
                  : 'Para entregar: inicia sesión como repartidor (repartidor@demo.co) e ingresa el código.',
              style: theme.textTheme.bodySmall,
            ),
            if (canAdvance) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _advance,
                icon: const Icon(Icons.skip_next),
                label: Text('Pasar a "${next.label}"'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
