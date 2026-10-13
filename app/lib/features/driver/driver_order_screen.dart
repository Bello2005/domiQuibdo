import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../orders/order_repository.dart';
import 'delivery_confirmation_screen.dart';
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
        onTick: (ref) => ref
          ..invalidate(orderDetailProvider(id))
          ..invalidate(courierPositionProvider(id)),
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(orderDetailProvider(id))),
          data: (order) => ResponsiveCenter(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomBarInset(context)),
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
  static const _minInterval = Duration(seconds: 3);

  StreamSubscription<Position>? _subscription;
  LocationAccess? _access;
  bool _sending = false;
  bool _lastSendFailed = false;

  /// Motivo que dio el servidor al rechazar la posición (por ejemplo, estar fuera de Quibdó).
  String? _rejection;
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
          _rejection = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _lastSendFailed = true;
          // 422: el servidor entendió la posición y la rechazó; no es un problema de conexión.
          _rejection = e.statusCode == 422 ? e.message : null;
        });
      }
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
      LocationAccess.granted when _rejection != null => (Icons.wrong_location_outlined, _rejection!, false),
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

/// Mapa con el restaurante, el punto de entrega, la ruta y la última posición que este
/// repartidor reportó por GPS, más accesos directos para navegar a cada punto.
class _DeliveryPointCard extends ConsumerWidget {
  const _DeliveryPointCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final address = order.address!;
    final restaurant = order.restaurant!;
    final route = ref.watch(orderRouteProvider(order.id)).valueOrNull ?? const <LatLng>[];
    final me = order.status == OrderStatus.enCamino
        ? ref.watch(courierPositionProvider(order.id)).valueOrNull?.position
        : null;

    return GlassCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              // Al llegar la primera posición se recrea el mapa para encuadrarla también.
              key: ValueKey(me != null),
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [restaurant.position, address.position, ?me],
                  padding: const EdgeInsets.all(36),
                  maxZoom: 17,
                ),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmUserAgent),
                if (route.length >= 2)
                  PolylineLayer(
                    polylines: [Polyline(points: route, strokeWidth: 5, color: scheme.primary.withValues(alpha: 0.45))],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: restaurant.position,
                      width: 36,
                      height: 36,
                      child: _PointBadge(icon: Icons.storefront, color: scheme.secondary),
                    ),
                    Marker(
                      point: address.position,
                      width: 36,
                      height: 36,
                      child: _PointBadge(icon: address.tipo.icon, color: AppColors.borojo),
                    ),
                    if (me != null)
                      Marker(point: me, width: 40, height: 40, child: _PointBadge(icon: Icons.two_wheeler, color: scheme.primary)),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text('Recoger en ${restaurant.name}'),
            subtitle: Text(restaurant.addressText),
            trailing: IconButton(
              tooltip: 'Cómo llegar al restaurante',
              onPressed: () => openDirections(restaurant.position),
              icon: const Icon(Icons.directions),
            ),
          ),
          ListTile(
            leading: Icon(address.tipo.icon),
            title: Text('Entregar en ${address.title}'),
            subtitle: address.detalle == null ? null : Text(address.detalle!),
            trailing: IconButton(
              tooltip: 'Cómo llegar a la entrega',
              onPressed: () => openDirections(address.position),
              icon: const Icon(Icons.directions),
            ),
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

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

class _DriverActions extends ConsumerStatefulWidget {
  const _DriverActions({required this.order});

  final Order order;

  @override
  ConsumerState<_DriverActions> createState() => _DriverActionsState();
}

class _DriverActionsState extends ConsumerState<_DriverActions> {
  bool _busy = false;
  String? _error;

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
      return _DeliveryEntryCard(order: order);
    }

    final next = order.status.next;
    if (next == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final position = await LocationService.current();
                    await ref.read(orderRepositoryProvider).driverAdvance(order.id, position: position);
                  }),
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

/// Entrada a la pantalla de confirmación de entrega: dice cuánto falta y abre la vista aparte.
class _DeliveryEntryCard extends ConsumerWidget {
  const _DeliveryEntryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final courier = ref.watch(courierPositionProvider(order.id)).valueOrNull;
    final hasSignal = courier != null && courier.hasFix && courier.live;
    final atDelivery = hasSignal && courier.hasArrived;
    final distance = courier?.distanceM;

    final detail = atDelivery
        ? 'Ya estás en el punto de entrega. Pídele el código al cliente.'
        : !hasSignal
            ? 'Esperando tu ubicación…'
            : distance == null
                ? 'Sigue hacia la dirección del cliente.'
                : 'Te faltan ~${formatDistance(distance)} para llegar.';

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: 0.12)),
                  child: Icon(atDelivery ? Icons.lock_open_rounded : Icons.lock_clock_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entrega', style: theme.textTheme.titleMedium),
                      Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push<bool>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => DeliveryConfirmationScreen(orderId: order.id),
                ),
              ),
              icon: Icon(atDelivery ? Icons.verified_rounded : Icons.near_me_rounded),
              label: Text(atDelivery ? 'Confirmar entrega' : 'Ver mi avance a la entrega'),
            ),
          ],
        ),
      ),
    );
  }
}
