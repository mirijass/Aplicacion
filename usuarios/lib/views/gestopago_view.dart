import 'package:flutter/material.dart';
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

  List<ProductoXml> _todosLosProductos = [];
  List<ProductoXml> _productosFiltrados = [];
  String _filtroCategoria = 'todos'; // 'todos', 'recargas', 'pagos', 'tarjetas', 'saldo'
  bool _isLoading = true;
  bool _isSyncingOnline = false;

  @override
  void initState() {
    super.initState();
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

  /// Diálogo para procesar Recarga Telefónica (10 dígitos + confirmación + selección de saldo)
  void _abrirModalRecarga(ProductoXml servicio) {
    final telCtrl = TextEditingController();
    final confirmTelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String metodoPago = 'Saldo con Proveedor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                            ),
                            Text(
                              servicio.producto,
                              style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${servicio.precio.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Teléfono a 10 dígitos
                  TextFormField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Número Celular (10 dígitos)',
                      hintText: 'Ej. 5512345678',
                      prefixIcon: Icon(Icons.phone_rounded, color: AppTheme.primaryPurple),
                      counterText: '',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length != 10 || int.tryParse(val.trim()) == null) {
                        return 'Ingresa un número telefónico válido a 10 dígitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Confirmar Teléfono
                  TextFormField(
                    controller: confirmTelCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Número Celular',
                      hintText: 'Vuelve a escribir el número',
                      prefixIcon: Icon(Icons.check_rounded, color: AppTheme.primaryPurple),
                      counterText: '',
                    ),
                    validator: (val) {
                      if (val != telCtrl.text) {
                        return 'Los números de teléfono no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Selección de Forma de Pago
                  _buildSelectorFormaPago(
                    monto: servicio.precio,
                    metodoSeleccionado: metodoPago,
                    onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _ejecutarPago(
                      servicio: servicio,
                      referencia: telCtrl.text.trim(),
                      monto: servicio.precio,
                      metodoPago: metodoPago,
                      formKey: formKey,
                      parentContext: ctx,
                    ),
                    child: Text(
                      'Aplicar Recarga de \$${servicio.precio.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Diálogo para procesar Pago de Servicios (CFE, Agua, Gas, etc.) con consulta de adeudo
  void _abrirModalPagoServicio(ProductoXml servicio) {
    final refCtrl = TextEditingController();
    final montoCtrl = TextEditingController(text: servicio.precio > 0 ? servicio.precio.toStringAsFixed(2) : '348.00');
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
                            ),
                            Text(
                              servicio.producto,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Número de Servicio / Contrato / Código de barras
                  TextFormField(
                    controller: refCtrl,
                    decoration: InputDecoration(
                      labelText: 'Número de Servicio / Contrato / Referencia',
                      hintText: 'Ej. 012345678901',
                      prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF2E7D32)),
                      suffixIcon: IconButton(
                        icon: consultando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search_rounded, color: Color(0xFF2E7D32)),
                        tooltip: 'Consultar Adeudo en Línea',
                        onPressed: () async {
                          if (refCtrl.text.trim().length < 4) return;
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
                      if (val == null || val.trim().length < 4) {
                        return 'Ingresa una referencia válida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Cuadro de Consulta de Adeudo
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
                              Text(
                                '${resultadoConsulta!['titularSimulado']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              ),
                              Text(
                                'Vence: ${resultadoConsulta!['fechaVencimiento']}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subtotal: \$${resultadoConsulta!['monto']} + Comisión GestoPago: \$${resultadoConsulta!['comision']} MXN',
                            style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),

                  // Monto a Pagar
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto a Pagar (MXN)',
                      prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF2E7D32)),
                    ),
                    validator: (val) {
                      final n = double.tryParse(val ?? '');
                      if (n == null || n <= 0) return 'Ingresa un monto válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Selección de Forma de Pago
                  _buildSelectorFormaPago(
                    monto: double.tryParse(montoCtrl.text) ?? 100.0,
                    metodoSeleccionado: metodoPago,
                    onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
                    child: const Text('Confirmar y Pagar Recibo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Diálogo para procesar Tarjetas Electrónicas y Pines Digitales
  void _abrirModalTarjetaDigital(ProductoXml servicio) {
    final emailCtrl = TextEditingController(text: widget.authController.currentUser?.correo ?? '');
    final formKey = GlobalKey<FormState>();
    String metodoPago = 'Saldo con Proveedor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                            ),
                            Text(
                              servicio.producto,
                              style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${servicio.precio.toStringAsFixed(2)} MXN',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Correo destino para entrega del PIN
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico para Entrega del PIN',
                      hintText: 'correo@ejemplo.com',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.orange),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty || !val.contains('@')) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Selección de Forma de Pago
                  _buildSelectorFormaPago(
                    monto: servicio.precio,
                    metodoSeleccionado: metodoPago,
                    onCambio: (nuevo) => setModalState(() => metodoPago = nuevo),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _ejecutarPago(
                      servicio: servicio,
                      referencia: emailCtrl.text.trim(),
                      monto: servicio.precio,
                      metodoPago: metodoPago,
                      formKey: formKey,
                      parentContext: ctx,
                      correoDestino: emailCtrl.text.trim(),
                    ),
                    child: Text(
                      'Emitir Tarjeta por \$${servicio.precio.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Selector reusable de método de pago (Saldo con Proveedor vs PayPal vs Tarjeta)
  Widget _buildSelectorFormaPago({
    required double monto,
    required String metodoSeleccionado,
    required Function(String) onCambio,
  }) {
    final saldoDisponible = _saldoCtrl.saldo;
    final saldoAlcanza = saldoDisponible >= monto;

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
          onTap: saldoAlcanza ? () => onCambio('Saldo con Proveedor') : null,
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
                  color: saldoAlcanza ? const Color(0xFF2E7D32) : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Saldo con Proveedor GestoPago',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8E6C9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Sin comisiones', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
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

        // Opción 2: PayPal
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

        // Opción 3: Tarjeta o Efectivo
        InkWell(
          onTap: () => onCambio('Tarjeta Bancaria / Efectivo'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                    'Tarjeta Bancaria o Efectivo en Mostrador',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (metodoSeleccionado == 'Tarjeta Bancaria / Efectivo')
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ejecución de la transacción
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
            usarSaldoProveedor: false,
            correoDestino: correoDestino,
          );
        },
      );
      return;
    }

    Navigator.pop(parentContext);

    final usarSaldo = metodoPago == 'Saldo con Proveedor';
    await _completarTransaccion(
      servicio: servicio,
      referencia: referencia,
      monto: monto,
      metodoPago: metodoPago,
      usarSaldoProveedor: usarSaldo,
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
                Text('Conectando con GestoPago API...', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Autorizando transacción y emitiendo folio', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['mensaje'] as String? ?? 'Error al procesar la operación'),
            backgroundColor: AppTheme.errorColor,
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
      metodoPago: 'GestoPago: $metodoPago (${result['folioGestoPago']})',
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
      direccionEntrega: 'Transacción Digital GestoPago (Ref: $referencia)',
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
        usuarioController: widget.usuarioController ?? UsuarioController(),
        productoController: widget.productoController ?? ProductoController(),
        compraController: widget.compraController,
        themeController: widget.themeController,
        currentRoute: 'gestopago',
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? const Color(0xFF282533) : AppTheme.primaryExtraLight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💼 Gestión de Saldo Proveedor',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                        onPressed: () => setState(() => _filtroCategoria = 'todos'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Volver al Catálogo XML'),
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
                                return _fila(_productosFiltrados[index], isDark);
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
                padding: const EdgeInsets.all(20),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bolsa de Saldo con Proveedor',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Modo Simulado / Live', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '\$${_saldoCtrl.saldo.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white30, height: 1),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ganancias por Comisión:',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              '+\$${_saldoCtrl.comisionesGanadas.toStringAsFixed(2)} MXN',
                              style: const TextStyle(color: Color(0xFFC8E6C9), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1B5E20),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_circle_rounded, size: 18),
                          label: const Text('Fondeo / Recargar', style: TextStyle(fontWeight: FontWeight.bold)),
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

              // Botones de Acción de Pruebas
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reiniciar a \$2,500.00'),
                      onPressed: () async {
                        await _saldoCtrl.reiniciarSaldoPruebas();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bolsa de saldo restablecida para pruebas')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Sync API Online'),
                      onPressed: _sincronizarConApiGestoPago,
                    ),
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
