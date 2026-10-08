import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/usuario_controller.dart';
import '../../controllers/producto_controller.dart';
import '../../controllers/compra_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_theme.dart';
import 'role_badge.dart';
import '../productos_view.dart';
import '../usuarios_list_view.dart';
import '../historial_compras_view.dart';
import '../configuracion_view.dart';
import '../cambiar_contrasena_dialog.dart';
import '../login_view.dart';

/// Menú lateral desplegable (Drawer) para navegación principal en la aplicación
class AppDrawer extends StatelessWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController productoController;
  final CompraController? compraController;
  final ThemeController? themeController;
  final String currentRoute; // 'productos', 'usuarios', 'compras', etc.

  const AppDrawer({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.productoController,
    this.compraController,
    this.themeController,
    this.currentRoute = 'productos',
  });

  void _cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text('¿Deseas salir de la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(ctx);
              productoController.resetCart();
              authController.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginView(
                    authController: authController,
                    usuarioController: usuarioController,
                    productoController: productoController,
                    compraController: compraController,
                    themeController: themeController,
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final curUser = authController.currentUser;
    final textMain = AppTheme.getTextMain(context);
    final mutedColor = isDark ? const Color(0xFFA098B0) : AppTheme.textMuted;

    return Drawer(
      backgroundColor: AppTheme.getScaffoldBg(context),
      child: Column(
        children: [
          // Header decorativo con información del perfil
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF282533), const Color(0xFF1E1C27)]
                    : [AppTheme.primaryPurple, const Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: isDark ? AppTheme.pastelMauve : Colors.white,
              child: Text(
                curUser?.iniciales ?? 'U',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF1E1C27) : AppTheme.primaryPurple,
                ),
              ),
            ),
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    curUser?.nombre ?? 'Usuario',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (curUser?.roleId != null)
                  RoleBadge(roleId: curUser!.roleId),
              ],
            ),
            accountEmail: Text(
              curUser?.correo ?? '',
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Opciones del Menú Desplegable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                // 1. Catálogo de Productos
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: currentRoute == 'productos'
                        ? (isDark ? const Color(0xFF38314A) : AppTheme.primaryExtraLight)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.storefront_rounded,
                      color: currentRoute == 'productos'
                          ? AppTheme.primaryPurple
                          : mutedColor,
                    ),
                    title: Text(
                      'Catálogo de Productos',
                      style: TextStyle(
                        fontWeight: currentRoute == 'productos' ? FontWeight.bold : FontWeight.w500,
                        color: currentRoute == 'productos' ? AppTheme.primaryPurple : textMain,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Cerrar menú desplegable
                      if (currentRoute != 'productos') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductosView(
                              authController: authController,
                              usuarioController: usuarioController,
                              productoController: productoController,
                              compraController: compraController,
                              themeController: themeController,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // 2. Gestión de Usuarios
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: currentRoute == 'usuarios'
                        ? (isDark ? const Color(0xFF38314A) : AppTheme.primaryExtraLight)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.people_alt_rounded,
                      color: currentRoute == 'usuarios'
                          ? AppTheme.primaryPurple
                          : mutedColor,
                    ),
                    title: Text(
                      'Gestión de Usuarios',
                      style: TextStyle(
                        fontWeight: currentRoute == 'usuarios' ? FontWeight.bold : FontWeight.w500,
                        color: currentRoute == 'usuarios' ? AppTheme.primaryPurple : textMain,
                      ),
                    ),
                    subtitle: authController.esLector
                        ? const Text('Panel Lector', style: TextStyle(fontSize: 11))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'usuarios') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UsuariosListView(
                              authController: authController,
                              usuarioController: usuarioController,
                              productoController: productoController,
                              compraController: compraController,
                              themeController: themeController,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // 3. Historial de Compras
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: currentRoute == 'compras'
                        ? (isDark ? const Color(0xFF38314A) : AppTheme.primaryExtraLight)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.receipt_long_rounded,
                      color: currentRoute == 'compras'
                          ? AppTheme.primaryPurple
                          : mutedColor,
                    ),
                    title: Text(
                      'Historial de Compras',
                      style: TextStyle(
                        fontWeight: currentRoute == 'compras' ? FontWeight.bold : FontWeight.w500,
                        color: currentRoute == 'compras' ? AppTheme.primaryPurple : textMain,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final compCtrl = compraController ?? CompraController();
                      compCtrl.cargarCompras(usuarioLogeado: curUser);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistorialComprasView(
                            authController: authController,
                            compraController: compCtrl,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 20),

                // 4. Cambiar mi Contraseña
                ListTile(
                  leading: Icon(Icons.lock_reset_rounded, color: mutedColor),
                  title: Text('Cambiar Contraseña', style: TextStyle(color: textMain, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    CambiarContrasenaDialog.show(context, authController);
                  },
                ),

                // 5. Conmutador directo de Tema Oscuro / Claro (Blanco y Negro)
                if (themeController != null)
                  AnimatedBuilder(
                    animation: themeController!,
                    builder: (context, _) {
                      final isDarkMode = themeController!.isDarkMode;
                      return SwitchListTile(
                        dense: true,
                        secondary: Icon(
                          isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: isDarkMode ? Colors.amber : AppTheme.primaryPurple,
                        ),
                        title: Text(
                          isDarkMode ? 'Modo Oscuro' : 'Modo Claro',
                          style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          isDarkMode ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
                          style: TextStyle(color: mutedColor, fontSize: 11),
                        ),
                        value: isDarkMode,
                        activeColor: AppTheme.primaryPurple,
                        onChanged: (val) {
                          themeController!.toggleTheme(val);
                        },
                      );
                    },
                  ),

                // 6. Configuración y Apariencia
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: mutedColor),
                  title: Text('Configuración y Tema', style: TextStyle(color: textMain, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    final themeCtrl = themeController ?? ThemeController();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfiguracionView(
                          themeController: themeCtrl,
                          authController: authController,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Botón Cerrar Sesión
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _cerrarSesion(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
