import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/producto_controller.dart';
import '../controllers/compra_controller.dart';
import '../models/usuario_model.dart';
import '../services/mail_helper.dart';
import '../utils/app_theme.dart';
import 'widgets/custom_text_field.dart';
import 'otp_view.dart';

/// Formulario para registrar un nuevo usuario (Vista MVC)
class RegistroView extends StatefulWidget {
  final UsuarioController usuarioController;
  final AuthController? authController;
  final ProductoController? productoController;
  final CompraController? compraController;

  const RegistroView({
    super.key,
    required this.usuarioController,
    this.authController,
    this.productoController,
    this.compraController,
  });

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _formKey = GlobalKey<FormState>();

  final _apPaternoController = TextEditingController();
  final _apMaternoController = TextEditingController();
  final _nombresController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _descController = TextEditingController();

  int _selectedRoleId = 3; // Por defecto: 3 (lector / solo de lectura)
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 1,
      'nombre': 'admin',
      'label': 'Administrador',
      'desc': 'Acceso total al sistema y gestión',
      'color': AppTheme.roleAdminText,
      'bgColor': AppTheme.roleAdminBg,
      'icon': Icons.admin_panel_settings_rounded,
    },
    {
      'id': 2,
      'nombre': 'editor',
      'label': 'Editor',
      'desc': 'Permisos para modificar contenidos',
      'color': AppTheme.roleEditorText,
      'bgColor': AppTheme.roleEditorBg,
      'icon': Icons.edit_note_rounded,
    },
    {
      'id': 3,
      'nombre': 'lector',
      'label': 'Solo de Lectura (Lector)',
      'desc': 'Permisos de consulta y solo lectura',
      'color': AppTheme.roleLectorText,
      'bgColor': AppTheme.roleLectorBg,
      'icon': Icons.visibility_rounded,
    },
  ];

  bool get _puedeCambiarRolLogeado =>
      widget.authController != null &&
      widget.authController!.currentUser != null &&
      widget.authController!.esAdmin;

  @override
  void dispose() {
    _apPaternoController.dispose();
    _apMaternoController.dispose();
    _nombresController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_isSubmitting || widget.usuarioController.isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_passController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      return;
    }

    setState(() => _isSubmitting = true);

    final nombreCompleto =
        '${_nombresController.text.trim()} ${_apPaternoController.text.trim()} ${_apMaternoController.text.trim()}'.trim();

    final nuevoUsuario = Usuario(
      nombre: nombreCompleto,
      correo: _emailController.text.trim(),
      pass: _passController.text,
      desc: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      roleId: _selectedRoleId,
      createdAt: DateTime.now().toIso8601String(),
    );

    final success = await widget.usuarioController.registrarUsuario(
      nuevoUsuario,
      usuarioLogeado: widget.authController?.currentUser,
    );

    if (!mounted) return;

    if (success) {
      final token = '${100000 + Random().nextInt(900000)}';
      try {
        await MailHelper.sendVerificationTokenEmail(nuevoUsuario.correo, token);
      } catch (e) {
        debugPrint('MailHelper token error: $e');
      }

      if (widget.authController != null) {
        await widget.authController!.login(nuevoUsuario.correo, nuevoUsuario.pass);
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${widget.usuarioController.successMessage ?? 'Usuario registrado con éxito'}. Se ha enviado el código de verificación.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );

        final authCtrl = widget.authController ?? AuthController();
        final prodCtrl = widget.productoController ?? ProductoController();
        final compCtrl = widget.compraController ?? CompraController();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpView(
              authController: authCtrl,
              usuarioController: widget.usuarioController,
              productoController: prodCtrl,
              compraController: compCtrl,
              correoDestino: nuevoUsuario.correo,
              otpGenerado: token,
            ),
          ),
        );
      }
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.usuarioController.errorMessage ?? 'Error al registrar',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Registrar Nuevo Usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: AnimatedBuilder(
            animation: widget.usuarioController,
            builder: (context, _) {
              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjeta Principal del Formulario
                    Container(
                      padding: const EdgeInsets.all(22.0),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryExtraLight,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x107E57C2),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información Personal',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Apellido Paterno
                          CustomTextField(
                            controller: _apPaternoController,
                            label: 'Apellido Paterno * (máx 36 car.)',
                            hint: 'ej. Pérez',
                            prefixIcon: Icons.badge_outlined,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa el apellido paterno';
                              }
                              final trimmed = val.trim();
                              if (trimmed.length > 36) {
                                return 'El apellido paterno no puede exceder los 36 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Apellido Materno
                          CustomTextField(
                            controller: _apMaternoController,
                            label: 'Apellido Materno * (máx 36 car.)',
                            hint: 'ej. González',
                            prefixIcon: Icons.badge_outlined,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa el apellido materno';
                              }
                              final trimmed = val.trim();
                              if (trimmed.length > 36) {
                                return 'El apellido materno no puede exceder los 36 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Nombres (min 3, max 36)
                          CustomTextField(
                            controller: _nombresController,
                            label: 'Nombres * (3 - 36 car.)',
                            hint: 'ej. Juan Carlos',
                            prefixIcon: Icons.person_outline_rounded,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa tus nombres';
                              }
                              final trimmed = val.trim();
                              if (trimmed.length < 3) {
                                return 'Los nombres deben tener al menos 3 caracteres';
                              }
                              if (trimmed.length > 36) {
                                return 'Los nombres no pueden exceder los 36 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Correo Electrónico
                          CustomTextField(
                            controller: _emailController,
                            label: 'Correo Electrónico * (máx 36 car.)',
                            hint: 'ej. juan@gmail.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Por favor ingresa el correo electrónico';
                              }
                              final trimmed = val.trim();
                              if (trimmed.length > 36) {
                                return 'El correo no puede exceder los 36 caracteres';
                              }
                              final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(trimmed)) {
                                return 'Ingresa un formato de correo válido (ej. usuario@dominio.com)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Contraseña
                          CustomTextField(
                            controller: _passController,
                            label:
                                'Contraseña * (min 8 car., Mayúscula, número y especial)',
                            hint: 'ej. Clave123!',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Por favor ingresa la contraseña';
                              }
                              if (val.length < 8) {
                                return 'La contraseña debe tener al menos 8 caracteres';
                              }
                              if (val.length > 36) {
                                return 'La contraseña no puede exceder los 36 caracteres';
                              }
                              final tieneMayuscula =
                                  val.contains(RegExp(r'[A-Z]'));
                              final tieneNumero =
                                  val.contains(RegExp(r'[0-9]'));
                              final tieneEspecial =
                                  val.contains(RegExp(r'[^a-zA-Z0-9]'));
                              if (!tieneMayuscula ||
                                  !tieneNumero ||
                                  !tieneEspecial) {
                                return 'La contraseña debe incluir al menos una letra mayúscula, un número y un carácter especial';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirmar Contraseña
                          CustomTextField(
                            controller: _confirmPassController,
                            label: 'Confirmar Contraseña *',
                            hint: 'Repite tu contraseña',
                            prefixIcon: Icons.lock_reset_rounded,
                            isPassword: true,
                            maxLength: 36,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Por favor confirma la contraseña';
                              }
                              if (val != _passController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Descripción o notas
                          CustomTextField(
                            controller: _descController,
                            label:
                                'Descripción / Notas (Opcional, máx 36 car.)',
                            hint: 'ej. Departamento de TI',
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 2,
                            maxLength: 36,
                            validator: (val) {
                              if (val != null && val.trim().length > 36) {
                                return 'La descripción no puede exceder los 36 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Rol Asignado
                          const Text(
                            'Rol Asignado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (!_puedeCambiarRolLogeado) ...[
                            // Tarjeta fija de Solo de Lectura (Lector) sin opciones adicionales
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.roleLectorBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.roleLectorText,
                                  width: 1.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.roleLectorText.withAlpha(80),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.visibility_rounded,
                                      color: AppTheme.roleLectorText,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Solo de Lectura (Lector)',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.roleLectorText,
                                          ),
                                        ),
                                        Text(
                                          'Permisos de consulta y solo lectura asignados automáticamente',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.roleLectorText,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Selecciona los permisos que tendrá el usuario:',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Opciones de Roles en Tarjetas Seleccionables
                            Column(
                              children: _roles.map((r) {
                                final isSelected = _selectedRoleId == r['id'];
                                final roleColor = r['color'] as Color;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedRoleId = r['id'] as int;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (r['bgColor'] as Color)
                                          : AppTheme.inputFill,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? roleColor
                                            : Colors.transparent,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: roleColor.withAlpha(80),
                                            ),
                                          ),
                                          child: Icon(
                                            r['icon'] as IconData,
                                            color: roleColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? roleColor
                                                      : AppTheme.textMain,
                                                ),
                                              ),
                                              Text(
                                                r['desc'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? roleColor
                                                      : AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? roleColor
                                                  : AppTheme.textLight,
                                              width: 2,
                                            ),
                                            color: isSelected
                                                ? roleColor
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón de Envío
                    ElevatedButton(
                      onPressed: (_isSubmitting || widget.usuarioController.isLoading)
                          ? null
                          : _submitForm,
                      child: (_isSubmitting || widget.usuarioController.isLoading)
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Enviando código...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Registrar Usuario'),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
