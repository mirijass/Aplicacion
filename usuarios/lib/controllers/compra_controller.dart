import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/compra_model.dart';
import '../models/usuario_model.dart';
import '../services/db_helper.dart';

/// Controlador de Compras, Historial, Reportes y Geolocalización (MVC)
class CompraController extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Compra> _compras = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Compra> get compras => _compras;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _notifySafely() {
    try {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return;
      }
    } catch (_) {
      // Fallback para entornos de pruebas unitarias sin binding inicializado
    }
    notifyListeners();
  }

  // Métricas para el Panel de Reportes (Admin Dashboard)
  double get totalVentasGlobales =>
      _compras.fold(0.0, (sum, c) => sum + c.total);

  int get totalOrdenes => _compras.length;

  Map<String, int> get productosMasVendidos {
    final Map<String, int> conteo = {};
    for (var c in _compras) {
      for (var item in c.items) {
        final nombre = item['nombre_product'] ?? item['nombre'] ?? 'Producto';
        final cant = (item['cantidad'] as int?) ?? 1;
        conteo[nombre] = (conteo[nombre] ?? 0) + cant;
      }
    }
    return conteo;
  }

  /// Cargar compras (filtradas por usuarioId si es Lector/Editor o todas si es Admin)
  Future<void> cargarCompras({Usuario? usuarioLogeado}) async {
    _isLoading = true;
    _errorMessage = null;
    _notifySafely();

    try {
      if (usuarioLogeado != null && !usuarioLogeado.esAdmin) {
        _compras = await _dbHelper.getCompras(usuarioId: usuarioLogeado.id);
      } else {
        _compras = await _dbHelper.getCompras();
      }
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _errorMessage = 'Error al cargar historial de compras: ${e.toString()}';
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Registrar una nueva compra en el sistema
  Future<bool> registrarNuevaCompra(Compra compra) async {
    try {
      final id = await _dbHelper.insertCompra(compra);
      if (id > 0) {
        await cargarCompras();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error al registrar compra: $e';
      notifyListeners();
      return false;
    }
  }
}
