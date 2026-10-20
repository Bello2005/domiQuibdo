import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/generated_cover.dart';
import '../../core/widgets/glass.dart';
import 'restaurant_repository.dart';

/// Mi negocio: abrir/cerrar el restaurante, sus fotos y el menú.
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
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomBarInset(context)),
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
  bool _uploading = false;

  /// Pide una foto de la galería o la cámara; el backend la redimensiona, aquí
  /// solo se limita el tamaño para que la subida sea rápida con datos móviles.
  Future<String?> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    return file?.path;
  }

  Future<void> _upload(Future<void> Function(RestaurantOwnerRepository repo, String path) action) async {
    final path = await _pickPhoto();
    if (path == null) return;
    setState(() => _uploading = true);
    await _run((repo) => action(repo, path));
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _photoOptions(RestaurantPhoto photo, {required bool isCover}) async {
    final photos = widget.restaurant.photos;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCover)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Usar como portada'),
                onTap: () => Navigator.pop(context, 'cover'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar foto'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'cover':
        await _run((repo) => repo.reorderPhotos(widget.restaurant.id, [
              photo.id,
              for (final other in photos)
                if (other.id != photo.id) other.id,
            ]));
      case 'delete':
        await _run((repo) => repo.deletePhoto(photo.id));
    }
  }

  Future<void> _dishPhotoOptions(Dish dish) async {
    if (dish.imageUrl == null) return _upload((repo, path) => repo.setDishPhoto(dish.id, path));
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Cambiar foto'),
              onTap: () => Navigator.pop(context, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Quitar foto'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'change':
        await _upload((repo, path) => repo.setDishPhoto(dish.id, path));
      case 'remove':
        await _run((repo) => repo.removeDishPhoto(dish.id));
    }
  }

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
        GlassCard(
          child: SwitchListTile(
            title: Text(restaurant.name, style: theme.textTheme.titleMedium),
            subtitle: Text(restaurant.isActive ? 'Abierto: recibiendo pedidos' : 'Cerrado: los clientes no pueden pedir'),
            secondary: Icon(restaurant.isActive ? Icons.storefront : Icons.store_mall_directory_outlined),
            value: restaurant.isActive,
            onChanged: (open) => _run((repo) => repo.setOpen(restaurant.id, open)),
          ),
        ),
        SectionTitle(
          'Fotos del negocio',
          trailing: _uploading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        Text(
          'La primera es la portada que ven los clientes. Toca una foto para cambiarla.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, photo) in restaurant.photos.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _PhotoThumb(
                    url: photo.thumbUrl,
                    label: i == 0 ? 'Portada' : null,
                    onTap: () => _photoOptions(photo, isCover: i == 0),
                  ),
                ),
              _AddPhotoTile(
                enabled: !_uploading,
                onTap: () => _upload((repo, path) => repo.addPhoto(restaurant.id, path)),
              ),
            ],
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
          GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _uploading ? null : () => _dishPhotoOptions(dish),
                child: SizedBox.square(
                  dimension: 52,
                  child: dish.imageUrl == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Icon(Icons.add_a_photo_outlined, size: 20, color: theme.colorScheme.primary),
                        )
                      : GeneratedCover(
                          category: restaurant.category,
                          iconSize: 16,
                          imageUrl: dish.imageThumbUrl ?? dish.imageUrl,
                          borderRadius: BorderRadius.circular(12),
                        ),
                ),
              ),
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.onTap, this.label});

  final String url;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GeneratedCover(category: '', iconSize: 20, imageUrl: url, borderRadius: BorderRadius.circular(16)),
              if (label != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(label!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            const SizedBox(height: 6),
            Text('Agregar', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.primary)),
          ],
        ),
      ),
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
