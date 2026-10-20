import 'dart:convert';

import 'package:domiquibdo/core/format.dart';
import 'package:domiquibdo/core/models.dart';
import 'package:domiquibdo/features/restaurant/finance_models.dart';
import 'package:domiquibdo/features/restaurant/finance_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> _breakdown({required bool sale}) => {
  'subtotal': 30000,
  'delivery_fee': 3000,
  'total': 33000,
  'commission_rate': 0.1,
  'commission': sale ? 3000 : 0,
  'net': sale ? 27000 : 0,
  'counts_as_sale': sale,
};

/// Respuesta de `GET /restaurant/finances` con [movements] pedidos.
Map<String, dynamic> _reportJson({int movements = 3}) => {
  'period': {'days': 7, 'from': '2026-10-14', 'to': '2026-10-20', 'timezone': 'America/Bogota'},
  'commission_rate': 0.1,
  'summary': {
    'gross_sales': 60000,
    'commission': 6000,
    'net_earnings': 54000,
    'orders': 2,
    'avg_ticket': 30000,
    'items_sold': 4,
    'delivery_fees': 6000,
    'cancelled_orders': 1,
    'cancelled_amount': 30000,
  },
  'previous': {
    'gross_sales': 0,
    'commission': 0,
    'net_earnings': 0,
    'orders': 0,
    'avg_ticket': 0,
    'items_sold': 0,
    'delivery_fees': 0,
    'cancelled_orders': 0,
    'cancelled_amount': 0,
  },
  'daily': [
    for (var i = 0; i < 7; i++)
      {
        'date': '2026-10-${14 + i}',
        'gross': i.isEven ? 30000 : 0,
        'net': i.isEven ? 27000 : 0,
        'orders': i.isEven ? 1 : 0,
      },
  ],
  'hourly': [
    for (var h = 0; h < 24; h++) {'hour': h, 'orders': h == 19 ? 2 : 0, 'gross': h == 19 ? 60000 : 0},
  ],
  'payment_methods': [
    {'method': 'efectivo', 'orders': 1, 'amount': 30000},
    {'method': 'payu', 'orders': 1, 'amount': 30000},
  ],
  'top_dishes': [
    {'name': '1/2 pollo asado', 'quantity': 2, 'revenue': 54000},
  ],
  'movements': [
    for (var i = 0; i < movements; i++)
      {
        'order_id': i + 1,
        'receipt_number': 'DQ-${(i + 1).toString().padLeft(6, '0')}',
        'created_at': '2026-10-20T19:30:00-05:00',
        'customer': 'Leidy Córdoba',
        'status': i == 0 ? 'cancelado' : 'entregado',
        'status_label': i == 0 ? 'Cancelado' : 'Entregado',
        'payment_method': 'efectivo',
        'items_count': 2,
        ..._breakdown(sale: i != 0),
      },
  ],
};

Map<String, dynamic> _receiptJson({String status = 'entregado'}) => {
  'receipt_number': 'DQ-000042',
  'issued_at': '2026-10-20T20:00:00-05:00',
  'restaurant': {'name': 'Pollos Nacho', 'address': 'Cl. 31 #6-11', 'phone': '+57 310 7505209'},
  'breakdown': _breakdown(sale: status == 'entregado'),
  'order': {
    'id': 42,
    'status': status,
    'subtotal': 30000,
    'delivery_fee': 3000,
    'total': 33000,
    'payment_method': 'efectivo',
    'created_at': '2026-10-20T19:30:00-05:00',
    'items': [
      {'name': '1/2 pollo asado', 'quantity': 1, 'unit_price': 27000, 'subtotal': 27000},
      {'name': 'Gaseosa 1.5 L', 'quantity': 1, 'unit_price': 3000, 'subtotal': 3000},
    ],
    'customer': {'name': 'Leidy Córdoba', 'phone': '3001112233'},
  },
};

bool _isPdf(List<int> bytes) => ascii.decode(bytes.take(5).toList()) == '%PDF-';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es'));

  group('formato de dinero', () {
    test('pesos colombianos con el símbolo adelante', () {
      expect(formatCop(9396900), r'$9.396.900');
    });

    test('montos cortos para ejes', () {
      expect(formatCopCompact(1250000), r'$1,3 M');
      expect(formatCopCompact(12000000), r'$12 M');
      expect(formatCopCompact(350000), r'$350 mil');
      expect(formatCopCompact(900), r'$900');
    });
  });

  group('FinanceReport', () {
    test('parsea totales, series y movimientos', () {
      final report = FinanceReport.fromJson(_reportJson());

      expect(report.days, 7);
      expect(report.summary.netEarnings, 54000);
      expect(report.daily, hasLength(7));
      expect(report.hourly[19].orders, 2);
      expect(report.paymentMethods.map((m) => m.label), ['Efectivo', 'En línea']);
      expect(report.movements.first.status, OrderStatus.cancelado);
      expect(report.movements.first.breakdown.countsAsSale, isFalse);
      expect(report.movements.last.breakdown.net, 27000);
    });
  });

  group('FinancePdf', () {
    test('comprobante de un pedido entregado y de uno anulado', () async {
      expect(_isPdf(await FinancePdf.receiptBytes(OrderReceipt.fromJson(_receiptJson()))), isTrue);
      expect(_isPdf(await FinancePdf.receiptBytes(OrderReceipt.fromJson(_receiptJson(status: 'cancelado')))), isTrue);
    });

    test('el reporte con 100 movimientos se reparte en varias páginas', () async {
      final bytes = await FinancePdf.reportBytes(FinanceReport.fromJson(_reportJson(movements: 100)), 'Pollos Nacho');

      expect(_isPdf(bytes), isTrue);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length, greaterThan(1));
    });
  });
}
