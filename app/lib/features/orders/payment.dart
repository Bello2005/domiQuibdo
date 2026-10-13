import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import 'order_repository.dart';
import 'payu_webview_screen.dart';

/// Abre el checkout de PayU: dentro de la app (WebView) en el teléfono y en otra pestaña en web,
/// donde no hay WebView. El estado del pago lo confirma el servidor con la notificación firmada
/// de PayU; la app solo lo vuelve a consultar.
Future<void> openPayuCheckout(BuildContext context, WidgetRef ref, int orderId) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final url = await ref.read(orderRepositoryProvider).paymentCheckoutUrl(orderId);
    if (url == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('Este pedido ya no tiene un pago pendiente.')));
      return;
    }
    if (kIsWeb) {
      final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      if (!opened) {
        messenger?.showSnackBar(const SnackBar(content: Text('No se pudo abrir la pasarela de pago.')));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PayuWebViewScreen(url: url, orderId: orderId),
      ),
    );
  } on ApiException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(e.message)));
  } finally {
    ref.invalidate(orderDetailProvider(orderId));
  }
}

/// Estado del pago en línea y botón para pagar o reintentar.
class PaymentCard extends ConsumerStatefulWidget {
  const PaymentCard({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de la pasarela, refresca el pedido para mostrar el resultado sin esperar el sondeo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(orderDetailProvider(widget.order.id));
  }

  Future<void> _payInCash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Pagar en efectivo?'),
        content: const Text(
          'Dejas de pagar en línea y le pagas al repartidor cuando recibas tu pedido. '
          'El restaurante lo podrá preparar de inmediato.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, en efectivo')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(orderRepositoryProvider).payInCash(widget.order.id);
      ref
        ..invalidate(orderDetailProvider(widget.order.id))
        ..invalidate(ordersProvider);
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    await openPayuCheckout(context, ref, widget.order.id);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = widget.order;
    final status = order.paymentStatus;

    final (icon, text, background, foreground) = switch (status) {
      PaymentStatus.aprobado => (
        Icons.verified,
        'Pago aprobado por PayU.',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      PaymentStatus.rechazado => (
        Icons.error_outline,
        'El pago fue rechazado. Puedes intentarlo de nuevo con otro medio.',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      PaymentStatus.expirado => (
        Icons.timer_off_outlined,
        'El pago expiró y el pedido se canceló.',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _ => (
        Icons.hourglass_top,
        'Falta pagar: el restaurante empieza a preparar tu pedido cuando PayU apruebe el pago.',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(icon: icon, text: text, background: background, foreground: foreground),
        if (order.canPayOnline) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _pay,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_outline),
            label: Text(status == PaymentStatus.rechazado ? 'Reintentar pago' : 'Pagar ahora con PayU'),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _busy ? null : _payInCash,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Mejor pago en efectivo'),
          ),
        ],
      ],
    );
  }
}
