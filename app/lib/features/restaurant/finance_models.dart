import '../../core/models.dart';

double _num(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

/// Totales de un periodo (`summary` y `previous` de `GET /restaurant/finances`).
class FinanceSummary {
  const FinanceSummary({
    required this.grossSales,
    required this.commission,
    required this.netEarnings,
    required this.orders,
    required this.avgTicket,
    required this.itemsSold,
    required this.deliveryFees,
    required this.cancelledOrders,
    required this.cancelledAmount,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
    grossSales: _num(json['gross_sales']),
    commission: _num(json['commission']),
    netEarnings: _num(json['net_earnings']),
    orders: json['orders'] as int,
    avgTicket: _num(json['avg_ticket']),
    itemsSold: json['items_sold'] as int,
    deliveryFees: _num(json['delivery_fees']),
    cancelledOrders: json['cancelled_orders'] as int,
    cancelledAmount: _num(json['cancelled_amount']),
  );

  final double grossSales;
  final double commission;
  final double netEarnings;
  final int orders;
  final double avgTicket;
  final int itemsSold;
  final double deliveryFees;
  final int cancelledOrders;
  final double cancelledAmount;
}

class DailySales {
  const DailySales({required this.date, required this.gross, required this.net, required this.orders});

  factory DailySales.fromJson(Map<String, dynamic> json) => DailySales(
    date: DateTime.parse(json['date'] as String),
    gross: _num(json['gross']),
    net: _num(json['net']),
    orders: json['orders'] as int,
  );

  final DateTime date;
  final double gross;
  final double net;
  final int orders;
}

class HourlySales {
  const HourlySales({required this.hour, required this.orders, required this.gross});

  factory HourlySales.fromJson(Map<String, dynamic> json) =>
      HourlySales(hour: json['hour'] as int, orders: json['orders'] as int, gross: _num(json['gross']));

  final int hour;
  final int orders;
  final double gross;
}

class PaymentMethodSales {
  const PaymentMethodSales({required this.method, required this.orders, required this.amount});

  factory PaymentMethodSales.fromJson(Map<String, dynamic> json) =>
      PaymentMethodSales(method: json['method'] as String, orders: json['orders'] as int, amount: _num(json['amount']));

  final String method;
  final int orders;
  final double amount;

  String get label => switch (method) {
    'efectivo' => 'Efectivo',
    'payu' => 'En línea',
    _ => paymentMethods[method]?.$1 ?? method,
  };
}

class TopDish {
  const TopDish({required this.name, required this.quantity, required this.revenue});

  factory TopDish.fromJson(Map<String, dynamic> json) =>
      TopDish(name: json['name'] as String, quantity: json['quantity'] as int, revenue: _num(json['revenue']));

  final String name;
  final int quantity;
  final double revenue;
}

/// Desglose contable de un pedido: lo mismo en el libro y en el comprobante.
class OrderBreakdown {
  const OrderBreakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.commissionRate,
    required this.commission,
    required this.net,
    required this.countsAsSale,
  });

  factory OrderBreakdown.fromJson(Map<String, dynamic> json) => OrderBreakdown(
    subtotal: _num(json['subtotal']),
    deliveryFee: _num(json['delivery_fee']),
    total: _num(json['total']),
    commissionRate: _num(json['commission_rate']),
    commission: _num(json['commission']),
    net: _num(json['net']),
    countsAsSale: json['counts_as_sale'] as bool,
  );

  final double subtotal;
  final double deliveryFee;
  final double total;
  final double commissionRate;
  final double commission;
  final double net;
  final bool countsAsSale;
}

/// Una línea del libro de movimientos: un pedido entregado (venta) o cancelado.
class FinanceMovement {
  const FinanceMovement({
    required this.orderId,
    required this.receiptNumber,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    required this.paymentMethod,
    required this.itemsCount,
    required this.breakdown,
    this.customer,
  });

  factory FinanceMovement.fromJson(Map<String, dynamic> json) => FinanceMovement(
    orderId: json['order_id'] as int,
    receiptNumber: json['receipt_number'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    customer: json['customer'] as String?,
    status: OrderStatus.parse(json['status'] as String),
    statusLabel: json['status_label'] as String,
    paymentMethod: json['payment_method'] as String,
    itemsCount: (json['items_count'] as num).toInt(),
    breakdown: OrderBreakdown.fromJson(json),
  );

  final int orderId;
  final String receiptNumber;
  final DateTime createdAt;
  final String? customer;
  final OrderStatus status;
  final String statusLabel;
  final String paymentMethod;
  final int itemsCount;
  final OrderBreakdown breakdown;
}

class FinanceReport {
  const FinanceReport({
    required this.days,
    required this.from,
    required this.to,
    required this.commissionRate,
    required this.summary,
    required this.previous,
    required this.daily,
    required this.hourly,
    required this.paymentMethods,
    required this.topDishes,
    required this.movements,
  });

  factory FinanceReport.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final item in json[key] as List<dynamic>) parse(item as Map<String, dynamic>),
    ];

    return FinanceReport(
      days: period['days'] as int,
      from: DateTime.parse(period['from'] as String),
      to: DateTime.parse(period['to'] as String),
      commissionRate: _num(json['commission_rate']),
      summary: FinanceSummary.fromJson(json['summary'] as Map<String, dynamic>),
      previous: FinanceSummary.fromJson(json['previous'] as Map<String, dynamic>),
      daily: list('daily', DailySales.fromJson),
      hourly: list('hourly', HourlySales.fromJson),
      paymentMethods: list('payment_methods', PaymentMethodSales.fromJson),
      topDishes: list('top_dishes', TopDish.fromJson),
      movements: list('movements', FinanceMovement.fromJson),
    );
  }

  final int days;
  final DateTime from;
  final DateTime to;
  final double commissionRate;
  final FinanceSummary summary;
  final FinanceSummary previous;
  final List<DailySales> daily;
  final List<HourlySales> hourly;
  final List<PaymentMethodSales> paymentMethods;
  final List<TopDish> topDishes;
  final List<FinanceMovement> movements;
}

/// Datos del comprobante (`GET /restaurant/orders/{id}/receipt`).
class OrderReceipt {
  const OrderReceipt({
    required this.receiptNumber,
    required this.issuedAt,
    required this.restaurantName,
    required this.breakdown,
    required this.order,
    this.restaurantAddress,
    this.restaurantPhone,
  });

  factory OrderReceipt.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>;
    return OrderReceipt(
      receiptNumber: json['receipt_number'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      restaurantName: restaurant['name'] as String,
      restaurantAddress: restaurant['address'] as String?,
      restaurantPhone: restaurant['phone'] as String?,
      breakdown: OrderBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>),
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
    );
  }

  final String receiptNumber;
  final DateTime issuedAt;
  final String restaurantName;
  final String? restaurantAddress;
  final String? restaurantPhone;
  final OrderBreakdown breakdown;
  final Order order;
}
