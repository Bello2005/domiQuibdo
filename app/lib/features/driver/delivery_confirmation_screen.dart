import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../orders/order_repository.dart';
import '../safety/share_location.dart';

/// Pantalla de confirmación de entrega del repartidor. Mientras no esté en la puerta muestra
/// cuánto le falta; al llegar se desbloquea el código (teclado propio de 4 dígitos), con el cobro
/// en efectivo bien a la vista. El servidor vuelve a comprobar la distancia al validar.
class DeliveryConfirmationScreen extends ConsumerStatefulWidget {
  const DeliveryConfirmationScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends ConsumerState<DeliveryConfirmationScreen>
    with SingleTickerProviderStateMixin {
  static const _codeLength = 4;

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  String _code = '';
  bool _busy = false;
  bool _delivered = false;
  String? _error;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _type(String digit) {
    if (_busy || _code.length >= _codeLength) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _codeLength) {
      unawaited(_submit());
    }
  }

  void _erase() {
    if (_busy || _code.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _code = _code.substring(0, _code.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(orderRepositoryProvider).deliver(widget.orderId, _code);
      HapticFeedback.heavyImpact();
      ref
        ..invalidate(orderDetailProvider(widget.orderId))
        ..invalidate(driverOrdersProvider);
      if (mounted) {
        setState(() => _delivered = true);
        await Future<void>.delayed(const Duration(milliseconds: 2600));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } on ApiException catch (e) {
      HapticFeedback.vibrate();
      if (mounted) {
        setState(() {
          _error = e.message;
          _code = '';
        });
        unawaited(_shake.forward(from: 0));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId)).valueOrNull;
    final courier = ref.watch(courierPositionProvider(widget.orderId)).valueOrNull;
    final atDelivery = courier != null && courier.hasFix && courier.live && courier.hasArrived;

    return PeriodicRefresh(
      interval: const Duration(seconds: 3),
      onTick: (ref) => ref.invalidate(courierPositionProvider(widget.orderId)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close_rounded)),
          title: Text('Confirmar entrega · #${widget.orderId}'),
        ),
        body: order == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  child: _delivered
                      ? _DeliveredView(key: const ValueKey('done'), order: order)
                      : atDelivery
                      ? _CodeEntry(
                          key: const ValueKey('code'),
                          order: order,
                          code: _code,
                          length: _codeLength,
                          error: _error,
                          busy: _busy,
                          shake: _shake,
                          onDigit: _type,
                          onErase: _erase,
                        )
                      : _Approaching(key: const ValueKey('approach'), order: order, courier: courier),
                ),
              ),
      ),
    );
  }
}

/// Aún no llegó: anillo de proximidad con la distancia que falta.
class _Approaching extends StatelessWidget {
  const _Approaching({super.key, required this.order, required this.courier});

  final Order order;
  final CourierPosition? courier;

  /// Desde esta distancia el anillo empieza a llenarse.
  static const _fullRingMeters = 600;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasSignal = courier != null && courier!.hasFix && courier!.live;
    final distance = courier?.distanceM;
    final progress = (!hasSignal || distance == null)
        ? 0.0
        : (1 - ((distance - CourierPosition.arrivedMeters) / (_fullRingMeters - CourierPosition.arrivedMeters))).clamp(
            0.0,
            1.0,
          );

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomBarInset(context)),
      children: [
        const SizedBox(height: 8),
        Center(
          child: SizedBox.square(
            dimension: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    size: const Size.square(240),
                    painter: _ProximityRing(progress: value, color: scheme.primary, track: scheme.outlineVariant),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSignal ? Icons.near_me_rounded : Icons.gps_not_fixed_rounded,
                      size: 34,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasSignal && distance != null ? formatDistance(distance) : '—',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      hasSignal ? 'para llegar' : 'Esperando tu ubicación…',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Casi llegas', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'El código del cliente se desbloquea cuando estés en el punto de entrega '
          '(a menos de ${CourierPosition.arrivedMeters} m).',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        _DestinationCard(order: order),
        const SizedBox(height: 14),
        if (order.address != null)
          OutlinedButton.icon(
            onPressed: () => openDirections(order.address!.position),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Cómo llegar a la entrega'),
          ),
      ],
    );
  }
}

/// Dirección y cliente, en un bloque compacto.
class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final address = order.address;

    return Glass(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.borojo.withValues(alpha: 0.15)),
            child: Icon(address?.tipo.icon ?? Icons.home_rounded, color: AppColors.borojo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customer?.name ?? 'Cliente', style: theme.textTheme.titleMedium),
                Text(
                  [if (address != null) address.title, if (address?.detalle != null) address!.detalle!].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo que se llena a medida que el repartidor se acerca.
class _ProximityRing extends CustomPainter {
  const _ProximityRing({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = track.withValues(alpha: 0.35),
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [color.withValues(alpha: 0.55), color],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_ProximityRing oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.track != track;
}

/// Ya está en la puerta: cobro, casillas del código y teclado.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    super.key,
    required this.order,
    required this.code,
    required this.length,
    required this.error,
    required this.busy,
    required this.shake,
    required this.onDigit,
    required this.onErase,
  });

  final Order order;
  final String code;
  final int length;
  final String? error;
  final bool busy;
  final Animation<double> shake;
  final ValueChanged<String> onDigit;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.where_to_vote_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Llegaste al punto de entrega',
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PaymentBadge(order: order),
              const SizedBox(height: 18),
              Text('Pídele al cliente su código', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Entrega el pedido solo si coincide.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              AnimatedBuilder(
                animation: shake,
                builder: (context, child) {
                  final dx = math.sin(shake.value * math.pi * 6) * 14 * (1 - shake.value);
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < length; i++)
                      _CodeCell(
                        digit: i < code.length ? code[i] : null,
                        active: i == code.length && !busy,
                        error: error != null,
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: error == null
                    ? const SizedBox(height: 28)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ],
          ),
        ),
        _Keypad(onDigit: onDigit, onErase: onErase, enabled: !busy),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
          child: SizedBox(
            height: 28,
            child: busy
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Validando código…', style: theme.textTheme.bodyMedium),
                    ],
                  )
                : Text(
                    'Se valida solo al escribir los 4 dígitos.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Qué debe hacer el repartidor con el dinero: cobrar en efectivo o no cobrar nada.
class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final online = order.isOnlinePayment;
    final tone = online ? scheme.primary : AppColors.borojo;

    return Glass(
      radius: 28,
      tint: tone,
      tintStrength: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.18)),
            child: Icon(online ? Icons.verified_rounded : Icons.payments_rounded, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'Pagado en línea' : 'Cobra en efectivo',
                  style: theme.textTheme.labelLarge?.copyWith(color: tone),
                ),
                Text(
                  online ? 'No cobres nada al cliente' : formatCop(order.total),
                  style: online
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una casilla del código: se ilumina la que se está escribiendo y se pone roja si hubo error.
class _CodeCell extends StatelessWidget {
  const _CodeCell({required this.digit, required this.active, required this.error});

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = error ? scheme.error : (active ? scheme.primary : Colors.white.withValues(alpha: 0.9));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 62,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surface.withValues(alpha: 0.96), scheme.surface.withValues(alpha: 0.72)],
        ),
        border: Border.all(color: border, width: active || error ? 2 : 1.2),
        boxShadow: [
          BoxShadow(
            color: (error ? scheme.error : scheme.primary).withValues(alpha: active || error ? 0.22 : 0.08),
            blurRadius: active || error ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: digit == null
            ? (active
                  ? Container(key: const ValueKey('caret'), width: 2, height: 30, color: scheme.primary)
                  : const SizedBox.shrink())
            : Text(
                digit!,
                key: ValueKey(digit),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}

/// Teclado numérico grande, para usar con una mano y con guantes.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onErase, required this.enabled});

  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: key.isEmpty
                              ? const SizedBox(height: 62)
                              : _Key(label: key, enabled: enabled, onTap: key == '⌫' ? onErase : () => onDigit(key)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label == '⌫' ? 'Borrar' : label,
      child: Glass(
        radius: 31,
        shadow: false,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 62,
          child: Center(
            child: label == '⌫'
                ? Icon(Icons.backspace_outlined, color: theme.colorScheme.onSurfaceVariant)
                : Text(label, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// Éxito: sello de entregado con un destello, y el resumen de lo entregado.
class _DeliveredView extends StatelessWidget {
  const _DeliveredView({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, size: 72, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text('¡Entrega confirmada!', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              order.isOnlinePayment
                  ? 'Pedido #${order.id} · pagado en línea'
                  : 'Pedido #${order.id} · ${formatCop(order.total)} cobrados',
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Buen trabajo, ${order.repartidor?.name.split(' ').first ?? 'repartidor'}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
