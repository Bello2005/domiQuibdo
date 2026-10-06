import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../orders/order_repository.dart';
import 'incident_type.dart';
import 'share_location.dart';

/// Botón SOS. La alerta y los reportes se guardan en el backend (soporte los ve en el panel);
/// la llamada al 123 sigue siendo simulada: no se marca ningún número real.
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
              subtitle: 'Policía Nacional (llamada simulada en esta demo)',
              onTap: () async {
                final registered = _report(ref, IncidentType.sos);
                await showDialog<void>(
                  context: context,
                  builder: (_) => _SimulatedCallDialog(registered: registered),
                );
                if (context.mounted) Navigator.pop(context);
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
              'La llamada al 123 es simulada en esta demo; tu alerta y tus reportes sí quedan registrados para soporte.',
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
        child: Card(
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

class _SimulatedCallDialog extends StatefulWidget {
  const _SimulatedCallDialog({required this.registered});

  /// Resultado de guardar la alerta SOS en el backend (se resuelve mientras corre la cuenta regresiva).
  final Future<bool> registered;

  @override
  State<_SimulatedCallDialog> createState() => _SimulatedCallDialogState();
}

class _SimulatedCallDialogState extends State<_SimulatedCallDialog> {
  static const _seconds = 3;
  int _remaining = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calling = _remaining > 0;

    return AlertDialog(
      icon: Icon(calling ? Icons.phone_in_talk : Icons.check_circle_outline, size: 44, color: AppColors.sos),
      title: Text(calling ? 'Llamando al 123 en $_remaining…' : 'Llamada simulada'),
      content: calling
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: 1 - _remaining / _seconds, color: AppColors.sos),
                const SizedBox(height: 12),
                const Text('Puedes cancelar si fue un error.'),
              ],
            )
          : FutureBuilder<bool>(
              future: widget.registered,
              builder: (context, snapshot) => Text(
                switch (snapshot.data) {
                  true => 'Tu alerta SOS quedó registrada con tu ubicación y soporte ya puede verla. '
                      'En la versión final, la app también marcará la Línea 123.',
                  false => 'No pudimos registrar la alerta por falta de conexión. '
                      'Si estás en peligro, llama directamente al 123.',
                  null => 'Registrando tu alerta…',
                },
                style: theme.textTheme.bodyMedium,
              ),
            ),
      actions: [
        if (calling)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))
        else
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    );
  }
}
