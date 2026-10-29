/// Configuración y Credenciales de la Cuenta de PayPal (Developer / Business)
class PayPalConfig {
  /// Tu correo de cuenta de negocios registrado en PayPal
  static const String paypalBusinessEmail = 'tu_cuenta_negocio@paypal.com';

  /// Client ID obtenido del portal https://developer.paypal.com/
  /// Reemplaza este valor con tu Client ID real de Sandbox (Pruebas) o Live (Producción)
  static const String clientId = 'YOUR_PAYPAL_CLIENT_ID_HERE';

  /// Secret Key obtenido del portal de desarrolladores de PayPal
  static const String secretKey = 'YOUR_PAYPAL_SECRET_KEY_HERE';

  /// Entorno de desarrollo: 'sandbox' para pruebas, 'live' para cobros reales
  static const String environment = 'sandbox';

  /// URL Base de la API REST de PayPal según el entorno
  static String get baseUrl => environment == 'live'
      ? 'https://api-m.paypal.com'
      : 'https://api-m.sandbox.paypal.com';

  /// Enlace PayPal.me opcional para cobros directos por link o código QR
  static const String paypalMeUrl = 'https://paypal.me/TuNegocio';
}
