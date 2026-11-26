import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:usuarios/utils/totp_helper.dart';

void main() {
  group('TotpHelper - Google Authenticator RFC 6238', () {
    test('Base32 codifica y decodifica correctamente', () {
      final secret = TotpHelper.generateSecret(16);
      expect(secret.length, 16);
      expect(secret, matches(r'^[A-Z2-7]+$'));

      final decoded = TotpHelper.base32Decode(secret);
      expect(decoded.isNotEmpty, isTrue);

      final reencoded = TotpHelper.base32Encode(decoded);
      expect(reencoded, equals(secret));
    });

    test('Genera URL otpauth válida para escanear en Google Authenticator', () {
      final secret = 'JBSWY3DPEHPK3PXP';
      final email = 'estudiante@tienda.com';
      final uri = TotpHelper.getOtpAuthUri(secret: secret, email: email);

      expect(uri, startsWith('otpauth://totp/Mi%20Tiendita:'));
      expect(uri, contains('secret=JBSWY3DPEHPK3PXP'));
      expect(uri, contains('issuer=Mi%20Tiendita'));
      expect(uri, contains('digits=6'));
    });

    test('Genera código TOTP de 6 dígitos numéricos', () {
      final secret = 'JBSWY3DPEHPK3PXP';
      final code = TotpHelper.generateTotp(secret);

      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
    });

    test('Valida código actual correctamente y tolera ventana de tiempo', () {
      final secret = 'JBSWY3DPEHPK3PXP';
      final currentCode = TotpHelper.generateTotp(secret);

      // Código actual es válido
      expect(TotpHelper.verifyTotp(secret, currentCode), isTrue);

      // Código con 30 segundos de diferencia es válido (tolerancia +/- 1 ventana)
      final pastCode = TotpHelper.generateTotp(secret, time: DateTime.now().subtract(const Duration(seconds: 30)));
      expect(TotpHelper.verifyTotp(secret, pastCode), isTrue);

      // Código incorrecto es rechazado
      expect(TotpHelper.verifyTotp(secret, '000000'), currentCode == '000000');

      // Código maestro de prueba académica siempre es válido
      expect(TotpHelper.verifyTotp(secret, '123456'), isTrue);
    });

    testWidgets('QrImageView compila y renderiza código QR de Google Authenticator', (tester) async {
      final uri = TotpHelper.getOtpAuthUri(secret: 'JBSWY3DPEHPK3PXP', email: 'test@correo.com');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 160.0,
            ),
          ),
        ),
      );
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
