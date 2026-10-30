import '../models/producto_xml_model.dart';
import 'db_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Servicio de Procesamiento e Importación de datos XML a SQLite (sqflite)
class XmlParserService {
  static final List<ProductoXml> _fallbackCache = [];
  static bool _tableCreated = false;

  /// Procesa una cadena de texto XML, deserializa a objetos Dart y los guarda en SQLite
  static Future<RespuestaXml> procesarYGuardarXml(String xmlData) async {
    // 1. Deserializar respuesta XML a objetos Dart
    final respuesta = RespuestaXml.fromXmlString(xmlData);

    // 2. Guardar lista de productos en la tabla 'productos_xml' de SQLite
    await guardarProductosXmlBatch(respuesta.productos);

    return respuesta;
  }

  /// Guarda una lista de ProductoXml masivamente utilizando Batch en SQLite
  static Future<void> guardarProductosXmlBatch(List<ProductoXml> productos) async {
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
