import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';
import 'finance_models.dart';

/// API del rol restaurante (`/api/restaurant/*`): pedidos propios, menú y abrir/cerrar el negocio.
class RestaurantOwnerRepository {
  RestaurantOwnerRepository(this._dio);

  final Dio _dio;

  Future<List<Order>> orders() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('restaurant/orders');
        return [for (final json in response.data!) Order.fromJson(json as Map<String, dynamic>)];
      });

  Future<Order> advance(int id) => _order(() => _dio.post('restaurant/orders/$id/advance'));

  Future<Order> cancel(int id) => _order(() => _dio.post('restaurant/orders/$id/cancel'));

  Future<List<Restaurant>> restaurants() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('restaurant/restaurants');
        return [for (final json in response.data!) Restaurant.fromJson(json as Map<String, dynamic>)];
      });

  Future<void> setOpen(int restaurantId, bool open) =>
      guardApi(() => _dio.put<void>('restaurant/restaurants/$restaurantId', data: {'is_active': open}));

  Future<void> addDish(int restaurantId, {required String name, required double price, String? description}) =>
      guardApi(() => _dio.post<void>('restaurant/restaurants/$restaurantId/menu-items', data: _dish(name, price, description)));

  Future<void> updateDish(
    Dish dish, {
    String? name,
    double? price,
    String? description,
    bool? isAvailable,
  }) =>
      guardApi(() => _dio.put<void>('restaurant/menu-items/${dish.id}', data: {
            ..._dish(name ?? dish.name, price ?? dish.price, description ?? dish.description),
            'is_available': isAvailable ?? dish.isAvailable,
          }));

  /// Ventas, comisión y ganancia de los últimos [days] días (7, 30 o 90).
  Future<FinanceReport> finances(int days) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('restaurant/finances', queryParameters: {'days': days});
        return FinanceReport.fromJson(response.data!);
      });

  Future<OrderReceipt> receipt(int orderId) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('restaurant/orders/$orderId/receipt');
        return OrderReceipt.fromJson(response.data!);
      });

  Future<void> deleteDish(int id) => guardApi(() => _dio.delete<void>('restaurant/menu-items/$id'));

  Map<String, dynamic> _dish(String name, double price, String? description) => {
        'name': name,
        'price': price,
        'description': (description == null || description.isEmpty) ? null : description,
      };

  Future<Order> _order(Future<Response<dynamic>> Function() request) => guardApi(() async {
        final response = await request();
        return Order.fromJson(response.data as Map<String, dynamic>);
      });
}

final restaurantOwnerRepositoryProvider =
    Provider<RestaurantOwnerRepository>((ref) => RestaurantOwnerRepository(ref.watch(dioProvider)));

final ownerOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(restaurantOwnerRepositoryProvider).orders();
});

final ownerRestaurantsProvider = FutureProvider.autoDispose<List<Restaurant>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(restaurantOwnerRepositoryProvider).restaurants();
});

/// Periodo elegido en Finanzas, en días.
final financeDaysProvider = StateProvider<int>((ref) => 30);

final financeReportProvider = FutureProvider.autoDispose<FinanceReport>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(restaurantOwnerRepositoryProvider).finances(ref.watch(financeDaysProvider));
});
