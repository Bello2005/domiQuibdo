import 'package:domiquibdo/core/models.dart';
import 'package:domiquibdo/features/orders/tracking_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const restaurant = LatLng(5.6942, -76.6570);

  Order order(String status) => Order.fromJson({
    'id': 3,
    'status': status,
    'subtotal': 27000,
    'delivery_fee': 3000,
    'total': 30000,
    'payment_method': 'efectivo',
    'created_at': '2026-10-12T21:18:00-05:00',
    'restaurant': {
      'id': 1,
      'name': 'Pollos Nacho',
      'category': 'Pollo',
      'latitude': restaurant.latitude,
      'longitude': restaurant.longitude,
      'address_text': 'Cl. 31 #6-11',
      'rating_avg': 4.3,
      'delivery_time_min': 30,
    },
  });

  group('courierPhase', () {
    test('al lado del restaurante o sin posición todavía: llegó al restaurante', () {
      expect(courierPhase(order('en_camino'), null), CourierPhase.atRestaurant);
      expect(courierPhase(order('en_camino'), const LatLng(5.69425, -76.65705)), CourierPhase.atRestaurant);
    });

    test('al alejarse del restaurante: en camino', () {
      expect(courierPhase(order('en_camino'), const LatLng(5.6948, -76.6588)), CourierPhase.onTheWay);
    });

    test('entregado gana sobre la posición', () {
      expect(courierPhase(order('entregado'), restaurant), CourierPhase.delivered);
      expect(courierPhase(order('entregado'), null), CourierPhase.delivered);
    });
  });
}
