import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config.dart';

/// Matriz que cambia la saturación (1 = sin cambio, 0 = grises) y desplaza el brillo.
List<double> _saturation(double s, {double brightness = 0, double contrast = 1}) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final o = brightness + 128 * (1 - contrast);
  return [
    (lr + (1 - lr) * s) * contrast, lg * (1 - s) * contrast, lb * (1 - s) * contrast, 0, o, //
    lr * (1 - s) * contrast, (lg + (1 - lg) * s) * contrast, lb * (1 - s) * contrast, 0, o,
    lr * (1 - s) * contrast, lg * (1 - s) * contrast, (lb + (1 - lb) * s) * contrast, 0, o,
    0, 0, 0, 1, 0,
  ];
}

/// Mosaicos de OpenStreetMap suavizados para que combinen con la app: en modo claro, menos saturados y
/// más luminosos (los colores de la ruta y los marcadores destacan); en modo oscuro, mapa oscuro.
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final tiles = TileLayer(
      urlTemplate: AppConfig.osmTileUrl,
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: AppConfig.osmUserAgent,
    );

    // El filtro se aplica a toda la capa de una vez (más barato que filtrar cada mosaico).
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(
        dark ? _saturation(0.55, brightness: -12, contrast: 0.92) : _saturation(0.5, brightness: 14, contrast: 0.94),
      ),
      child: dark ? Builder(builder: (context) => darkModeTilesContainerBuilder(context, tiles)) : tiles,
    );
  }
}

/// Atribución obligatoria de los datos del mapa, discreta y con fondo propio para leerse.
Widget appMapAttribution(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;

  return SimpleAttributionWidget(
    source: Text('© OpenStreetMap contributors', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10)),
    backgroundColor: scheme.surface.withValues(alpha: 0.82),
  );
}
