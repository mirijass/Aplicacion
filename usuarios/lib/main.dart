import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'controllers/usuario_controller.dart';
import 'controllers/producto_controller.dart';
import 'controllers/compra_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/db_helper.dart';
import 'utils/app_theme.dart';
import 'views/login_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicio de base de datos
  final dbHelper = DBHelper();
  await dbHelper.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthController _authController;
  late final UsuarioController _usuarioController;
  late final ProductoController _productoController;
  late final CompraController _compraController;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _usuarioController = UsuarioController();
    _productoController = ProductoController();
    _compraController = CompraController();
    _themeController = ThemeController();

    // Cargar datos iniciales
    _usuarioController.cargarRoles();
    _usuarioController.cargarUsuarios();
    _productoController.cargarProductos();
  }

  @override
  void dispose() {
    _authController.dispose();
    _usuarioController.dispose();
    _productoController.dispose();
    _compraController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Gestión de Usuarios, Productos y Seguridad',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: LoginView(
            authController: _authController,
            usuarioController: _usuarioController,
            productoController: _productoController,
            compraController: _compraController,
            themeController: _themeController,
          ),
        );
      },
    );
  }
}
