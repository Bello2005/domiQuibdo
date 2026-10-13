import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/widgets/glass.dart';

/// ¿Es la página a la que PayU devuelve al comprador al terminar (aprobado, rechazado o pendiente)?
bool isPayuReturnUrl(Uri uri) => uri.path.endsWith('/pagos/payu/respuesta');

/// Esquemas que el WebView no maneja y deben abrirse fuera (app del banco, Nequi, etc.).
bool opensOutsideWebView(Uri uri) =>
    !const {'http', 'https', 'about', 'data', 'blob', 'javascript'}.contains(uri.scheme);

/// Checkout de PayU dentro de la app. Es la misma pasarela de PayU en una pantalla propia:
/// la app nunca ve los datos de la tarjeta. Al volver PayU a nuestra página de respuesta se
/// muestra el resultado y la pantalla se cierra sola (devuelve `true`).
class PayuWebViewScreen extends StatefulWidget {
  const PayuWebViewScreen({super.key, required this.url, required this.orderId});

  final String url;
  final int orderId;

  @override
  State<PayuWebViewScreen> createState() => _PayuWebViewScreenState();
}

class _PayuWebViewScreenState extends State<PayuWebViewScreen> {
  static const _autoCloseDelay = Duration(seconds: 4);

  late final WebViewController _controller;
  int _progress = 0;
  bool _returned = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) {
              setState(() => _progress = value);
            }
          },
          onNavigationRequest: _onNavigationRequest,
          onPageFinished: (url) => _onPageFinished(Uri.parse(url)),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<NavigationDecision> _onNavigationRequest(NavigationRequest request) async {
    final uri = Uri.parse(request.url);
    if (opensOutsideWebView(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Sin app que lo abra: el pago puede seguir por otro medio dentro de PayU.
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPageFinished(Uri uri) {
    if (_returned || !isPayuReturnUrl(uri)) {
      return;
    }
    setState(() => _returned = true);
    _closeTimer = Timer(_autoCloseDelay, _close);
  }

  void _close() {
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmExit() async {
    if (_returned) {
      _close();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del pago?'),
        content: const Text('Tu pedido queda pendiente de pago y puedes pagarlo después desde "Pedidos".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir pagando')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _controller.canGoBack() && !_returned) {
          await _controller.goBack();
        } else {
          await _confirmExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: _confirmExit, icon: const Icon(Icons.close_rounded)),
          title: Row(
            children: [
              Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Pago seguro · Pedido #${widget.orderId}', style: theme.textTheme.titleMedium),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress < 100
                ? LinearProgressIndicator(value: _progress / 100, minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_returned)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                child: Glass(
                  blur: true,
                  radius: 28,
                  padding: const EdgeInsets.all(10),
                  child: FilledButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver a mi pedido'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
