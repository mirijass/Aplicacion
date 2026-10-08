import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import 'cambiar_contrasena_dialog.dart';

/// Pantalla de Ajustes, Personalización de Tema y Seguridad
class ConfiguracionView extends StatefulWidget {
  final ThemeController themeController;
  final AuthController authController;

  const ConfiguracionView({
    super.key,
    required this.themeController,
    required this.authController,
  });

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  bool _pinActivo = false;
  bool _biometriaActiva = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) {
        final isDark = widget.themeController.isDarkMode;
        final notifEnabled = widget.themeController.notificacionesHabilitadas;

        return Scaffold(
          backgroundColor: AppTheme.getScaffoldBg(context),
          appBar: AppBar(
            title: const Text('Ajustes y Personalización'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Apariencia y Tema
                const Text('Apariencia y Tema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: const Text('Modo Oscuro (Dark Theme)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Cambiar la apariencia visual de la aplicación'),
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.primaryPurple),
                    value: isDark,
                    onChanged: (val) => widget.themeController.toggleTheme(val),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Notificaciones y Alertas
                const Text('Notificaciones y Alertas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: const Text('Notificaciones en Tiempo Real', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Recibir alertas de pedidos, promociones y seguridad'),
                    secondary: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryPurple),
                    value: notifEnabled,
                    onChanged: (val) => widget.themeController.toggleNotificaciones(val),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Seguridad Avanzada y Biometría
                const Text('Seguridad de la Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Autenticación Biométrica (Huella / Face ID)', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Permite desbloqueo rápido con sensor del teléfono'),
                        secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryPurple),
                        value: _biometriaActiva,
                        onChanged: (val) => setState(() => _biometriaActiva = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Protección por PIN de Seguridad (4 dígitos)', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Solicitar PIN al realizar compras in-app'),
                        secondary: const Icon(Icons.pin_rounded, color: AppTheme.primaryPurple),
                        value: _pinActivo,
                        onChanged: (val) => setState(() => _pinActivo = val),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.password_rounded, color: AppTheme.primaryPurple),
                        title: const Text('Cambiar mi Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Actualiza la clave de acceso de tu cuenta activa'),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryPurple),
                        onTap: () => CambiarContrasenaDialog.show(context, widget.authController),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
