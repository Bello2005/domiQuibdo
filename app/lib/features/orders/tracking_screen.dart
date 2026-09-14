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

/// Tracking con GPS simulado: el marcador recorre `delivery_mock_route`
/// avanzando un punto cada [AppConfig.mockStepDuration].
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> with SingleTickerProviderStateMixin {
  AnimationController? _progress;
  bool _deliveredShown = false;

  @override
  void dispose() {
    _progress?.dispose();
    super.dispose();
  }

  void _startAnimation(List<LatLng> route) {
    if (_progress != null || route.length < 2) return;
    _progress = AnimationController(vsync: this, duration: AppConfig.mockStepDuration * (route.length - 1))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      })
      ..forward();
  }

  /// Posición interpolada sobre la ruta para que el movimiento sea fluido.
  LatLng _positionAt(List<LatLng> route, double t) {
    if (route.length < 2) return route.first;
    final segments = route.length - 1;
    final scaled = t * segments;
    final i = scaled.floor().clamp(0, segments - 1);
    final f = scaled - i;
    final a = route[i];
    final b = route[i + 1];
    return LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f);
  }

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

    ref.listen(orderDetailProvider(widget.orderId), (_, next) {
      final order = next.valueOrNull;
      if (order?.status == OrderStatus.entregado && !_deliveredShown) {
        _deliveredShown = true;
        _showDelivered();
      }
    });

    final order = orderAsync.valueOrNull;
    final route = routeAsync.valueOrNull;

    if (order == null || route == null || route.isEmpty) {
      final error = orderAsync.error ?? routeAsync.error;
      return Scaffold(
        appBar: AppBar(),
        body: error != null
            ? ErrorView(message: error.toString(), onRetry: () => ref.invalidate(orderRouteProvider(widget.orderId)))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    _startAnimation(route);
    final progress = _progress ?? const AlwaysStoppedAnimation(1.0);
    final scheme = Theme.of(context).colorScheme;
    final restaurant = order.restaurant!;
    final destination = order.address!;

    return Scaffold(
      body: PeriodicRefresh(
        interval: const Duration(seconds: 4),
        onTick: (ref) => ref.invalidate(orderDetailProvider(widget.orderId)),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [restaurant.position, destination.position, ...route],
                  padding: const EdgeInsets.fromLTRB(56, 140, 56, 320),
                  maxZoom: 17,
                ),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmUserAgent),
                PolylineLayer(
                  polylines: [
                    Polyline(points: route, strokeWidth: 6, color: scheme.primary.withValues(alpha: 0.3)),
                  ],
                ),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) {
                    final t = progress.value;
                    final passed = (t * (route.length - 1)).floor() + 1;
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [...route.take(passed), _positionAt(route, t)],
                          strokeWidth: 6,
                          color: scheme.primary,
                        ),
                      ],
                    );
                  },
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
                  ],
                ),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => MarkerLayer(
                    markers: [
                      Marker(
                        point: _positionAt(route, progress.value),
                        width: 56,
                        height: 56,
                        child: _CourierMarker(color: scheme.primary),
                      ),
                    ],
                  ),
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
                    Expanded(
                      child: AnimatedBuilder(
                        animation: progress,
                        builder: (context, _) => _EtaPill(progress: progress.value, steps: route.length - 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sos,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => showSosSheet(
                        context,
                        shareMessage: trackingShareMessage(order: order, position: _positionAt(route, progress.value)),
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
                    child: _TrackingPanel(
                      order: order,
                      arrived: progress.isCompleted,
                      currentPosition: () => _positionAt(route, progress.value),
                    ),
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
  const _EtaPill({required this.progress, required this.steps});

  final double progress;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrived = progress >= 1;
    // Sprint 0: ETA simulado (~2 min por tramo de la ruta).
    final minutes = ((1 - progress) * steps * 2).ceil();

    return Material(
      elevation: 3,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(arrived ? Icons.where_to_vote : Icons.two_wheeler, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                arrived ? 'Tu repartidor llegó' : 'En camino · llega en ~$minutes min',
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.order, required this.arrived, required this.currentPosition});

  final Order order;
  final bool arrived;
  final LatLng Function() currentPosition;

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
                      trackingShareMessage(order: order, position: currentPosition()),
                    ),
                    icon: const Icon(Icons.share_location),
                    label: const Text('Compartir por WhatsApp'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Más opciones',
                  onPressed: () => shareWithSystem(trackingShareMessage(order: order, position: currentPosition())),
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
