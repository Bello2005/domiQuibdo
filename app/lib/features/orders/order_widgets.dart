import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';

extension OrderStatusColors on OrderStatus {
  (Color background, Color foreground) colors(ColorScheme scheme) => switch (this) {
        OrderStatus.pendiente => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
        OrderStatus.confirmado => (scheme.secondaryContainer, scheme.onSecondaryContainer),
        OrderStatus.preparando => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
        OrderStatus.enCamino => (scheme.primary, scheme.onPrimary),
        OrderStatus.entregado => (scheme.primaryContainer, scheme.onPrimaryContainer),
        OrderStatus.cancelado => (scheme.errorContainer, scheme.onErrorContainer),
      };
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = status.colors(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

class StatusStepper extends StatelessWidget {
  const StatusStepper({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (status == OrderStatus.cancelado) return StatusChip(status: status);

    final current = OrderStatus.flow.indexOf(status);
    final last = OrderStatus.flow.length - 1;

    Widget line(bool active) => Expanded(
          child: Container(height: 3, color: active ? scheme.primary : scheme.outlineVariant),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i <= last; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    i == 0 ? const Spacer() : line(i <= current),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        OrderStatus.flow[i].icon,
                        size: 18,
                        color: i <= current ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                    i == last ? const Spacer() : line(i < current),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  OrderStatus.flow[i].label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: i == current ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class StatusHeaderCard extends StatelessWidget {
  const StatusHeaderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.status.headline, style: theme.textTheme.titleLarge),
            if (order.restaurant != null)
              Text(
                '${order.restaurant!.name} · ${formatDateTime(order.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 18),
            StatusStepper(status: order.status),
          ],
        ),
      ),
    );
  }
}

/// Código de 4 dígitos que el cliente muestra al repartidor al recibir.
class VerificationCodeCard extends StatelessWidget {
  const VerificationCodeCard({super.key, required this.code, required this.delivered});

  final String code;
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onTertiaryContainer;

    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(delivered ? Icons.verified : Icons.verified_user_outlined, color: fg),
                const SizedBox(width: 8),
                Text('Código de entrega', style: theme.textTheme.titleSmall?.copyWith(color: fg)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final digit in code.split(''))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 56,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      digit,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: delivered ? scheme.onSurfaceVariant : scheme.onSurface,
                        decoration: delivered ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              delivered
                  ? 'El repartidor validó este código al entregar tu pedido.'
                  : 'Dáselo al repartidor solo cuando tengas tu pedido en la mano. '
                      'Nadie de DomiQuibdó te lo pedirá por llamada o chat.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.title, required this.contact, required this.icon});

  final String title;
  final Contact contact;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(contact.name, style: theme.textTheme.titleSmall),
        subtitle: Text(contact.phone == null ? title : '$title · ${contact.phone}'),
      ),
    );
  }
}

class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final item in order.items)
              SummaryRow(label: '${item.quantity} × ${item.name}', value: formatCop(item.subtotal)),
            const Divider(height: 20),
            SummaryRow(label: 'Subtotal', value: formatCop(order.subtotal)),
            SummaryRow(label: 'Domicilio', value: formatCop(order.deliveryFee)),
            SummaryRow(label: 'Total', value: formatCop(order.total), emphasize: true),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(paymentMethods[order.paymentMethod]?.$2 ?? Icons.payments_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Pago: ${order.paymentLabel}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
