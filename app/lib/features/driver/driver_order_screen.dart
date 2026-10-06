import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../orders/order_repository.dart';
import '../orders/order_widgets.dart';
import '../safety/share_location.dart';
import '../safety/sos_sheet.dart';

class DriverOrderScreen extends ConsumerWidget {
  const DriverOrderScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(id));
    final order = orderAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #$id'),
        actions: [
          if (order?.address != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sos,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () => showSosSheet(
                  context,
                  orderId: id,
                  shareMessage: 'Soy repartidor de DomiQuibdó y estoy entregando el pedido #$id. '
                      'Punto de entrega: ${googleMapsLink(order!.address!.position)}',
                ),
                icon: const Icon(Icons.sos),
                label: const Text('SOS'),
              ),
            ),
        ],
      ),
      body: PeriodicRefresh(
        interval: const Duration(seconds: 5),
        onTick: (ref) => ref.invalidate(orderDetailProvider(id)),
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(orderDetailProvider(id))),
          data: (order) => ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                StatusHeaderCard(order: order),
                const SizedBox(height: 12),
                _DeliveryPointCard(order: order),
                if (order.customer != null) ...[
                  const SizedBox(height: 12),
                  ContactCard(title: 'Cliente', contact: order.customer!, icon: Icons.person_outline),
                ],
                const SizedBox(height: 12),
                if (order.status == OrderStatus.enCamino) ...[
                  _LocationSharing(orderId: order.id),
                  const SizedBox(height: 12),
                ],
                _DriverActions(order: order),
                const SizedBox(height: 12),
                const SectionTitle('Pedido'),
                OrderItemsCard(order: order),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Envía el GPS real al backend cada pocos segundos mientras el pedido va en camino,
/// para que el cliente vea el avance y un ETA real. En Android sigue enviando con la pantalla apagada
/// (servicio de primer plano con notificación) y se detiene al salir de la pantalla o al entregar.
class _LocationSharing extends ConsumerStatefulWidget {
  const _LocationSharing({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_LocationSharing> createState() => _LocationSharingState();
}

class _LocationSharingState extends ConsumerState<_LocationSharing> {
  /// Mínimo entre envíos al servidor (el GPS puede reportar más seguido).
  static const _minInterval = Duration(seconds: 4);

  StreamSubscription<Position>? _subscription;
  LocationAccess? _access;
  bool _sending = false;
  bool _lastSendFailed = false;
  DateTime? _lastSent;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final access = await LocationService.ensureAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access != LocationAccess.granted) return;

    _subscription?.cancel();
    _subscription = LocationService.positions().listen(
      _send,
      onError: (_) {
        if (mounted) setState(() => _lastSendFailed = true);
      },
    );
  }

  Future<void> _send(Position position) async {
    final last = _lastSent;
    if (_sending || !mounted || (last != null && DateTime.now().difference(last) < _minInterval)) return;
    _sending = true;
    try {
      await ref.read(orderRepositoryProvider).sendCourierPosition(widget.orderId, position);
      if (mounted) {
        setState(() {
          _lastSent = DateTime.now();
          _lastSendFailed = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _lastSendFailed = true);
    } finally {
      _sending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (icon, text, ok) = switch (_access) {
      null => (Icons.gps_not_fixed, 'Activando tu ubicación…', true),
      LocationAccess.serviceOff => (Icons.location_off, 'Activa el GPS del celular para que el cliente pueda seguirte.', false),
      LocationAccess.denied => (Icons.location_disabled, 'Necesitamos permiso de ubicación para compartir tu avance con el cliente.', false),
      LocationAccess.deniedForever => (
          Icons.location_disabled,
          'El permiso de ubicación está bloqueado. Actívalo en los ajustes del celular.',
          false,
        ),
      LocationAccess.granted when _lastSendFailed => (Icons.sync_problem, 'Sin conexión: reintentando enviar tu ubicación…', false),
      LocationAccess.granted when _lastSent == null => (Icons.gps_not_fixed, 'Buscando señal GPS…', true),
      LocationAccess.granted => (Icons.gps_fixed, 'Compartiendo tu ubicación en vivo con el cliente.', true),
    };

    return InfoBanner(
      icon: icon,
      text: text,
      background: ok ? scheme.primaryContainer : scheme.errorContainer,
      foreground: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
    );
  }
}

class _DeliveryPointCard extends StatelessWidget {
  const _DeliveryPointCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = order.address!;
    final restaurant = order.restaurant!;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 170,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: address.position,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmUserAgent),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: address.position,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, size: 48, color: AppColors.borojo),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text('Recoger en ${restaurant.name}'),
            subtitle: Text(restaurant.addressText),
          ),
          ListTile(
            leading: Icon(address.tipo.icon),
            title: Text('Entregar en ${address.title}'),
            subtitle: address.detalle == null ? null : Text(address.detalle!),
          ),
          if (order.notes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Nota: ${order.notes}', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _DriverActions extends ConsumerStatefulWidget {
  const _DriverActions({required this.order});

  final Order order;

  @override
  ConsumerState<_DriverActions> createState() => _DriverActionsState();
}

class _DriverActionsState extends ConsumerState<_DriverActions> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(orderDetailProvider(widget.order.id))
      ..invalidate(driverOrdersProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver() async {
    if (_code.text.length != 4) {
      setState(() => _error = 'Ingresa los 4 dígitos del código.');
      return;
    }
    await _run(() async {
      await ref.read(orderRepositoryProvider).deliver(widget.order.id, _code.text);
      if (mounted) showMessage(context, '¡Entrega confirmada con código!');
    });
    if (_error != null) _code.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final order = widget.order;

    if (order.status == OrderStatus.entregado) {
      return InfoBanner(
        icon: Icons.verified,
        text: 'Pedido entregado y verificado con el código del cliente.',
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    }

    if (order.status == OrderStatus.enCamino) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Validar entrega', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Pídele al cliente el código de 4 dígitos que aparece en su app. '
                'Entrega el pedido solo si coincide.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (order.paymentMethod == 'efectivo') ...[
                const SizedBox(height: 8),
                Text('Cobrar ${formatCop(order.total)} en efectivo', style: theme.textTheme.titleSmall),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 16),
                onSubmitted: (_) => _deliver(),
                decoration: InputDecoration(counterText: '', hintText: '••••', errorText: _error),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _deliver,
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified),
                label: const Text('Validar código y entregar'),
              ),
            ],
          ),
        ),
      );
    }

    final next = order.status.next;
    if (next == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => ref.read(orderRepositoryProvider).driverAdvance(order.id)),
          icon: Icon(next.icon),
          label: Text('Marcar como "${next.label}"'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
      ],
    );
  }
}
