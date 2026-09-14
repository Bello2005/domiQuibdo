import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/addresses/address_list_screen.dart';
import '../features/addresses/address_picker_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/cart/checkout_screen.dart';
import '../features/catalog/home_screen.dart';
import '../features/catalog/restaurant_detail_screen.dart';
import '../features/driver/driver_home_screen.dart';
import '../features/driver/driver_order_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/tracking_screen.dart';
import '../features/profile/profile_screen.dart';
import 'models.dart';
import 'shells.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

int _id(GoRouterState state) => int.parse(state.pathParameters['id']!);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<AppUser?>>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => _redirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

      // App del cliente: Inicio · Pedidos · Carrito · Perfil
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ClientShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'restaurant/:id',
                  builder: (_, state) => RestaurantDetailScreen(id: _id(state), initial: state.extra as Restaurant?),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              builder: (_, _) => const OrdersScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => OrderDetailScreen(id: _id(state)),
                  routes: [
                    GoRoute(
                      path: 'tracking',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) => TrackingScreen(orderId: _id(state)),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              builder: (_, _) => const CartScreen(),
              routes: [
                GoRoute(
                  path: 'checkout',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const CheckoutScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [GoRoute(path: 'addresses', builder: (_, _) => const AddressListScreen())],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/addresses/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const AddressPickerScreen(),
      ),

      // App del repartidor: Entregas · Perfil
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => DriverShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/driver',
              builder: (_, _) => const DriverHomeScreen(),
              routes: [
                GoRoute(
                  path: 'order/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => DriverOrderScreen(id: _id(state)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/driver-profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

String? _redirect(AsyncValue<AppUser?> auth, String location) {
  final isPublic = location == '/login' || location == '/register';

  if (auth.isLoading && !auth.hasValue) return location == '/splash' ? null : '/splash';

  final user = auth.valueOrNull;
  if (user == null) return isPublic ? null : '/login';

  final home = user.isDriver ? '/driver' : '/home';
  if (isPublic || location == '/splash') return home;

  // Cada rol solo navega por su propia sección.
  final inDriverArea = location.startsWith('/driver');
  if (user.isDriver != inDriverArea) return home;

  return null;
}
