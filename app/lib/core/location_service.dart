import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// Posición del dispositivo (GPS real). Los permisos se piden solo cuando una función los necesita.
abstract final class LocationService {
  static Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();

    return switch (permission) {
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationAccess.denied,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.granted,
    };
  }

  static Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Posición actual sin pedir permisos (para adjuntarla a un SOS si ya fue concedida).
  static Future<LatLng?> currentIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      final position = await current();
      return position == null ? null : LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
