import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../addresses/address_repository.dart';
import '../addresses/address_widgets.dart';
import '../orders/order_repository.dart';
import 'cart_controller.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notes = TextEditingController();
  Address? _selected;
  String _payment = 'efectivo';
  bool _placing = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final created = await context.push<Address>('/addresses/new');
    if (created != null && mounted) setState(() => _selected = created);
  }

  Future<void> _pickAddress(List<Address> addresses) async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final address in addresses) ...[
              AddressCard(address: address, onTap: () => Navigator.pop(context, address)),
              const SizedBox(height: 8),
            ],
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Agregar nueva dirección'),
              onTap: () => Navigator.pop(context, 'new'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (picked is Address) setState(() => _selected = picked);
    if (picked == 'new') await _addAddress();
  }

  Future<void> _place(CartState cart, Address address) async {
    setState(() => _placing = true);
    final cartController = ref.read(cartProvider.notifier);
    try {
      final order = await ref.read(orderRepositoryProvider).place(
            addressId: address.id,
            lines: cart.lines.values,
            paymentMethod: _payment,
            notes: _notes.text.trim(),
          );
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      context.go('/orders/${order.id}');
      cartController.clear();
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message);
        setState(() => _placing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);
    final theme = Theme.of(context);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar pedido')),
        body: const EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: 'No hay productos',
          message: 'Agrega productos al carrito para continuar.',
        ),
      );
    }

    final addresses = addressesAsync.valueOrNull ?? const <Address>[];
    final address = _selected ?? addresses.where((a) => a.esPredeterminada).firstOrNull ?? addresses.firstOrNull;
    final fee = address == null ? null : estimateDeliveryFee(cart.restaurant!.position, address.position);
    final total = cart.subtotal + (fee ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SectionTitle(
              'Entregar en',
              trailing: address == null
                  ? null
                  : TextButton(onPressed: () => _pickAddress(addresses), child: const Text('Cambiar')),
            ),
            addressesAsync.when(
              loading: () => const Skeleton(child: SkeletonBox(height: 76, radius: 20)),
              error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(addressesProvider)),
              data: (_) => address == null
                  ? OutlinedButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Agregar dirección con pin en el mapa'),
                    )
                  : AddressCard(address: address),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Método de pago'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: value, value: (label, icon)) in paymentMethods.entries)
                  ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: _payment == value,
                    onSelected: (_) => setState(() => _payment = value),
                  ),
              ],
            ),
            if (_payment != 'efectivo') ...[
              const SizedBox(height: 8),
              Text(
                'Sprint 0: el pago se coordina al recibir. La pasarela de pagos llega en la siguiente fase.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle('Notas para el restaurante'),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(hintText: 'Ej: sin cebolla, el timbre no funciona…'),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SummaryRow(label: 'Subtotal', value: formatCop(cart.subtotal)),
                    SummaryRow(label: 'Domicilio (estimado)', value: fee == null ? '—' : formatCop(fee)),
                    const Divider(height: 20),
                    SummaryRow(label: 'Total', value: formatCop(total), emphasize: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InfoBanner(
              icon: Icons.verified_user_outlined,
              text: 'Al confirmar recibirás un código de 4 dígitos. Dáselo al repartidor solo cuando tengas tu pedido en la mano.',
              background: theme.colorScheme.tertiaryContainer,
              foreground: theme.colorScheme.onTertiaryContainer,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: address == null || _placing ? null : () => _place(cart, address),
            child: _placing
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text('Confirmar pedido · ${formatCop(total)}'),
          ),
        ),
      ),
    );
  }
}
