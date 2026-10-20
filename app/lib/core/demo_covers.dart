import 'package:flutter/services.dart';

/// Fotos de portada locales para la demo de clase.
///
/// Las fotos van en `assets/demo_covers/<id del restaurante>_<n>.jpg` (o .png/.webp):
/// la `_0` es la portada y el resto forman la galería del detalle. Reemplazan a la
/// foto que manda el backend. Esa carpeta está en .gitignore: las fotos solo viajan
/// dentro del APK que se compila en el equipo, no se publican.
abstract final class DemoCovers {
  static const _dir = 'assets/demo_covers/';
  static final Map<int, List<String>> _byRestaurant = {};

  static Future<void> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final pattern = RegExp(r'^assets/demo_covers/(\d+)_(\d+)\.(jpe?g|png|webp)$', caseSensitive: false);
    final found = <int, List<(int, String)>>{};
    for (final asset in manifest.listAssets().where((a) => a.startsWith(_dir))) {
      final match = pattern.firstMatch(asset);
      if (match == null) continue;
      found.putIfAbsent(int.parse(match.group(1)!), () => []).add((int.parse(match.group(2)!), asset));
    }
    for (final MapEntry(:key, :value) in found.entries) {
      value.sort((a, b) => a.$1.compareTo(b.$1));
      _byRestaurant[key] = [for (final (_, asset) in value) asset];
    }
  }

  /// Portada local del restaurante, o null si no hay.
  static String? of(int restaurantId) => _byRestaurant[restaurantId]?.first;

  /// Todas las fotos locales del restaurante (portada primero); vacía si no hay.
  static List<String> gallery(int restaurantId) => _byRestaurant[restaurantId] ?? const [];
}
