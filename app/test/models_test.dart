import 'package:domiquibdo/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourierPosition', () {
    test('parsea una posición en vivo con ETA', () {
      final position = CourierPosition.fromJson({
        'live': true,
        'latitude': 5.695,
        'longitude': -76.659,
        'heading': 90.0,
        'distance_m': 800,
        'eta_min': 3,
      });

      expect(position.live, isTrue);
      expect(position.hasFix, isTrue);
      expect(position.position!.latitude, 5.695);
      expect(position.etaMin, 3);
      expect(position.hasArrived, isFalse);
    });

    test('sin posiciones el servidor devuelve nulos y no hay fix', () {
      final position = CourierPosition.fromJson({'live': false, 'latitude': null, 'longitude': null});

      expect(position.hasFix, isFalse);
      expect(position.hasArrived, isFalse);
    });

    test('llegó cuando está a menos de 60 m del destino', () {
      final position = CourierPosition.fromJson({
        'live': true,
        'latitude': 5.6,
        'longitude': -76.6,
        'distance_m': 40,
        'eta_min': 1,
      });

      expect(position.hasArrived, isTrue);
    });
  });

  group('Restaurant y Dish', () {
    test('is_active e is_available se leen y por defecto son verdaderos', () {
      final dish = Dish.fromJson({'id': 1, 'restaurant_id': 2, 'name': 'Sancocho', 'price': 15000, 'is_available': false});
      final fallback = Dish.fromJson({'id': 2, 'restaurant_id': 2, 'name': 'Arroz', 'price': 9000});

      expect(dish.isAvailable, isFalse);
      expect(fallback.isAvailable, isTrue);
    });
  });

  group('AppUser', () {
    test('reconoce el rol restaurante', () {
      final user = AppUser.fromJson({'id': 1, 'name': 'Restaurante Demo', 'email': 'r@demo.co', 'role': 'restaurante'});

      expect(user.isRestaurant, isTrue);
      expect(user.isDriver, isFalse);
    });
  });

  group('Order · pago en línea', () {
    Order order({required String method, String? paymentStatus, String status = 'pendiente'}) => Order.fromJson({
          'id': 7,
          'status': status,
          'subtotal': 10000,
          'delivery_fee': 4000,
          'total': 14000,
          'payment_method': method,
          'payment_status': paymentStatus,
          'created_at': '2026-10-12T12:00:00-05:00',
        });

    test('PayU pendiente o rechazado espera pago y se puede pagar', () {
      expect(order(method: 'payu', paymentStatus: 'pendiente').isAwaitingPayment, isTrue);
      expect(order(method: 'payu', paymentStatus: 'pendiente').canPayOnline, isTrue);
      expect(order(method: 'payu', paymentStatus: 'rechazado').canPayOnline, isTrue);
    });

    test('el título pide el pago mientras falte pagar', () {
      expect(order(method: 'payu', paymentStatus: 'pendiente').headline, 'Esperando tu pago');
      expect(order(method: 'payu', paymentStatus: 'aprobado').headline, 'Esperando confirmación del restaurante');
      expect(order(method: 'efectivo').headline, 'Esperando confirmación del restaurante');
    });

    test('la etiqueta de la lista no dice "Recibido" mientras falte el pago', () {
      expect(order(method: 'payu', paymentStatus: 'pendiente').statusLabel, 'Por pagar');
      expect(order(method: 'payu', paymentStatus: 'rechazado').statusLabel, 'Pago rechazado');
      expect(order(method: 'payu', paymentStatus: 'aprobado').statusLabel, 'Recibido');
      expect(order(method: 'efectivo').statusLabel, 'Recibido');
      expect(order(method: 'payu', paymentStatus: 'pendiente', status: 'cancelado').statusLabel, 'Cancelado');
    });

    test('aprobado ya no espera pago', () {
      final paid = order(method: 'payu', paymentStatus: 'aprobado');
      expect(paid.paymentStatus, PaymentStatus.aprobado);
      expect(paid.isAwaitingPayment, isFalse);
      expect(paid.canPayOnline, isFalse);
    });

    test('expirado o pedido cancelado no se puede pagar', () {
      expect(order(method: 'payu', paymentStatus: 'expirado', status: 'cancelado').canPayOnline, isFalse);
      expect(order(method: 'payu', paymentStatus: 'pendiente', status: 'cancelado').canPayOnline, isFalse);
    });

    test('efectivo no tiene estado de pago', () {
      final cash = order(method: 'efectivo');
      expect(cash.paymentStatus, isNull);
      expect(cash.isOnlinePayment, isFalse);
      expect(cash.isAwaitingPayment, isFalse);
    });
  });
}
