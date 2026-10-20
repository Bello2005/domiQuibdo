import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/skeleton.dart';
import 'finance_charts.dart';
import 'finance_models.dart';
import 'finance_pdf.dart';
import 'restaurant_repository.dart';

/// Finanzas del restaurante: ganancia neta, ventas, comisión, gráficas y libro de movimientos
/// con comprobantes en PDF. Todo se calcula en el servidor a partir de los pedidos entregados.
class RestaurantFinanceScreen extends ConsumerWidget {
  const RestaurantFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(financeReportProvider);
    final days = ref.watch(financeDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          IconButton(
            tooltip: 'Descargar reporte PDF',
            onPressed: report.valueOrNull == null ? null : () => _downloadReport(context, ref, report.value!),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(financeReportProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 960,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(financeReportProvider.future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 32 + bottomBarInset(context)),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 días')),
                  ButtonSegment(value: 30, label: Text('30 días')),
                  ButtonSegment(value: 90, label: Text('90 días')),
                ],
                selected: {days},
                onSelectionChanged: (value) => ref.read(financeDaysProvider.notifier).state = value.first,
              ),
              const SizedBox(height: 16),
              ...report.when(
                skipLoadingOnReload: true,
                loading: () => const [_FinanceSkeleton()],
                error: (error, _) => [
                  ErrorView(message: error.toString(), onRetry: () => ref.invalidate(financeReportProvider)),
                ],
                data: (data) => _content(context, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FinanceReport report) {
    final colors = FinanceColors.of(context);
    final s = report.summary;
    final p = report.previous;
    final rate = '${(report.commissionRate * 100).round()} %';
    final peak = report.hourly.fold<HourlySales?>(null, (best, h) => best == null || h.orders > best.orders ? h : best);

    if (s.orders == 0 && report.movements.isEmpty) {
      return const [
        SizedBox(height: 40),
        EmptyView(
          icon: Icons.insights_outlined,
          title: 'Aún no hay ventas en este periodo',
          message: 'Cuando entregues pedidos, aquí verás tus ganancias, gráficas y comprobantes.',
        ),
      ];
    }

    return [
      _FadeIn(index: 0, child: _NetHero(report: report)),
      const SizedBox(height: 14),
      _FadeIn(
        index: 1,
        child: _KpiGrid(
          tiles: [
            _Kpi(Icons.receipt_long, 'Pedidos entregados', '${s.orders}', _delta(s.orders, p.orders)),
            _Kpi(
              Icons.confirmation_number_outlined,
              'Ticket promedio',
              formatCop(s.avgTicket),
              _delta(s.avgTicket, p.avgTicket),
            ),
            _Kpi(Icons.restaurant, 'Platos vendidos', '${s.itemsSold}', _delta(s.itemsSold, p.itemsSold)),
            _Kpi(
              Icons.cancel_outlined,
              'Cancelados',
              '${s.cancelledOrders}',
              _delta(s.cancelledOrders, p.cancelledOrders),
              higherIsBetter: false,
              footnote: s.cancelledAmount > 0 ? '${formatCopCompact(s.cancelledAmount)} sin vender' : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _FadeIn(
        index: 2,
        child: _ChartCard(
          title: 'Ventas por día',
          subtitle: 'Toca la gráfica para ver el detalle de cada día',
          legend: ChartLegend(entries: [(colors.gross, 'Ventas brutas'), (colors.net, 'Ganancia neta')]),
          child: SizedBox(height: 230, child: SalesTrendChart(daily: report.daily)),
        ),
      ),
      const SizedBox(height: 14),
      _FadeIn(
        index: 3,
        child: _TwoUp(
          left: _ChartCard(
            title: 'Cómo te pagan',
            subtitle: 'Ventas brutas por medio de pago',
            child: PaymentDonut(methods: report.paymentMethods),
          ),
          right: _ChartCard(
            title: 'Horas pico',
            subtitle: peak == null || peak.orders == 0
                ? 'Pedidos entregados por hora'
                : 'Tu mejor hora es a las ${PeakHoursChart.hourName(peak.hour)}',
            child: SizedBox(height: 150, child: PeakHoursChart(hourly: report.hourly)),
          ),
        ),
      ),
      if (report.topDishes.isNotEmpty) ...[
        const SizedBox(height: 14),
        _FadeIn(
          index: 4,
          child: _ChartCard(
            title: 'Platos estrella',
            subtitle: 'Los que más dinero te dejan',
            child: TopDishesList(dishes: report.topDishes),
          ),
        ),
      ],
      const SizedBox(height: 14),
      _FadeIn(index: 5, child: _Ledger(report: report)),
      const SizedBox(height: 14),
      InfoBanner(
        icon: Icons.info_outline,
        text:
            report.commissionRate == 0
                ? 'Solo los pedidos entregados cuentan como venta. Recibes el 100 % de tu carta: '
                    'DomiQuibdó no te cobra comisión, su tarifa la paga el cliente. El domicilio '
                    '(${formatCop(s.deliveryFees)} en el periodo) es del repartidor.'
                : 'Solo los pedidos entregados cuentan como venta. DomiQuibdó cobra el $rate de la comida; '
                    'el domicilio (${formatCop(s.deliveryFees)} en el periodo) es del repartidor.',
      ),
    ];
  }
}

/// Cambio porcentual contra el periodo anterior; null si antes no había con qué comparar.
double? _delta(num current, num previous) => previous == 0 ? null : (current - previous) / previous;

Future<void> _downloadReport(BuildContext context, WidgetRef ref, FinanceReport report) async {
  final restaurants = await ref.read(ownerRestaurantsProvider.future).catchError((_) => <Restaurant>[]);
  final name = restaurants.isEmpty ? 'Mi restaurante' : restaurants.map((r) => r.name).join(' · ');
  try {
    await FinancePdf.shareReport(report, name);
  } catch (_) {
    if (context.mounted) showMessage(context, 'No pudimos generar el reporte. Intenta de nuevo.');
  }
}

/// Pide el comprobante al servidor y abre el PDF (descarga en web, compartir en Android).
Future<void> downloadReceipt(BuildContext context, WidgetRef ref, int orderId) async {
  showMessage(context, 'Preparando el comprobante…');
  try {
    final receipt = await ref.read(restaurantOwnerRepositoryProvider).receipt(orderId);
    await FinancePdf.shareReceipt(receipt);
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } catch (_) {
    if (context.mounted) showMessage(context, 'No pudimos generar el comprobante. Intenta de nuevo.');
  }
}

/// Ganancia neta en grande sobre el degradado de marca, con la tendencia de fondo.
class _NetHero extends StatelessWidget {
  const _NetHero({required this.report});

  final FinanceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = report.summary;
    final delta = _delta(s.netEarnings, report.previous.netEarnings);
    final onBrand = Colors.white.withValues(alpha: 0.78);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: AppColors.brandGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: const [BoxShadow(color: Color(0x401B5E3F), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.savings_outlined, color: onBrand, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ganancia neta · últimos ${report.days} días',
                        style: theme.textTheme.labelMedium?.copyWith(color: onBrand),
                      ),
                    ),
                    _DeltaPill(delta: delta, onDark: true),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  key: ValueKey(report.days),
                  tween: Tween(begin: 0, end: s.netEarnings),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCop(value),
                      style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.commissionRate == 0
                      ? 'Recibes el 100 % de tu carta: sin comisión'
                      : 'Lo que te queda después de la comisión de DomiQuibdó',
                  style: theme.textTheme.bodySmall?.copyWith(color: onBrand),
                ),
                // Tendencia en su propio espacio: nunca se monta sobre el texto ni los totales.
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.55,
                      child: Sparkline(values: [for (final d in report.daily) d.net], color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroStat(label: 'Ventas brutas', value: formatCop(s.grossSales)),
                      ),
                      Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _HeroStat(
                          label: 'Comisión (${(report.commissionRate * 100).round()} %)',
                          value: s.commission == 0 ? r'$0' : '- ${formatCop(s.commission)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: text.titleMedium?.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// "▲ 12 %" frente al periodo anterior. Con flecha y signo, no solo color.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta, this.higherIsBetter = true, this.onDark = false});

  final double? delta;
  final bool higherIsBetter;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = this.delta;
    final isUp = delta != null && delta >= 0;
    final isGood = delta != null && (isUp == higherIsBetter || delta == 0);
    final scheme = theme.colorScheme;

    final (Color fg, Color bg) = onDark
        ? (Colors.white, Colors.white.withValues(alpha: 0.18))
        : delta == null
        ? (scheme.onSurfaceVariant, scheme.onSurfaceVariant.withValues(alpha: 0.10))
        : isGood
        ? (scheme.primary, scheme.primary.withValues(alpha: 0.12))
        : (scheme.error, scheme.error.withValues(alpha: 0.12));

    final label = delta == null ? 'Nuevo' : '${(delta.abs() * 100).round()} %';

    return Tooltip(
      message: delta == null ? 'Sin ventas en el periodo anterior para comparar' : 'Comparado con el periodo anterior',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (delta != null)
              Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: fg),
            const SizedBox(width: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.icon, this.label, this.value, this.delta, {this.higherIsBetter = true, this.footnote});

  final IconData icon;
  final String label;
  final String value;
  final double? delta;
  final bool higherIsBetter;
  final String? footnote;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.tiles});

  final List<_Kpi> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 4 : 2;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tile in tiles)
            SizedBox(
              width: width,
              child: _KpiTile(tile: tile),
            ),
        ],
      );
    },
  );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.tile});

  final _Kpi tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: Icon(tile.icon, size: 18, color: scheme.primary),
                ),
                const Spacer(),
                _DeltaPill(delta: tile.delta, higherIsBetter: tile.higherIsBetter),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(tile.value, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: 2),
            Text(tile.label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text(
              tile.footnote ?? 'vs. periodo anterior',
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.subtitle, this.legend});

  final String title;
  final String? subtitle;
  final Widget? legend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (legend != null) ...[const SizedBox(height: 10), legend!],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Dos tarjetas lado a lado en pantallas anchas; una debajo de otra en el celular.
class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 700
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left),
                const SizedBox(width: 14),
                Expanded(child: right),
              ],
            ),
          )
        : Column(children: [left, const SizedBox(height: 14), right]),
  );
}

/// Libro de movimientos: cada pedido del periodo con su bruto, comisión y neto.
class _Ledger extends StatefulWidget {
  const _Ledger({required this.report});

  final FinanceReport report;

  @override
  State<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends State<_Ledger> {
  static const _collapsed = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movements = widget.report.movements;
    final visible = _expanded ? movements : movements.take(_collapsed).toList();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Libro de movimientos', style: theme.textTheme.titleMedium),
                      Text(
                        'Toca un pedido para ver y descargar su comprobante',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${movements.length}',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (i, movement) in visible.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _MovementRow(movement: movement),
            ],
            if (movements.length > _collapsed)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Ver menos' : 'Ver los ${movements.length} movimientos'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends ConsumerWidget {
  const _MovementRow({required this.movement});

  final FinanceMovement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSale = movement.breakdown.countsAsSale;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        // Por encima de la barra de pestañas flotante.
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => _ReceiptSheet(movement: movement),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isSale ? scheme.primary : scheme.error).withValues(alpha: 0.10),
              ),
              child: Icon(
                isSale ? Icons.payments_outlined : Icons.block,
                size: 18,
                color: isSale ? scheme.primary : scheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.customer ?? 'Pedido #${movement.orderId}',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${movement.receiptNumber} · ${formatDateTime(movement.createdAt)}',
                    style: muted,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isSale ? '+ ${formatCop(movement.breakdown.net)}' : 'Anulado',
                  style: theme.textTheme.titleSmall?.copyWith(color: isSale ? null : scheme.onSurfaceVariant),
                ),
                Text(
                  isSale ? 'de ${formatCop(movement.breakdown.subtotal)}' : formatCop(movement.breakdown.subtotal),
                  style: muted?.copyWith(decoration: isSale ? null : TextDecoration.lineThrough),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptSheet extends ConsumerStatefulWidget {
  const _ReceiptSheet({required this.movement});

  final FinanceMovement movement;

  @override
  ConsumerState<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<_ReceiptSheet> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    await downloadReceipt(context, ref, widget.movement.orderId);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.movement;
    final b = m.breakdown;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comprobante ${m.receiptNumber}', style: theme.textTheme.titleLarge),
                      Text(
                        '${m.customer ?? 'Cliente'} · ${formatDateTime(m.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(avatar: Icon(m.status.icon, size: 16), label: Text(m.statusLabel)),
              ],
            ),
            const SizedBox(height: 16),
            Glass(
              radius: 22,
              shadow: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SummaryRow(
                    label:
                        '${m.itemsCount} ${m.itemsCount == 1 ? 'producto' : 'productos'} · '
                        '${paymentMethods[m.paymentMethod]?.$1 ?? m.paymentMethod}',
                    value: '',
                  ),
                  SummaryRow(label: 'Venta bruta (comida)', value: formatCop(b.subtotal)),
                  if (b.commission > 0)
                    SummaryRow(
                      label: 'Comisión DomiQuibdó (${(b.commissionRate * 100).round()} %)',
                      value: '- ${formatCop(b.commission)}',
                    ),
                  SummaryRow(label: 'Domicilio (del repartidor)', value: formatCop(b.deliveryFee)),
                  if (b.serviceFee + b.paymentFee > 0)
                    SummaryRow(
                      label: 'Tarifa DomiQuibdó (la paga el cliente)',
                      value: formatCop(b.serviceFee + b.paymentFee),
                    ),
                  const Divider(height: 20),
                  SummaryRow(label: 'Ganancia neta', value: formatCop(b.net), emphasize: true),
                ],
              ),
            ),
            if (!b.countsAsSale) ...[
              const SizedBox(height: 12),
              const InfoBanner(
                icon: Icons.block,
                text: 'Pedido cancelado: no cuenta como venta. El comprobante sale marcado como ANULADO.',
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              label: const Text('Descargar comprobante PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada escalonada: cada bloque aparece y sube un poco después del anterior.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 450 + index * 90),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
    ),
    child: child,
  );
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton();

  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Column(
      children: [
        SkeletonBox(height: 210, radius: 28),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 130, radius: 24)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 130, radius: 24)),
          ],
        ),
        SizedBox(height: 14),
        SkeletonBox(height: 300, radius: 24),
      ],
    ),
  );
}
