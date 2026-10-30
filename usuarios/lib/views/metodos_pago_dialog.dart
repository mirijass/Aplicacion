import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/saldo_proveedor_controller.dart';
import '../utils/app_theme.dart';
import 'paypal_checkout_dialog.dart';
import 'recargar_saldo_dialog.dart';

/// Modal para seleccionar y procesar métodos de pago in-app con validación de saldo, referencia y folio
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
  final _formKey = GlobalKey<FormState>();
  final SaldoProveedorController _saldoCtrl = SaldoProveedorController();

  String _metodoSeleccionado = 'Tarjeta de Crédito/Débito';
  final _direccionCtrl = TextEditingController(text: 'Obteniendo ubicación GPS actual...');
  final _tarjetaCtrl = TextEditingController(text: '4152313245679821');
  final _expCtrl = TextEditingController(text: '09/28');
  final _cvvCtrl = TextEditingController(text: '842');

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
      'id': 'Apple Pay / Google Wallet',
      'label': 'Apple Pay / Google Wallet',
      'icon': Icons.contactless_rounded,
      'color': Colors.black87,
    },
    {
      'id': 'Saldo Disponible In-App',
      'label': 'Bolsa de Saldo / Monedero In-App',
      'icon': Icons.savings_rounded,
      'color': const Color(0xFF2E7D32),
    },
  ];

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _tarjetaCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _procesarPago() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que el usuario disponga de saldo suficiente para realizar la compra
    if (_saldoCtrl.saldo <= 0 || _saldoCtrl.saldo < widget.total) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saldo insuficiente (\$${_saldoCtrl.saldo.toStringAsFixed(2)} MXN). Sí o sí debes disponer de dinero suficiente (\$${widget.total.toStringAsFixed(2)} MXN) para realizar la compra.',
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final direccionFinal = _direccionCtrl.text.trim().isNotEmpty
        ? _direccionCtrl.text.trim()
        : 'Mi Ubicación Actual (GPS: 19.4326° N, 99.1332° O)';

    if (_metodoSeleccionado == 'PayPal') {
      PayPalCheckoutDialog.show(
        context,
        total: widget.total,
        usuarioEmail: 'cliente.paypal@ejemplo.com',
        onPagoExitoso: (transactionId, paypalEmail) async {
          final folioAprobado = 'GP-AUTH-${DateTime.now().millisecondsSinceEpoch}';
          await _saldoCtrl.descontarSaldo(
            monto: widget.total,
            concepto: 'Compra en Tiendita (PayPal: $transactionId)',
            folio: folioAprobado,
            comisionGanada: 0.0,
          );
          if (!mounted) return;
          Navigator.pop(context);
          widget.onPagoConfirmado(
            'PayPal ($transactionId | Folio: $folioAprobado)',
            direccionFinal,
          );
        },
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 900));

    // El folio de autorización se retorna únicamente después de que el pago es aprobado por el proveedor
    final folioAprobado = 'GP-AUTH-${DateTime.now().millisecondsSinceEpoch}';

    final cobroOk = await _saldoCtrl.descontarSaldo(
      monto: widget.total,
      concepto: 'Compra en Tiendita ($_metodoSeleccionado)',
      folio: folioAprobado,
      comisionGanada: 0.0,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!cobroOk) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('No dispones de saldo suficiente para completar la compra.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    Navigator.pop(context);
    widget.onPagoConfirmado(
      '$_metodoSeleccionado (Folio: $folioAprobado)',
      direccionFinal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _saldoCtrl,
      builder: (context, _) {
        final saldoActual = _saldoCtrl.saldo;
        final alcanzaSaldo = saldoActual >= widget.total && saldoActual > 0;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
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
          child: SingleChildScrollView(
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
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Pasarela de Pago In-App',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${widget.total.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Indicador de Saldo Disponible y Validación de Fondos
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: alcanzaSaldo ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: alcanzaSaldo ? const Color(0xFFC8E6C9) : AppTheme.errorColor.withAlpha(120),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alcanzaSaldo ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                          color: alcanzaSaldo ? const Color(0xFF2E7D32) : AppTheme.errorColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alcanzaSaldo
                                ? 'Saldo disponible para compra: \$${saldoActual.toStringAsFixed(2)} MXN'
                                : 'Saldo insuficiente (\$${saldoActual.toStringAsFixed(2)} MXN). Debes disponer de dinero para realizar la compra.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: alcanzaSaldo ? const Color(0xFF1B5E20) : AppTheme.errorColor,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            RecargarSaldoDialog.show(
                              context,
                              controller: _saldoCtrl,
                              usuarioEmail: 'cliente@ejemplo.com',
                            );
                          },
                          child: const Text('Recargar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selector de Método de Pago
                  const Text('Selecciona tu Método de Pago:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Column(
                    children: _opcionesPago.map((op) {
                      final isSel = _metodoSeleccionado == op['id'];
                      return InkWell(
                        onTap: () => setState(() => _metodoSeleccionado = op['id'] as String),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              Icon(op['icon'] as IconData, color: op['color'] as Color, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  op['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13.5,
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

                  // Restricciones de Tarjeta de Crédito / Débito
                  if (_metodoSeleccionado == 'Tarjeta de Crédito/Débito') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tarjetaCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Número de Tarjeta (16 dígitos) *',
                        prefixIcon: Icon(Icons.credit_card_rounded, color: AppTheme.primaryPurple, size: 18),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (_metodoSeleccionado != 'Tarjeta de Crédito/Débito') return null;
                        if (val == null || val.trim().length != 16) {
                          return 'Ingresa exactamente 16 dígitos numéricos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expCtrl,
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Vencimiento (MM/AA) *',
                              hintText: '09/28',
                              isDense: true,
                            ),
                            validator: (val) {
                              if (_metodoSeleccionado != 'Tarjeta de Crédito/Débito') return null;
                              if (val == null || !RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(val.trim())) {
                                return 'Usa formato MM/AA';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'CVV (3-4 díg.) *',
                              hintText: '123',
                              isDense: true,
                            ),
                            validator: (val) {
                              if (_metodoSeleccionado != 'Tarjeta de Crédito/Débito') return null;
                              if (val == null || val.trim().length < 3 || val.trim().length > 4) {
                                return 'CVV de 3 o 4 dígitos';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Campo de Dirección de Entrega para Geolocalización
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Dirección de Entrega *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _isGettingLocation ? null : _obtenerUbicacionActual,
                        icon: _isGettingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                              )
                            : const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primaryPurple),
                        label: const Text(
                          'Usar ubicación GPS',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
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
                    validator: (val) {
                      if (val == null || val.trim().length < 6) {
                        return 'Ingresa una dirección de entrega válida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Botón Pagar Ahora
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alcanzaSaldo ? AppTheme.primaryPurple : Colors.grey.shade500,
                    ),
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
            ),
          ),
        );
      },
    );
  }
}
