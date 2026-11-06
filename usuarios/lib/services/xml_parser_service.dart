import '../models/producto_xml_model.dart';
import 'db_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Servicio de Procesamiento e Importación de datos XML a SQLite (sqflite)
class XmlParserService {
  static final List<ProductoXml> _fallbackCache = [];
  static bool _tableCreated = false;

  /// Procesa una cadena de texto XML oficial de `getProductList.do`,
  /// deserializa a objetos Dart y reemplaza la tabla `productos_xml` en SQLite.
  static Future<RespuestaXml> procesarYGuardarXml(String xmlData) async {
    final respuesta = RespuestaXml.fromXmlString(xmlData);
    await guardarProductosXmlBatch(respuesta.productos, limpiarAntes: true);
    return respuesta;
  }

  /// Guarda una lista de ProductoXml masivamente utilizando Batch en SQLite
  static Future<void> guardarProductosXmlBatch(
    List<ProductoXml> productos, {
    bool limpiarAntes = false,
  }) async {
    _fallbackCache
      ..clear()
      ..addAll(productos);

    final dbHelper = DBHelper();
    final db = await dbHelper.database;

    if (db == null) return;

    if (!_tableCreated) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS productos_xml (
          idProducto INTEGER PRIMARY KEY,
          servicio TEXT,
          producto TEXT,
          idServicio INTEGER,
          idCatTipoServicio INTEGER,
          tipoFront INTEGER,
          hasDigitoVerificador INTEGER,
          precio REAL,
          showAyuda INTEGER,
          tipoReferencia TEXT,
          legend TEXT
        )
      ''');
      _tableCreated = true;
    }

    if (limpiarAntes) {
      await db.delete('productos_xml');
    }

    final batch = db.batch();
    for (var prod in productos) {
      batch.insert(
        'productos_xml',
        prod.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Obtiene los productos XML desde caché en memoria o SQLite
  static Future<List<ProductoXml>> obtenerProductosXml() async {
    if (_fallbackCache.isNotEmpty) {
      return List<ProductoXml>.from(_fallbackCache);
    }

    final dbHelper = DBHelper();
    final db = await dbHelper.database;

    if (db == null) {
      return List<ProductoXml>.from(_fallbackCache);
    }

    if (!_tableCreated) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS productos_xml (
          idProducto INTEGER PRIMARY KEY,
          servicio TEXT,
          producto TEXT,
          idServicio INTEGER,
          idCatTipoServicio INTEGER,
          tipoFront INTEGER,
          hasDigitoVerificador INTEGER,
          precio REAL,
          showAyuda INTEGER,
          tipoReferencia TEXT,
          legend TEXT
        )
      ''');
      _tableCreated = true;
    }

    final List<Map<String, dynamic>> maps = await db.query('productos_xml');
    final loaded = maps.map((map) => ProductoXml.fromMap(map)).toList();
    if (loaded.isNotEmpty) {
      _fallbackCache
        ..clear()
        ..addAll(loaded);
    }
    return loaded;
  }
}
