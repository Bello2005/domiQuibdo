import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass.dart';
import '../orders/order_repository.dart';
import 'incident_type.dart';
import 'share_location.dart';

/// Botón SOS. La alerta y los reportes se guardan en el backend (soporte los ve en el panel) y
/// "Llamar" abre el marcador del teléfono con el 123 listo: la persona confirma la llamada.
Future<void> showSosSheet(BuildContext context, {required int orderId, required String shareMessage}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SosSheet(orderId: orderId, shareMessage: shareMessage),
    );

class _SosSheet extends ConsumerWidget {
  const _SosSheet({required this.orderId, required this.shareMessage});

  final int orderId;
  final String shareMessage;

  /// Registra el incidente con la ubicación actual (si el permiso ya fue concedido).
  /// Devuelve false si no se pudo guardar, para avisarle a la persona.
  Future<bool> _report(WidgetRef ref, IncidentType type) async {
    final position = await LocationService.currentIfAllowed();
    try {
      await ref.read(orderRepositoryProvider).reportIncident(orderId, type, position: position);
      return true;
    } on ApiException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.sos,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.shield_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Necesitas ayuda?', style: theme.textTheme.titleLarge),
                      Text('Tu seguridad es lo primero.', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SosAction(
              icon: Icons.local_police_outlined,
              color: AppColors.sos,
              title: 'Llamar a emergencias · 123',
              subtitle: 'Policía Nacional · también avisamos a soporte',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final registered = _report(ref, IncidentType.sos);
                final dialed = await launchUrl(Uri.parse('tel:123'), mode: LaunchMode.externalApplication);
                final sent = await registered;
                messenger.showSnackBar(SnackBar(
                  content: Text([
                    if (!dialed) 'No se pudo abrir el marcador: llama al 123 desde tu teléfono.',
                    sent ? 'Alerta SOS enviada a soporte con tu ubicación.' : 'No pudimos avisar a soporte: revisa tu conexión.',
                  ].join(' ')),
                ));
              },
            ),
            _SosAction(
              icon: Icons.share_location,
              color: scheme.primary,
              title: 'Enviar mi ubicación a un contacto',
              subtitle: 'Abre WhatsApp con el enlace de Google Maps',
              onTap: () => shareViaWhatsApp(context, shareMessage),
            ),
            _SosAction(
              icon: Icons.report_outlined,
              color: scheme.secondary,
              title: 'Reportar un problema con el pedido',
              subtitle: 'Soporte revisará tu caso',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final sent = await _report(ref, IncidentType.problema);
                messenger.showSnackBar(SnackBar(
                  content: Text(sent
                      ? 'Reporte enviado. Soporte revisará tu caso.'
                      : 'No pudimos enviar el reporte. Revisa tu conexión e intenta de nuevo.'),
                ));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Tus alertas y reportes quedan registrados con tu ubicación para que soporte te contacte.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosAction extends StatelessWidget {
  const _SosAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              child: Icon(icon),
            ),
            title: Text(title, style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );
}
