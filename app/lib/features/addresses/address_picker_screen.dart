import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/map_layers.dart';
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
  bool _locating = false;
  List<Zone> _zones = const [];

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

  /// Pone el pin en la ubicación real del teléfono si cae dentro de alguna zona de cobertura.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final access = await LocationService.ensureAccess();
      if (!mounted) {
        return;
      }
      if (access != LocationAccess.granted) {
        showMessage(context, switch (access) {
          LocationAccess.serviceOff => 'Activa el GPS del teléfono para usar tu ubicación.',
          LocationAccess.deniedForever => 'El permiso de ubicación está bloqueado. Actívalo en los ajustes.',
          _ => 'Necesitamos el permiso de ubicación para usar tu posición actual.',
        });
        return;
      }

      final position = await LocationService.current();
      if (!mounted) {
        return;
      }
      if (position == null) {
        showMessage(context, 'No pudimos obtener tu ubicación. Inténtalo de nuevo.');
        return;
      }

      final here = LatLng(position.latitude, position.longitude);
      final zone = _zones.where((z) => z.contains(here)).firstOrNull;
      if (zone == null) {
        showMessage(
          context,
          'Tu ubicación está fuera de las zonas de cobertura. Mueve el pin a un barrio con servicio.',
        );
        return;
      }
      setState(() {
        _zone = zone;
        _pin = here;
      });
      _map.move(here, 18);
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _save(Zone zone) async {
    setState(() => _saving = true);
    try {
      final address = await ref
          .read(addressRepositoryProvider)
          .create(
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
          _zones = list;
          final zone = _zone!;
          final inside = zone.contains(_pin);

          return LayoutBuilder(
            builder: (context, constraints) {
              final map = _buildMap(zone, inside);
              final form = _buildForm(list, zone, inside);
              if (constraints.maxWidth >= 840) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: map),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 420, child: form),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      child: map,
                    ),
                  ),
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
            const AppTileLayer(),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: zone.center,
                  radius: zone.radiusM.toDouble(),
                  useRadiusInMeter: true,
                  color: scheme.primary.withValues(alpha: 0.07),
                  borderColor: scheme.primary.withValues(alpha: 0.65),
                  borderStrokeWidth: 1.6,
                ),
              ],
            ),
            appMapAttribution(context),
          ],
        ),
        IgnorePointer(
          child: Center(
            // La base del pin queda exactamente en el centro del mapa.
            child: Padding(
              padding: const EdgeInsets.only(bottom: 54),
              child: _MapPin(color: pinColor),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Center(
            child: Glass(
              solid: true,
              radius: 22,
              tint: inside ? scheme.primary : scheme.error,
              tintStrength: 0.10,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(inside ? Icons.check_circle_rounded : Icons.wrong_location_outlined, size: 18, color: pinColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      inside ? 'Dentro de la cobertura de ${zone.name}' : 'Fuera de ${zone.name}: mueve el mapa',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 18,
          child: Glass(
            solid: true,
            radius: 26,
            onTap: _locating ? null : _useCurrentLocation,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _locating
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Mi ubicación', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(List<Zone> zones, Zone zone, bool inside) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Glass(
        solid: true,
        radius: 30,
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
      ),
    );
  }
}

/// Pin del mapa: cabeza redonda con brillo y sombra, y una punta que marca el punto exacto.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 76,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        // Sombra en el suelo, bajo la punta.
        Positioned(
          bottom: 0,
          child: Container(
            width: 18,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
        ),
        Positioned(bottom: 6, child: Container(width: 3, height: 22, color: color)),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.25)!, color],
            ),
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
        ),
      ],
    ),
  );
}
