import 'package:flutter/services.dart';

/// Fotos de portada locales para la demo de clase.
///
/// Si existe `assets/demo_covers/<id del restaurante>.jpg` (o .png/.webp) se usa
/// en lugar de la foto que manda el backend. Esa carpeta está en .gitignore: las
/// fotos solo viajan dentro del APK que se compila en el equipo, no se publican.
abstract final class DemoCovers {
  static const _dir = 'assets/demo_covers/';
  static final Map<int, String> _byRestaurant = {};

  static Future<void> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final pattern = RegExp(r'^assets/demo_covers/(\d+)\.(jpe?g|png|webp)$', caseSensitive: false);
    for (final asset in manifest.listAssets().where((a) => a.startsWith(_dir))) {
      final match = pattern.firstMatch(asset);
      if (match != null) _byRestaurant[int.parse(match.group(1)!)] = asset;
    }
  }

  /// Ruta del asset local para el restaurante, o null si no hay.
  static String? of(int restaurantId) => _byRestaurant[restaurantId];
}
