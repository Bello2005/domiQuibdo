import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
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
  final _map = MapController();

  /// Última posición del repartidor con la que se encuadró el mapa.
  LatLng? _framedCourier;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Mantiene a la vista al repartidor y al destino mientras el repartidor avanza.
  void _followCourier(LatLng courier, LatLng destination) {
    if (courier == _framedCourier) {
      return;
    }
    _framedCourier = courier;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: [courier, destination],
          padding: const EdgeInsets.fromLTRB(56, 140, 56, 320),
          maxZoom: 17,
        ),
      );
    });
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
    if (courierAt != null) {
      _followCourier(courierAt, destination.position);
    }

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
              mapController: _map,
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
                    polylines: [Polyline(points: route, strokeWidth: 6, color: scheme.primary.withValues(alpha: 0.45))],
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
                      Marker(
                        point: courierAt,
                        width: 56,
                        height: 56,
                        child: _CourierMarker(color: scheme.primary),
                      ),
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
                    Glass(
                      blur: true,
                      radius: 24,
                      child: SizedBox.square(
                        dimension: 48,
                        child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                      ),
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
      CourierPosition(hasFix: true, live: true) => (Icons.two_wheeler, 'Llega en ~${real.etaMin ?? 1} min'),
      CourierPosition(hasFix: true) => (Icons.gps_not_fixed, 'Buscando señal…'),
      _ => (Icons.hourglass_top, 'Esperando ubicación…'),
    };

    return Glass(
      blur: true,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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

/// Etapas de la entrega vistas desde el repartidor.
enum CourierPhase {
  atRestaurant('Llegó al restaurante', Icons.storefront_rounded),
  onTheWay('En camino', Icons.two_wheeler_rounded),
  delivered('Entregó', Icons.check_circle_rounded);

  const CourierPhase(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A esta distancia del restaurante se considera que el repartidor todavía está recogiendo el pedido.
const _pickupRadiusMeters = 100;

/// Etapa actual: entregado, en camino (ya se alejó del restaurante) o recién llegado a recoger.
CourierPhase courierPhase(Order order, LatLng? courier) {
  if (order.status == OrderStatus.entregado) {
    return CourierPhase.delivered;
  }
  final restaurant = order.restaurant?.position;
  if (courier != null && restaurant != null) {
    final away = const Distance().as(LengthUnit.Meter, restaurant, courier);
    if (away > _pickupRadiusMeters) {
      return CourierPhase.onTheWay;
    }
  }
  return CourierPhase.atRestaurant;
}

/// Tres pasos: llegó al restaurante, en camino, entregó.
class CourierTimeline extends StatelessWidget {
  const CourierTimeline({super.key, required this.phase});

  final CourierPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final steps = CourierPhase.values;

    Widget line(bool done) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: done ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps) ...[
          if (step != steps.first) line(step.index <= phase.index),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.index <= phase.index ? scheme.primary : scheme.surfaceContainerHighest,
                  boxShadow: step == phase
                      ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Icon(
                  step.icon,
                  size: 18,
                  color: step.index <= phase.index ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: step == phase ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: step == phase ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
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

    return GlassCard(
      blur: true,
      radius: 30,
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
            const SizedBox(height: 14),
            CourierTimeline(phase: courierPhase(order, courierPosition)),
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
                    onPressed: () =>
                        shareViaWhatsApp(context, trackingShareMessage(order: order, position: courierPosition)),
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
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.22)!, color],
      ),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [BoxShadow(blurRadius: 12, offset: const Offset(0, 5), color: color.withValues(alpha: 0.45))],
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

/// Marcador del repartidor con un pulso continuo, para que se note que la posición es en vivo.
class _CourierMarker extends StatefulWidget {
  const _CourierMarker({required this.color});

  final Color color;

  @override
  State<_CourierMarker> createState() => _CourierMarkerState();
}

class _CourierMarkerState extends State<_CourierMarker> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Transform.scale(
            scale: 0.6 + _pulse.value * 0.6,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 * (1 - _pulse.value)),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.2)!, color],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(blurRadius: 14, offset: const Offset(0, 6), color: color.withValues(alpha: 0.5))],
          ),
          child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}
