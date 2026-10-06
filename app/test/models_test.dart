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
}
