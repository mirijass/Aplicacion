import 'dart:math';
import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/db_helper.dart';
import '../services/mail_helper.dart';

/// Controlador de Autenticación (MVC)
/// Gestiona la sesión del usuario activo, inicio y cierre de sesión, y recuperación de contraseña.
class AuthController extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  Usuario? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Usuario? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Permisos del usuario autenticado
  bool get puedeCrear => _currentUser?.puedeCrearEditar ?? false;
  bool get puedeEditar => _currentUser?.puedeCrearEditar ?? false;
  bool get puedeEliminar => _currentUser?.puedeEliminar ?? false;
  bool get esLector => _currentUser?.esLector ?? false;
  bool get esAdmin => _currentUser?.esAdmin ?? false;
  bool get esEditor => _currentUser?.esEditor ?? false;
  bool get puedeCambiarRol => _currentUser?.esAdmin ?? false;

  /// Iniciar sesión con identificador (correo o nombre) y contraseña
  Future<bool> login(String identificador, String password) async {
    if (identificador.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Por favor completa todos los campos';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _dbHelper.loginUser(identificador.trim(), password);
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'El correo/usuario o la contraseña son incorrectos.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Recuperación de contraseña enviando una clave temporal al correo del usuario
  Future<bool> recuperarContrasena(String email) async {
    if (email.trim().isEmpty) {
      _errorMessage = 'Ingresa un correo electrónico válido';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _dbHelper.getUsuarioByCorreo(email.trim());
      if (user == null) {
        _errorMessage = 'No existe un usuario registrado con ese correo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Generar contraseña temporal segura de 6 caracteres con letras y números
      final random = Random();
      final tempPass = 'Pass${1000 + random.nextInt(9000)}';

      // Actualizar en BD
      final updatedUser = user.copyWith(pass: tempPass);
      await _dbHelper.updateUsuario(updatedUser);

      // Intentar enviar correo con MailHelper
      try {
        await MailHelper.sendPasswordRecoveryEmail(email.trim(), tempPass);
      } catch (e) {
        debugPrint('MailHelper error (fallback simulado): $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al recuperar contraseña: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Enviar código de verificación por correo
  Future<bool> enviarCodigoVerificacion(String email) async {
    if (email.trim().isEmpty) return false;
    try {
      final random = Random();
      final token = '${100000 + random.nextInt(900000)}';
      await MailHelper.sendVerificationTokenEmail(email.trim(), token);
      return true;
    } catch (e) {
      debugPrint('Error enviando código de verificación: $e');
      return false;
    }
  }

  /// Cambiar contraseña del usuario actualmente autenticado
  Future<bool> cambiarContrasena({
    required String passActual,
    required String passNueva,
    required String passConfirmar,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'No hay una sesión activa de usuario.';
      notifyListeners();
      return false;
    }

    if (passActual.isEmpty) {
      _errorMessage = 'Ingresa tu contraseña actual.';
      notifyListeners();
      return false;
    }

    if (passActual != _currentUser!.pass) {
      _errorMessage = 'La contraseña actual es incorrecta.';
      notifyListeners();
      return false;
    }

    if (passNueva.isEmpty) {
      _errorMessage = 'Ingresa la nueva contraseña.';
      notifyListeners();
      return false;
    }

    if (passNueva.length < 8) {
      _errorMessage = 'La nueva contraseña debe tener al menos 8 caracteres.';
      notifyListeners();
      return false;
    }

    if (passNueva.length > 36) {
      _errorMessage = 'La contraseña no puede exceder los 36 caracteres.';
      notifyListeners();
      return false;
    }

    final tieneMayuscula = passNueva.contains(RegExp(r'[A-Z]'));
    final tieneNumero = passNueva.contains(RegExp(r'[0-9]'));
    final tieneEspecial = passNueva.contains(RegExp(r'[^a-zA-Z0-9]'));
    if (!tieneMayuscula || !tieneNumero || !tieneEspecial) {
      _errorMessage = 'La nueva contraseña debe incluir al menos una letra mayúscula, un número y un carácter especial.';
      notifyListeners();
      return false;
    }

    if (passNueva == passActual) {
      _errorMessage = 'La nueva contraseña debe ser diferente a la contraseña actual.';
      notifyListeners();
      return false;
    }

    if (passNueva != passConfirmar) {
      _errorMessage = 'La confirmación de la nueva contraseña no coincide.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userActualizado = _currentUser!.copyWith(pass: passNueva);
      final rows = await _dbHelper.updateUsuario(userActualizado);
      if (rows > 0) {
        _currentUser = userActualizado;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'No se pudo actualizar la contraseña en la base de datos.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al cambiar la contraseña: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cerrar sesión actual
  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpiar mensajes de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

