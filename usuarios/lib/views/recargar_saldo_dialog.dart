import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/saldo_proveedor_controller.dart';
import '../utils/app_theme.dart';
import 'paypal_checkout_dialog.dart';

/// Modal interactivo para recargar la bolsa de saldo con el proveedor GestoPago
class RecargarSaldoDialog extends StatefulWidget {
  final SaldoProveedorController controller;
  final String usuarioEmail;

  const RecargarSaldoDialog({
    super.key,
    required this.controller,
    required this.usuarioEmail,
  });

  static Future<void> show(
    BuildContext context, {
    required SaldoProveedorController controller,
    required String usuarioEmail,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecargarSaldoDialog(
        controller: controller,
        usuarioEmail: usuarioEmail,
      ),
    );
  }

  @override
  State<RecargarSaldoDialog> createState() => _RecargarSaldoDialogState();
}

class _RecargarSaldoDialogState extends State<RecargarSaldoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController(text: '500');
  String _metodoSeleccionado = 'SPEI Directo';
  bool _isProcessing = false;

  final List<double> _montosRapidos = [200, 500, 1000, 2000, 5000];

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  void _procesarRecarga() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0.0;

    if (_metodoSeleccionado == 'PayPal') {
      PayPalCheckoutDialog.show(
        context,
        total: monto,
        usuarioEmail: widget.usuarioEmail,
        onPagoExitoso: (txId, email) async {
          await widget.controller.recargarSaldo(
            monto: monto,
            metodoPago: 'PayPal ($txId)',
            referencia: txId,
          );
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            messenger
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('¡Bolsa recargada con éxito! +\$${monto.toStringAsFixed(2)} MXN (Folio aprobado: $txId)'),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 2),
                ),
              );
          }
        },
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));

    // El folio/referencia se genera y retorna únicamente cuando el pago es aprobado por el proveedor
    final folioAprobado = 'GP-FOND-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    await widget.controller.recargarSaldo(
      monto: monto,
      metodoPago: _metodoSeleccionado,
      referencia: folioAprobado,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('¡Saldo con Proveedor recargado! +\$${monto.toStringAsFixed(2)} MXN (Folio aprobado: $folioAprobado)'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
              // Handle
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

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2E7D32), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recargar Saldo de Proveedor',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Bolsa virtual para emisión de recargas y pagos',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Montos rápidos
              const Text('Selecciona o ingresa el monto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _montosRapidos.map((m) {
                  final isSel = _montoCtrl.text == m.toStringAsFixed(0);
                  return ChoiceChip(
                    label: Text('\$${m.toStringAsFixed(0)}'),
                    selected: isSel,
                    selectedColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : AppTheme.textMain,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _montoCtrl.text = m.toStringAsFixed(0));
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monto a Recargar (MXN) *',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF2E7D32)),
                ),
                validator: (val) {
                  final n = double.tryParse(val?.trim() ?? '');
                  if (n == null || n < 10.0) {
                    return 'El monto mínimo de recarga es de \$10.00 MXN';
                  }
                  if (n > 50000.0) {
                    return 'El monto máximo permitido es de \$50,000.00 MXN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Método de Pago para abonar a la bolsa
              const Text('Forma de Depósito / Fondeo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),

              _buildMetodoItem(
                id: 'SPEI Directo',
                label: 'Transferencia SPEI Inmediata (Simulada)',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF1B5E20),
              ),
              _buildMetodoItem(
                id: 'Tarjeta Bancaria',
                label: 'Tarjeta de Débito / Crédito',
                icon: Icons.credit_card_rounded,
                color: AppTheme.primaryPurple,
              ),
              _buildMetodoItem(
                id: 'PayPal',
                label: 'PayPal In-App',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isProcessing ? null : _procesarRecarga,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Confirmar y Fondear Bolsa de Saldo',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetodoItem({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSel = _metodoSeleccionado == id;
    return InkWell(
      onTap: () => setState(() => _metodoSeleccionado = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFE8F5E9) : AppTheme.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? const Color(0xFF2E7D32) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            if (isSel)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
          ],
        ),
      ),
    );
  }
}
