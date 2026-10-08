import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/producto_model.dart';
import '../models/usuario_model.dart';
import '../services/db_helper.dart';

/// Controlador de Gestión de Productos y Carrito de Compras (MVC)
class ProductoController extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  final String _apiUrl = 'https://fakestoreapi.com/products';

  List<Producto> _productos = [];
  List<Map<String, dynamic>> _carrito = [];
  double _total = 0.0;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;
  String _searchQuery = '';

  // Getters
  List<Producto> get productos => _productos;
  List<Map<String, dynamic>> get carrito => _carrito;
  double get total => _total;
  int get cantidadItemsCarrito =>
      _carrito.fold(0, (sum, item) => sum + (item['cantidad'] as int? ?? 1));
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get searchQuery => _searchQuery;

  ProductoController() {
    cargarCartFromPreferences();
  }

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

  /// Cargar productos desde la base de datos local SQLite
  Future<void> cargarProductos() async {
    _isLoading = true;
    _errorMessage = null;
    _notifySafely();

    try {
      _productos = await _dbHelper.getProductos(query: _searchQuery);
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _errorMessage = 'Error al cargar productos locales: ${e.toString()}';
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Limpiar/Vaciar todo el catálogo de productos local
  Future<void> vaciarProductosLocal() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await _dbHelper.database;
      if (db != null) {
        await db.delete('producto');
      }
      _productos.clear();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sincronizar catálogo con productos online de FakeStore API (Admin y Editor)
  Future<bool> sincronizarOnline({Usuario? usuarioLogeado}) async {
    if (usuarioLogeado != null && usuarioLogeado.esLector) {
      _errorMessage = 'Los usuarios con perfil "Lector" no tienen permiso para sincronizar productos.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var item in data) {
          final prod = Producto(
            nombre: item['title'] ?? 'Producto sin nombre',
            precio: item['price'] is int
                ? (item['price'] as int).toDouble()
                : item['price'] is double
                    ? item['price'] as double
                    : 0.0,
            cantidad: 1000,
            imagen: item['image'] ?? '',
            desc: item['description'] as String?,
          );
          await _dbHelper.insertProducto(prod);
        }
        _successMessage = 'Productos sincronizados desde FakeStore API con éxito';
        _productos = await _dbHelper.getProductos(query: _searchQuery);
        _isSyncing = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Respuesta HTTP ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = 'Error al conectar con FakeStore API: ${e.toString()}';
      _isSyncing = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Filtrar productos por término de búsqueda
  void setSearchQuery(String query) {
    _searchQuery = query;
    cargarProductos();
  }

  /// Registrar un nuevo producto (Admin y Editor)
  Future<bool> crearProducto(Producto nuevoProducto, {Usuario? usuarioLogeado}) async {
    if (usuarioLogeado != null && usuarioLogeado.esLector) {
      _errorMessage = 'Los usuarios con perfil "Lector" no tienen permiso para agregar productos.';
      notifyListeners();
      return false;
    }

    if (nuevoProducto.nombre.trim().isEmpty) {
      _errorMessage = 'El nombre del producto es obligatorio';
      notifyListeners();
      return false;
    }

    if (nuevoProducto.precio <= 0) {
      _errorMessage = 'Ingresa un precio mayor a 0';
      notifyListeners();
      return false;
    }

    try {
      final id = await _dbHelper.insertProducto(nuevoProducto);
      if (id > 0) {
        _successMessage = 'Producto "${nuevoProducto.nombre}" agregado con éxito';
        await cargarProductos();
        return true;
      } else {
        _errorMessage = 'No se pudo guardar el producto';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al crear producto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Actualizar datos de un producto (Admin y Editor)
  Future<bool> actualizarProducto(Producto producto, {Usuario? usuarioLogeado}) async {
    if (usuarioLogeado != null && usuarioLogeado.esLector) {
      _errorMessage = 'Los usuarios con perfil "Lector" no tienen permiso para modificar productos.';
      notifyListeners();
      return false;
    }

    if (producto.id == null) return false;

    try {
      final rows = await _dbHelper.updateProducto(producto);
      if (rows > 0) {
        _successMessage = 'Producto actualizado correctamente';
        await cargarProductos();
        return true;
      } else {
        _errorMessage = 'No se pudo actualizar el producto';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar producto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Eliminar un producto (Solo Admin)
  Future<bool> eliminarProducto(int id, {Usuario? usuarioLogeado}) async {
    if (usuarioLogeado != null && !usuarioLogeado.puedeEliminar) {
      _errorMessage = 'Solo los Administradores tienen permiso para eliminar productos.';
      notifyListeners();
      return false;
    }

    try {
      final rows = await _dbHelper.deleteProducto(id);
      if (rows > 0) {
        _successMessage = 'Producto eliminado del catálogo';
        await cargarProductos();
        return true;
      } else {
        _errorMessage = 'No se pudo eliminar el producto';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar producto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // GESTIÓN DEL CARRITO DE COMPRAS (SharedPreferences)
  // ==========================================

  int _activeUserId = 0; // 0 para sesión por defecto, o ID del usuario autenticado

  /// Asociar el carrito de compras al usuario activo
  void setActiveUser(Usuario? user) {
    final newId = user?.id ?? 0;
    if (_activeUserId != newId) {
      _activeUserId = newId;
      cargarCartFromPreferences();
    }
  }

  /// Limpiar el carrito en memoria al cerrar sesión
  void resetCart() {
    _activeUserId = 0;
    _carrito = [];
    _total = 0.0;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> cargarCartFromPreferences({int? userId}) async {
    try {
      final targetId = userId ?? _activeUserId;
      final prefs = await SharedPreferences.getInstance();
      String? savedCart = prefs.getString('user_cart_$targetId');
      if (savedCart != null) {
        _carrito = List<Map<String, dynamic>>.from(
          json.decode(savedCart) as List<dynamic>,
        );
      } else {
        _carrito = [];
      }
      _calcularTotal();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar carrito: $e');
    }
  }

  Future<void> _guardarCartInPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_cart_$_activeUserId', json.encode(_carrito));
    } catch (e) {
      debugPrint('Error al guardar carrito: $e');
    }
  }

  void _calcularTotal() {
    _total = _carrito.fold(0.0, (sum, item) {
      double price = double.tryParse(item['precio'].toString()) ?? 0.0;
      int quantity = (item['cantidad'] as int?) ?? 1;
      return sum + (price * quantity);
    });
  }

  /// Agregar producto al carrito validando el stock disponible
  bool agregarAlCarrito(Producto producto, int cantidad) {
    if (cantidad <= 0) return false;

    if (producto.cantidad <= 0) {
      _errorMessage = 'No hay stock disponible para "${producto.nombre}".';
      notifyListeners();
      return false;
    }

    final existingIndex = _carrito.indexWhere(
      (item) => item['id'] == producto.id || item['nombre_product'] == producto.nombre,
    );

    final cantActual = existingIndex != -1 ? (_carrito[existingIndex]['cantidad'] as int) : 0;
    final nuevaCant = cantActual + cantidad;

    if (nuevaCant > producto.cantidad) {
      final disp = producto.cantidad - cantActual;
      if (disp <= 0) {
        _errorMessage = 'Ya tienes el stock máximo disponible (${producto.cantidad} unidades) de "${producto.nombre}" en tu carrito.';
      } else {
        _errorMessage = 'No puedes agregar $cantidad unidades más. Solo quedan $disp disponibles (Stock total: ${producto.cantidad}).';
      }
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    if (existingIndex != -1) {
      _carrito[existingIndex]['cantidad'] = nuevaCant;
    } else {
      _carrito.add({
        'id': producto.id,
        'nombre_product': producto.nombre,
        'precio': producto.precio,
        'cantidad': cantidad,
        'imagen': producto.imagen,
      });
    }

    _guardarCartInPreferences();
    _calcularTotal();
    _successMessage = '"${producto.nombre}" agregado al carrito (x$cantidad)';
    notifyListeners();
    return true;
  }

  /// Modificar cantidad de un ítem en el carrito validando el stock disponible
  bool cambiarCantidadCarrito(int index, int delta) {
    if (index >= 0 && index < _carrito.length) {
      final item = _carrito[index];
      final cantActual = item['cantidad'] as int;
      final nuevaCant = cantActual + delta;

      if (nuevaCant <= 0) {
        _errorMessage = null;
        _carrito.removeAt(index);
        _guardarCartInPreferences();
        _calcularTotal();
        notifyListeners();
        return true;
      }

      if (delta > 0) {
        final prodId = item['id'] as int?;
        final nombreProd = item['nombre_product'] as String? ?? '';
        Producto? prod;
        if (prodId != null) {
          final matches = _productos.where((p) => p.id == prodId);
          if (matches.isNotEmpty) prod = matches.first;
        }
        if (prod == null && nombreProd.isNotEmpty) {
          final matches = _productos.where(
            (p) => p.nombre.trim().toLowerCase() == nombreProd.trim().toLowerCase(),
          );
          if (matches.isNotEmpty) prod = matches.first;
        }

        if (prod != null && nuevaCant > prod.cantidad) {
          _errorMessage = 'Alcanzaste el límite del stock disponible (${prod.cantidad} unidades).';
          notifyListeners();
          return false;
        }
      }

      _errorMessage = null;
      _carrito[index]['cantidad'] = nuevaCant;
      _guardarCartInPreferences();
      _calcularTotal();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Eliminar ítem del carrito
  void eliminarDelCarrito(int index) {
    if (index >= 0 && index < _carrito.length) {
      _carrito.removeAt(index);
      _guardarCartInPreferences();
      _calcularTotal();
      notifyListeners();
    }
  }

  /// Vaciar todo el carrito
  void vaciarCarrito() {
    _carrito.clear();
    _guardarCartInPreferences();
    _calcularTotal();
    notifyListeners();
  }

  /// Finalizar la compra: descuenta la cantidad comprada y elimina los productos cuyo stock llega a 0 del catálogo
  Future<void> finalizarCompra() async {
    for (var item in List<Map<String, dynamic>>.from(_carrito)) {
      final prodId = item['id'] as int?;
      final cantComprada = (item['cantidad'] as int?) ?? 1;
      final nombreProd = item['nombre_product'] as String? ?? '';

      // Buscar producto en la lista cargada
      Producto? prod;
      if (prodId != null) {
        final matches = _productos.where((p) => p.id == prodId);
        if (matches.isNotEmpty) prod = matches.first;
      }
      if (prod == null && nombreProd.isNotEmpty) {
        final matches = _productos.where(
          (p) => p.nombre.trim().toLowerCase() == nombreProd.trim().toLowerCase(),
        );
        if (matches.isNotEmpty) prod = matches.first;
      }

      if (prod != null && prod.id != null) {
        final nuevoStock = prod.cantidad - cantComprada;
        if (nuevoStock <= 0) {
          // Si el stock se agota o se compraron todos, eliminar de la BD para que ya no aparezca en el catálogo
          await _dbHelper.deleteProducto(prod.id!);
        } else {
          // Si queda stock disponible, actualizar la cantidad
          await _dbHelper.updateProducto(prod.copyWith(cantidad: nuevoStock));
        }
      }
    }

    vaciarCarrito();
    await cargarProductos();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
