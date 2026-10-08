import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import 'widgets/role_badge.dart';
import 'productos_view.dart';
import 'historial_compras_view.dart';
import 'configuracion_view.dart';
import 'cambiar_contrasena_dialog.dart';
import 'carrito_dialog.dart';
import 'login_view.dart';

/// Pantalla de Inicio / Dashboard exclusiva para usuarios con perfil "Lector"
/// Reemplaza la vista de gestión de usuarios con un panel de bienvenida personalizado y adaptativo.
class LectorHomeView extends StatelessWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController productoController;
  final CompraController? compraController;
  final ThemeController? themeController;

  const LectorHomeView({
    super.key,
    required this.authController,
    required this.usuarioController,
    required this.productoController,
    this.compraController,
    this.themeController,
  });

  void _cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Deseas salir de la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              productoController.resetCart();
              authController.logout();
              Navigator.pushReplacement(
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
              );
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _abrirProductos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductosView(
          authController: authController,
          productoController: productoController,
          compraController: compraController,
          themeController: themeController,
        ),
      ),
    );
  }

  void _abrirHistorialCompras(BuildContext context) {
    final compCtrl = compraController ?? CompraController();
    final curUser = authController.currentUser;
    compCtrl.cargarCompras(usuarioLogeado: curUser);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistorialComprasView(
          compraController: compCtrl,
          authController: authController,
        ),
      ),
    );
  }

  void _abrirConfiguracion(BuildContext context) {
    final thCtrl = themeController ?? ThemeController();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfiguracionView(
          themeController: thCtrl,
          authController: authController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thCtrl = themeController;
    if (thCtrl != null) {
      return AnimatedBuilder(
        animation: thCtrl,
        builder: (context, _) => _buildBody(context),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final user = authController.currentUser;
    productoController.setActiveUser(user);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.getScaffoldBg(context),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.storefront_rounded,
              color: isDark ? AppTheme.primaryLight : AppTheme.primaryPurple,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Tiendita App',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextMain(context),
              ),
            ),
          ],
        ),
        actions: [
          // Botón Carrito con Badge
          ListenableBuilder(
            listenable: productoController,
            builder: (context, _) {
              final count = productoController.cantidadItemsCarrito;
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: AppTheme.errorColor,
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Ver Carrito',
                  onPressed: () => CarritoDialog.show(
                    context,
                    productoController,
                    authController: authController,
                  ),
                ),
              );
            },
          ),
          // Botón de Ajustes
          IconButton(
            icon: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
            ),
            tooltip: 'Configuración de Tema',
            onPressed: () => _abrirConfiguracion(context),
          ),
          // Botón de Salir
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Card de Bienvenida Personalizado Adaptativo (Modo Claro / Oscuro)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF311B92), Color(0xFF1A237E)]
                        : const [AppTheme.primaryPurple, AppTheme.deepPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.primaryLight.withAlpha(80) : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x60311B92) : const Color(0x307E57C2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: isDark
                              ? AppTheme.pastelLavender.withAlpha(200)
                              : Colors.white.withAlpha(220),
                          child: Text(
                            user?.iniciales ?? 'L',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.deepPurple : AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Bienvenido(a), ${user?.nombre ?? 'Usuario'}! 👋',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.correo ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(200),
                                ),
                              ),
                            ],
                          ),
                        ),
                        RoleBadge(
                          rol: user?.rolNombre ?? 'lector',
                          roleId: user?.roleId ?? 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(isDark ? 20 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tu panel de usuario incluye consulta del catálogo de productos y seguimiento de tus compras.',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Servicios Disponibles',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextMain(context),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Tarjetas de Acceso Rápido con Soporte para Modo Oscuro
              _buildMenuCard(
                context: context,
                icon: Icons.shopping_bag_rounded,
                iconColor: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
                bgColor: isDark ? const Color(0xFF2D2140) : AppTheme.primaryExtraLight,
                title: 'Catálogo de Productos',
                subtitle: 'Explora nuestros productos disponibles, agrega al carrito y realiza compras en línea.',
                buttonText: 'Ver Productos',
                onTap: () => _abrirProductos(context),
              ),

              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.local_shipping_rounded,
                iconColor: isDark ? const Color(0xFF81D4FA) : const Color(0xFF0288D1),
                bgColor: isDark ? const Color(0xFF102A43) : const Color(0xFFE1F5FE),
                title: 'Mis Compras y Envíos',
                subtitle: 'Consulta el historial de tus pedidos realizados y sigue la ruta de entrega en el mapa en vivo.',
                buttonText: 'Ver Mis Envíos',
                onTap: () => _abrirHistorialCompras(context),
              ),

              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.lock_reset_rounded,
                iconColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                bgColor: isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0),
                title: 'Cambiar mi Contraseña',
                subtitle: 'Actualiza tu contraseña de acceso personal de forma rápida y segura desde tu perfil.',
                buttonText: 'Cambiar Clave',
                onTap: () => CambiarContrasenaDialog.show(context, authController),
              ),

              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.palette_rounded,
                iconColor: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF388E3C),
                bgColor: isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
                title: 'Ajustes y Personalización',
                subtitle: 'Cambia entre modo claro y modo oscuro, notificaciones y opciones de seguridad.',
                buttonText: 'Configuración de Tema',
                onTap: () => _abrirConfiguracion(context),
              ),

              const SizedBox(height: 28),

              // Banner promocional adaptativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceCard(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.primaryLight.withAlpha(40) : AppTheme.primaryLight.withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚡ Alertas en Tiempo Real',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.getTextMain(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Descuentos exclusivos in-app y envíos gratis activados.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFA098B0) : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 2,
      color: AppTheme.getSurfaceCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF2C2838) : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextMain(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA098B0) : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: iconColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
