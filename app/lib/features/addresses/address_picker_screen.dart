import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import 'address_repository.dart';

/// Selección de dirección con pin fijo al centro: el usuario mueve el mapa debajo.
/// Solo se permite guardar si el pin cae dentro del barrio (zona de cobertura).
class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _map = MapController();
  final _detalle = TextEditingController();
  Zone? _zone;
  LatLng _pin = AppConfig.quibdoCenter;
  AddressType _tipo = AddressType.casa;
  bool _isDefault = true;
  bool _saving = false;

  @override
  void dispose() {
    _detalle.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onMapMoved(MapCamera camera, bool _) {
    void update() {
      if (mounted) setState(() => _pin = camera.center);
    }

    // flutter_map puede notificar durante el build inicial.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  void _selectZone(Zone zone) {
    setState(() {
      _zone = zone;
      _pin = zone.center;
    });
    _map.move(zone.center, 16);
  }

  Future<void> _save(Zone zone) async {
    setState(() => _saving = true);
    try {
      final address = await ref.read(addressRepositoryProvider).create(
            zoneId: zone.id,
            position: _pin,
            tipo: _tipo,
            detalle: _detalle.text.trim(),
            esPredeterminada: _isDefault,
          );
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(address);
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = ref.watch(zonesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva dirección')),
      body: zones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(zonesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.map_outlined,
              title: 'Sin cobertura',
              message: 'Aún no hay barrios habilitados.',
            );
          }
          if (_zone == null) {
            _zone = list.where((z) => z.name == 'Centro').firstOrNull ?? list.first;
            _pin = _zone!.center;
          }
          final zone = _zone!;
          final inside = zone.contains(_pin);

          return LayoutBuilder(
            builder: (context, constraints) {
              final map = _buildMap(zone, inside);
              final form = _buildForm(list, zone, inside);
              if (constraints.maxWidth >= 840) {
                return Row(children: [Expanded(child: map), SizedBox(width: 420, child: form)]);
              }
              return Column(
                children: [
                  Expanded(child: map),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.58),
                    child: form,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMap(Zone zone, bool inside) {
    final scheme = Theme.of(context).colorScheme;
    final pinColor = inside ? scheme.primary : scheme.error;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: zone.center,
            initialZoom: 16,
            minZoom: 13,
            maxZoom: 19,
            onPositionChanged: _onMapMoved,
          ),
          children: [
            TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmUserAgent),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: zone.center,
                  radius: zone.radiusM.toDouble(),
                  useRadiusInMeter: true,
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderColor: scheme.primary,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ),
        IgnorePointer(
          child: Center(
            child: Padding(
              // La punta del pin queda exactamente en el centro del mapa.
              padding: const EdgeInsets.only(bottom: 48),
              child: Icon(Icons.location_on, size: 52, color: pinColor, shadows: const [
                Shadow(blurRadius: 8, color: Colors.black38, offset: Offset(0, 2)),
              ]),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Center(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(24),
              color: inside ? scheme.primaryContainer : scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      inside ? Icons.check_circle : Icons.wrong_location_outlined,
                      size: 18,
                      color: inside ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        inside ? 'Dentro de la cobertura de ${zone.name}' : 'Fuera de ${zone.name}: mueve el mapa',
                        style: TextStyle(color: inside ? scheme.onPrimaryContainer : scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(List<Zone> zones, Zone zone, bool inside) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: zone.id,
                decoration: const InputDecoration(
                  labelText: 'Barrio (zona de cobertura)',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: [for (final z in zones) DropdownMenuItem(value: z.id, child: Text(z.name))],
                onChanged: (id) => _selectZone(zones.firstWhere((z) => z.id == id)),
              ),
              const SizedBox(height: 16),
              Text('Tipo de lugar', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tipo in AddressType.values)
                    ChoiceChip(
                      avatar: Icon(tipo.icon, size: 18),
                      label: Text(tipo.label),
                      selected: _tipo == tipo,
                      onSelected: (_) => setState(() => _tipo = tipo),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detalle,
                maxLength: 255,
                decoration: InputDecoration(labelText: 'Detalle', hintText: _tipo.hint),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar como dirección predeterminada'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: inside && !_saving ? () => _save(zone) : null,
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(inside ? 'Guardar dirección' : 'El pin debe estar dentro del barrio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
