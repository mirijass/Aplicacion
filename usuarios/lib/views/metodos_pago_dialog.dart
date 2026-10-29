import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'paypal_checkout_dialog.dart';

/// Modal para seleccionar y procesar métodos de pago in-app
class MetodosPagoDialog extends StatefulWidget {
  final double total;
  final Function(String metodoPago, String direccion) onPagoConfirmado;

  const MetodosPagoDialog({
    super.key,
    required this.total,
    required this.onPagoConfirmado,
  });

  static Future<void> show(
    BuildContext context, {
    required double total,
    required Function(String metodoPago, String direccion) onPagoConfirmado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MetodosPagoDialog(
        total: total,
        onPagoConfirmado: onPagoConfirmado,
      ),
    );
  }

  @override
  State<MetodosPagoDialog> createState() => _MetodosPagoDialogState();
}

class _MetodosPagoDialogState extends State<MetodosPagoDialog> {
  String _metodoSeleccionado = 'Tarjeta de Crédito/Débito';
  final _direccionCtrl = TextEditingController(text: 'Obteniendo ubicación GPS actual...');
  final _tarjetaCtrl = TextEditingController(text: '4152 •••• •••• 9821');
  bool _isProcessing = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  void _obtenerUbicacionActual() async {
    setState(() => _isGettingLocation = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _isGettingLocation = false;
      _direccionCtrl.text = 'Mi Ubicación Actual (GPS: 19.4326° N, 99.1332° O - Ciudad de México)';
    });
  }

  final List<Map<String, dynamic>> _opcionesPago = [
    {
      'id': 'Tarjeta de Crédito/Débito',
      'label': 'Tarjeta de Crédito / Débito',
      'icon': Icons.credit_card_rounded,
      'color': AppTheme.primaryPurple,
    },
    {
      'id': 'PayPal',
      'label': 'PayPal In-App',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Colors.blue,
    },
    {
      'id': 'Google Pay / Apple Pay',
      'label': 'Google Pay / Apple Pay',
      'icon': Icons.phone_android_rounded,
      'color': Colors.black,
    },
    {
      'id': 'Efectivo contra entrega',
      'label': 'Efectivo al recibir',
      'icon': Icons.payments_rounded,
      'color': Colors.green,
    },
  ];

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _tarjetaCtrl.dispose();
    super.dispose();
  }

  void _procesarPago() async {
    final direccionFinal = _direccionCtrl.text.trim().isNotEmpty
        ? _direccionCtrl.text.trim()
        : 'Mi Ubicación Actual (GPS: 19.4326° N, 99.1332° O)';

    if (_metodoSeleccionado == 'PayPal') {
      PayPalCheckoutDialog.show(
        context,
        total: widget.total,
        usuarioEmail: 'cliente.paypal@ejemplo.com',
        onPagoExitoso: (transactionId, paypalEmail) {
          Navigator.pop(context);
          widget.onPagoConfirmado(
            'PayPal ($transactionId)',
            direccionFinal,
          );
        },
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.pop(context);
    widget.onPagoConfirmado(
      _metodoSeleccionado,
      direccionFinal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Pasarela de Pago In-App',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total a pagar: \$${widget.total.toStringAsFixed(2)} MXN',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 20),

          // Selector de Método de Pago
          const Text('Selecciona tu Método de Pago:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Column(
            children: _opcionesPago.map((op) {
              final isSel = _metodoSeleccionado == op['id'];
              return InkWell(
                onTap: () => setState(() => _metodoSeleccionado = op['id'] as String),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primaryExtraLight : AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? AppTheme.primaryPurple : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(op['icon'] as IconData, color: op['color'] as Color, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          op['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                      if (isSel)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Campo de Dirección de Entrega para Geolocalización
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dirección de Entrega',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
              ),
              TextButton.icon(
                onPressed: _isGettingLocation ? null : _obtenerUbicacionActual,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primaryPurple),
                label: const Text(
                  'Usar mi ubicación GPS',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _direccionCtrl,
            decoration: InputDecoration(
              hintText: 'Ingresa la dirección o usa GPS',
              prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryPurple),
              suffixIcon: IconButton(
                icon: const Icon(Icons.gps_fixed_rounded, color: AppTheme.primaryPurple, size: 20),
                tooltip: 'Obtener Ubicación Actual por GPS',
                onPressed: _obtenerUbicacionActual,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botón Pagar Ahora
          ElevatedButton(
            onPressed: _isProcessing ? null : _procesarPago,
            child: _isProcessing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Pagar \$${widget.total.toStringAsFixed(2)} MXN'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
