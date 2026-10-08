import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/usuario_model.dart';
import '../services/db_helper.dart';
import '../services/mail_helper.dart';
import '../utils/app_theme.dart';
import 'widgets/custom_text_field.dart';
import 'registro_view.dart';
import 'usuarios_list_view.dart';
import 'lector_home_view.dart';
import 'otp_view.dart';
import 'productos_view.dart';
import 'recuperar_usuario_dialog.dart';

/// Vista de Inicio de Sesión (Login con 2FA, Social Login y Recuperación)
class LoginView extends StatefulWidget {
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController? productoController;
  final CompraController? compraController;
  final ThemeController? themeController;

  const LoginView({
    super.key,
    required this.authController,
    required this.usuarioController,
    this.productoController,
    this.compraController,
    this.themeController,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _identificadorController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void dispose() {
    _identificadorController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _mostrarDialogoRecuperacion() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryPurple),
            SizedBox(width: 8),
            Text('Recuperar Contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu correo electrónico registrado. Te enviaremos una nueva contraseña temporal por correo.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: emailCtrl,
              label: 'Correo Electrónico',
              hint: 'ej. juan@gmail.com',
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dialogContext);

              final ok = await widget.authController.recuperarContrasena(email);
              if (!mounted) return;

              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Se ha enviado la nueva contraseña a tu correo electrónico.'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.authController.errorMessage ?? 'Error al recuperar contraseña',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Enviar Correo'),
          ),
        ],
      ),
    );
  }

  void _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.authController.login(
      _identificadorController.text,
      _passController.text,
    );

    if (!mounted) return;

    if (ok) {
      widget.usuarioController.cargarUsuarios();
      final prodCtrl = widget.productoController ?? ProductoController();
      prodCtrl.setActiveUser(widget.authController.currentUser);
      final compCtrl = widget.compraController ?? CompraController();

      // Generar código de verificación OTP (2FA) para validar al entrar
      final random = Random();
      final otpToken = '${100000 + random.nextInt(900000)}';
      final correoUser = widget.authController.currentUser?.correo ??
          _identificadorController.text.trim();

      // Si es el usuario Admin predeterminado (juan@gmail.com), ingresar directamente sin OTP
      final esAdminPredeterminado = (correoUser == 'juan@gmail.com' || _identificadorController.text.trim().toLowerCase() == 'juan@gmail.com' || _identificadorController.text.trim() == 'Juan Pérez');
      if (esAdminPredeterminado) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductosView(
              authController: widget.authController,
              usuarioController: widget.usuarioController,
              productoController: prodCtrl,
              compraController: compCtrl,
              themeController: widget.themeController,
            ),
          ),
        );
        return;
      }

      try {
        await MailHelper.sendVerificationTokenEmail(correoUser, otpToken);
      } catch (e) {
        debugPrint('Aviso de envío de verificación en login: $e');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpView(
            authController: widget.authController,
            usuarioController: widget.usuarioController,
            productoController: prodCtrl,
            compraController: compCtrl,
            themeController: widget.themeController,
            correoDestino: correoUser,
            otpGenerado: otpToken,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.authController.errorMessage ?? 'Credenciales incorrectas',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _socialLogin(String proveedor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SocialRegistroModal(
        proveedor: proveedor,
        authController: widget.authController,
        usuarioController: widget.usuarioController,
        productoController: widget.productoController,
        compraController: widget.compraController,
        themeController: widget.themeController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = AppTheme.getTextMain(context);
    final linkColor = isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple;
    final mutedColor = isDark ? const Color(0xFFA098B0) : AppTheme.textMuted;
    final dividerColor = isDark ? const Color(0xFF383347) : AppTheme.primaryExtraLight;

    return Scaffold(
      backgroundColor: AppTheme.getScaffoldBg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: AnimatedBuilder(
              animation: widget.authController,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header decorativo con icono pastel
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282533) : AppTheme.primaryExtraLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.pastelMauve : AppTheme.primaryLight,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? const Color(0x407E57C2) : const Color(0x267E57C2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 46,
                          color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Título y Subtítulo
                    Text(
                      'Gestión de Usuarios',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inicia sesión con tu cuenta de seguridad',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tarjeta contenedora del formulario
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceCard(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: dividerColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? const Color(0x30000000) : const Color(0x107E57C2),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomTextField(
                              controller: _identificadorController,
                              label: 'Correo o Nombre de Usuario',
                              hint: 'ej. juan@gmail.com o Juan Pérez',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Por favor ingresa tu correo o nombre';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            CustomTextField(
                              controller: _passController,
                              label: 'Contraseña',
                              hint: 'Ingresa tu contraseña',
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Por favor ingresa tu contraseña';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            
                            // Opciones de Recuperación (Usuario / Contraseña)
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => RecuperarUsuarioDialog.show(context),
                                  child: Text(
                                    '¿Olvidaste tu usuario?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: linkColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _mostrarDialogoRecuperacion,
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: linkColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Botón de Iniciar Sesión
                            ElevatedButton(
                              onPressed: widget.authController.isLoading
                                  ? null
                                  : _submitLogin,
                              child: widget.authController.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text('Iniciar Sesión'),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // División de Social Login
                            Row(
                              children: [
                                Expanded(child: Divider(color: dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('O inicia sesión con', style: TextStyle(fontSize: 12, color: mutedColor)),
                                ),
                                Expanded(child: Divider(color: dividerColor)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Botones de Redes Sociales (Google, Facebook)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: dividerColor, width: 1.5),
                                    ),
                                    icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 24),
                                    label: Text('Google', style: TextStyle(fontSize: 12, color: textMain)),
                                    onPressed: () => _socialLogin('Google'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: dividerColor, width: 1.5),
                                    ),
                                    icon: const Icon(Icons.facebook_rounded, color: Colors.blue, size: 20),
                                    label: Text('Facebook', style: TextStyle(fontSize: 12, color: textMain)),
                                    onPressed: () => _socialLogin('Facebook'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Enlace para crear nuevo usuario
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegistroView(
                              usuarioController: widget.usuarioController,
                              authController: widget.authController,
                              productoController: widget.productoController,
                              compraController: widget.compraController,
                            ),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: '¿No tienes una cuenta? ',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'Regístrate aquí',
                              style: TextStyle(
                                color: linkColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo modal para registrarse / iniciar sesión con proveedor de red social (Google, Facebook)
class _SocialRegistroModal extends StatefulWidget {
  final String proveedor;
  final AuthController authController;
  final UsuarioController usuarioController;
  final ProductoController? productoController;
  final CompraController? compraController;
  final ThemeController? themeController;

  const _SocialRegistroModal({
    required this.proveedor,
    required this.authController,
    required this.usuarioController,
    this.productoController,
    this.compraController,
    this.themeController,
  });

  @override
  State<_SocialRegistroModal> createState() => _SocialRegistroModalState();
}

class _SocialRegistroModalState extends State<_SocialRegistroModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final nombre = _nombreCtrl.text.trim();
    final isGoogle = widget.proveedor.toLowerCase() == 'google';

    if (isGoogle && !email.toLowerCase().endsWith('@gmail.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para registrarte con Google debes utilizar una cuenta válida de Gmail (@gmail.com)'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 1. Verificar si la cuenta ya existe en la base de datos
    final existe = await DBHelper().emailExists(email);
    if (existe) {
      // Intentar iniciar sesión si ya está registrada
      final loginOk = await widget.authController.login(email, pass);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      if (loginOk) {
        Navigator.pop(context);
        widget.usuarioController.cargarUsuarios();
        final prodCtrl = widget.productoController ?? ProductoController();
        final curUser = widget.authController.currentUser;

        if (curUser != null && curUser.esLector) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LectorHomeView(
                authController: widget.authController,
                usuarioController: widget.usuarioController,
                productoController: prodCtrl,
                compraController: widget.compraController,
                themeController: widget.themeController,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UsuariosListView(
                authController: widget.authController,
                usuarioController: widget.usuarioController,
                productoController: prodCtrl,
                compraController: widget.compraController,
                themeController: widget.themeController,
              ),
            ),
          );
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El correo ya pertenece a un usuario registrado. Verifica tu contraseña.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    // 2. Si es una cuenta nueva con Google, generar token OTP y enviarlo por correo
    // Esto comprueba activamente que el correo de Gmail EXISTE y que el usuario puede recibir el código de 6 dígitos
    final random = Random();
    final otpToken = '${100000 + random.nextInt(900000)}';

    try {
      await MailHelper.sendVerificationTokenEmail(email, otpToken);
    } catch (e) {
      debugPrint('Aviso de envío de verificación: $e');
    }

    // Registrar nuevo usuario con perfil Lector
    final nuevoUsuario = Usuario(
      nombre: nombre,
      correo: email,
      pass: pass,
      roleId: 3, // Perfil Lector
      rolNombre: 'lector',
      desc: 'Registrado con ${widget.proveedor}',
      createdAt: DateTime.now().toIso8601String(),
    );

    final regOk = await widget.usuarioController.registrarUsuario(nuevoUsuario);
    if (!regOk) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.usuarioController.errorMessage ?? 'No se pudo completar el registro.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Autenticar en segundo plano
    await widget.authController.login(email, pass);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    Navigator.pop(context); // Cerrar modal

    // Redirigir a OtpView para requerir el código enviado al correo real de Gmail
    final prodCtrl = widget.productoController ?? ProductoController();
    final compCtrl = widget.compraController ?? CompraController();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OtpView(
          authController: widget.authController,
          usuarioController: widget.usuarioController,
          productoController: prodCtrl,
          compraController: compCtrl,
          themeController: widget.themeController,
          correoDestino: email,
          otpGenerado: otpToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = AppTheme.getTextMain(context);
    final isGoogle = widget.proveedor.toLowerCase() == 'google';
    final socialColor = isGoogle ? Colors.red : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceCard(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.primaryLight.withAlpha(40) : Colors.transparent,
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.primaryLight.withAlpha(80) : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado Social
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: socialColor.withAlpha(30),
                  child: Icon(
                    isGoogle ? Icons.g_mobiledata_rounded : Icons.facebook_rounded,
                    color: socialColor,
                    size: isGoogle ? 30 : 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registro con ${widget.proveedor}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGoogle
                            ? 'Ingresa tu correo de Gmail para crear tu cuenta'
                            : 'Ingresa tus datos para registrarte con ${widget.proveedor}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFA098B0) : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppTheme.primaryLight : AppTheme.textMuted,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Tarjeta informativa del rol asignado (Lector)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2140) : AppTheme.primaryExtraLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.pastelMauve.withAlpha(60) : AppTheme.primaryLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_rounded,
                    color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se creará tu cuenta con el perfil Lector (acceso a compras y catálogo).',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Formulario de datos
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _nombreCtrl,
                    label: 'Nombre Completo *',
                    hint: 'Tu nombre completo',
                    prefixIcon: Icons.person_outline_rounded,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                      if (v.trim().length < 3) return 'Debe tener al menos 3 caracteres';
                      if (v.trim().length > 36) return 'No puede exceder los 36 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _emailCtrl,
                    label: isGoogle ? 'Correo de Gmail (@gmail.com) *' : 'Correo Electrónico *',
                    hint: isGoogle ? 'usuario@gmail.com' : 'correo@ejemplo.com',
                    prefixIcon: Icons.email_outlined,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                      final emailTrim = v.trim().toLowerCase();
                      if (emailTrim.length > 36) return 'No puede exceder los 36 caracteres';
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(emailTrim)) return 'Formato de correo inválido';
                      if (isGoogle && !emailTrim.endsWith('@gmail.com')) {
                        return 'Para Google la cuenta debe ser Gmail (@gmail.com)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _passCtrl,
                    label: 'Contraseña para la app *',
                    hint: 'Mínimo 8 car., Mayúscula, número y especial',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                      if (v.length < 8) return 'Debe tener al menos 8 caracteres';
                      if (v.length > 36) return 'No puede exceder los 36 caracteres';
                      final tieneMayuscula = v.contains(RegExp(r'[A-Z]'));
                      final tieneNumero = v.contains(RegExp(r'[0-9]'));
                      final tieneEspecial = v.contains(RegExp(r'[^a-zA-Z0-9]'));
                      if (!tieneMayuscula || !tieneNumero || !tieneEspecial) {
                        return 'Debe incluir al menos una mayúscula, un número y un carácter especial';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: socialColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Registrarme con ${widget.proveedor}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
