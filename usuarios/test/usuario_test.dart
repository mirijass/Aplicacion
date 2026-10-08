import 'package:flutter_test/flutter_test.dart';
import 'package:usuarios/models/usuario_model.dart';
import 'package:usuarios/models/rol_model.dart';
import 'package:usuarios/services/db_helper.dart';
import 'package:usuarios/controllers/usuario_controller.dart';
import 'package:usuarios/controllers/auth_controller.dart';

void main() {
  setUpAll(() async {
    final dbHelper = DBHelper();
    await dbHelper.init();
  });

  group('Pruebas de Modelos (Usuario y Rol)', () {
    test('Modelo Rol serializa y deserializa correctamente', () {
      final rol = Rol(id: 1, rol: 'admin');
      final map = rol.toMap();
      expect(map['id'], 1);
      expect(map['rol'], 'admin');

      final fromMap = Rol.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.rol, 'admin');
      expect(fromMap.rolFormateado, 'Admin');
    });

    test('Modelo Usuario serializa y calcula iniciales correctamente', () {
      final user = Usuario(
        id: 10,
        nombre: 'Carlos Santana',
        correo: 'carlos@test.com',
        pass: 'clave123',
        roleId: 2,
        rolNombre: 'editor',
      );

      expect(user.iniciales, 'CS');
      expect(user.rolTexto, 'Editor');
      expect(user.esAdmin, isFalse);
      expect(user.esEditor, isTrue);
      expect(user.esLector, isFalse);
      expect(user.puedeCrearEditar, isTrue);
      expect(user.puedeEliminar, isFalse);

      final map = user.toMap();
      expect(map['nombre'], 'Carlos Santana');
      expect(map['correo'], 'carlos@test.com');
      expect(map['role_id'], 2);

      final userFromMap = Usuario.fromMap(map);
      expect(userFromMap.nombre, 'Carlos Santana');
      expect(userFromMap.correo, 'carlos@test.com');
    });
  });

  group('Pruebas de Base de Datos y Operaciones (DBHelper)', () {
    final dbHelper = DBHelper();

    test('Sembrado inicial de roles y usuarios', () async {
      final roles = await dbHelper.getRoles();
      expect(roles.length, greaterThanOrEqualTo(3));
      expect(roles.any((r) => r.rol == 'admin'), isTrue);
      expect(roles.any((r) => r.rol == 'editor'), isTrue);
      expect(roles.any((r) => r.rol == 'lector'), isTrue);

      final usuarios = await dbHelper.getUsuarios();
      expect(usuarios.length, greaterThanOrEqualTo(3));
    });

    test('Registro y Login de un usuario nuevo', () async {
      final emailTest = 'test_${DateTime.now().millisecondsSinceEpoch}@correo.com';
      final nuevo = Usuario(
        nombre: 'Usuario Prueba',
        correo: emailTest,
        pass: 'passPrueba123',
        roleId: 1,
      );

      final id = await dbHelper.insertUsuario(nuevo);
      expect(id, greaterThan(0));

      final logueado = await dbHelper.loginUser(emailTest, 'passPrueba123');
      expect(logueado, isNotNull);
      expect(logueado?.nombre, 'Usuario Prueba');

      final existe = await dbHelper.emailExists(emailTest);
      expect(existe, isTrue);
    });
  });

  group('Pruebas de Controladores (MVC)', () {
    test('AuthController autentica usuarios válidos y rechaza inválidos', () async {
      final authCtrl = AuthController();
      
      // Credenciales precargadas de prueba
      final exito = await authCtrl.login('juan@gmail.com', '123456');
      expect(exito, isTrue);
      expect(authCtrl.isAuthenticated, isTrue);
      expect(authCtrl.currentUser?.nombre, 'Juan Pérez');
      expect(authCtrl.puedeCrear, isTrue);
      expect(authCtrl.puedeEliminar, isTrue);

      authCtrl.logout();
      expect(authCtrl.isAuthenticated, isFalse);

      // Login como Lector
      final exitoLector = await authCtrl.login('ana@gmail.com', '123456');
      expect(exitoLector, isTrue);
      expect(authCtrl.esLector, isTrue);
      expect(authCtrl.puedeCrear, isFalse);
      expect(authCtrl.puedeEliminar, isFalse);

      authCtrl.logout();

      // Credenciales inválidas
      final fallo = await authCtrl.login('juan@gmail.com', 'password_erronea');
      expect(fallo, isFalse);
      expect(authCtrl.errorMessage, isNotNull);
    });

    test('AuthController recupera contraseña y genera clave temporal', () async {
      final authCtrl = AuthController();
      final ok = await authCtrl.recuperarContrasena('juan@gmail.com');
      expect(ok, isTrue);

      // El usuario debe poder ingresar con su nueva clave o la anterior si falló
      final existe = await DBHelper().emailExists('juan@gmail.com');
      expect(existe, isTrue);

      final noExiste = await authCtrl.recuperarContrasena('noexiste@correo.com');
      expect(noExiste, isFalse);
      expect(authCtrl.errorMessage, contains('No existe'));
    });

    test('AuthController permite a un usuario autenticado cambiar su contraseña', () async {
      final authCtrl = AuthController();
      await authCtrl.login('ana@gmail.com', '123456');

      // Intentar cambiar con contraseña actual incorrecta
      final falloActual = await authCtrl.cambiarContrasena(
        passActual: 'incorrecta',
        passNueva: 'NuevaPass123!',
        passConfirmar: 'NuevaPass123!',
      );
      expect(falloActual, isFalse);
      expect(authCtrl.errorMessage, contains('incorrecta'));

      // Intentar cambiar con contraseña nueva sin números
      final falloNum = await authCtrl.cambiarContrasena(
        passActual: '123456',
        passNueva: 'SinNumeros!',
        passConfirmar: 'SinNumeros!',
      );
      expect(falloNum, isFalse);
      expect(authCtrl.errorMessage, contains('número'));

      // Intentar cambiar con confirmación que no coincide
      final falloMatch = await authCtrl.cambiarContrasena(
        passActual: '123456',
        passNueva: 'NuevaPass123!',
        passConfirmar: 'Diferente123!',
      );
      expect(falloMatch, isFalse);
      expect(authCtrl.errorMessage, contains('coincide'));

      // Cambio exitoso
      final ok = await authCtrl.cambiarContrasena(
        passActual: '123456',
        passNueva: 'NuevaPass123!',
        passConfirmar: 'NuevaPass123!',
      );
      expect(ok, isTrue);
      expect(authCtrl.currentUser?.pass, 'NuevaPass123!');

      // Verificar que ahora se puede iniciar sesión con la nueva contraseña
      authCtrl.logout();
      final loginNuevo = await authCtrl.login('ana@gmail.com', 'NuevaPass123!');
      expect(loginNuevo, isTrue);
    });

    test('UsuarioController valida reglas de negocio (longitud 3-36, correo y clave)', () async {
      final userCtrl = UsuarioController();
      await userCtrl.cargarRoles();

      // Intento con nombre corto (< 3 caracteres)
      final nombreCorto = Usuario(
        nombre: 'Ab',
        correo: 'ab@correo.com',
        pass: 'Clave123!',
        roleId: 3,
      );
      final rCorto = await userCtrl.registrarUsuario(nombreCorto);
      expect(rCorto, isFalse);
      expect(userCtrl.errorMessage, contains('3 caracteres'));

      // Intento sin correo
      final sinCorreo = Usuario(
        nombre: 'Nombre Valido',
        correo: '',
        pass: 'Clave123!',
        roleId: 3,
      );
      final r1 = await userCtrl.registrarUsuario(sinCorreo);
      expect(r1, isFalse);
      expect(userCtrl.errorMessage, contains('correo'));

      // Intento con correo inválido
      final correoInvalido = Usuario(
        nombre: 'Nombre Valido',
        correo: 'no-es-correo',
        pass: 'Clave123!',
        roleId: 3,
      );
      final r2 = await userCtrl.registrarUsuario(correoInvalido);
      expect(r2, isFalse);
      expect(userCtrl.errorMessage, contains('formato'));

      // Intento con contraseña corta (< 8 caracteres)
      final claveCorta = Usuario(
        nombre: 'Nombre Valido',
        correo: 'valido@correo.com',
        pass: 'Clav1!',
        roleId: 3,
      );
      final rCorta = await userCtrl.registrarUsuario(claveCorta);
      expect(rCorta, isFalse);
      expect(userCtrl.errorMessage, contains('8 caracteres'));

      // Intento con contraseña sin mayúscula, número o especial
      final claveSinEspecial = Usuario(
        nombre: 'Nombre Valido',
        correo: 'valido@correo.com',
        pass: 'sololetras123',
        roleId: 3,
      );
      final r3 = await userCtrl.registrarUsuario(claveSinEspecial);
      expect(r3, isFalse);
      expect(userCtrl.errorMessage, contains('mayúscula'));
    });

    test('Registro combina Apellido Paterno, Materno y Nombres con perfil Solo de lectura (Lector)', () async {
      final userCtrl = UsuarioController();
      final apPaterno = 'Pérez';
      final apMaterno = 'González';
      final nombres = 'Juan Carlos';
      final nombreCompleto = '$nombres $apPaterno $apMaterno';

      final usuarioLector = Usuario(
        nombre: nombreCompleto,
        correo: 'juan_perez_${DateTime.now().millisecondsSinceEpoch}@correo.com',
        pass: 'Clave123!',
        roleId: 3, // Solo de lectura
      );

      final exito = await userCtrl.registrarUsuario(usuarioLector);
      expect(exito, isTrue);
      expect(userCtrl.usuarios.first.nombre, nombreCompleto);
      expect(userCtrl.usuarios.first.esLector, isTrue);
    });

    test('UsuarioController rechaza registro cuando el usuario logeado es Lector', () async {
      final userCtrl = UsuarioController();
      final usuarioLector = Usuario(
        id: 3,
        nombre: 'Ana García',
        correo: 'ana@gmail.com',
        pass: '123456',
        roleId: 3,
      );

      final nuevoUser = Usuario(
        nombre: 'Nuevo Test',
        correo: 'nuevotest@correo.com',
        pass: 'Clave123!',
        roleId: 3,
      );

      final resultado = await userCtrl.registrarUsuario(
        nuevoUser,
        usuarioLogeado: usuarioLector,
      );
      expect(resultado, isFalse);
      expect(userCtrl.errorMessage, contains('Lector'));
    });

    test('UsuarioController no permite que un Editor cambie roles de usuarios', () async {
      final userCtrl = UsuarioController();
      await userCtrl.cargarUsuarios();

      final usuarioEditor = Usuario(
        id: 2,
        nombre: 'Carlos Editor',
        correo: 'carlos@gmail.com',
        pass: '123456',
        roleId: 2,
      );

      final usuarioAdmin = Usuario(
        id: 1,
        nombre: 'Juan Perez',
        correo: 'juan@gmail.com',
        pass: '123456',
        roleId: 1,
      );

      // Usuario objetivo a modificar (un Lector id: 3)
      final usuarioLector = Usuario(
        id: 3,
        nombre: 'Ana García',
        correo: 'ana@gmail.com',
        pass: 'Clave123!',
        roleId: 3,
      );

      // 1. Intento de cambio de rol por un Editor (de Lector 3 a Admin 1)
      final usuarioModificadoRol = usuarioLector.copyWith(roleId: 1);
      final resEditor = await userCtrl.actualizarUsuario(
        usuarioModificadoRol,
        usuarioLogeado: usuarioEditor,
      );
      expect(resEditor, isFalse);
      expect(userCtrl.errorMessage, contains('Administradores'));

      // 2. Editor sí puede actualizar otros datos sin cambiar el rol
      final usuarioModificadoNombre = usuarioLector.copyWith(nombre: 'Ana Modificada');
      final resNombre = await userCtrl.actualizarUsuario(
        usuarioModificadoNombre,
        usuarioLogeado: usuarioEditor,
      );
      expect(resNombre, isTrue);

      // 3. Un Admin sí puede cambiar el rol
      final resAdmin = await userCtrl.actualizarUsuario(
        usuarioModificadoRol,
        usuarioLogeado: usuarioAdmin,
      );
      expect(resAdmin, isTrue);
    });
  });
}
