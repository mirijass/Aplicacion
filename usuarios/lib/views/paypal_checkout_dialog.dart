import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../config/paypal_config.dart';

/// Modal interactivo de Pasarela de Pago PayPal In-App
class PayPalCheckoutDialog extends StatefulWidget {
  final double total;
  final String usuarioEmail;
  final Function(String transactionId, String paypalEmail) onPagoExitoso;

  const PayPalCheckoutDialog({
    super.key,
    required this.total,
    required this.usuarioEmail,
    required this.onPagoExitoso,
  });

  static Future<void> show(
    BuildContext context, {
    required double total,
    required String usuarioEmail,
    required Function(String transactionId, String paypalEmail) onPagoExitoso,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PayPalCheckoutDialog(
        total: total,
        usuarioEmail: usuarioEmail,
        onPagoExitoso: onPagoExitoso,
      ),
    );
  }

  @override
  State<PayPalCheckoutDialog> createState() => _PayPalCheckoutDialogState();
}

class _PayPalCheckoutDialogState extends State<PayPalCheckoutDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _pasoActual = 0; // 0: Login / Confirmación PayPal, 1: Procesando Pago, 2: Éxito
  bool _recordarSesion = true;
  String _transactionId = '';

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.usuarioEmail.isNotEmpty
        ? widget.usuarioEmail
        : 'cliente.paypal@ejemplo.com';
    _passCtrl.text = '••••••••••••';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _iniciarProcesamientoPayPal() async {
    if (_pasoActual == 0) {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _pasoActual = 1); // Estado procesando

      // Simulación de respuesta API REST de PayPal (Order Create & Capture API)
      await Future.delayed(const Duration(milliseconds: 1800));

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _transactionId = 'PAYID-MX$nowMs';

      if (!mounted) return;
      setState(() => _pasoActual = 2); // Estado éxito

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      Navigator.pop(context);
      widget.onPagoExitoso(_transactionId, _emailCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    const paypalBlue = Color(0xFF003087);
    const paypalLightBlue = Color(0xFF0070BA);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado Oficial PayPal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: paypalBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'PayPal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Checkout Seguro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_pasoActual == 0) ...[
              // Detalles del Monto a Pagar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comercio: Mi Tiendita App',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cuenta Beneficiaria: ${PayPalConfig.paypalBusinessEmail}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${widget.total.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: paypalBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Formulario Iniciar Sesión PayPal
              const Text(
                'Inicia sesión en PayPal para completar la compra:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico de PayPal',
                  prefixIcon: const Icon(Icons.email_outlined, color: paypalLightBlue),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty || !val.contains('@')) {
                    return 'Ingresa un correo de PayPal válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Contraseña de PayPal',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: paypalLightBlue),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa tu contraseña de PayPal';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Checkbox(
                    value: _recordarSesion,
                    activeColor: paypalLightBlue,
                    onChanged: (v) => setState(() => _recordarSesion = v ?? true),
                  ),
                  const Text(
                    'Recordar esta cuenta para compras futuras',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Botón Oficial Pagar con PayPal
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC439), // Color oficial del botón PayPal
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 2,
                ),
                onPressed: _iniciarProcesamientoPayPal,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: paypalBlue, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Pagar ahora con PayPal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: paypalBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_pasoActual == 1) ...[
              // Estado Procesando
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: paypalLightBlue, strokeWidth: 3),
                    const SizedBox(height: 20),
                    const Text(
                      'Autorizando transacción con PayPal API...',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: paypalBlue),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Conectando con la cuenta de ${_emailCtrl.text}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Estado Éxito
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 54),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '¡Pago Autorizado Exitosamente!',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.successColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID de Transacción PayPal: $_transactionId',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
