import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto_xml_model.dart';
import '../services/gestopago_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/saldo_proveedor_controller.dart';
import '../models/compra_model.dart';
import '../utils/app_theme.dart';
import 'widgets/app_drawer.dart';
import 'gestopago_ticket_dialog.dart';
import 'recargar_saldo_dialog.dart';
import 'paypal_checkout_dialog.dart';
import 'widgets/servicio_logo_widget.dart';

/// Pantalla Principal con Secciones de Pagos, Recargas, Tarjetas y Saldo de Proveedor
class GestoPagoView extends StatefulWidget {
  final AuthController authController;
  final CompraController? compraController;
  final ProductoController? productoController;
  final UsuarioController? usuarioController;
  final ThemeController? themeController;

  const GestoPagoView({
    super.key,
    required this.authController,
    this.compraController,
    this.productoController,
    this.usuarioController,
    this.themeController,
  });

  @override
  State<GestoPagoView> createState() => _GestoPagoViewState();
}

class _GestoPagoViewState extends State<GestoPagoView> {
  final SaldoProveedorController _saldoCtrl = SaldoProveedorController();
  final TextEditingController _searchCtrl = TextEditingController();
  late final UsuarioController _usuarioCtrl;
  late final ProductoController _productoCtrl;

  List<ProductoXml> _todosLosProductos = [];
  List<ProductoXml> _productosFiltrados = [];
  String _filtroCategoria = 'todos'; // 'todos', 'recargas', 'pagos', 'tarjetas', 'saldo'
  bool _isLoading = true;
  bool _isSyncingOnline = false;

  @override
  void initState() {
    super.initState();
    _usuarioCtrl = widget.usuarioController ?? UsuarioController();
    _productoCtrl = widget.productoController ?? ProductoController();
    _cargarCatalogoInicial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogoInicial() async {
    setState(() => _isLoading = true);
    final todos = await GestoPagoService.obtenerTodosLosProductos();
    if (mounted) {
      setState(() {
        _todosLosProductos = todos;
        _isLoading = false;
      });
      _filtrarCatalogo();
    }
  }

  void _filtrarCatalogo() {
    final query = _searchCtrl.text.trim().toLowerCase();
    List<ProductoXml> resultado = List.from(_todosLosProductos);

    if (_filtroCategoria == 'recargas') {
      resultado = resultado.where((p) {
        final cat = p.idCatTipoServicio?.toString() ?? '';
        return GestoPagoService.categoriasRecargas.contains(cat);
      }).toList();
    } else if (_filtroCategoria == 'pagos') {
      resultado = resultado.where((p) {
        final cat = p.idCatTipoServicio?.toString() ?? '';
        return GestoPagoService.categoriasPagos.contains(cat);
      }).toList();
    } else if (_filtroCategoria == 'tarjetas') {
      resultado = resultado.where((p) {
        final cat = p.idCatTipoServicio?.toString() ?? '';
        return GestoPagoService.categoriasTarjetas.contains(cat);
      }).toList();
    }

    if (query.isNotEmpty) {
      resultado = resultado.where((p) {
        return p.servicio.toLowerCase().contains(query) ||
            p.producto.toLowerCase().contains(query) ||
            p.legend.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _productosFiltrados = resultado;
    });
  }

  void _abrirModalPorTipo(ProductoXml item) {
    final cat = item.idCatTipoServicio?.toString() ?? '';
    if (GestoPagoService.categoriasTarjetas.contains(cat)) {
      _abrirModalTarjetaDigital(item);
    } else if (GestoPagoService.categoriasRecargas.contains(cat)) {
      _abrirModalRecarga(item);
    } else {
      _abrirModalPagoServicio(item);
    }
  }

  /// Sincroniza en vivo con el Endpoint de la API de GestoPago
  Future<void> _sincronizarConApiGestoPago() async {
    setState(() => _isSyncingOnline = true);

    final resultado = await GestoPagoService.sincronizarConApiOnline();

    if (!mounted) return;
    setState(() => _isSyncingOnline = false);

    await _cargarCatalogoInicial();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              resultado['esSimulado'] == true
                  ? Icons.info_outline_rounded
                  : Icons.cloud_done_rounded,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            const Text('Sincronización GestoPago', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resultado['mensaje'] as String,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Total disponible: ${resultado['totalProductos']} servicios',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FLUJOS DE PAGO Y DIÁLOGOS
  // ===========================================================================

  /// Diálogo para procesar Recarga Telefónica (10 dígitos + confirmación + validación de saldo)
  void _abrirModalRecarga(ProductoXml servicio) {
    final telCtrl = TextEditingController();
    final confirmTelCtrl = TextEditingController();
    final montoCtrl = TextEditingController(
      text: servicio.precio > 0 ? servicio.precio.toStringAsFixed(2) : '50.00',
    );
    final tarjetaNumCtrl = TextEditingController();
    final tarjetaExpCtrl = TextEditingController();
    final tarjetaCvvCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String metodoPago = 'Saldo con Proveedor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final montoActual = servicio.precio > 0
              ? servicio.precio
              : (double.tryParse(montoCtrl.text.trim()) ?? 50.0);
          final saldoDisponible = _saldoCtrl.saldo;
          final saldoAlcanza = saldoDisponible >= montoActual && saldoDisponible > 0;

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
                key: formKey,
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
                        ServicioLogoWidget(servicio: servicio.servicio, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                servicio.servicio,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                servicio.producto,
                                style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${montoActual.toStringAsFixed(2)} MXN',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Alerta si no dispone de saldo suficiente
                    if (!saldoAlcanza)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saldo insuficiente (\$${saldoDisponible.toStringAsFixed(2)} MXN). Sí o sí debes disponer de dinero para realizar la compra.',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(this.context).clearSnackBars();
                                Navigator.pop(ctx);
                                RecargarSaldoDialog.show(
                                  this.context,
                                  controller: _saldoCtrl,
                                  usuarioEmail: widget.authController.currentUser?.correo ?? '',
                                );
                              },
                              child: const Text('Fondear', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // Teléfono a 10 dígitos (Solo dígitos numéricos permitidos)
                    TextFormField(
                      controller: telCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Número Telefónico (10 dígitos) *',
                        hintText: 'Ej. 5512345678 (solo números)',
                        prefixIcon: Icon(Icons.phone_android_rounded, color: AppTheme.primaryPurple),
                        helperText: 'Exactamente 10 dígitos numéricos sin espacios',
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'El número telefónico es obligatorio';
                        }
                        if (!GestoPagoService.validarNumeroTelefonico(v)) {
                          return 'Ingresa un número válido de 10 dígitos (sin iniciar en 0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Confirmar Teléfono (Solo dígitos numéricos permitidos)
                    TextFormField(
                      controller: confirmTelCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Confirmar Número Telefónico *',
                        hintText: 'Repite los 10 dígitos del celular',
                        prefixIcon: Icon(Icons.verified_user_outlined, color: AppTheme.primaryPurple),
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Confirma el número telefónico';
                        }
                        if (v != telCtrl.text.trim()) {
                          return 'Los números telefónicos no coinciden';
                        }
                        return null;
                      },
                    ),

                    if (servicio.precio <= 0) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          LengthLimitingTextInputFormatter(7),
                        ],
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Monto de la Recarga (MXN) *',
                          prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF2E7D32)),
                        ),
                        validator: (val) {
                          final n = double.tryParse(val?.trim() ?? '');
                          if (n == null || n < 10 || n > 1000) {
                            return 'El monto de recarga debe ser entre \$10.00 y \$1,000.00 MXN';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Selección de Forma de Pago
                    _buildSelectorFormaPago(
                      monto: montoActual,
                      metodoSeleccionado: metodoPago,
                      onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                      tarjetaNumCtrl: tarjetaNumCtrl,
                      tarjetaExpCtrl: tarjetaExpCtrl,
                      tarjetaCvvCtrl: tarjetaCvvCtrl,
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: saldoAlcanza ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.send_to_mobile_rounded, color: Colors.white, size: 18),
                      onPressed: () => _ejecutarPago(
                        servicio: servicio,
                        referencia: telCtrl.text.trim(),
                        monto: montoActual,
                        metodoPago: metodoPago,
                        formKey: formKey,
                        parentContext: ctx,
                      ),
                      label: Text(
                        'Aplicar Recarga de \$${montoActual.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Diálogo para procesar Pago de Servicios (CFE, Agua, Gas, etc.) con Referencia y Saldo obligatorios
  void _abrirModalPagoServicio(ProductoXml servicio) {
    final refCtrl = TextEditingController();
    final montoCtrl = TextEditingController(
      text: servicio.precio > 0 ? servicio.precio.toStringAsFixed(2) : '348.00',
    );
    final tarjetaNumCtrl = TextEditingController();
    final tarjetaExpCtrl = TextEditingController();
    final tarjetaCvvCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String metodoPago = 'Saldo con Proveedor';
    bool consultando = false;
    Map<String, dynamic>? resultadoConsulta;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final montoActual = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
          final saldoDisponible = _saldoCtrl.saldo;
          final saldoAlcanza = saldoDisponible >= montoActual && saldoDisponible > 0 && montoActual > 0;

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
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        ServicioLogoWidget(servicio: servicio.servicio, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                servicio.servicio,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                servicio.producto,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Alerta si no dispone de saldo suficiente
                    if (!saldoAlcanza && montoActual > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saldo disponible insuficiente (\$${saldoDisponible.toStringAsFixed(2)} MXN). Sí o sí debes disponer de dinero para realizar el pago.',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(this.context).clearSnackBars();
                                Navigator.pop(ctx);
                                RecargarSaldoDialog.show(
                                  this.context,
                                  controller: _saldoCtrl,
                                  usuarioEmail: widget.authController.currentUser?.correo ?? '',
                                );
                              },
                              child: const Text('Fondear', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // 1. Referencia / Número de Servicio / Contrato (Obligatorio y restringido)
                    TextFormField(
                      controller: refCtrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Referencia / Número de Servicio o Contrato *',
                        hintText: 'Ej. 012345678901 (mín. 6 caracteres)',
                        prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF2E7D32)),
                        suffixIcon: IconButton(
                          icon: consultando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search_rounded, color: Color(0xFF2E7D32)),
                          tooltip: 'Consultar Adeudo en API de Pruebas',
                          onPressed: () async {
                            if (refCtrl.text.trim().length < 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingresa al menos 4 caracteres de referencia para consultar en la API de pruebas.'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }
                            setModalState(() => consultando = true);
                            final res = await GestoPagoService.consultarReferencia(servicio, refCtrl.text.trim());
                            setModalState(() {
                              consultando = false;
                              resultadoConsulta = res;
                              if (res['exito'] == true) {
                                montoCtrl.text = (res['monto'] as double).toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'La referencia es obligatoria para realizar el pago';
                        }
                        if (v.length < 6) {
                          return 'La referencia debe tener al menos 6 dígitos o caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Cuadro de Consulta de Adeudo en API de Pruebas
                    if (resultadoConsulta != null && resultadoConsulta!['exito'] == true)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${resultadoConsulta!['titularSimulado']}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Vence: ${resultadoConsulta!['fechaVencimiento']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subtotal: \$${resultadoConsulta!['monto']} + Comisión: \$${resultadoConsulta!['comision']} MXN',
                              style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),

                    // 3. Monto a Pagar (Solo números y hasta 2 decimales)
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto a Pagar (MXN) *',
                        prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF2E7D32)),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val?.trim() ?? '');
                        if (n == null || n <= 0) {
                          return 'Ingresa un monto válido mayor a \$0.00';
                        }
                        if (n < 10.0) {
                          return 'El monto mínimo de pago es de \$10.00 MXN';
                        }
                        if (n > 50000.0) {
                          return 'El monto máximo permitido por operación es \$50,000.00 MXN';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Selección de Forma de Pago
                    _buildSelectorFormaPago(
                      monto: montoActual > 0 ? montoActual : 100.0,
                      metodoSeleccionado: metodoPago,
                      onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                      tarjetaNumCtrl: tarjetaNumCtrl,
                      tarjetaExpCtrl: tarjetaExpCtrl,
                      tarjetaCvvCtrl: tarjetaCvvCtrl,
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: saldoAlcanza ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                      onPressed: () {
                        final monto = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
                        _ejecutarPago(
                          servicio: servicio,
                          referencia: refCtrl.text.trim(),
                          monto: monto,
                          metodoPago: metodoPago,
                          formKey: formKey,
                          parentContext: ctx,
                        );
                      },
                      label: const Text('Confirmar y Pagar Recibo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Diálogo para procesar Tarjetas Electrónicas y Pines Digitales con Referencia y Saldo obligatorios
  void _abrirModalTarjetaDigital(ProductoXml servicio) {
    final emailCtrl = TextEditingController(text: widget.authController.currentUser?.correo ?? '');
    final tarjetaNumCtrl = TextEditingController();
    final tarjetaExpCtrl = TextEditingController();
    final tarjetaCvvCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String metodoPago = 'Saldo con Proveedor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final montoActual = servicio.precio > 0 ? servicio.precio : 100.0;
          final saldoDisponible = _saldoCtrl.saldo;
          final saldoAlcanza = saldoDisponible >= montoActual && saldoDisponible > 0;

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
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        ServicioLogoWidget(servicio: servicio.servicio, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                servicio.servicio,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                servicio.producto,
                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${montoActual.toStringAsFixed(2)} MXN',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Alerta si no dispone de saldo suficiente
                    if (!saldoAlcanza)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saldo insuficiente (\$${saldoDisponible.toStringAsFixed(2)} MXN). Sí o sí debes disponer de dinero para realizar la compra.',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(this.context).clearSnackBars();
                                Navigator.pop(ctx);
                                RecargarSaldoDialog.show(
                                  this.context,
                                  controller: _saldoCtrl,
                                  usuarioEmail: widget.authController.currentUser?.correo ?? '',
                                );
                              },
                              child: const Text('Fondear', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // Correo destino / Referencia para entrega del PIN
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(60),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Referencia / Correo para Entrega del PIN *',
                        hintText: 'correo@ejemplo.com',
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.orange),
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        if (v.isEmpty || !RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
                          return 'Ingresa un correo electrónico válido como referencia';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Selección de Forma de Pago
                    _buildSelectorFormaPago(
                      monto: montoActual,
                      metodoSeleccionado: metodoPago,
                      onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                      tarjetaNumCtrl: tarjetaNumCtrl,
                      tarjetaExpCtrl: tarjetaExpCtrl,
                      tarjetaCvvCtrl: tarjetaCvvCtrl,
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: saldoAlcanza ? const Color(0xFF2E7D32) : Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
                      onPressed: () => _ejecutarPago(
                        servicio: servicio,
                        referencia: emailCtrl.text.trim(),
                        monto: montoActual,
                        metodoPago: metodoPago,
                        formKey: formKey,
                        parentContext: ctx,
                        correoDestino: emailCtrl.text.trim(),
                      ),
                      label: Text(
                        'Emitir Tarjeta por \$${montoActual.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Selector reusable de método de pago con campos restringidos de tarjeta y validación de saldo
  Widget _buildSelectorFormaPago({
    required double monto,
    required String metodoSeleccionado,
    required Function(String) onCambio,
    TextEditingController? tarjetaNumCtrl,
    TextEditingController? tarjetaExpCtrl,
    TextEditingController? tarjetaCvvCtrl,
  }) {
    final saldoDisponible = _saldoCtrl.saldo;
    final saldoAlcanza = saldoDisponible >= monto && saldoDisponible > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona la forma de pago:',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Opción 1: Saldo con Proveedor
        InkWell(
          onTap: () => onCambio('Saldo con Proveedor'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: metodoSeleccionado == 'Saldo con Proveedor'
                  ? const Color(0xFFE8F5E9)
                  : (saldoAlcanza ? AppTheme.inputFill : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: metodoSeleccionado == 'Saldo con Proveedor'
                    ? const Color(0xFF2E7D32)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: saldoAlcanza ? const Color(0xFF2E7D32) : AppTheme.errorColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          const Text(
                            'Saldo con Proveedor GestoPago',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8E6C9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('API Pruebas', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                          ),
                        ],
                      ),
                      Text(
                        'Saldo disponible: \$${saldoDisponible.toStringAsFixed(2)} MXN ${!saldoAlcanza ? '(Insuficiente)' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: saldoAlcanza ? Colors.black54 : AppTheme.errorColor,
                          fontWeight: !saldoAlcanza ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (metodoSeleccionado == 'Saldo con Proveedor')
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
              ],
            ),
          ),
        ),

        // Opción 2: PayPal In-App
        InkWell(
          onTap: () => onCambio('PayPal'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: metodoSeleccionado == 'PayPal' ? const Color(0xFFE3F2FD) : AppTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: metodoSeleccionado == 'PayPal' ? Colors.blue : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment_rounded, color: Colors.blue, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'PayPal In-App',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (metodoSeleccionado == 'PayPal')
                  const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
              ],
            ),
          ),
        ),

        // Opción 3: Tarjeta de Crédito / Débito
        InkWell(
          onTap: () => onCambio('Tarjeta Bancaria / Efectivo'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: metodoSeleccionado == 'Tarjeta Bancaria / Efectivo'
                  ? AppTheme.primaryExtraLight
                  : AppTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: metodoSeleccionado == 'Tarjeta Bancaria / Efectivo'
                    ? AppTheme.primaryPurple
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: AppTheme.primaryPurple, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tarjeta de Crédito / Débito',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (metodoSeleccionado == 'Tarjeta Bancaria / Efectivo')
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 18),
              ],
            ),
          ),
        ),

        // Campos restringidos de Tarjeta cuando se selecciona Tarjeta de Crédito / Débito
        if (metodoSeleccionado == 'Tarjeta Bancaria / Efectivo' &&
            tarjetaNumCtrl != null &&
            tarjetaExpCtrl != null &&
            tarjetaCvvCtrl != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryExtraLight.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryLight),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: tarjetaNumCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Número de Tarjeta (16 dígitos) *',
                    hintText: '4152313245678901',
                    prefixIcon: Icon(Icons.credit_card_rounded, size: 18),
                    isDense: true,
                  ),
                  validator: (val) {
                    if (metodoSeleccionado != 'Tarjeta Bancaria / Efectivo') return null;
                    if (val == null || val.trim().length != 16) {
                      return 'Ingresa los 16 dígitos numéricos de la tarjeta';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: tarjetaExpCtrl,
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Vencimiento (MM/AA) *',
                          hintText: '08/28',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (metodoSeleccionado != 'Tarjeta Bancaria / Efectivo') return null;
                          final v = val?.trim() ?? '';
                          if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(v)) {
                            return 'Formato MM/AA';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: tarjetaCvvCtrl,
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
                          if (metodoSeleccionado != 'Tarjeta Bancaria / Efectivo') return null;
                          final v = val?.trim() ?? '';
                          if (v.length < 3 || v.length > 4) {
                            return 'CVV de 3 o 4 dígitos';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Opción 4: Apple Pay / Google Wallet
        InkWell(
          onTap: () => onCambio('Apple Pay / Google Wallet'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: metodoSeleccionado == 'Apple Pay / Google Wallet'
                  ? const Color(0xFFEDE7F6)
                  : AppTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: metodoSeleccionado == 'Apple Pay / Google Wallet'
                    ? Colors.black87
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.contactless_rounded, color: Colors.black87, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Apple Pay / Google Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (metodoSeleccionado == 'Apple Pay / Google Wallet')
                  const Icon(Icons.check_circle_rounded, color: Colors.black87, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ejecución de la transacción validando formulario, referencia y disponibilidad de saldo
  void _ejecutarPago({
    required ProductoXml servicio,
    required String referencia,
    required double monto,
    required String metodoPago,
    required GlobalKey<FormState> formKey,
    required BuildContext parentContext,
    String? correoDestino,
  }) async {
    if (!formKey.currentState!.validate()) return;

    // Validación obligatoria: Sí o sí debe disponer de dinero/saldo para realizar la compra
    if (_saldoCtrl.saldo <= 0 || _saldoCtrl.saldo < monto) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Saldo insuficiente (\$${_saldoCtrl.saldo.toStringAsFixed(2)} MXN). Sí o sí debes disponer de dinero suficiente (\$${monto.toStringAsFixed(2)} MXN) para realizar la compra.',
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    if (metodoPago == 'PayPal') {
      PayPalCheckoutDialog.show(
        context,
        total: monto,
        usuarioEmail: widget.authController.currentUser?.correo ?? 'cliente.paypal@ejemplo.com',
        onPagoExitoso: (txId, email) async {
          Navigator.pop(parentContext);
          await _completarTransaccion(
            servicio: servicio,
            referencia: referencia,
            monto: monto,
            metodoPago: 'PayPal ($txId)',
            usarSaldoProveedor: true,
            correoDestino: correoDestino,
          );
        },
      );
      return;
    }

    Navigator.pop(parentContext);

    await _completarTransaccion(
      servicio: servicio,
      referencia: referencia,
      monto: monto,
      metodoPago: metodoPago,
      usarSaldoProveedor: true,
      correoDestino: correoDestino,
    );
  }

  Future<void> _completarTransaccion({
    required ProductoXml servicio,
    required String referencia,
    required double monto,
    required String metodoPago,
    required bool usarSaldoProveedor,
    String? correoDestino,
  }) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF2E7D32)),
                SizedBox(height: 16),
                Text('Conectando con API de Pruebas GestoPago...', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Procesando pago con el proveedor', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await GestoPagoService.procesarTransaccion(
      servicio: servicio,
      referencia: referencia,
      monto: monto,
      metodoPago: metodoPago,
      usarSaldoProveedor: usarSaldoProveedor,
      correoDestino: correoDestino,
    );

    if (mounted) Navigator.pop(context); // cerrar loading

    if (result['exito'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(result['mensaje'] as String? ?? 'Error al procesar la operación'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    // Registrar en Historial de Compras global
    final curUser = widget.authController.currentUser;
    final nuevaCompra = Compra(
      usuarioId: curUser?.id ?? 1,
      usuarioNombre: curUser?.nombre ?? 'Cliente App',
      usuarioCorreo: curUser?.correo ?? 'cliente@ejemplo.com',
      total: monto,
      fecha: DateTime.now().toString().split('.')[0],
      metodoPago: 'GestoPago: $metodoPago (Folio: ${result['folioGestoPago']} | Ref: $referencia)',
      estado: 'Aplicado',
      items: [
        {
          'nombre_product': '${servicio.servicio} - ${servicio.producto}',
          'precio': monto,
          'cantidad': 1,
          'referencia': referencia,
          'folioGestoPago': result['folioGestoPago'],
          if (result['pinDigital'] != null) 'pinDigital': result['pinDigital'],
        }
      ],
      direccionEntrega: 'Transacción Digital GestoPago (Ref: $referencia • Folio: ${result['folioGestoPago']})',
    );

    if (widget.compraController != null) {
      await widget.compraController!.registrarNuevaCompra(nuevaCompra);
    }

    // Mostrar Comprobante Oficial GestoPago
    if (mounted) {
      GestoPagoTicketDialog.show(context, result);
    }
  }

  // ===========================================================================
  // CONSTRUCCIÓN DE LA INTERFAZ
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.getScaffoldBg(context),
      drawer: AppDrawer(
        authController: widget.authController,
        usuarioController: _usuarioCtrl,
        productoController: _productoCtrl,
        compraController: widget.compraController,
        themeController: widget.themeController,
        currentRoute: 'gestopago',
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Productos (XML)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Acceso directo a Saldo Proveedor
          AnimatedBuilder(
            animation: _saldoCtrl,
            builder: (context, _) => TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(46),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _filtroCategoria = _filtroCategoria == 'saldo' ? 'todos' : 'saldo';
                });
              },
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 15, color: Colors.white),
              label: Text(
                'Saldo: \$${_saldoCtrl.saldo.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ),
          // Botón Sincronizar API Online
          IconButton(
            tooltip: 'Sincronizar con API Online GestoPago',
            icon: _isSyncingOnline
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
            onPressed: _isSyncingOnline ? null : _sincronizarConApiGestoPago,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _filtroCategoria == 'saldo'
          ? Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: isDark ? const Color(0xFF282533) : AppTheme.primaryExtraLight,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '💼 Gestión de Saldo Proveedor',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() => _filtroCategoria = 'todos'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 15),
                        label: const Text(
                          'Volver al Catálogo',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildTabSaldoProveedor()),
              ],
            )
          : Column(
              children: [
                // 1. Banner Superior con degradado morado de la aplicación
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF512DA8), Color(0xFF7E57C2)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withAlpha(65),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.format_list_bulleted_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Productos cargados del XML',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Total: ${_todosLosProductos.length} · Filtrados: ${_productosFiltrados.length}',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Buscador redondeado con icono morado
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceCard(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF38314A) : AppTheme.primaryLight.withAlpha(160),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _filtrarCatalogo(),
                    style: TextStyle(fontSize: 14, color: AppTheme.getTextMain(context)),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o servicio...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryPurple, size: 22),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              color: AppTheme.primaryPurple,
                              onPressed: () {
                                _searchCtrl.clear();
                                _filtrarCatalogo();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Filtros rápidos de categoría en morado
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildChipFiltro('todos', 'Todos (${_todosLosProductos.length})', isDark),
                      const SizedBox(width: 8),
                      _buildChipFiltro('recargas', '📱 Recargas', isDark),
                      const SizedBox(width: 8),
                      _buildChipFiltro('pagos', '💡 Pagos', isDark),
                      const SizedBox(width: 8),
                      _buildChipFiltro('tarjetas', '🎟️ Tarjetas', isDark),
                      const SizedBox(width: 8),
                      _buildChipFiltro('saldo', '💼 Saldo Proveedor', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 4. Lista de productos cargados del XML
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                        )
                      : _productosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se encontraron productos coincidentes',
                                    style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: _productosFiltrados.length,
                              itemBuilder: (context, index) {
                                return RepaintBoundary(
                                  child: _fila(_productosFiltrados[index], isDark),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  /// Chip selector de categoría con tono morado
  Widget _buildChipFiltro(String id, String label, bool isDark) {
    final isSel = _filtroCategoria == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppTheme.primaryPurple,
      backgroundColor: isDark ? const Color(0xFF282533) : AppTheme.surfaceCard,
      labelStyle: TextStyle(
        color: isSel ? Colors.white : (isDark ? const Color(0xFFE6E1E5) : AppTheme.textMain),
        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
        fontSize: 11.5,
      ),
      side: BorderSide(
        color: isSel ? AppTheme.primaryPurple : (isDark ? const Color(0xFF38314A) : AppTheme.primaryLight.withAlpha(120)),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (val) {
        if (val) {
          setState(() => _filtroCategoria = id);
          _filtrarCatalogo();
        }
      },
    );
  }

  /// Tarjeta de fila individual con la estética y colores morados de la app
  Widget _fila(ProductoXml item, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1C24) : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2B38) : AppTheme.primaryExtraLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : AppTheme.primaryPurple.withAlpha(12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _abrirModalPorTipo(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo de la marca o servicio
                ServicioLogoWidget(servicio: item.servicio, size: 52),
                const SizedBox(width: 12),

                // Información central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del producto (en negritas, texto temático)
                      Text(
                        item.producto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? const Color(0xFFE6E1E5) : AppTheme.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Fila de servicio con icono morado de establecimiento
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 14,
                            color: AppTheme.primaryPurple,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.servicio,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // ID Servicio e ID Producto en gris
                      Text(
                        'ID Servicio: ${item.idServicio ?? ""} · ID Producto: ${item.idProducto ?? ""}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Precio en morado de la aplicación
                Text(
                  '\$${item.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // GESTIÓN DE SALDO CON EL PROVEEDOR
  // ===========================================================================

  Widget _buildTabSaldoProveedor() {
    return AnimatedBuilder(
      animation: _saldoCtrl,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gran Tarjeta de Saldo y Ganancias
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x261B5E20),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Bolsa de Saldo con Proveedor',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'API Pruebas / Live',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$${_saldoCtrl.saldo.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white30, height: 1),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ganancias por Comisión:',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '+\$${_saldoCtrl.comisionesGanadas.toStringAsFixed(2)} MXN',
                                style: const TextStyle(color: Color(0xFFC8E6C9), fontSize: 15, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1B5E20),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_circle_rounded, size: 17),
                          label: const Text(
                            'Fondeo / Recargar',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          onPressed: () {
                            RecargarSaldoDialog.show(
                              context,
                              controller: _saldoCtrl,
                              usuarioEmail: widget.authController.currentUser?.correo ?? '',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Botones de Acción de Pruebas (Reiniciar Saldo, Vaciar Saldo para probar bloqueo, Sync API)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Reiniciar a \$2,500.00', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await _saldoCtrl.reiniciarSaldoPruebas();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Bolsa de saldo restablecida a \$2,500.00 MXN para pruebas'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.money_off_csred_rounded, size: 17),
                    label: const Text('Simular Saldo \$0.00', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await _saldoCtrl.reiniciarSaldoPruebas(nuevoSaldo: 0.0);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Saldo puesto en \$0.00 MXN para validar restricción de compras sin fondos.'),
                              backgroundColor: AppTheme.errorColor,
                              duration: Duration(seconds: 2),
                            ),
                          );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 17),
                    label: const Text('Sync API Pruebas', style: TextStyle(fontSize: 12)),
                    onPressed: _sincronizarConApiGestoPago,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Historial de Movimientos de la Bolsa
              const Text(
                'Movimientos Recientes de Saldo:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
              const SizedBox(height: 10),

              if (_saldoCtrl.movimientos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No hay movimientos registrados.', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _saldoCtrl.movimientos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final mov = _saldoCtrl.movimientos[index];
                    final esAbono = mov.tipo == TipoMovimientoSaldo.abono;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryExtraLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: esAbono ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              esAbono ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: esAbono ? const Color(0xFF2E7D32) : AppTheme.errorColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mov.concepto,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Folio: ${mov.folio} • ${mov.fecha}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${esAbono ? '+' : '-'}\$${mov.monto.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: esAbono ? const Color(0xFF2E7D32) : AppTheme.errorColor,
                                ),
                              ),
                              Text(
                                'Saldo: \$${mov.saldoResultante.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
