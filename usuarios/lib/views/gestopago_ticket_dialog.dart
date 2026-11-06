import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gestopago_tx_response.dart';
import '../utils/app_theme.dart';

/// Pantalla / Comprobante de Pago Oficial de GestoPago.
/// Diseñado con la estructura exacta solicitada:
/// - Fondo suave (#F7F6FB)
/// - Encabezado 'Comprobante de pago'
/// - Tarjeta blanca con bordes redondeados
/// - Ícono de verificación verde sólido
/// - '¡Pago exitoso!' con Folio (`<ID_TX>`)
/// - Servicio, Producto, Teléfono, Fecha (`<FECHA>`), Autorización (`<NUM_AUTORIZACION>`)
/// - Comisión (`<COMISION>`) y Saldo restante (`<SALDO>`)
/// - Cuadro destacado 'Total pagado' en tono morado suave (`<MONTO>`)
/// - Botón principal morado: 'VOLVER AL CATÁLOGO'
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
    final aut = _obtenerAutorizacion();
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
${aut.isNotEmpty ? 'Autorización: $aut\n' : ''}Servicio: $servicio
Producto: $producto
Teléfono / Ref: $ref
Fecha: $fecha
Comisión: ${_obtenerComision()}
Saldo restante: ${_obtenerSaldoRestante()}
Total pagado: \$${monto.toStringAsFixed(2)}
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
    if (idTx != null && idTx.trim().isNotEmpty) {
      return idTx.trim();
    }
    final rawFolio = datosTicket['folioGestoPago']?.toString() ?? '';
    final limpio = rawFolio.replaceFirst('GP-AUTH-', '').trim();
    if (limpio.isNotEmpty) {
      return limpio;
    }
    return '';
  }

  String _obtenerAutorizacion() {
    final rawAut = datosTicket['numeroAutorizacion']?.toString() ??
        datosTicket['numAutorizacion']?.toString() ??
        (datosTicket['detalles'] != null
            ? datosTicket['detalles']['numeroAutorizacion']?.toString()
            : null) ??
        '';
    return rawAut.trim();
  }

  String _formatearFecha() {
    final fXml = datosTicket['fechaGestoPago']?.toString();
    if (fXml != null && fXml.trim().isNotEmpty) return fXml.trim();

    final fHora = datosTicket['fechaHora']?.toString();
    if (fHora != null && fHora.trim().isNotEmpty) {
      if (fHora.contains('/')) return fHora.trim();
      final parsed = DateTime.tryParse(fHora);
      if (parsed != null) {
        return GestoPagoTxResponse.formatFechaGestoPago(parsed);
      }
      return fHora.trim();
    }

    return '';
  }

  String _obtenerComision() {
    final cProv = datosTicket['comisionProveedorXml'];
    if (cProv != null && cProv is num) {
      return '\$${cProv.toDouble().toStringAsFixed(2)}';
    }
    final cXml = datosTicket['comisionFormateadaXml']?.toString().replaceAll('\$', '').trim();
    if (cXml != null && cXml.isNotEmpty) {
      final parsed = double.tryParse(cXml);
      if (parsed != null) {
        return '\$${parsed.toStringAsFixed(2)}';
      }
      return '\$$cXml';
    }
    final cGanada = datosTicket['comisionGanada'];
    if (cGanada != null && cGanada is num) {
      return '\$${cGanada.toDouble().toStringAsFixed(2)}';
    }
    return '\$0.00';
  }

  String _obtenerSaldoRestante() {
    final sProv = datosTicket['saldoProveedorXml'];
    if (sProv != null && sProv is num && sProv > 0) {
      return '\$${sProv.toDouble().toStringAsFixed(2)}';
    }
    final sRest = datosTicket['saldoRestante'];
    if (sRest != null && sRest is num && sRest > 0) {
      return '\$${sRest.toDouble().toStringAsFixed(2)}';
    }
    final sXml = datosTicket['saldoFormateadoXml']
        ?.toString()
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .trim();
    if (sXml != null && sXml.isNotEmpty) {
      final parsed = double.tryParse(sXml);
      if (parsed != null) {
        return '\$${parsed.toStringAsFixed(2)}';
      }
      return '\$$sXml';
    }
    return '\$0.00';
  }

  @override
  Widget build(BuildContext context) {
    final folio = _obtenerFolio();
    final numeroAutorizacion = _obtenerAutorizacion();
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
            fontSize: 19,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        actions: [
          if (xmlOficial.isNotEmpty)
            IconButton(
              tooltip: 'Ver XML Oficial (<RESPONSE>)',
              icon: const Icon(Icons.code_rounded, color: Color(0xFF6750A4), size: 20),
              onPressed: () => _mostrarModalXml(context, xmlOficial),
            ),
          IconButton(
            tooltip: 'Compartir comprobante',
            icon: const Icon(Icons.share_outlined, color: Color(0xFF6750A4), size: 20),
            onPressed: _compartirComprobante,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // Tarjeta principal blanca idéntica al diseño oficial
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                    const SizedBox(height: 5),

                    // 3. Folio (<ID_TX>) retornado por GestoPago
                    if (folio.isNotEmpty)
                      Text(
                        'Folio: $folio',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.normal,
                        ),
                      ),

                    const SizedBox(height: 16),
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
                    if (fecha.isNotEmpty)
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

                    // PIN Digital (si el XML de GestoPago incluyó <PIN>)
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
                              '🎁 PIN / Código',
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
                                        content: Text('¡PIN copiado!'),
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

                    const SizedBox(height: 18),

                    // 6. Cuadro Destacado 'Total pagado'
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFFA),
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
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            '\$${monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6750A4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // 7. Botón Principal: VOLVER AL CATÁLOGO
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6750A4),
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
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
  }

  /// Construye cada fila de clave-valor con la alineación exacta de la imagen de referencia
  Widget _buildFila({
    required String label,
    required String value,
    bool isSelectable = false,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  /// Modal para consultar y copiar el XML oficial de la respuesta de GestoPago (`<RESPONSE>`)
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
