import 'package:latlong2/latlong.dart';

abstract final class AppConfig {
  /// Backend en nuestro servidor (dirsoft). Se puede sobreescribir con `--dart-define=API_BASE_URL=...`
  /// (por ejemplo para apuntar a un backend local en desarrollo).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.domiquibdo.bello.works/api',
  );

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmUserAgent = 'co.uniclaretiana.domiquibdo';

  static const quibdoCenter = LatLng(5.6935, -76.6600);
}
