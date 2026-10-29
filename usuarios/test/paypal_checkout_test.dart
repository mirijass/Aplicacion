import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usuarios/views/paypal_checkout_dialog.dart';

void main() {
  testWidgets('PayPalCheckoutDialog muestra los elementos de pago correctamente', (WidgetTester tester) async {
    bool pagoExitoso = false;
    String idTx = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                PayPalCheckoutDialog.show(
                  context,
                  total: 499.0,
                  usuarioEmail: 'test.paypal@ejemplo.com',
                  onPagoExitoso: (txId, email) {
                    pagoExitoso = true;
                    idTx = txId;
                  },
                );
              },
              child: const Text('Abrir PayPal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir PayPal'));
    await tester.pumpAndSettle();

    // Verificar encabezado y elementos de PayPal
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('Checkout Seguro'), findsOneWidget);
    expect(find.text('\$499.00 MXN'), findsOneWidget);
    expect(find.text('Pagar ahora con PayPal'), findsOneWidget);
  });
}
