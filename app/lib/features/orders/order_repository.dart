import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../cart/cart_controller.dart';
import '../safety/incident_type.dart';

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<List<Order>> list() => _orders('orders');

  Future<Order> detail(int id) => _order(() => _dio.get('orders/$id'));

  Future<List<LatLng>> route(int id) => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('orders/$id/route');
        return [
          for (final point in response.data!.cast<Map<String, dynamic>>())
            LatLng((point['latitude'] as num).toDouble(), (point['longitude'] as num).toDouble()),
        ];
      });

  /// Solo se envían ids y cantidades: el servidor calcula precios y total.
  Future<Order> place({
    required int addressId,
    required Iterable<CartLine> lines,
    required String paymentMethod,
    String? notes,
  }) =>
      _order(() => _dio.post('orders', data: {
            'address_id': addressId,
            'items': [
              for (final line in lines) {'menu_item_id': line.dish.id, 'quantity': line.quantity},
            ],
            'payment_method': paymentMethod,
            'notes': (notes == null || notes.isEmpty) ? null : notes,
          }));

  Future<Order> cancel(int id) => _order(() => _dio.post('orders/$id/cancel'));

  /// GPS real del repartidor (última posición + ETA calculado por el servidor).
  Future<CourierPosition> courierPosition(int id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('orders/$id/location');
        return CourierPosition.fromJson(response.data!);
      });

  Future<void> sendCourierPosition(int id, Position position) => guardApi(
        () => _dio.post<void>('driver/orders/$id/location', data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          if (position.heading >= 0) 'heading': position.heading,
          if (position.speed >= 0) 'speed_mps': position.speed,
          'accuracy_m': position.accuracy,
        }),
      );

  /// SOS o reporte de problema: queda guardado y lo ve soporte en el panel admin.
  Future<void> reportIncident(int orderId, IncidentType type, {String? message, LatLng? position}) => guardApi(
        () => _dio.post<void>('orders/$orderId/incidents', data: {
          'type': type.name,
          if (message != null && message.isNotEmpty) 'message': message,
          if (position != null) ...{'latitude': position.latitude, 'longitude': position.longitude},
        }),
      );

  Future<Order> demoAdvance(int id) => _order(() => _dio.post('demo/orders/$id/advance'));

  Future<List<Order>> driverOrders() => _orders('driver/orders');

  Future<Order> driverAdvance(int id) => _order(() => _dio.post('driver/orders/$id/advance'));

  Future<Order> deliver(int id, String code) =>
      _order(() => _dio.post('driver/orders/$id/deliver', data: {'code': code}));

  Future<List<Order>> _orders(String path) => guardApi(() async {
        final response = await _dio.get<List<dynamic>>(path);
        return [for (final json in response.data!) Order.fromJson(json as Map<String, dynamic>)];
      });

  Future<Order> _order(Future<Response<dynamic>> Function() request) => guardApi(() async {
        final response = await request();
        return Order.fromJson(response.data as Map<String, dynamic>);
      });
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository(ref.watch(dioProvider)));

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) => ref.watch(orderRepositoryProvider).list());

final orderDetailProvider = FutureProvider.autoDispose.family<Order, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).detail(id),
);

final orderRouteProvider = FutureProvider.autoDispose.family<List<LatLng>, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).route(id),
);

final driverOrdersProvider = FutureProvider.autoDispose<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).driverOrders(),
);

final courierPositionProvider = FutureProvider.autoDispose.family<CourierPosition, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).courierPosition(id),
);
