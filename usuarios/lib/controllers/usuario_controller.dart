import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/usuario_model.dart';
import '../models/rol_model.dart';
import '../services/db_helper.dart';

/// Controlador de Gestión de Usuarios (MVC)
/// Contiene la lógica de negocio, validaciones y estado de la vista de usuarios.
class UsuarioController extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Usuario> _usuarios = [];
  List<Rol> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filtros y búsqueda
  String _searchQuery = '';
  int? _selectedRoleId;

  // Getters
  List<Usuario> get usuarios => _usuarios;
  List<Rol> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get searchQuery => _searchQuery;
  int? get selectedRoleId => _selectedRoleId;

  // Métricas de conteo
  int get totalUsuarios => _usuarios.length;
  int get totalAdmins => _usuarios.where((u) => u.roleId == 1).length;
  int get totalEditores => _usuarios.where((u) => u.roleId == 2).length;
  int get totalLectores => _usuarios.where((u) => u.roleId == 3).length;

  /// Cargar roles disponibles de la base de datos
  Future<void> cargarRoles() async {
    try {
      _roles = await _dbHelper.getRoles();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar roles: ${e.toString()}';
      notifyListeners();
    }
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

  /// Cargar usuarios aplicando los filtros actuales de búsqueda y rol
  Future<void> cargarUsuarios() async {
    _isLoading = true;
    _errorMessage = null;
    _notifySafely();

    try {
      // Cargar roles si aún no están cargados
      if (_roles.isEmpty) {
        _roles = await _dbHelper.getRoles();
      }

      _usuarios = await _dbHelper.getUsuarios(
        query: _searchQuery,
        roleId: _selectedRoleId,
      );
      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _errorMessage = 'Error al consultar usuarios: ${e.toString()}';
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Filtrar en tiempo real por término de búsqueda (nombre o correo)
  void setSearchQuery(String query) {
    _searchQuery = query;
    cargarUsuarios();
  }

  /// Filtrar por rol específico (null para todos)
  void setFilterRole(int? roleId) {
    _selectedRoleId = roleId;
    cargarUsuarios();
  }

  /// Limpiar todos los filtros aplicados
  void limpiarFiltros() {
    _searchQuery = '';
    _selectedRoleId = null;
    cargarUsuarios();
  }

  /// Validar campos de formulario según las reglas de negocio
  String? _validarCamposUsuario(Usuario usuario) {
    final nombre = usuario.nombre.trim();
    if (nombre.isEmpty) {
      return 'El nombre es obligatorio';
    }
    if (nombre.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }
    if (nombre.length > 36) {
      return 'El nombre no puede exceder los 36 caracteres';
    }

    final correo = usuario.correo.trim();
    if (correo.isEmpty) {
      return 'El correo electrónico es obligatorio';
    }
    if (correo.length > 36) {
      return 'El correo electrónico no puede exceder los 36 caracteres';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(correo)) {
      return 'El formato del correo electrónico no es válido';
    }

    final pass = usuario.pass.trim();
    if (pass.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (pass.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (pass.length > 36) {
      return 'La contraseña no puede exceder los 36 caracteres';
    }
    final tieneMayuscula = pass.contains(RegExp(r'[A-Z]'));
    final tieneNumero = pass.contains(RegExp(r'[0-9]'));
    final tieneEspecial = pass.contains(RegExp(r'[^a-zA-Z0-9]'));
    if (!tieneMayuscula || !tieneNumero || !tieneEspecial) {
      return 'La contraseña debe incluir al menos una letra mayúscula, un número y un carácter especial';
    }

    if (usuario.desc != null && usuario.desc!.trim().isNotEmpty) {
      if (usuario.desc!.trim().length > 36) {
        return 'La descripción no puede exceder los 36 caracteres';
      }
    }

    return null;
  }

  /// Registrar un nuevo usuario con validaciones de negocio y permisos
  Future<bool> registrarUsuario(Usuario nuevoUsuario, {Usuario? usuarioLogeado}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // 0. Validar permisos del usuario logeado (El perfil Lector no puede agregar)
      if (usuarioLogeado != null && usuarioLogeado.esLector) {
        _errorMessage = 'Los usuarios con perfil "Lector" no tienen permiso para agregar usuarios';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validar asignación de roles (Solo Admin puede asignar rol Admin o Editor)
      if (usuarioLogeado != null && !usuarioLogeado.esAdmin && nuevoUsuario.roleId != 3) {
        _errorMessage = 'Solo los Administradores tienen permiso para asignar roles de Administrador o Editor';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 1. Validaciones de negocio en los campos
      final validacionError = _validarCamposUsuario(nuevoUsuario);
      if (validacionError != null) {
        _errorMessage = validacionError;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Validación de correo duplicado
      final existe = await _dbHelper.emailExists(nuevoUsuario.correo.trim());
      if (existe) {
        _errorMessage = 'El correo electrónico ya está registrado por otro usuario';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Inserción en base de datos SQLite
      final insertedId = await _dbHelper.insertUsuario(nuevoUsuario);
      if (insertedId > 0) {
        _successMessage = 'Usuario "${nuevoUsuario.nombre}" registrado con éxito';
        await cargarUsuarios();
        return true;
      } else {
        _errorMessage = 'No se pudo registrar el usuario en la base de datos';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error en el registro: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar datos de un usuario existente con validaciones de permisos
  Future<bool> actualizarUsuario(Usuario usuario, {Usuario? usuarioLogeado}) async {
    if (usuario.id == null) return false;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Validar permisos (Lector no puede editar)
      if (usuarioLogeado != null && usuarioLogeado.esLector) {
        _errorMessage = 'Los usuarios con perfil "Lector" no tienen permiso para modificar usuarios';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validar cambio de rol (Solo Admin puede cambiar roles)
      if (usuarioLogeado != null && !usuarioLogeado.esAdmin) {
        final usuarioOriginal = _usuarios.firstWhere(
          (u) => u.id == usuario.id,
          orElse: () => usuario,
        );
        if (usuarioOriginal.roleId != usuario.roleId) {
          _errorMessage = 'Solo los Administradores tienen permiso para cambiar los roles de usuario';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Validar datos del formulario
      final validacionError = _validarCamposUsuario(usuario);
      if (validacionError != null) {
        _errorMessage = validacionError;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validar correo duplicado excluyendo el ID actual
      final existe = await _dbHelper.emailExists(usuario.correo.trim(), excludeId: usuario.id);
      if (existe) {
        _errorMessage = 'El correo electrónico ya pertenece a otro usuario';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final rowsAffected = await _dbHelper.updateUsuario(usuario);
      if (rowsAffected > 0) {
        _successMessage = 'Usuario actualizado correctamente';
        await cargarUsuarios();
        return true;
      } else {
        _errorMessage = 'No se encontró el usuario para actualizar';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar usuario: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar usuario por ID con validaciones de permisos
  Future<bool> eliminarUsuario(int id, {Usuario? usuarioLogeado}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (usuarioLogeado != null && !usuarioLogeado.puedeEliminar) {
        _errorMessage = 'Solo los Administradores tienen permiso para eliminar usuarios';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final rowsAffected = await _dbHelper.deleteUsuario(id);
      if (rowsAffected > 0) {
        _successMessage = 'Usuario eliminado exitosamente';
        await cargarUsuarios();
        return true;
      } else {
        _errorMessage = 'No se pudo eliminar el usuario';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar usuario: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Limpiar mensajes de alerta
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
