import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import 'restaurant_repository.dart';

/// Mi negocio: abrir/cerrar el restaurante y administrar el menú.
class RestaurantMenuScreen extends ConsumerWidget {
  const RestaurantMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(ownerRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi negocio')),
      body: restaurants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(ownerRestaurantsProvider)),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.storefront_outlined,
                title: 'Sin restaurante asignado',
                message: 'Pídele al equipo de DomiQuibdó que vincule tu cuenta a tu restaurante.',
              )
            : ResponsiveCenter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [for (final restaurant in list) _RestaurantSection(restaurant: restaurant)],
                ),
              ),
      ),
    );
  }
}

class _RestaurantSection extends ConsumerStatefulWidget {
  const _RestaurantSection({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_RestaurantSection> createState() => _RestaurantSectionState();
}

class _RestaurantSectionState extends ConsumerState<_RestaurantSection> {
  Future<void> _run(Future<void> Function(RestaurantOwnerRepository repo) action) async {
    try {
      await action(ref.read(restaurantOwnerRepositoryProvider));
      ref.invalidate(ownerRestaurantsProvider);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _editDish({Dish? dish}) async {
    final result = await showDialog<_DishFormResult>(context: context, builder: (_) => _DishDialog(dish: dish));
    if (result == null) return;
    await _run((repo) => dish == null
        ? repo.addDish(widget.restaurant.id, name: result.name, price: result.price, description: result.description)
        : repo.updateDish(dish, name: result.name, price: result.price, description: result.description));
  }

  Future<void> _deleteDish(Dish dish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar "${dish.name}"?'),
        content: const Text('Si solo quieres dejar de venderlo por hoy, mejor márcalo como agotado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) await _run((repo) => repo.deleteDish(dish.id));
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            title: Text(restaurant.name, style: theme.textTheme.titleMedium),
            subtitle: Text(restaurant.isActive ? 'Abierto: recibiendo pedidos' : 'Cerrado: los clientes no pueden pedir'),
            secondary: Icon(restaurant.isActive ? Icons.storefront : Icons.store_mall_directory_outlined),
            value: restaurant.isActive,
            onChanged: (open) => _run((repo) => repo.setOpen(restaurant.id, open)),
          ),
        ),
        SectionTitle(
          'Menú',
          trailing: TextButton.icon(
            onPressed: () => _editDish(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar plato'),
          ),
        ),
        if (restaurant.menu.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Aún no tienes platos en el menú.')),
        for (final dish in restaurant.menu)
          Card(
            child: ListTile(
              title: Text(dish.name, style: dish.isAvailable ? null : const TextStyle(decoration: TextDecoration.lineThrough)),
              subtitle: Text(
                dish.isAvailable ? formatCop(dish.price) : '${formatCop(dish.price)} · Agotado',
              ),
              onTap: () => _editDish(dish: dish),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: dish.isAvailable ? 'Disponible' : 'Agotado',
                    child: Switch(
                      value: dish.isAvailable,
                      onChanged: (value) => _run((repo) => repo.updateDish(dish, isAvailable: value)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _deleteDish(dish),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DishFormResult {
  const _DishFormResult(this.name, this.price, this.description);

  final String name;
  final double price;
  final String? description;
}

class _DishDialog extends StatefulWidget {
  const _DishDialog({this.dish});

  final Dish? dish;

  @override
  State<_DishDialog> createState() => _DishDialogState();
}

class _DishDialogState extends State<_DishDialog> {
  late final _name = TextEditingController(text: widget.dish?.name);
  late final _price = TextEditingController(text: widget.dish == null ? '' : widget.dish!.price.round().toString());
  late final _description = TextEditingController(text: widget.dish?.description);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_price.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del plato.');
    } else if (price == null || price <= 0) {
      setState(() => _error = 'Escribe un precio válido (solo números).');
    } else {
      Navigator.pop(context, _DishFormResult(_name.text.trim(), price, _description.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.dish == null ? 'Nuevo plato' : 'Editar plato'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre'), maxLength: 120),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio (COP)', prefixText: r'$ '),
              ),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Guardar')),
        ],
      );
}
