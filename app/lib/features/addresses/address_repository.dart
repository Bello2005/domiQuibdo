import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

class AddressRepository {
  AddressRepository(this._dio);

  final Dio _dio;

  Future<List<Zone>> zones() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('zones');
        return [for (final json in response.data!) Zone.fromJson(json as Map<String, dynamic>)];
      });

  Future<List<Address>> list() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('addresses');
        return [for (final json in response.data!) Address.fromJson(json as Map<String, dynamic>)];
      });

  Future<Address> create({
    required int zoneId,
    required LatLng position,
    required AddressType tipo,
    required String detalle,
    required bool esPredeterminada,
  }) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          'addresses',
          data: _payload(zoneId, position, tipo, detalle, esPredeterminada),
        );
        return Address.fromJson(response.data!);
      });

  Future<Address> makeDefault(Address address) => guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          'addresses/${address.id}',
          data: _payload(address.zoneId!, address.position, address.tipo, address.detalle, true),
        );
        return Address.fromJson(response.data!);
      });

  Future<void> delete(int id) => guardApi(() => _dio.delete<void>('addresses/$id'));

  Map<String, dynamic> _payload(int zoneId, LatLng position, AddressType tipo, String? detalle, bool isDefault) => {
        'coverage_zone_id': zoneId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'tipo': tipo.name,
        'detalle': (detalle == null || detalle.isEmpty) ? null : detalle,
        'es_predeterminada': isDefault,
      };
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) => AddressRepository(ref.watch(dioProvider)));

final zonesProvider = FutureProvider<List<Zone>>((ref) => ref.watch(addressRepositoryProvider).zones());

final addressesProvider = FutureProvider<List<Address>>((ref) {
  // Se recarga al cambiar de usuario.
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(addressRepositoryProvider).list();
});

final defaultAddressProvider = FutureProvider<Address?>((ref) async {
  final addresses = await ref.watch(addressesProvider.future);
  return addresses.where((a) => a.esPredeterminada).firstOrNull ?? addresses.firstOrNull;
});
