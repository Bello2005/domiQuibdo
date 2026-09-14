import 'package:latlong2/latlong.dart';

abstract final class AppConfig {
  /// Chrome: default. APK en celular: `--dart-define=API_BASE_URL=http://IP-DE-LA-MAC:8000/api`
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmUserAgent = 'co.uniclaretiana.domiquibdo';

  static const quibdoCenter = LatLng(5.6935, -76.6600);

  /// Sprint 0: cada cuánto avanza el marcador entre puntos de la ruta simulada.
  static const mockStepDuration = Duration(milliseconds: 3500);
}
