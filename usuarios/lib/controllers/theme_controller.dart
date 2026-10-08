import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controlador de Personalización de Tema y Preferencias de Usuario (MVC)
class ThemeController extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _notificacionesHabilitadas = true;

  bool get isDarkMode => _isDarkMode;
  bool get notificacionesHabilitadas => _notificacionesHabilitadas;

  ThemeController() {
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _notificacionesHabilitadas = prefs.getBool('notif_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar tema: $e');
    }
  }

  Future<void> toggleTheme(bool dark) async {
    _isDarkMode = dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', dark);
    } catch (e) {
      debugPrint('Error al guardar tema: $e');
    }
  }

  Future<void> toggleNotificaciones(bool enabled) async {
    _notificacionesHabilitadas = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', enabled);
    } catch (e) {
      debugPrint('Error al guardar preferencias de notificación: $e');
    }
  }
}
