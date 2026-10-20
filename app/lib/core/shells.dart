import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_controller.dart';
import 'widgets/glass.dart';

/// Contenedor de pestañas: el contenido pasa por debajo de la barra de vidrio flotante
/// (`extendBody`), y las listas reservan ese espacio con [bottomBarInset].
class _GlassShell extends StatelessWidget {
  const _GlassShell({required this.shell, required this.items});

  final StatefulNavigationShell shell;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: GlassNavBar(
          items: items,
          currentIndex: shell.currentIndex,
          onTap: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        ),
      );
}

class ClientShell extends ConsumerWidget {
  const ClientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((cart) => cart.itemCount));

    return _GlassShell(
      shell: shell,
      items: [
        const GlassNavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Inicio'),
        const GlassNavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Pedidos'),
        GlassNavItem(
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag,
          label: 'Carrito',
          badge: cartCount,
        ),
        const GlassNavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
      ],
    );
  }
}

class RestaurantShell extends StatelessWidget {
  const RestaurantShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => _GlassShell(
        shell: shell,
        items: const [
          GlassNavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Pedidos'),
          GlassNavItem(icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: 'Finanzas'),
          GlassNavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Mi negocio'),
          GlassNavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
        ],
      );
}

class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => _GlassShell(
        shell: shell,
        items: const [
          GlassNavItem(icon: Icons.two_wheeler_outlined, selectedIcon: Icons.two_wheeler, label: 'Entregas'),
          GlassNavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
        ],
      );
}
