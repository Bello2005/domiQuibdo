import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import 'finance_models.dart';

/// PDFs del restaurante: comprobante de cada pedido y reporte contable del periodo.
///
/// Se generan en el teléfono a partir de los datos del servidor; en web se descargan y en
/// Android se abren con el menú de compartir (guardar en Archivos, WhatsApp, correo…).
abstract final class FinancePdf {
  static const _selva = PdfColor.fromInt(0xFF1B5E3F);
  static const _selvaDeep = PdfColor.fromInt(0xFF0F3B2A);
  static const _rio = PdfColor.fromInt(0xFF1F6F8B);
  static const _borojo = PdfColor.fromInt(0xFFE07A2E);
  static const _ink = PdfColor.fromInt(0xFF1C2420);
  static const _muted = PdfColor.fromInt(0xFF55615A);
  static const _line = PdfColor.fromInt(0xFFE3DED4);
  static const _paper = PdfColor.fromInt(0xFFFBF8F3);

  static final _date = DateFormat("d 'de' MMMM 'de' y", 'es');
  static final _dateShort = DateFormat('dd/MM/yyyy', 'es');

  static Future<void> shareReceipt(OrderReceipt receipt) async =>
      Printing.sharePdf(bytes: await receiptBytes(receipt), filename: 'comprobante-${receipt.receiptNumber}.pdf');

  static Future<void> shareReport(FinanceReport report, String restaurantName) async => Printing.sharePdf(
    bytes: await reportBytes(report, restaurantName),
    filename:
        'reporte-${DateFormat('yyyy-MM-dd').format(report.from)}-al-${DateFormat('yyyy-MM-dd').format(report.to)}.pdf',
  );

  /// Manrope como en la app; sin internet se usa la fuente base del PDF.
  static Future<pw.ThemeData> _theme() async {
    try {
      return pw.ThemeData.withFont(
        base: await PdfGoogleFonts.manropeRegular(),
        bold: await PdfGoogleFonts.manropeBold(),
      );
    } catch (_) {
      return pw.ThemeData.base();
    }
  }

  static Future<Uint8List> receiptBytes(OrderReceipt receipt) async {
    final order = receipt.order;
    final b = receipt.breakdown;
    final doc = pw.Document(title: 'Comprobante ${receipt.receiptNumber}', author: 'DomiQuibdó');
    final stamp = switch (order.status) {
      OrderStatus.entregado => null,
      OrderStatus.cancelado => 'ANULADO',
      _ => 'EN CURSO',
    };

    doc.addPage(
      pw.Page(
        theme: await _theme(),
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _banner('Comprobante de venta', receipt.receiptNumber, receipt.restaurantName),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(40, 28, 40, 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _facts('Restaurante', [
                              receipt.restaurantName,
                              ?receipt.restaurantAddress,
                              ?receipt.restaurantPhone,
                            ]),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Expanded(
                            child: _facts('Cliente', [
                              order.customer?.name ?? 'Cliente DomiQuibdó',
                              if (order.address?.zoneName case final zone?) 'Barrio $zone',
                            ]),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Expanded(
                            child: _facts('Pedido', [
                              'Pedido #${order.id}',
                              formatDateTime(order.createdAt),
                              '${order.paymentLabel} · ${order.status.label}',
                            ]),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 26),
                      _itemsTable(order.items),
                      pw.SizedBox(height: 16),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              order.notes == null ? '' : 'Nota del cliente: ${order.notes}',
                              style: const pw.TextStyle(fontSize: 9, color: _muted),
                            ),
                          ),
                          pw.SizedBox(width: 24),
                          pw.SizedBox(
                            width: 230,
                            child: pw.Column(
                              children: [
                                _row('Subtotal comida', formatCop(b.subtotal)),
                                _row('Domicilio (repartidor)', formatCop(b.deliveryFee)),
                                pw.Divider(color: _line, height: 14),
                                _row('Total pagado por el cliente', formatCop(b.total), bold: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 26),
                      _settlement(b),
                    ],
                  ),
                ),
                pw.Spacer(),
                _footer('Emitido el ${_date.format(receipt.issuedAt.toLocal())}'),
              ],
            ),
            if (stamp != null)
              pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.5,
                  child: pw.Opacity(
                    opacity: 0.12,
                    child: pw.Text(
                      stamp,
                      style: pw.TextStyle(fontSize: 96, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> reportBytes(FinanceReport report, String restaurantName) async {
    final s = report.summary;
    final doc = pw.Document(title: 'Reporte financiero $restaurantName', author: 'DomiQuibdó');
    final period = '${_date.format(report.from)} al ${_date.format(report.to)}';
    final rate = '${(report.commissionRate * 100).round()} %';
    final activeDays = report.daily.where((d) => d.orders > 0).toList();

    doc.addPage(
      pw.MultiPage(
        theme: await _theme(),
        pageFormat: PdfPageFormat.a4,
        // MultiPage reparte entre páginas solo los hijos de primer nivel (y las tablas fila por fila),
        // así que el contenido va como lista plana y no dentro de una sola columna.
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 24),
        header: (context) => context.pageNumber == 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 22),
                child: pw.ClipRRect(
                  horizontalRadius: 16,
                  verticalRadius: 16,
                  child: _banner('Reporte financiero', period, restaurantName),
                ),
              )
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text('$restaurantName · $period', style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ),
        footer: (context) => _footer('Página ${context.pageNumber} de ${context.pagesCount}', inset: false),
        build: (context) => [
          pw.Row(
            children: [
              _kpi('Ganancia neta', formatCop(s.netEarnings), _selva),
              pw.SizedBox(width: 10),
              _kpi('Ventas brutas', formatCop(s.grossSales), _rio),
              pw.SizedBox(width: 10),
              _kpi('Comisión ($rate)', formatCop(s.commission), _borojo),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _kpi('Pedidos entregados', '${s.orders}', _muted),
              pw.SizedBox(width: 10),
              _kpi('Ticket promedio', formatCop(s.avgTicket), _muted),
              pw.SizedBox(width: 10),
              _kpi('Cancelados', '${s.cancelledOrders} · ${formatCop(s.cancelledAmount)}', _muted),
            ],
          ),
          pw.SizedBox(height: 22),
          _heading('Medios de pago'),
          _table(
            headers: ['Medio', 'Pedidos', 'Ventas brutas'],
            rows: [
              for (final m in report.paymentMethods) [m.label, '${m.orders}', formatCop(m.amount)],
            ],
          ),
          if (report.topDishes.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _heading('Platos más vendidos'),
            _table(
              headers: ['Plato', 'Unidades', 'Ventas'],
              rows: [
                for (final d in report.topDishes) [d.name, '${d.quantity}', formatCop(d.revenue)],
              ],
            ),
          ],
          pw.SizedBox(height: 18),
          _heading('Ventas por día'),
          if (activeDays.isEmpty)
            pw.Text('Sin ventas en el periodo.', style: const pw.TextStyle(color: _muted))
          else
            _table(
              headers: ['Fecha', 'Pedidos', 'Ventas brutas', 'Comisión', 'Ganancia neta'],
              rows: [
                for (final d in activeDays)
                  [
                    _dateShort.format(d.date),
                    '${d.orders}',
                    formatCop(d.gross),
                    formatCop(d.gross - d.net),
                    formatCop(d.net),
                  ],
              ],
            ),
          pw.SizedBox(height: 18),
          _heading('Libro de movimientos'),
          _table(
            headers: ['Comprobante', 'Fecha', 'Cliente', 'Estado', 'Bruto', 'Comisión', 'Neto'],
            rows: [
              for (final m in report.movements)
                [
                  m.receiptNumber,
                  formatDateTime(m.createdAt),
                  m.customer ?? '—',
                  m.statusLabel,
                  formatCop(m.breakdown.subtotal),
                  formatCop(m.breakdown.commission),
                  formatCop(m.breakdown.net),
                ],
            ],
            fontSize: 8,
          ),
          if (report.movements.length >= 100)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                'Se muestran los 100 movimientos más recientes; los totales incluyen todo el periodo.',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _banner(String title, String subtitle, String restaurant) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(40, 34, 40, 28),
    decoration: const pw.BoxDecoration(
      gradient: pw.LinearGradient(
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
        colors: [_selvaDeep, _selva, _rio],
        stops: [0, 0.45, 1],
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // La marca nunca se parte; el texto de la derecha (p. ej. un periodo largo) es el que cede.
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DomiQuibdó',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(restaurant, style: const pw.TextStyle(color: PdfColor(1, 1, 1, 0.8), fontSize: 11)),
          ],
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.75), fontSize: 9, letterSpacing: 1.2),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                subtitle,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _facts(String title, List<String> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: _muted, letterSpacing: 1)),
      pw.SizedBox(height: 4),
      for (final (i, line) in lines.indexed)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            line,
            style: i == 0
                ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)
                : const pw.TextStyle(fontSize: 9.5, color: _muted),
          ),
        ),
    ],
  );

  static pw.Widget _itemsTable(List<OrderItem> items) => _table(
    headers: ['Cant.', 'Producto', 'Precio unit.', 'Subtotal'],
    rows: [
      for (final item in items) ['${item.quantity}', item.name, formatCop(item.unitPrice), formatCop(item.subtotal)],
    ],
    columnWidths: const {
      0: pw.FixedColumnWidth(40),
      1: pw.FlexColumnWidth(),
      2: pw.FixedColumnWidth(90),
      3: pw.FixedColumnWidth(90),
    },
  );

  static pw.Widget _settlement(OrderBreakdown b) => pw.Container(
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: _paper,
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(color: _line),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'Liquidación para el restaurante',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _selvaDeep),
        ),
        pw.SizedBox(height: 10),
        if (b.countsAsSale) ...[
          _row('Venta bruta (comida)', formatCop(b.subtotal)),
          _row('Comisión DomiQuibdó (${(b.commissionRate * 100).round()} %)', '- ${formatCop(b.commission)}'),
          pw.Divider(color: _line, height: 14),
          _row('Ganancia neta', formatCop(b.net), bold: true, color: _selva),
        ] else
          pw.Text(
            'Este pedido no está entregado, así que todavía no cuenta como venta ni genera comisión.',
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
      ],
    ),
  );

  static pw.Widget _row(String label, String value, {bool bold = false, PdfColor color = _ink}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static pw.Widget _kpi(String label, String value, PdfColor accent) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _paper, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Row(
        children: [
          // Barra de acento (un borde de un solo lado no admite esquinas redondeadas en el PDF).
          pw.Container(
            width: 3,
            height: 30,
            decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(2)),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                pw.SizedBox(height: 4),
                pw.Text(
                  value,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _selvaDeep),
    ),
  );

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
    double fontSize = 9.5,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    columnWidths: columnWidths,
    border: null,
    headerStyle: pw.TextStyle(fontSize: fontSize - 0.5, fontWeight: pw.FontWeight.bold, color: _selvaDeep),
    headerDecoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _selva, width: 1.2)),
    ),
    cellStyle: pw.TextStyle(fontSize: fontSize, color: _ink),
    rowDecoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
    ),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    // Texto a la izquierda; cantidades y montos a la derecha para que se puedan sumar con la vista.
    cellAlignments: {
      for (var i = 0; i < headers.length; i++)
        i: rows.isNotEmpty && RegExp(r'^[-\d$.,\s%]+$').hasMatch(rows.first[i])
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    },
    headerAlignments: {
      for (var i = 0; i < headers.length; i++)
        i: rows.isNotEmpty && RegExp(r'^[-\d$.,\s%]+$').hasMatch(rows.first[i])
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    },
  );

  static pw.Widget _footer(String left, {bool inset = true}) => pw.Container(
    margin: inset ? const pw.EdgeInsets.fromLTRB(40, 16, 40, 24) : const pw.EdgeInsets.only(top: 16),
    padding: const pw.EdgeInsets.only(top: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Documento soporte generado por DomiQuibdó. No reemplaza la factura electrónica de la DIAN.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        pw.Text(left, style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );
}
