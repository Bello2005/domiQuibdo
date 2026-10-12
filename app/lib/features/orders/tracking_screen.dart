import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../safety/share_location.dart';
import '../safety/sos_sheet.dart';
import 'order_repository.dart';

/// Tracking del pedido: ruta por calles restaurante → entrega y la posición real que reporta el
/// repartidor por GPS. Mientras no haya una posición, el mapa lo dice en vez de simular el recorrido.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _deliveredShown = false;

  Future<void> _showDelivered() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 48),
        title: const Text('¡Pedido entregado!'),
        content: const Text('El repartidor validó tu código de entrega. ¡Buen provecho!'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final routeAsync = ref.watch(orderRouteProvider(widget.orderId));
    final courier = ref.watch(courierPositionProvider(widget.orderId)).valueOrNull;
    final courierAt = courier?.position;

    ref.listen(orderDetailProvider(widget.orderId), (_, next) {
      final order = next.valueOrNull;
      if (order?.status == OrderStatus.entregado && !_deliveredShown) {
        _deliveredShown = true;
        _showDelivered();
      }
    });

    final order = orderAsync.valueOrNull;
    final route = routeAsync.valueOrNull;

    if (order == null || route == null) {
      final error = orderAsync.error ?? routeAsync.error;
      return Scaffold(
        appBar: AppBar(),
        body: error != null
            ? ErrorView(message: error.toString(), onRetry: () => ref.invalidate(orderRouteProvider(widget.orderId)))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final restaurant = order.restaurant!;
    final destination = order.address!;
    final arrived = courier?.hasFix == true && courier!.hasArrived;

    return Scaffold(
      body: PeriodicRefresh(
        interval: const Duration(seconds: 4),
        onTick: (ref) {
          ref.invalidate(orderDetailProvider(widget.orderId));
          ref.invalidate(courierPositionProvider(widget.orderId));
        },
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [restaurant.position, destination.position, ...route, ?courierAt],
                  padding: const EdgeInsets.fromLTRB(56, 140, 56, 320),
                  maxZoom: 17,
                ),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmUserAgent),
                if (route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: route, strokeWidth: 6, color: scheme.primary.withValues(alpha: 0.45)),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: restaurant.position,
                      width: 44,
                      height: 44,
                      child: _MapBadge(icon: Icons.storefront, color: scheme.secondary),
                    ),
                    Marker(
                      point: destination.position,
                      width: 44,
                      height: 44,
                      child: _MapBadge(icon: destination.tipo.icon, color: AppColors.borojo),
                    ),
                    if (courierAt != null)
                      Marker(point: courierAt, width: 56, height: 56, child: _CourierMarker(color: scheme.primary)),
                  ],
                ),
                const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _EtaPill(courier: courier)),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sos,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => showSosSheet(
                        context,
                        orderId: order.id,
                        shareMessage: trackingShareMessage(order: order, position: courierAt),
                      ),
                      icon: const Icon(Icons.sos),
                      label: const Text('SOS'),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _TrackingPanel(order: order, arrived: arrived, courierPosition: courierAt),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaPill extends StatelessWidget {
  const _EtaPill({this.courier});

  /// Última posición conocida del repartidor (null mientras carga).
  final CourierPosition? courier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final real = courier;

    final (icon, text) = switch (real) {
      CourierPosition(hasFix: true, hasArrived: true) => (Icons.where_to_vote, 'Tu repartidor llegó'),
      CourierPosition(hasFix: true, live: true) => (Icons.two_wheeler, 'En camino · llega en ~${real.etaMin ?? 1} min'),
      CourierPosition(hasFix: true) => (Icons.gps_not_fixed, 'Buscando señal del repartidor…'),
      _ => (Icons.hourglass_top, 'Esperando la ubicación del repartidor…'),
    };

    return Material(
      elevation: 3,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.order, required this.arrived, this.courierPosition});

  final Order order;
  final bool arrived;
  final LatLng? courierPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.two_wheeler),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.repartidor?.name ?? 'Repartidor asignado', style: theme.textTheme.titleMedium),
                      Text(
                        '${order.restaurant?.name} → ${order.address?.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (arrived && order.verificationCode != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                icon: Icons.verified_user_outlined,
                text: 'Recibe tu pedido y luego dile al repartidor tu código: ${order.verificationCode}',
                background: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => shareViaWhatsApp(
                      context,
                      trackingShareMessage(order: order, position: courierPosition),
                    ),
                    icon: const Icon(Icons.share_location),
                    label: const Text('Compartir por WhatsApp'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Más opciones',
                  onPressed: () => shareWithSystem(trackingShareMessage(order: order, position: courierPosition)),
                  icon: const Icon(Icons.ios_share),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );
}

class _CourierMarker extends StatelessWidget {
  const _CourierMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black38)],
            ),
            child: const Icon(Icons.two_wheeler, color: Colors.white, size: 20),
          ),
        ],
      );
}
