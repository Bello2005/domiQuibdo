import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../addresses/address_widgets.dart';
import 'order_repository.dart';
import 'order_widgets.dart';
import 'payment.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(id));

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
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomBarInset(context)),
              children: [
                StatusHeaderCard(order: order),
                if (order.isOnlinePayment) ...[
                  const SizedBox(height: 12),
                  PaymentCard(order: order),
                ],
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
                // Pagado en línea, cancelar implica devolución: lo gestiona soporte.
                if (order.status == OrderStatus.pendiente && order.paymentStatus != PaymentStatus.aprobado) ...[
                  const SizedBox(height: 12),
                  _CancelButton(orderId: order.id),
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

/// El cliente puede cancelar mientras el restaurante no haya confirmado el pedido.
class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: const Text('Aún no lo ha confirmado el restaurante, así que no tiene costo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(orderRepositoryProvider).cancel(widget.orderId);
      ref
        ..invalidate(orderDetailProvider(widget.orderId))
        ..invalidate(ordersProvider);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar pedido'),
      );
}
