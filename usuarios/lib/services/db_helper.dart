import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/usuario_model.dart';
import '../models/rol_model.dart';
import '../models/producto_model.dart';
import '../models/compra_model.dart';

/// Servicio de Base de Datos SQLite (DAO / Repository)
/// Encargado de la persistencia de datos local para la aplicación.
/// Compatible tanto con SQLite nativo (Android/iOS) como con fallback en Web/Desktop.
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _database;
  bool _isWebOrFallback = false;
  bool _tablesInitialized = false;

  // Almacenamiento en memoria para modo Web o fallback
  final List<Rol> _fallbackRoles = [
    Rol(id: 1, rol: 'admin'),
    Rol(id: 2, rol: 'editor'),
    Rol(id: 3, rol: 'lector'),
  ];

  final List<Usuario> _fallbackUsuarios = [];
  final List<Producto> _fallbackProductos = [];
  final List<Compra> _fallbackCompras = [];
  int _nextId = 4;
  int _nextProductoId = 1;
  int _nextCompraId = 1;

  /// Inicializar el sistema de base de datos
  Future<void> init() async {
    if (kIsWeb) {
      _isWebOrFallback = true;
      _seedFallbackUsuarios();
      return;
    }

    try {
      _database = await _initDB('seguridad_app.db');
    } catch (e) {
      debugPrint('Aviso: Inicializando en modo compatibilidad/memoria: $e');
      _isWebOrFallback = true;
      _seedFallbackUsuarios();
    }
  }

  /// Obtener la instancia de la base de datos o inicializarla si no existe
  Future<Database?> get database async {
    if (_isWebOrFallback) return null;
    if (_database != null) return _database!;
    try {
      _database = await _initDB('seguridad_app.db');
      return _database;
    } catch (e) {
      _isWebOrFallback = true;
      _seedFallbackUsuarios();
      return null;
    }
  }

  /// Inicialización de SQLite
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
      onOpen: (db) async {
        await _ensureTablesAndSeed(db);
      },
    );
  }

  /// Verificar existencia de tablas y realizar sembrado automático de datos iniciales
  Future<void> _ensureTablesAndSeed(Database db) async {
    if (_tablesInitialized) return;
    _tablesInitialized = true;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS rol_permiso (
        id INTEGER PRIMARY KEY,
        rol TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_app (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        nombre TEXT NOT NULL,
        desc TEXT,
        pass TEXT NOT NULL,
        correo TEXT NOT NULL UNIQUE,
        role_id INTEGER NOT NULL,
        token_recuperacion TEXT,
        token_expiracion TIMESTAMP,
        codigo_verificacion TEXT,
        codigo_expiracion TIMESTAMP,
        createdAT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (role_id) REFERENCES rol_permiso (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        cantidad INTEGER NOT NULL,
        imagen TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS compra (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        usuario_id INTEGER NOT NULL,
        usuario_nombre TEXT NOT NULL,
        usuario_correo TEXT NOT NULL,
        total REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodo_pago TEXT NOT NULL,
        estado TEXT NOT NULL,
        items_json TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        direccion_entrega TEXT NOT NULL
      )
    ''');

    // Verificar y sembrar roles si no existen
    final countRoles = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM rol_permiso')) ?? 0;
    if (countRoles == 0) {
      await _seedRoles(db);
    }

    // Verificar y sembrar usuarios si no existen
    final countUsers = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_app')) ?? 0;
    if (countUsers == 0) {
      await _seedUsuarios(db);
    }

    // Verificar y sembrar productos si no existen
    final countProds = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM producto')) ?? 0;
    if (countProds == 0) {
      await _seedProductos(db);
    } else {
      // Actualizar automáticamente imágenes de fakestoreapi que generaban error 403 en teléfonos
      await _actualizarImagenesRotas(db);
    }
  }

  /// Actualiza productos con imágenes rotas de fakestoreapi a URLs directas de Unsplash
  Future<void> _actualizarImagenesRotas(Database db) async {
    try {
      await db.rawUpdate('''
        UPDATE producto SET imagen = 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500' 
        WHERE (imagen LIKE '%fakestoreapi%' OR imagen = '') AND nombre LIKE '%Mochila%';
      ''');
      await db.rawUpdate('''
        UPDATE producto SET imagen = 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500' 
        WHERE (imagen LIKE '%fakestoreapi%' OR imagen = '') AND nombre LIKE '%Camiseta%';
      ''');
      await db.rawUpdate('''
        UPDATE producto SET imagen = 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500' 
        WHERE (imagen LIKE '%fakestoreapi%' OR imagen = '') AND nombre LIKE '%Chamarra%';
      ''');
      await db.rawUpdate('''
        UPDATE producto SET imagen = 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500' 
        WHERE (imagen LIKE '%fakestoreapi%' OR imagen = '') AND nombre LIKE '%Reloj%';
      ''');
      await db.rawUpdate('''
        UPDATE producto SET imagen = 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500' 
        WHERE (imagen LIKE '%fakestoreapi%' OR imagen = '') AND nombre LIKE '%Audífonos%';
      ''');
    } catch (_) {}
  }

  /// Migración / actualización de base de datos
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureTablesAndSeed(db);
  }

  /// Habilitar soporte para llaves foráneas en SQLite
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creación de las tablas según las especificaciones
  Future<void> _createDB(Database db, int version) async {
    await _ensureTablesAndSeed(db);
  }

  /// Insertar roles por defecto: admin, editor, lector
  Future<void> _seedRoles(Database db) async {
    final batch = db.batch();
    batch.insert('rol_permiso', {'id': 1, 'rol': 'admin'});
    batch.insert('rol_permiso', {'id': 2, 'rol': 'editor'});
    batch.insert('rol_permiso', {'id': 3, 'rol': 'lector'});
    await batch.commit(noResult: true);
  }

  /// Insertar usuarios iniciales para pruebas en SQLite
  Future<void> _seedUsuarios(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    batch.insert('user_app', {
      'nombre': 'Juan Pérez',
      'desc': 'Administrador general del sistema',
      'pass': '123456',
      'correo': 'juan@gmail.com',
      'role_id': 1,
      'createdAT': now,
    });
    batch.insert('user_app', {
      'nombre': 'Pedro López',
      'desc': 'Editor de contenidos y reportes',
      'pass': '123456',
      'correo': 'pedro@gmail.com',
      'role_id': 2,
      'createdAT': now,
    });
    batch.insert('user_app', {
      'nombre': 'Ana García',
      'desc': 'Usuario con permisos de solo lectura',
      'pass': '123456',
      'correo': 'ana@gmail.com',
      'role_id': 3,
      'createdAT': now,
    });
    await batch.commit(noResult: true);
  }

  /// Insertar productos iniciales del catálogo
  Future<void> _seedProductos(Database db) async {
    final batch = db.batch();
    final productosIniciales = [
      {
        'nombre': 'Mochila Urbana Casual',
        'precio': 499.00,
        'cantidad': 50,
        'imagen': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500',
      },
      {
        'nombre': 'Camiseta Slim Fit Algodón',
        'precio': 299.00,
        'cantidad': 100,
        'imagen': 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500',
      },
      {
        'nombre': 'Chamarra de Algodón Premium',
        'precio': 899.00,
        'cantidad': 30,
        'imagen': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500',
      },
      {
        'nombre': 'Reloj Inteligente Sport',
        'precio': 1299.00,
        'cantidad': 25,
        'imagen': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500',
      },
      {
        'nombre': 'Audífonos Bluetooth Estéreo',
        'precio': 650.00,
        'cantidad': 40,
        'imagen': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500',
      },
    ];

    for (var p in productosIniciales) {
      batch.insert('producto', p);
    }
    await batch.commit(noResult: true);
  }

  /// Sembrado para modo Web / Fallback
  void _seedFallbackUsuarios() {
    final now = DateTime.now().toIso8601String();
    if (_fallbackUsuarios.isEmpty) {
      _fallbackUsuarios.addAll([
        Usuario(
          id: 1,
          nombre: 'Juan Pérez',
          desc: 'Administrador general del sistema',
          pass: '123456',
          correo: 'juan@gmail.com',
          roleId: 1,
          rolNombre: 'admin',
          createdAt: now,
        ),
        Usuario(
          id: 2,
          nombre: 'Pedro López',
          desc: 'Editor de contenidos y reportes',
          pass: '123456',
          correo: 'pedro@gmail.com',
          roleId: 2,
          rolNombre: 'editor',
          createdAt: now,
        ),
        Usuario(
          id: 3,
          nombre: 'Ana García',
          desc: 'Usuario con permisos de solo lectura',
          pass: '123456',
          correo: 'ana@gmail.com',
          roleId: 3,
          rolNombre: 'lector',
          createdAt: now,
        ),
      ]);
    }

    if (_fallbackProductos.isEmpty) {
      _fallbackProductos.addAll([
        Producto(id: 1, nombre: 'Mochila Urbana Casual', precio: 499.00, cantidad: 50, imagen: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500'),
        Producto(id: 2, nombre: 'Camiseta Slim Fit Algodón', precio: 299.00, cantidad: 100, imagen: 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500'),
        Producto(id: 3, nombre: 'Chamarra de Algodón Premium', precio: 899.00, cantidad: 30, imagen: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500'),
        Producto(id: 4, nombre: 'Reloj Inteligente Sport', precio: 1299.00, cantidad: 25, imagen: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500'),
        Producto(id: 5, nombre: 'Audífonos Bluetooth Estéreo', precio: 650.00, cantidad: 40, imagen: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500'),
      ]);
      _nextProductoId = 6;
    }
  }

  // ==========================================
  // OPERACIONES CRUD: USUARIOS
  // ==========================================

  /// Registrar un nuevo usuario
  Future<int> insertUsuario(Usuario usuario) async {
    if (_isWebOrFallback) {
      final newId = _nextId++;
      String rolNom = 'lector';
      if (usuario.roleId == 1) rolNom = 'admin';
      if (usuario.roleId == 2) rolNom = 'editor';

      final user = usuario.copyWith(
        id: newId,
        rolNombre: rolNom,
        createdAt: usuario.createdAt ?? DateTime.now().toIso8601String(),
      );
      _fallbackUsuarios.insert(0, user);
      return newId;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.insert(
      'user_app',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Obtener todos los usuarios con su rol correspondiente (mediante JOIN)
  Future<List<Usuario>> getUsuarios({String? query, int? roleId}) async {
    if (_isWebOrFallback) {
      var list = List<Usuario>.from(_fallbackUsuarios);

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        list = list.where((u) {
          return u.nombre.toLowerCase().contains(q) ||
              u.correo.toLowerCase().contains(q);
        }).toList();
      }

      if (roleId != null && roleId > 0) {
        list = list.where((u) => u.roleId == roleId).toList();
      }

      return list;
    }

    final db = await database;
    if (db == null) return [];

    String sql = '''
      SELECT u.*, r.rol AS rol_nombre
      FROM user_app u
      INNER JOIN rol_permiso r ON u.role_id = r.id
    ''';

    List<dynamic> whereArgs = [];
    List<String> whereClauses = [];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(u.nombre LIKE ? OR u.correo LIKE ?)');
      whereArgs.add('%${query.trim()}%');
      whereArgs.add('%${query.trim()}%');
    }

    if (roleId != null && roleId > 0) {
      whereClauses.add('u.role_id = ?');
      whereArgs.add(roleId);
    }

    if (whereClauses.isNotEmpty) {
      sql += ' WHERE ${whereClauses.join(' AND ')}';
    }

    sql += ' ORDER BY u.id DESC';

    final result = await db.rawQuery(sql, whereArgs);
    return result.map((map) => Usuario.fromMap(map)).toList();
  }

  /// Obtener un usuario por su ID
  Future<Usuario?> getUsuarioById(int id) async {
    if (_isWebOrFallback) {
      final matches = _fallbackUsuarios.where((u) => u.id == id);
      return matches.isNotEmpty ? matches.first : null;
    }

    final db = await database;
    if (db == null) return null;

    final result = await db.rawQuery('''
      SELECT u.*, r.rol AS rol_nombre
      FROM user_app u
      INNER JOIN rol_permiso r ON u.role_id = r.id
      WHERE u.id = ?
    ''', [id]);

    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  /// Actualizar datos de un usuario
  Future<int> updateUsuario(Usuario usuario) async {
    if (usuario.id == null) return 0;

    if (_isWebOrFallback) {
      final index = _fallbackUsuarios.indexWhere((u) => u.id == usuario.id);
      if (index != -1) {
        String rolNom = 'lector';
        if (usuario.roleId == 1) rolNom = 'admin';
        if (usuario.roleId == 2) rolNom = 'editor';

        _fallbackUsuarios[index] = usuario.copyWith(rolNombre: rolNom);
        return 1;
      }
      return 0;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.update(
      'user_app',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  /// Eliminar un usuario por su ID
  Future<int> deleteUsuario(int id) async {
    if (_isWebOrFallback) {
      final countBefore = _fallbackUsuarios.length;
      _fallbackUsuarios.removeWhere((u) => u.id == id);
      return countBefore - _fallbackUsuarios.length;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.delete(
      'user_app',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Verificar si un correo ya existe en la base de datos
  Future<bool> emailExists(String email, {int? excludeId}) async {
    if (_isWebOrFallback) {
      return _fallbackUsuarios.any((u) =>
          u.correo.toLowerCase() == email.trim().toLowerCase() &&
          (excludeId == null || u.id != excludeId));
    }

    final db = await database;
    if (db == null) return false;

    String sql = 'SELECT id FROM user_app WHERE LOWER(correo) = LOWER(?)';
    List<dynamic> args = [email.trim()];

    if (excludeId != null) {
      sql += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.rawQuery(sql, args);
    return result.isNotEmpty;
  }

  /// Autenticación de usuario por correo o nombre y contraseña
  Future<Usuario?> loginUser(String identificador, String pass) async {
    if (_isWebOrFallback) {
      final idTrim = identificador.trim().toLowerCase();
      final matches = _fallbackUsuarios.where((u) =>
          (u.correo.toLowerCase() == idTrim || u.nombre.toLowerCase() == idTrim) &&
          u.pass == pass);
      return matches.isNotEmpty ? matches.first : null;
    }

    final db = await database;
    if (db == null) return null;

    final result = await db.rawQuery('''
      SELECT u.*, r.rol AS rol_nombre
      FROM user_app u
      INNER JOIN rol_permiso r ON u.role_id = r.id
      WHERE (LOWER(u.correo) = LOWER(?) OR LOWER(u.nombre) = LOWER(?))
        AND u.pass = ?
    ''', [identificador.trim(), identificador.trim(), pass]);

    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  /// Obtener un usuario por su correo electrónico
  Future<Usuario?> getUsuarioByCorreo(String correo) async {
    if (_isWebOrFallback) {
      final matches = _fallbackUsuarios.where(
        (u) => u.correo.toLowerCase() == correo.trim().toLowerCase(),
      );
      return matches.isNotEmpty ? matches.first : null;
    }

    final db = await database;
    if (db == null) return null;

    final result = await db.rawQuery('''
      SELECT u.*, r.rol AS rol_nombre
      FROM user_app u
      INNER JOIN rol_permiso r ON u.role_id = r.id
      WHERE LOWER(u.correo) = LOWER(?)
    ''', [correo.trim()]);

    if (result.isNotEmpty) {
      return Usuario.fromMap(result.first);
    }
    return null;
  }

  // ==========================================
  // OPERACIONES CRUD: ROLES
  // ==========================================

  /// Obtener todos los roles disponibles
  Future<List<Rol>> getRoles() async {
    if (_isWebOrFallback) {
      return List<Rol>.from(_fallbackRoles);
    }

    final db = await database;
    if (db == null) return List<Rol>.from(_fallbackRoles);

    final result = await db.query('rol_permiso', orderBy: 'id ASC');
    return result.map((map) => Rol.fromMap(map)).toList();
  }

  // ==========================================
  // OPERACIONES CRUD: PRODUCTOS
  // ==========================================

  /// Registrar o actualizar producto en SQLite
  Future<int> insertProducto(Producto producto) async {
    if (_isWebOrFallback) {
      final existingIndex = _fallbackProductos.indexWhere(
          (p) => p.nombre.trim().toLowerCase() == producto.nombre.trim().toLowerCase());
      if (existingIndex != -1) {
        final exist = _fallbackProductos[existingIndex];
        _fallbackProductos[existingIndex] = exist.copyWith(
          precio: producto.precio,
          cantidad: exist.cantidad + producto.cantidad,
          imagen: producto.imagen.isNotEmpty ? producto.imagen : exist.imagen,
        );
        return exist.id ?? (existingIndex + 1);
      }
      final newId = _nextProductoId++;
      final prod = producto.copyWith(id: newId);
      _fallbackProductos.add(prod);
      return newId;
    }

    final db = await database;
    if (db == null) return 0;

    // Verificar si ya existe por nombre
    final existing = await db.query(
      'producto',
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [producto.nombre.trim()],
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final currentCant = existing.first['cantidad'] as int? ?? 0;
      await db.update(
        'producto',
        {
          'precio': producto.precio,
          'cantidad': currentCant + producto.cantidad,
          'imagen': producto.imagen,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }

    return await db.insert('producto', producto.toMap());
  }

  /// Obtener productos filtrados o todos
  Future<List<Producto>> getProductos({String? query}) async {
    if (_isWebOrFallback) {
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        return _fallbackProductos
            .where((p) => p.nombre.toLowerCase().contains(q))
            .toList();
      }
      return List<Producto>.from(_fallbackProductos);
    }

    final db = await database;
    if (db == null) return [];

    List<Map<String, dynamic>> maps;
    if (query != null && query.trim().isNotEmpty) {
      maps = await db.query(
        'producto',
        where: 'nombre LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: 'id DESC',
      );
    } else {
      maps = await db.query('producto', orderBy: 'id DESC');
      if (maps.isEmpty) {
        await _seedProductos(db);
        maps = await db.query('producto', orderBy: 'id DESC');
      }
    }

    return maps.map((map) => Producto.fromMap(map)).toList();
  }

  /// Actualizar datos de un producto
  Future<int> updateProducto(Producto producto) async {
    if (producto.id == null) return 0;

    if (_isWebOrFallback) {
      final index = _fallbackProductos.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        _fallbackProductos[index] = producto;
        return 1;
      }
      return 0;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.update(
      'producto',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  /// Eliminar un producto por su ID
  Future<int> deleteProducto(int id) async {
    if (_isWebOrFallback) {
      final countBefore = _fallbackProductos.length;
      _fallbackProductos.removeWhere((p) => p.id == id);
      return countBefore - _fallbackProductos.length;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.delete(
      'producto',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // OPERACIONES CRUD: COMPRAS / PEDIDOS
  // ==========================================

  /// Registrar una nueva compra en SQLite o memoria
  Future<int> insertCompra(Compra compra) async {
    if (_isWebOrFallback) {
      final newId = _nextCompraId++;
      final c = Compra(
        id: newId,
        usuarioId: compra.usuarioId,
        usuarioNombre: compra.usuarioNombre,
        usuarioCorreo: compra.usuarioCorreo,
        total: compra.total,
        fecha: compra.fecha,
        metodoPago: compra.metodoPago,
        estado: compra.estado,
        items: compra.items,
        latitud: compra.latitud,
        longitud: compra.longitud,
        direccionEntrega: compra.direccionEntrega,
      );
      _fallbackCompras.insert(0, c);
      return newId;
    }

    final db = await database;
    if (db == null) return 0;

    return await db.insert('compra', compra.toMap());
  }

  /// Obtener todas las compras o las filtradas por usuarioId
  Future<List<Compra>> getCompras({int? usuarioId}) async {
    if (_isWebOrFallback) {
      if (usuarioId != null && usuarioId > 0) {
        return _fallbackCompras.where((c) => c.usuarioId == usuarioId).toList();
      }
      return List<Compra>.from(_fallbackCompras);
    }

    final db = await database;
    if (db == null) return [];

    List<Map<String, dynamic>> maps;
    if (usuarioId != null && usuarioId > 0) {
      maps = await db.query(
        'compra',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: 'id DESC',
      );
    } else {
      maps = await db.query('compra', orderBy: 'id DESC');
    }

    return maps.map((map) => Compra.fromMap(map)).toList();
  }

  // ==========================================
  // MÉTODOS DE COMPATIBILIDAD CON EJEMPLOS DE CLASE
  // ==========================================

  /// Método estático compatible con la firma: SQHelper.createProduct(...)
  static Future<int> createProduct(
    String nombre,
    double precio,
    int cantidad,
    String imagen,
  ) async {
    final prod = Producto(
      nombre: nombre,
      precio: precio,
      cantidad: cantidad,
      imagen: imagen,
    );
    return await DBHelper().insertProducto(prod);
  }

  /// Método estático compatible con la firma: SQLHelper.createUser(...)
  static Future<int> createUser(
    String nombre,
    String? apP,
    String? apM,
    String pass, {
    String? correo,
    int roleId = 3,
  }) async {
    final fullName = [nombre, apP, apM]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');

    final mail = correo ??
        '${nombre.toLowerCase().replaceAll(' ', '')}@ejemplo.com';

    final user = Usuario(
      nombre: fullName.isNotEmpty ? fullName : nombre,
      correo: mail,
      pass: pass,
      roleId: roleId,
    );

    return await DBHelper().insertUsuario(user);
  }

  /// Método de instancia compatible con login_user
  // ignore: non_constant_identifier_names
  Future<bool> login_user(String identificador, String pass) async {
    final user = await loginUser(identificador, pass);
    return user != null;
  }
}

/// Alias para compatibilidad con la referencia dada en clase (SQLHelper y SQHelper)
typedef SQLHelper = DBHelper;
typedef SQHelper = DBHelper;
