import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';

String googleMapsLink(LatLng position) =>
    'https://maps.google.com/?q=${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';

/// [position] es la última posición real del repartidor; sin ella se comparte el pedido sin enlace.
String trackingShareMessage({required Order order, LatLng? position}) =>
    'Hola, estoy recibiendo un domicilio de ${order.restaurant?.name ?? 'DomiQuibdó'} '
    '(pedido #${order.id}) por DomiQuibdó.'
    '${position == null ? '' : ' Ubicación actual del repartidor: ${googleMapsLink(position)}'}';

/// Abre WhatsApp con el mensaje prellenado (en web abre wa.me en otra pestaña).
Future<void> shareViaWhatsApp(BuildContext context, String message) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp. Usa "Más opciones".')));
  }
}

/// Navegación paso a paso hasta [destination] en Google Maps (o el navegador si no está instalada).
Future<void> openDirections(LatLng destination) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&travelmode=driving'
          '&destination=${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}'),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

Future<void> shareWithSystem(String message) =>
    SharePlus.instance.share(ShareParams(text: message, subject: 'Mi domicilio en DomiQuibdó'));
