import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import 'finance_models.dart';

/// Colores de las series de Finanzas. Validados para daltonismo (verde ≠ azul también con
/// protanopía/deuteranopía) y con su propio paso en modo oscuro; no se invierten automáticamente.
class FinanceColors {
  const FinanceColors._(this.net, this.gross);

  /// Ganancia neta (selva).
  final Color net;

  /// Ventas brutas (río).
  final Color gross;

  static const _light = FinanceColors._(Color(0xFF1E8C55), Color(0xFF2F78C8));
  static const _dark = FinanceColors._(Color(0xFF38A872), Color(0xFF5A90DA));

  static FinanceColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

final _dayLabel = DateFormat('d MMM', 'es');
final _dayLong = DateFormat("EEE d 'de' MMM", 'es');

/// Tooltip opaco y legible en ambos temas.
Color _tooltipColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xF2E8F1EC) : const Color(0xF20F1F18);

Color _tooltipInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F3B2A) : Colors.white;

/// Leyenda: punto de color + texto en tinta del tema (el color nunca va en el texto).
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<(Color, String)> entries;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}

/// Ventas brutas y ganancia neta por día: dos líneas en el mismo eje (misma unidad, COP).
class SalesTrendChart extends StatelessWidget {
  const SalesTrendChart({super.key, required this.daily});

  final List<DailySales> daily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final maxY = daily.fold<double>(0, (m, d) => math.max(m, d.gross));
    final interval = _niceInterval(maxY);
    final labelEvery = math.max(1, (daily.length / 5).ceil());

    LineChartBarData series(List<double> values, Color color, {bool area = false}) => LineChartBarData(
      spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v)],
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: area,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    );

    return LineChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      LineChartData(
        minY: 0,
        maxY: interval * (maxY / interval).ceil().clamp(1, 1000),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 58,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(value == 0 ? '\$0' : formatCopCompact(value), style: muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final show = i == daily.length - 1 || (i % labelEvery == 0 && daily.length - 1 - i >= labelEvery / 2);
                if (!show || i < 0 || i >= daily.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_dayLabel.format(daily[i].date), style: muted),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, _, bar, _) => FlDotCirclePainter(
                    radius: 5,
                    color: bar.color ?? colors.net,
                    strokeWidth: 2,
                    strokeColor: theme.colorScheme.surface,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(14),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            getTooltipItems: (spots) {
              final ink = _tooltipInk(context);
              final day = daily[spots.first.x.toInt()];
              return [
                for (final (i, spot) in spots.indexed)
                  LineTooltipItem(
                    i == 0 ? '${_dayLong.format(day.date)} · ${day.orders} pedidos\n' : '',
                    TextStyle(color: ink.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: '${spot.barIndex == 0 ? 'Bruto' : 'Neto'}  ${formatCop(spot.y)}',
                        style: TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
              ];
            },
          ),
        ),
        lineBarsData: [
          series([for (final d in daily) d.gross], colors.gross),
          series([for (final d in daily) d.net], colors.net, area: true),
        ],
      ),
    );
  }
}

/// Pedidos por hora del día (solo la franja con movimiento): la hora pico va resaltada.
class PeakHoursChart extends StatelessWidget {
  const PeakHoursChart({super.key, required this.hourly});

  final List<HourlySales> hourly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.tertiary;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final active = hourly.where((h) => h.orders > 0).toList();
    final first = active.isEmpty ? 8 : math.min(active.first.hour, 10);
    final last = active.isEmpty ? 22 : math.max(active.last.hour, 20);
    final range = hourly.where((h) => h.hour >= first && h.hour <= last).toList();
    final peak = range.fold<HourlySales?>(null, (best, h) => best == null || h.orders > best.orders ? h : best);

    return BarChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 3 != 0 && hour != peak?.hour) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_hourLabel(hour), style: muted),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(14),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, rod, _) {
              final h = hourly[group.x];
              return BarTooltipItem(
                '${_hourLabel(h.hour)} – ${_hourLabel(h.hour + 1)}\n',
                TextStyle(
                  color: _tooltipInk(context).withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: '${h.orders} pedidos · ${formatCopCompact(h.gross)}',
                    style: TextStyle(color: _tooltipInk(context), fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (final h in range)
            BarChartGroupData(
              x: h.hour,
              barRods: [
                BarChartRodData(
                  toY: h.orders.toDouble(),
                  width: 10,
                  color: h == peak ? accent : accent.withValues(alpha: 0.38),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _hourLabel(int hour) {
    final h = hour % 24;
    final suffix = h < 12 ? 'am' : 'pm';
    final twelve = h % 12 == 0 ? 12 : h % 12;
    return '$twelve$suffix';
  }

  /// "7 pm" para describir la hora pico en texto.
  static String hourName(int hour) => _hourLabel(hour).replaceFirstMapped(RegExp(r'(am|pm)$'), (m) => ' ${m[1]}');
}

/// Dona de medios de pago con el total en el centro; la leyenda dice monto y porcentaje.
class PaymentDonut extends StatefulWidget {
  const PaymentDonut({super.key, required this.methods});

  final List<PaymentMethodSales> methods;

  @override
  State<PaymentDonut> createState() => _PaymentDonutState();
}

class _PaymentDonutState extends State<PaymentDonut> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final palette = [colors.net, colors.gross];
    final methods = widget.methods;
    final total = methods.fold<double>(0, (sum, m) => sum + m.amount);
    final focus = _touched == null ? null : methods[_touched!];

    return Row(
      children: [
        SizedBox.square(
          dimension: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 44,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) => setState(() {
                      final index = response?.touchedSection?.touchedSectionIndex;
                      _touched = event.isInterestedForInteractions && index != null && index >= 0 ? index : null;
                    }),
                  ),
                  sections: total == 0
                      ? [
                          PieChartSectionData(
                            value: 1,
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            radius: 18,
                            showTitle: false,
                          ),
                        ]
                      : [
                          for (final (i, m) in methods.indexed)
                            PieChartSectionData(
                              value: m.amount,
                              color: palette[i % palette.length],
                              radius: _touched == i ? 24 : 18,
                              showTitle: false,
                            ),
                        ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focus == null ? 'Total' : focus.label,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(formatCopCompact(focus?.amount ?? total), style: theme.textTheme.titleSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, m) in methods.indexed) ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.label, style: theme.textTheme.labelLarge?.copyWith(fontSize: 14))),
                    Text(
                      total == 0 ? '0 %' : '${(m.amount / total * 100).round()} %',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 2, bottom: 12),
                  child: Text(
                    '${formatCop(m.amount)} · ${m.orders} pedidos',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ranking de platos con barras horizontales que crecen al aparecer.
class TopDishesList extends StatelessWidget {
  const TopDishesList({super.key, required this.dishes});

  final List<TopDish> dishes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = FinanceColors.of(context).net;
    final best = dishes.isEmpty ? 1.0 : dishes.first.revenue;

    return Column(
      children: [
        for (final (i, dish) in dishes.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == dishes.length - 1 ? 0 : 14),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? theme.colorScheme.tertiary : theme.colorScheme.primary.withValues(alpha: 0.10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: i == 0 ? theme.colorScheme.onTertiary : theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(dish.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                          ),
                          Text(formatCop(dish.revenue), style: theme.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: dish.revenue / best),
                        duration: Duration(milliseconds: 700 + i * 120),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            color: color,
                            backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dish.quantity} vendidos',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Línea mínima de tendencia, sin ejes, para fondos y tarjetas.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => LineChart(
    duration: const Duration(milliseconds: 600),
    LineChartData(
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v)],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Intervalo "redondo" para el eje Y: 1, 2 o 5 × 10ⁿ, con unas 4 líneas de guía.
double _niceInterval(double max) {
  if (max <= 0) return 10000;
  final raw = max / 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = raw / magnitude;
  final nice = step <= 1
      ? 1
      : step <= 2
      ? 2
      : step <= 5
      ? 5
      : 10;
  return nice * magnitude;
}
