import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Servicio auxiliar de correo electrónico utilizando la librería `mailer` (Gmail SMTP).
class MailHelper {
  // Credenciales de configuración (Reemplazar por credenciales reales de Gmail / App Password)
  static final String _username = 'miriamlozano204@gmail.com';
  static final String _password = 'mvqp zxfw xeio lhgn';

  static SmtpServer get _smtpServer => gmail(
        _username.trim(),
        _password.replaceAll(' ', ''),
      );

  /// Enviar correo genérico
  static Future<void> sendEmail(
    String destino,
    String asunto,
    String mensaje, {
    String? htmlContent,
  }) async {
    if (destino.trim().isEmpty) {
      debugPrint('MailHelper: Dirección de correo vacía.');
      return;
    }

    final message = Message()
      ..from = Address(_username, 'Mi Tiendita App')
      ..recipients.add(destino.trim())
      ..subject = asunto
      ..text = mensaje
      ..html = htmlContent ?? "<p style='font-family: Roboto;'>$mensaje</p>";

    try {
      await send(message, _smtpServer);
      debugPrint("Correo enviado exitosamente a $destino");
    } catch (e) {
      debugPrint("Error al enviar el correo a $destino: $e");
      rethrow;
    }
  }

  /// Recuperación de contraseña
  static Future<void> sendPasswordRecoveryEmail(
    String destino,
    String nuevaPassword,
  ) async {
    final asunto = 'Recuperación de Contraseña';
    final mensaje =
        'Hola,\n\nHas solicitado restablecer tu contraseña. Tu nueva contraseña temporal es: $nuevaPassword\nPor seguridad, te recomendamos cambiarla al iniciar sesión en la aplicación.';
    
    final html = '''
    <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px;">
      <h2 style="color: #7E57C2; margin-top: 0;">Recuperación de Contraseña</h2>
      <p>Hola,</p>
      <p>Has solicitado restablecer tu contraseña. Tu nueva contraseña temporal es:</p>
      <div style="text-align: center; margin: 20px 0;">
        <span style="font-size: 22px; font-weight: bold; letter-spacing: 2px; color: #5E35B1; background: #EDE7F6; padding: 12px 24px; border-radius: 8px; display: inline-block;">$nuevaPassword</span>
      </div>
      <p style="color: #666; font-size: 13px;">Por seguridad, te recomendamos cambiar esta contraseña inmediatamente después de iniciar sesión.</p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
      <p style="font-size: 12px; color: #999;">Este correo fue generado automáticamente por Mi Tiendita App.</p>
    </div>
    ''';

    await sendEmail(destino, asunto, mensaje, htmlContent: html);
  }

  /// Resumen de compra
  static Future<void> sendPurchaseSummaryEmail(
    String destino,
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final asunto = 'Resumen de Compra - Mi Tiendita';
    
    final buffer = StringBuffer();
    buffer.writeln('¡Gracias por tu compra!');
    buffer.writeln('Detalle de productos:');
    for (var item in items) {
      final nombre = item['nombre_product'] ?? item['nombre'] ?? 'Producto';
      final cant = item['cantidad'] ?? 1;
      final precio = double.tryParse(item['precio'].toString()) ?? 0.0;
      buffer.writeln('- $nombre x$cant: \$${(precio * cant).toStringAsFixed(2)} MXN');
    }
    buffer.writeln('Total pagado: \$${total.toStringAsFixed(2)} MXN');

    final itemsHtml = items.map((item) {
      final nombre = item['nombre_product'] ?? item['nombre'] ?? 'Producto';
      final cant = item['cantidad'] ?? 1;
      final precio = double.tryParse(item['precio'].toString()) ?? 0.0;
      final subtotal = (precio * cant).toStringAsFixed(2);
      return '''
        <tr>
          <td style="padding: 10px; border-bottom: 1px solid #eee;">$nombre</td>
          <td style="padding: 10px; border-bottom: 1px solid #eee; text-align: center;">$cant</td>
          <td style="padding: 10px; border-bottom: 1px solid #eee; text-align: right;">\$$subtotal MXN</td>
        </tr>
      ''';
    }).join('');

    final html = '''
    <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px;">
      <h2 style="color: #7E57C2; margin-top: 0;">¡Gracias por tu compra! 🛒</h2>
      <p>Hemos procesado tu pedido correctamente. A continuación se muestra el detalle de tu recibo:</p>
      
      <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
        <thead>
          <tr style="background-color: #EDE7F6; color: #5E35B1;">
            <th style="padding: 10px; text-align: left;">Producto</th>
            <th style="padding: 10px; text-align: center;">Cantidad</th>
            <th style="padding: 10px; text-align: right;">Subtotal</th>
          </tr>
        </thead>
        <tbody>
          $itemsHtml
        </tbody>
      </table>

      <div style="text-align: right; background-color: #F5F0FF; padding: 12px; border-radius: 8px;">
        <span style="font-size: 16px; color: #333;">Total Pagado: </span>
        <span style="font-size: 20px; font-weight: bold; color: #5E35B1;">\$${total.toStringAsFixed(2)} MXN</span>
      </div>

      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
      <p style="font-size: 12px; color: #999;">Si tienes dudas sobre tu pedido, contáctanos.</p>
    </div>
    ''';

    await sendEmail(destino, asunto, buffer.toString(), htmlContent: html);
  }

  /// Verificación / Token
  static Future<void> sendVerificationTokenEmail(
    String destino,
    String token,
  ) async {
    final asunto = 'Código de Verificación de Cuenta';
    final mensaje = 'Tu código de verificación de seguridad es: $token';
    
    final html = '''
    <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px;">
      <h2 style="color: #7E57C2; margin-top: 0;">Verificación de Cuenta 🔐</h2>
      <p>Utiliza el siguiente código para verificar tu cuenta o completar el registro:</p>
      <div style="text-align: center; margin: 25px 0;">
        <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #5E35B1; background: #EDE7F6; padding: 14px 28px; border-radius: 8px; display: inline-block;">$token</span>
      </div>
      <p style="font-size: 13px; color: #666;">Si no realizaste esta solicitud, puedes ignorar este mensaje.</p>
    </div>
    ''';

    await sendEmail(destino, asunto, mensaje, htmlContent: html);
  }
}
