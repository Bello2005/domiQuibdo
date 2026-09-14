import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  Future<AppUser?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      final response = await guardApi(() => _dio.get<Map<String, dynamic>>('me'));
      return AppUser.fromJson(response.data!);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _tokens.clear();
      return null;
    }
  }

  Future<AppUser> login(String email, String password) =>
      _authenticate('auth/login', {'email': email, 'password': password});

  Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      _authenticate('auth/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
      });

  Future<void> logout() async {
    try {
      await _dio.post<void>('auth/logout');
    } catch (_) {
      // Si falla la red igual se cierra la sesión local.
    }
    await _tokens.clear();
  }

  Future<AppUser> _authenticate(String path, Map<String, dynamic> body) async {
    final response = await guardApi(() => _dio.post<Map<String, dynamic>>(path, data: body));
    await _tokens.write(response.data!['token'] as String);
    return AppUser.fromJson(response.data!['user'] as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final events = ref.watch(sessionEventsProvider);
    void onExpired() {
      ref.read(tokenStorageProvider).clear();
      state = const AsyncData(null);
    }

    events.addListener(onExpired);
    ref.onDispose(() => events.removeListener(onExpired));

    return ref.read(authRepositoryProvider).restoreSession();
  }

  // No se pone el estado en loading: cada pantalla maneja su propio indicador
  // y así el router no redirige al splash en medio del login.
  Future<void> login(String email, String password) async {
    state = AsyncData(await ref.read(authRepositoryProvider).login(email, password));
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = AsyncData(await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, phone: phone, password: password));
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).valueOrNull);
