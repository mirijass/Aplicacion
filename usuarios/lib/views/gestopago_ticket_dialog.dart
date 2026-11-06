import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gestopago_tx_response.dart';
import '../utils/app_theme.dart';
import '../services/gestopago_service.dart';

/// Pantalla / Comprobante de Pago Oficial de GestoPago.
/// Diseñado con la estructura exacta solicitada:
/// - Fondo suave (#F7F6FB)
/// - Encabezado 'Comprobante de pago'
/// - Tarjeta blanca con bordes redondeados
/// - Ícono de verificación verde sólido
/// - '¡Pago exitoso!' con folio
/// - Servicio, Producto, Teléfono, Fecha, Autorización (10 dígitos)
/// - Comisión y Saldo restante
/// - Cuadro destacado 'Total pagado' en tono morado suave
/// - Botón principal morado: 'VOLVER AL CATÁLOGO'
/// - Acciones secundarias para ver el XML oficial (<RESPONSE>) y compartir
class GestoPagoTicketDialog extends StatelessWidget {
  final Map<String, dynamic> datosTicket;

  const GestoPagoTicketDialog({
    super.key,
    required this.datosTicket,
  });

  /// Muestra el comprobante como una vista de pantalla completa
  static Future<void> show(BuildContext context, Map<String, dynamic> datos) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GestoPagoTicketDialog(datosTicket: datos),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _compartirComprobante() {
    final folio = _obtenerFolio();
    final rawAut = datosTicket['numeroAutorizacion']?.toString() ?? '';
    final aut = rawAut.isNotEmpty ? GestoPagoService.formatearNumeroAutorizacion(rawAut) : '';
    final servicio = datosTicket['servicio'] ?? '';
    final producto = datosTicket['producto'] ?? '';
    final ref = datosTicket['referencia'] ?? '';
    final double monto = (datosTicket['monto'] as num?)?.toDouble() ?? 0.0;
    final fecha = _formatearFecha();
    final pin = datosTicket['pinDigital'];
    final xml = datosTicket['xmlOficial'] ??
        (datosTicket['detalles'] != null ? datosTicket['detalles']['xmlOficial'] : null);

    String texto = '''
🧾 COMPROBANTE DE PAGO
=============================
¡Pago exitoso!
Folio: $folio
${aut.toString().isNotEmpty ? 'Autorización: $aut\n' : ''}Servicio: $servicio
Producto: $producto
Teléfono / Ref: $ref
Fecha: $fecha
Comisión: ${_obtenerComision()}
Saldo restante: ${_obtenerSaldoRestante()}
Total pagado: \$${monto.toStringAsFixed(2)} MXN
${pin != null ? '\n🎁 PIN DIGITAL: $pin\n' : ''}=============================
''';

    if (xml != null && xml.toString().trim().isNotEmpty) {
      texto += '''

XML OFICIAL GESTOPAGO (<RESPONSE>):
$xml
''';
    }

    Share.share(texto, subject: 'Comprobante de pago - Folio $folio');
  }

  String _obtenerFolio() {
    final idTx = datosTicket['idTx']?.toString() ??
        (datosTicket['detalles'] != null ? datosTicket['detalles']['idTx']?.toString() : null);
    if (idTx != null && idTx.isNotEmpty) {
      return idTx;
    }
    final rawFolio = datosTicket['folioGestoPago']?.toString() ?? '';
    final limpio = rawFolio.replaceFirst('GP-AUTH-', '').trim();
    if (limpio.isNotEmpty) {
      return limpio;
    }
    return '';
  }

  String _formatearFecha() {
    final fXml = datosTicket['fechaGestoPago']?.toString();
    if (fXml != null && fXml.isNotEmpty) return fXml;

    final fHora = datosTicket['fechaHora']?.toString();
    if (fHora != null && fHora.isNotEmpty) {
      // Si ya viene formateada como dd/Mes/yyyy HH:mm:ss
      if (fHora.contains('/')) return fHora;
      final parsed = DateTime.tryParse(fHora);
      if (parsed != null) {
        return GestoPagoTxResponse.formatFechaGestoPago(parsed);
      }
      return fHora;
    }

    return GestoPagoTxResponse.formatFechaGestoPago(DateTime.now());
  }

  String _obtenerComision() {
    final cXml = datosTicket['comisionFormateadaXml']?.toString();
    if (cXml != null && cXml.isNotEmpty) {
      return cXml.startsWith('\$') ? cXml : '\$$cXml';
    }
    final cProv = datosTicket['comisionProveedorXml'];
    if (cProv != null && cProv is num) {
      return '\$${cProv.toStringAsFixed(2)}';
    }
    final cGanada = datosTicket['comisionGanada'];
    if (cGanada != null && cGanada is num) {
      return '\$${cGanada.toStringAsFixed(2)}';
    }
    return '\$0.00';
  }

  String _obtenerSaldoRestante() {
    final sXml = datosTicket['saldoFormateadoXml']?.toString();
    if (sXml != null && sXml.isNotEmpty) {
      return sXml.startsWith('\$') ? sXml : '\$$sXml';
    }
    final sRest = datosTicket['saldoRestante'];
    if (sRest != null && sRest is num) {
      return '\$${sRest.toStringAsFixed(2)}';
    }
    final sProv = datosTicket['saldoProveedorXml'];
    if (sProv != null && sProv is num) {
      return '\$${sProv.toStringAsFixed(2)}';
    }
    return '\$0.00';
  }

  @override
  Widget build(BuildContext context) {
    final folio = _obtenerFolio();
    final rawAut = datosTicket['numeroAutorizacion']?.toString() ?? '';
    final numeroAutorizacion = rawAut.isNotEmpty
        ? GestoPagoService.formatearNumeroAutorizacion(rawAut)
        : '';
    final esRecarga = datosTicket['esRecarga'] == true;
    final servicio = (datosTicket['servicio'] ?? '').toString();
    final producto = (datosTicket['producto'] ?? '').toString();
    final ref = (datosTicket['referencia'] ?? '').toString();
    final double monto = (datosTicket['monto'] as num?)?.toDouble() ?? 0.0;
    final fecha = _formatearFecha();
    final pin = datosTicket['pinDigital'];
    final xmlOficial = (datosTicket['xmlOficial'] ??
        (datosTicket['detalles'] != null ? datosTicket['detalles']['xmlOficial'] ?? '' : '')).toString();
    final comision = _obtenerComision();
    final saldoRestante = _obtenerSaldoRestante();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Comprobante de pago',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 50 ? constraints.maxHeight - 20 : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Tarjeta principal blanca
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Ícono de éxito (Círculo verde sólido con palomita blanca)
                            Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5CB85C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Título de Éxito
                            const Text(
                              '¡Pago exitoso!',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1C1C1E),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // 3. Folio (si viene en la respuesta)
                            if (folio.isNotEmpty)
                              Text(
                                'Folio: $folio',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),

                            const SizedBox(height: 14),
                            const Divider(height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 8),

                            // 4. Detalles de la Transacción (Sección 1)
                            if (servicio.isNotEmpty)
                              _buildFila(
                                label: 'Servicio',
                                value: servicio,
                              ),
                            if (producto.isNotEmpty)
                              _buildFila(
                                label: 'Producto',
                                value: producto,
                              ),
                            if (ref.isNotEmpty)
                              _buildFila(
                                label: esRecarga ? 'Teléfono' : 'Referencia',
                                value: ref,
                              ),
                            _buildFila(
                              label: 'Fecha',
                              value: fecha,
                            ),
                            if (numeroAutorizacion.isNotEmpty)
                              _buildFila(
                                label: 'Autorización',
                                value: numeroAutorizacion,
                                isSelectable: true,
                              ),

                            const SizedBox(height: 8),
                            const Divider(height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 8),

                            // 5. Detalles Financieros (Sección 2)
                            _buildFila(
                              label: 'Comisión',
                              value: comision,
                            ),
                            _buildFila(
                              label: 'Saldo restante',
                              value: saldoRestante,
                            ),

                            // PIN Digital (si aplica a tarjeta digital o de regalo)
                            if (pin != null && pin.toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryExtraLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primaryLight),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '🎁 PIN Digital',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        SelectableText(
                                          '$pin',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                            color: AppTheme.deepPurple,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: AppTheme.primaryPurple,
                                          tooltip: 'Copiar PIN',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: '$pin'));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('¡PIN digital copiado!'),
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

                            const SizedBox(height: 16),

                            // 6. Cuadro Destacado 'Total pagado'
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EBF9), // Tono morado suave
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total pagado',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                  Text(
                                    '\$${monto.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 7. Botón Principal: VOLVER AL CATÁLOGO
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'VOLVER AL CATÁLOGO',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // 8. Enlaces secundarios (Ver XML oficial y Compartir)
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (xmlOficial.isNotEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryPurple,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.code_rounded, size: 16),
                                    label: const Text(
                                      'Ver XML (<RESPONSE>)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => _mostrarModalXml(context, xmlOficial),
                                  ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.black54,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: const Text(
                                    'Compartir',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _compartirComprobante,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Construye cada fila de clave-valor con la alineación exacta de la imagen de referencia
  Widget _buildFila({
    required String label,
    required String value,
    bool isSelectable = false,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF757575),
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: isSelectable
                ? SelectableText(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Modal para consultar y copiar el XML oficial de la respuesta de GestoPago (<RESPONSE>)
  void _mostrarModalXml(BuildContext context, String xmlString) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.code_rounded, color: AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'XML Oficial GestoPago',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Estructura exacta devuelta por la API (<RESPONSE>):',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  xmlString,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Color(0xFF80CBC4),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar XML'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: xmlString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡XML oficial copiado al portapapeles!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
