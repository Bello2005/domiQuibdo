import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';

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
  const StatusChip({super.key, required this.status, this.label, this.icon, this.waitingForPayment = false});

  /// Estado del pedido junto con su pago: antes de pagar dice "Por pagar", no "Recibido".
  StatusChip.ofOrder(Order order, {super.key})
    : status = order.status,
      label = order.statusLabel,
      icon = order.statusIcon,
      waitingForPayment = order.isWaitingForPayment;

  final OrderStatus status;
  final String? label;
  final IconData? icon;

  /// Se pinta en el tono de aviso (borojó), como las tarjetas de pago pendiente.
  final bool waitingForPayment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = waitingForPayment
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : status.colors(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(Colors.white.withValues(alpha: 0.18), background), background],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? status.icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label ?? status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: active
              ? LinearGradient(colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.6)!])
              : null,
          color: active ? null : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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
                        gradient: i <= current
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color.lerp(scheme.primary, Colors.white, 0.18)!, scheme.primary],
                              )
                            : null,
                        color: i <= current ? null : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: i <= current ? 0.55 : 0.8),
                          width: 1.5,
                        ),
                        boxShadow: i == current
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      OrderStatus.flow[i].label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0,
                        color: i == current ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
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
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.headline, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22)),
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

    return GlassCard(
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
                    width: 58,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [scheme.surface.withValues(alpha: 0.95), scheme.surface.withValues(alpha: 0.7)],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                      boxShadow: [
                        BoxShadow(color: fg.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Text(
                      digit,
                      style: theme.textTheme.displaySmall?.copyWith(
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
    return GlassCard(
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
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final item in order.items)
              SummaryRow(label: '${item.quantity} × ${item.name}', value: formatCop(item.subtotal)),
            const Divider(height: 20),
            SummaryRow(label: 'Subtotal', value: formatCop(order.subtotal)),
            SummaryRow(label: 'Domicilio', value: formatCop(order.deliveryFee)),
            if (order.serviceFee > 0) SummaryRow(label: 'Tarifa de servicio', value: formatCop(order.serviceFee)),
            if (order.paymentFee > 0) SummaryRow(label: 'Costo del pago en línea', value: formatCop(order.paymentFee)),
            SummaryRow(label: 'Total', value: formatCop(order.total), emphasize: true),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(paymentMethods[order.paymentMethod]?.$2 ?? Icons.payments_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pago: ${order.paymentLabel}${order.paymentStatus == null ? '' : ' · ${order.paymentStatus!.label}'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
