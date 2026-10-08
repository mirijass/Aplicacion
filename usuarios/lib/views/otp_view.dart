import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import 'productos_view.dart';

/// Pantalla de Autenticación de Doble Factor (2FA / OTP por Correo o SMS)
class OtpView extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController productoController;
  final CompraController compraController;
  final ThemeController? themeController;
  final String correoDestino;
  final String otpGenerado;

  const OtpView({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.productoController,
    required this.compraController,
    this.themeController,
    required this.correoDestino,
    required this.otpGenerado,
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _segundosRestantes = 60;
  Timer? _timer;
  bool _isVerifying = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    setState(() => _segundosRestantes = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes > 0) {
        setState(() => _segundosRestantes--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verificarOtp() {
    final codigoIngresado = _controllers.map((c) => c.text.trim()).join();
    if (codigoIngresado.length < 6) {
      setState(() => _errorMsg = 'Ingresa el código completo de 6 dígitos');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    // Validar código OTP
    if (codigoIngresado == widget.otpGenerado || codigoIngresado == '123456') {
      widget.usuarioController.cargarUsuarios();
      widget.productoController.setActiveUser(widget.authController.currentUser);
      widget.compraController.cargarCompras(usuarioLogeado: widget.authController.currentUser);

      Navigator.pushReplacement(
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
      );
    } else {
      setState(() {
        _isVerifying = false;
        _errorMsg = 'Código OTP incorrecto. Revisa el correo enviado.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Autenticación de 2 Factores (2FA)'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono decorativo de Seguridad 2FA
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryExtraLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryLight, width: 2),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 42,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Verificación de Seguridad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hemos enviado un código OTP de 6 dígitos a:\n${widget.correoDestino}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Hint de código para pruebas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryExtraLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.primaryPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Código enviado: ${widget.otpGenerado} (o 123456)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

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
                const SizedBox(height: 20),

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
                  const SizedBox(height: 16),
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
                            Icon(Icons.lock_open_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Verificar e Ingresar'),
                          ],
                        ),
                ),
                const SizedBox(height: 20),

                // Reenviar código
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No recibiste el código? ', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    TextButton(
                      onPressed: _segundosRestantes == 0
                          ? () {
                              _iniciarTimer();
                              widget.authController.enviarCodigoVerificacion(widget.correoDestino);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nuevo código reenviado a tu correo'),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        _segundosRestantes > 0
                            ? 'Reenviar en ${_segundosRestantes}s'
                            : 'Reenviar Código',
                        style: TextStyle(
                          color: _segundosRestantes == 0 ? AppTheme.primaryPurple : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
