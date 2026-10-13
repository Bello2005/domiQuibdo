import 'package:domiquibdo/core/theme.dart';
import 'package:domiquibdo/core/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(extendBody: true, body: const SizedBox.expand(), bottomNavigationBar: child),
  );

  testWidgets('GlassNavBar avisa la pestaña tocada y muestra la insignia del carrito', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      host(
        GlassNavBar(
          currentIndex: 0,
          onTap: (i) => tapped = i,
          items: const [
            GlassNavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Inicio'),
            GlassNavItem(
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag,
              label: 'Carrito',
              badge: 3,
            ),
          ],
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Carrito'));
    expect(tapped, 1);
  });

  testWidgets('GlassCard responde al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: GlassCard(onTap: () => taps++, child: const Text('Pedido')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pedido'));
    expect(taps, 1);
  });

  testWidgets('GlassCard solid es casi opaco: el mapa de atrás no se ve a través del panel', (tester) async {
    Color topOf(WidgetTester tester) {
      final box = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(GlassCard), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.gradient != null);
      return (box.gradient! as LinearGradient).colors.first;
    }

    for (final solid in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: GlassCard(solid: solid, child: const Text('Panel')),
            ),
          ),
        ),
      );
      final alpha = topOf(tester).a;
      solid ? expect(alpha, greaterThan(0.9)) : expect(alpha, lessThan(0.5));
    }
  });
}
