import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'settings.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// Traduce errores de Dio/Laravel a un mensaje listo para mostrar.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return ApiException('Ocurrió un error inesperado.');

    final response = error.response;
    if (response == null) {
      return ApiException('No pudimos conectar con el servidor. Revisa tu conexión.');
    }

    final status = response.statusCode;
    if (status == 429) {
      return ApiException('Demasiados intentos. Espera un minuto e intenta de nuevo.', statusCode: status);
    }

    final data = response.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return ApiException('${first.first}', statusCode: status);
      }
      if (data['message'] is String) return ApiException(data['message'] as String, statusCode: status);
    }
    return ApiException('Ocurrió un error inesperado ($status).', statusCode: status);
  }

  @override
  String toString() => message;
}

Future<T> guardApi<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (error) {
    throw ApiException.from(error);
  }
}

class TokenStorage {
  static const _key = 'auth_token';
  final _storage = const FlutterSecureStorage();
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _cached = await _storage.read(key: _key);
      _loaded = true;
    }
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}

/// Avisa cuando el backend responde 401 (token vencido o revocado).
class SessionEvents extends ChangeNotifier {
  void expired() => notifyListeners();
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  final events = ref.watch(sessionEventsProvider);

  // Dio concatena baseUrl + path: sin la barra final "api" + "auth/login" daría "apiauth/login".
  final configured = ref.watch(apiBaseUrlProvider);
  final baseUrl = configured.endsWith('/') ? configured : '$configured/';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokens.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (error, handler) {
      final isAuthCall = error.requestOptions.path.startsWith('auth/');
      if (error.response?.statusCode == 401 && !isAuthCall) events.expired();
      handler.next(error);
    },
  ));

  return dio;
});
