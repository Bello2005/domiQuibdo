import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<String>> categories() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('restaurants/categories');
        return response.data!.cast<String>();
      });

  Future<List<Restaurant>> restaurants({String? category}) => guardApi(() async {
        final response = await _dio.get<List<dynamic>>(
          'restaurants',
          queryParameters: {'category': ?category},
        );
        return [for (final json in response.data!) Restaurant.fromJson(json as Map<String, dynamic>)];
      });

  Future<Restaurant> restaurant(int id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('restaurants/$id');
        return Restaurant.fromJson(response.data!);
      });
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(dioProvider)));

final categoriesProvider = FutureProvider<List<String>>((ref) => ref.watch(catalogRepositoryProvider).categories());

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final restaurantsProvider = FutureProvider.family<List<Restaurant>, String?>(
  (ref, category) => ref.watch(catalogRepositoryProvider).restaurants(category: category),
);

final restaurantDetailProvider = FutureProvider.autoDispose.family<Restaurant, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).restaurant(id),
);
