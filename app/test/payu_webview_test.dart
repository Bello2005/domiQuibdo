import 'package:domiquibdo/features/orders/payu_webview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPayuReturnUrl', () {
    test('reconoce la página de respuesta con su query de PayU', () {
      final uri = Uri.parse(
        'https://api.domiquibdo.bello.works/pagos/payu/respuesta?transactionState=4&referenceCode=DQ-3-AB12CD',
      );

      expect(isPayuReturnUrl(uri), isTrue);
    });

    test('no confunde la pasarela de PayU ni el checkout propio con el regreso', () {
      expect(
        isPayuReturnUrl(Uri.parse('https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/app/v4?k=1')),
        isFalse,
      );
      expect(isPayuReturnUrl(Uri.parse('https://api.domiquibdo.bello.works/pagos/payu/3?signature=abc')), isFalse);
    });
  });

  group('opensOutsideWebView', () {
    test('las páginas web se quedan dentro de la app', () {
      expect(opensOutsideWebView(Uri.parse('https://www.pse.com.co/inicio')), isFalse);
      expect(opensOutsideWebView(Uri.parse('about:blank')), isFalse);
    });

    test('los esquemas de apps (Nequi, bancos, intents) salen a la app correspondiente', () {
      expect(opensOutsideWebView(Uri.parse('nequi://payment?id=1')), isTrue);
      expect(opensOutsideWebView(Uri.parse('intent://pay#Intent;scheme=bank;end')), isTrue);
      expect(opensOutsideWebView(Uri.parse('tel:123')), isTrue);
    });
  });
}
