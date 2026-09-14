import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import 'address_repository.dart';
import 'address_widgets.dart';

enum _AddressAction { makeDefault, delete }

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  Future<void> _handle(BuildContext context, WidgetRef ref, Address address, _AddressAction action) async {
    final repository = ref.read(addressRepositoryProvider);
    try {
      switch (action) {
        case _AddressAction.makeDefault:
          await repository.makeDefault(address);
        case _AddressAction.delete:
          await repository.delete(address.id);
      }
      ref.invalidate(addressesProvider);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis direcciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/addresses/new'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nueva dirección'),
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.location_on_outlined,
                title: 'Sin direcciones',
                message: 'Pon un pin en el mapa dentro de tu barrio para recibir pedidos.',
              )
            : ResponsiveCenter(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final address = list[i];
                    return AddressCard(
                      address: address,
                      trailing: PopupMenuButton<_AddressAction>(
                        onSelected: (action) => _handle(context, ref, address, action),
                        itemBuilder: (_) => [
                          if (!address.esPredeterminada)
                            const PopupMenuItem(
                              value: _AddressAction.makeDefault,
                              child: Text('Hacer predeterminada'),
                            ),
                          const PopupMenuItem(value: _AddressAction.delete, child: Text('Eliminar')),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
