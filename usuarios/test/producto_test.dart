import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usuarios/models/producto_model.dart';
import 'package:usuarios/models/usuario_model.dart';
import 'package:usuarios/services/db_helper.dart';
import 'package:usuarios/controllers/producto_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final dbHelper = DBHelper();
    await dbHelper.init();
  });

  group('Pruebas de Modelo Producto y DBHelper', () {
    test('Modelo Producto serializa y deserializa correctamente', () {
      final prod = Producto(
        id: 1,
        nombre: 'Producto Test',
        precio: 150.50,
        cantidad: 10,
        imagen: 'https://test.com/img.jpg',
      );

      final map = prod.toMap();
      expect(map['nombre'], 'Producto Test');
      expect(map['precio'], 150.50);
      expect(map['cantidad'], 10);

      final fromMap = Producto.fromMap(map);
      expect(fromMap.nombre, 'Producto Test');
      expect(fromMap.precio, 150.50);
    });

    test('DBHelper guarda y recupera productos con el alias SQHelper.createProduct', () async {
      final id = await SQHelper.createProduct('Reloj Inteligente', 1200.0, 50, 'https://test.com/reloj.jpg');
      expect(id, greaterThan(0));

      final productos = await DBHelper().getProductos();
      expect(productos.any((p) => p.nombre == 'Reloj Inteligente'), isTrue);
    });
  });

  group('Pruebas de ProductoController y Permisos de Roles', () {
    test('ProductoController gestiona carrito y calcula total en MXN', () async {
      final controller = ProductoController();
      final prod = Producto(id: 100, nombre: 'Tenis Deportivos', precio: 500.0, cantidad: 20, imagen: '');

      controller.agregarAlCarrito(prod, 2);
      expect(controller.cantidadItemsCarrito, 2);
      expect(controller.total, 1000.0);

      controller.vaciarCarrito();
      expect(controller.cantidadItemsCarrito, 0);
      expect(controller.total, 0.0);
    });

    test('ProductoController elimina productos del catálogo al finalizar la compra', () async {
      final controller = ProductoController();
      final prodComprar = Producto(nombre: 'Camisa Especial', precio: 300.0, cantidad: 1, imagen: '');
      
      await controller.crearProducto(prodComprar);
      expect(controller.productos.any((p) => p.nombre == 'Camisa Especial'), isTrue);

      final pGuardado = controller.productos.firstWhere((p) => p.nombre == 'Camisa Especial');
      controller.agregarAlCarrito(pGuardado, 1);
      
      await controller.finalizarCompra();
      expect(controller.productos.any((p) => p.nombre == 'Camisa Especial'), isFalse);
    });

    test('ProductoController restringe creación, edición y eliminación para el rol Lector', () async {
      final controller = ProductoController();
      final usuarioLector = Usuario(id: 3, nombre: 'Ana Lector', correo: 'ana@gmail.com', pass: '123456', roleId: 3);
      final prodNuevo = Producto(nombre: 'Nuevo Item', precio: 99.9, cantidad: 5, imagen: '');

      // Intento de crear como Lector
      final resCrear = await controller.crearProducto(prodNuevo, usuarioLogeado: usuarioLector);
      expect(resCrear, isFalse);
      expect(controller.errorMessage, contains('Lector'));

      // Intento de eliminar como Lector
      final resEliminar = await controller.eliminarProducto(1, usuarioLogeado: usuarioLector);
      expect(resEliminar, isFalse);
      expect(controller.errorMessage, contains('Administradores'));
    });

    test('ProductoController rechaza agregar o incrementar más cantidad que el stock disponible', () async {
      final controller = ProductoController();
      final prodLimitado = Producto(id: 200, nombre: 'Audífonos Pro', precio: 800.0, cantidad: 3, imagen: '');

      // Intento de agregar 5 unidades (solo hay 3)
      final okExceso = controller.agregarAlCarrito(prodLimitado, 5);
      expect(okExceso, isFalse);
      expect(controller.errorMessage, contains('disponibles'));

      // Agregar 2 unidades (válido)
      final okValido = controller.agregarAlCarrito(prodLimitado, 2);
      expect(okValido, isTrue);

      // Intentar agregar 2 más (total 4, supera stock de 3)
      final okMasDeStock = controller.agregarAlCarrito(prodLimitado, 2);
      expect(okMasDeStock, isFalse);
      expect(controller.errorMessage, contains('disponibles'));
    });
  });
}
