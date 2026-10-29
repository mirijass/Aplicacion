import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_theme.dart';
import 'widgets/servicio_logo_widget.dart';

/// Diálogo modal con el Comprobante Oficial de Transacción de GestoPago
class GestoPagoTicketDialog extends StatelessWidget {
  final Map<String, dynamic> datosTicket;

  const GestoPagoTicketDialog({
    super.key,
    required this.datosTicket,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> datos) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GestoPagoTicketDialog(datosTicket: datos),
    );
  }

  void _compartirComprobante() {
    final folio = datosTicket['folioGestoPago'] ?? '';
    final servicio = datosTicket['servicio'] ?? '';
    final producto = datosTicket['producto'] ?? '';
    final ref = datosTicket['referencia'] ?? '';
    final monto = datosTicket['monto']?.toString() ?? '0.00';
    final fecha = datosTicket['fechaHora'] ?? '';
    final pin = datosTicket['pinDigital'];

    String texto = '''
🧾 COMPROBANTE OFICIAL DE PAGO - GESTOPAGO
===========================================
Folio de Autorización: $folio
Fecha y Hora: $fecha
Servicio: $servicio
Producto / Paquete: $producto
Referencia / Teléfono: $ref
Monto Pagado: \$$monto MXN
Método de Pago: ${datosTicket['metodoPago'] ?? 'Saldo Proveedor'}
${pin != null ? '\n🎁 CÓDIGO PIN DIGITAL: $pin\n' : ''}
Estado: APLICADO EXITOSAMENTE
Proveedor: GESTO PAGO DE SERVICIOS S.A.P.I. DE C.V.
===========================================
''';

    Share.share(texto, subject: 'Comprobante GestoPago - $folio');
  }

  @override
  Widget build(BuildContext context) {
    final folio = datosTicket['folioGestoPago'] ?? 'GP-AUTH-0000';
    final servicio = datosTicket['servicio'] ?? 'Servicio';
    final producto = datosTicket['producto'] ?? '';
    final ref = datosTicket['referencia'] ?? '';
    final double monto = (datosTicket['monto'] as num?)?.toDouble() ?? 0.0;
    final fecha = datosTicket['fechaHora'] ?? '';
    final pin = datosTicket['pinDigital'];
    final leyenda = datosTicket['leyenda'] ?? '';
    final metodo = datosTicket['metodoPago'] ?? 'Saldo Proveedor';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado con Icono de Éxito
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Transacción Exitosa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Text(
              'GESTO PAGO DE SERVICIOS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ServicioLogoWidget(servicio: servicio, size: 52),
            ),
            const SizedBox(height: 14),

            // Tarjeta de Monto y Folio
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Column(
                children: [
                  Text(
                    '\$${monto.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Folio: $folio',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Datos del Pago
            _buildFilaDetalle('Servicio', servicio),
            _buildFilaDetalle('Detalle', producto),
            _buildFilaDetalle('Referencia / Tel.', ref),
            _buildFilaDetalle('Fecha y Hora', fecha),
            _buildFilaDetalle('Forma de Pago', metodo),

            // PIN Digital (si es Tarjeta Electrónica / Pin)
            if (pin != null) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryExtraLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryLight),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🎁 CÓDIGO PIN / CANJE DIGITAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(
                          '$pin',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppTheme.deepPurple,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copiar PIN',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: '$pin'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Código PIN copiado al portapapeles!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 20),

            // Leyenda Legal de GestoPago
            if (leyenda.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  leyenda,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 20),

            // Botones de Acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Compartir'),
                    onPressed: _compartirComprobante,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaDetalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
