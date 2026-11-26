import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/totp_helper.dart';
import 'productos_view.dart';

/// Pantalla de Autenticación de Doble Factor (2FA) mediante Google Authenticator (RFC 6238 / TOTP)
class OtpView extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController productoController;
  final CompraController compraController;
  final ThemeController? themeController;
  final String correoDestino;
  final String? otpGenerado;
  final String? secret;

  const OtpView({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.productoController,
    required this.compraController,
    this.themeController,
    required this.correoDestino,
    this.otpGenerado,
    this.secret,
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  late final String _secret;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _secret = widget.secret ?? TotpHelper.getSecretForEmail(widget.correoDestino);
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verificarOtp() {
    if (_isVerifying) return;
    final codigoIngresado = _controllers.map((c) => c.text.trim()).join();
    if (codigoIngresado.length < 6) {
      setState(() => _errorMsg = 'Ingresa el código completo de 6 dígitos de Google Authenticator');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    final isValid = TotpHelper.verifyTotp(_secret, codigoIngresado) ||
        (widget.otpGenerado != null &&
            widget.otpGenerado!.isNotEmpty &&
            codigoIngresado == widget.otpGenerado);

    if (isValid) {
      widget.usuarioController.cargarUsuarios();
      widget.productoController.setActiveUser(widget.authController.currentUser);
      widget.compraController.cargarCompras(usuarioLogeado: widget.authController.currentUser);

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('¡Autenticación con Google Authenticator exitosa!'),
            backgroundColor: AppTheme.successColor,
          ),
        );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ProductosView(
            authController: widget.authController,
            usuarioController: widget.usuarioController,
            productoController: widget.productoController,
            compraController: widget.compraController,
            themeController: widget.themeController,
          ),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        _isVerifying = false;
        _errorMsg = 'Código incorrecto o expirado. Ingresa el código actual que muestra Google Authenticator.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uriTotp = TotpHelper.getOtpAuthUri(
      secret: _secret,
      email: widget.correoDestino,
      issuer: 'Mi Tiendita',
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Google Authenticator (2FA)'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono decorativo de Google Authenticator / Seguridad
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryExtraLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryLight, width: 2),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Doble Factor (2FA)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escanea el código QR desde la aplicación Google Authenticator en tu celular:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Tarjeta con Código QR de Google Authenticator
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryLight, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x157E57C2),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: uriTotp,
                          version: QrVersions.auto,
                          size: 175.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.correoDestino,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Clave secreta manual con botón de copiar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryExtraLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 20, color: AppTheme.primaryPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clave manual (si no puedes escanear):',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            SelectableText(
                              _secret,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppTheme.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.primaryPurple),
                        tooltip: 'Copiar clave',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _secret));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Clave secreta copiada al portapapeles'),
                              backgroundColor: AppTheme.successColor,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Ingresa el código de 6 dígitos de Google Authenticator:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 14),

                // Campos de entrada para 6 dígitos OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 55,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (index == 5 && value.isNotEmpty) {
                            _verificarOtp();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),

                if (_errorMsg != null) ...[
                  Text(
                    _errorMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Botón de Confirmación
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verificarOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Verificar con Google Authenticator'),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // Indicador de clave de prueba para el profesor
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textMuted),
                      SizedBox(width: 8),
                      Text(
                        'Código de prueba académica disponible: 123456',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
