import 'package:latlong2/latlong.dart';

abstract final class AppConfig {
  /// Backend en Render. Se puede sobreescribir con `--dart-define=API_BASE_URL=...`
  /// (por ejemplo para apuntar a un backend local en desarrollo).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://domiquibdo.onrender.com/api',
  );

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const osmUserAgent = 'co.uniclaretiana.domiquibdo';

  static const quibdoCenter = LatLng(5.6935, -76.6600);

  /// Sprint 0: cada cuánto avanza el marcador entre puntos de la ruta simulada.
  static const mockStepDuration = Duration(milliseconds: 3500);
}
