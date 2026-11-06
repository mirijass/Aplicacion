import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipo de movimiento en la bolsa de saldo del proveedor
enum TipoMovimientoSaldo { abono, cargo }

/// Registro de movimiento en la cuenta de saldo del proveedor
class MovimientoSaldo {
  final String id;
  final TipoMovimientoSaldo tipo;
  final String concepto;
  final double monto;
  final double comisionGanada;
  final double saldoResultante;
  final String fecha;
  final String folio;
  final Map<String, dynamic>? detalles;

  MovimientoSaldo({
    required this.id,
    required this.tipo,
    required this.concepto,
    required this.monto,
    required this.comisionGanada,
    required this.saldoResultante,
    required this.fecha,
    required this.folio,
    this.detalles,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo.name,
      'concepto': concepto,
      'monto': monto,
      'comisionGanada': comisionGanada,
      'saldoResultante': saldoResultante,
      'fecha': fecha,
      'folio': folio,
      'detalles': detalles,
    };
  }

  factory MovimientoSaldo.fromMap(Map<String, dynamic> map) {
    return MovimientoSaldo(
      id: map['id'] as String? ?? '',
      tipo: map['tipo'] == 'abono'
          ? TipoMovimientoSaldo.abono
          : TipoMovimientoSaldo.cargo,
      concepto: map['concepto'] as String? ?? 'Movimiento',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      comisionGanada: (map['comisionGanada'] as num?)?.toDouble() ?? 0.0,
      saldoResultante: (map['saldoResultante'] as num?)?.toDouble() ?? 0.0,
      fecha: map['fecha'] as String? ?? '',
      folio: map['folio'] as String? ?? '',
      detalles: map['detalles'] != null
          ? Map<String, dynamic>.from(map['detalles'] as Map)
          : null,
    );
  }
}

/// Controlador para gestionar la bolsa de saldo con el proveedor GestoPago
class SaldoProveedorController extends ChangeNotifier {
  static final SaldoProveedorController _instance =
      SaldoProveedorController._internal();
  factory SaldoProveedorController() => _instance;
  SaldoProveedorController._internal() {
    _cargarDatos();
  }

  static const String _kSaldoKey = 'gestopago_saldo_proveedor_v1';
  static const String _kComisionesKey = 'gestopago_comisiones_ganadas_v1';
  static const String _kMovimientosKey = 'gestopago_movimientos_historial_v1';
  static const double _kSaldoInicial = 42999.89;

  double _saldo = _kSaldoInicial;
  double _comisionesGanadas = 0.0;
  List<MovimientoSaldo> _movimientos = [];
  bool _isLoading = true;

  double get saldo => _saldo;
  double get comisionesGanadas => _comisionesGanadas;
  List<MovimientoSaldo> get movimientos => List.unmodifiable(_movimientos);
  bool get isLoading => _isLoading;

  Future<void> _cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _saldo = prefs.getDouble(_kSaldoKey) ?? _kSaldoInicial;
      _comisionesGanadas = prefs.getDouble(_kComisionesKey) ?? 0.0;

      final movJson = prefs.getString(_kMovimientosKey);
      if (movJson != null && movJson.isNotEmpty) {
        final decoded = jsonDecode(movJson) as List;
        _movimientos = decoded
            .map((item) => MovimientoSaldo.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error al cargar saldo proveedor: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _guardarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSaldoKey, _saldo);
      await prefs.setDouble(_kComisionesKey, _comisionesGanadas);
      await _guardarMovimientos(prefs);
    } catch (e) {
      debugPrint('Error al guardar saldo proveedor: $e');
    }
  }

  Future<void> _guardarMovimientos(SharedPreferences prefs) async {
    final listMap = _movimientos.map((m) => m.toMap()).toList();
    await prefs.setString(_kMovimientosKey, jsonEncode(listMap));
  }

  /// Sincroniza el saldo directamente con el valor `<SALDO>` devuelto por `getBalance.do` de GestoPago
  Future<void> sincronizarSaldoDesdeServidor(
    double saldoRealServidor, {
    bool registrarMovimiento = false,
  }) async {
    final anterior = _saldo;
    _saldo = saldoRealServidor;

    if (registrarMovimiento && (anterior - saldoRealServidor).abs() >= 0.01) {
      final folio = 'BAL-${DateTime.now().millisecondsSinceEpoch}';
      _movimientos.insert(
        0,
        MovimientoSaldo(
          id: folio,
          tipo: TipoMovimientoSaldo.abono,
          concepto: 'Sincronización de Saldo GestoPago (getBalance.do)',
          monto: saldoRealServidor,
          comisionGanada: 0.0,
          saldoResultante: _saldo,
          fecha: DateTime.now().toString().split('.')[0],
          folio: folio,
        ),
      );
    }

    await _guardarDatos();
    notifyListeners();
  }

  /// Registra el cargo aplicando el saldo real `<SALDO>` y `<COMISION>` devueltos por `sendTx.do`
  Future<void> registrarCargoConSaldoServidor({
    required double monto,
    required double saldoServidorPosterior,
    required double comisionProveedor,
    required String concepto,
    required String folio,
    String? fechaServidor,
    Map<String, dynamic>? detalles,
  }) async {
    if (saldoServidorPosterior > 0) {
      _saldo = saldoServidorPosterior;
    } else if (_saldo >= monto) {
      _saldo -= monto;
    }
    _comisionesGanadas += comisionProveedor;

    final mov = MovimientoSaldo(
      id: 'TX-$folio-${DateTime.now().millisecondsSinceEpoch}',
      tipo: TipoMovimientoSaldo.cargo,
      concepto: concepto,
      monto: monto,
      comisionGanada: comisionProveedor,
      saldoResultante: _saldo,
      fecha: (fechaServidor != null && fechaServidor.isNotEmpty)
          ? fechaServidor
          : DateTime.now().toString().split('.')[0],
      folio: folio,
      detalles: detalles,
    );

    _movimientos.insert(0, mov);
    await _guardarDatos();
    notifyListeners();
  }

  /// Recarga saldo en la bolsa con el proveedor
  Future<void> recargarSaldo({
    required double monto,
    required String metodoPago,
    String? referencia,
  }) async {
    if (monto <= 0) return;

    _saldo += monto;
    final folio = 'REC-${DateTime.now().millisecondsSinceEpoch}';

    final mov = MovimientoSaldo(
      id: folio,
      tipo: TipoMovimientoSaldo.abono,
      concepto: 'Recarga de Saldo Proveedor ($metodoPago)',
      monto: monto,
      comisionGanada: 0.0,
      saldoResultante: _saldo,
      fecha: DateTime.now().toString().split('.')[0],
      folio: folio,
      detalles: {
        'metodoPago': metodoPago,
        'referencia': referencia ?? 'SPEI-DIRECTO',
      },
    );

    _movimientos.insert(0, mov);
    await _guardarDatos();
    notifyListeners();
  }

  /// Descuenta saldo para aplicar un pago de servicio, recarga o pin
  Future<bool> descontarSaldo({
    required double monto,
    required String concepto,
    required String folio,
    double comisionGanada = 0.0,
    Map<String, dynamic>? detalles,
  }) async {
    if (_saldo < monto) {
      return false; // Saldo insuficiente
    }

    _saldo -= monto;
    _comisionesGanadas += comisionGanada;

    final mov = MovimientoSaldo(
      id: 'PAG-${DateTime.now().millisecondsSinceEpoch}',
      tipo: TipoMovimientoSaldo.cargo,
      concepto: concepto,
      monto: monto,
      comisionGanada: comisionGanada,
      saldoResultante: _saldo,
      fecha: DateTime.now().toString().split('.')[0],
      folio: folio,
      detalles: detalles,
    );

    _movimientos.insert(0, mov);
    await _guardarDatos();
    notifyListeners();
    return true;
  }

  /// Actualiza el saldo de la bolsa a un monto específico
  Future<void> reiniciarSaldoPruebas({double nuevoSaldo = _kSaldoInicial}) async {
    _saldo = nuevoSaldo;
    _comisionesGanadas = 0.0;
    _movimientos.clear();

    _movimientos.add(
      MovimientoSaldo(
        id: 'BAL-${DateTime.now().millisecondsSinceEpoch}',
        tipo: TipoMovimientoSaldo.abono,
        concepto: 'Actualización de Bolsa de Saldo GestoPago',
        monto: nuevoSaldo,
        comisionGanada: 0.0,
        saldoResultante: nuevoSaldo,
        fecha: DateTime.now().toString().split('.')[0],
        folio: 'GP-BAL-01',
      ),
    );

    await _guardarDatos();
    notifyListeners();
  }
}
