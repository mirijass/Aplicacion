import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import 'widgets/role_badge.dart';
import 'widgets/custom_text_field.dart';
import 'cambiar_contrasena_dialog.dart';

/// Diálogo modal para ver detalles completos y editar un usuario
class UsuarioDetalleDialog extends StatefulWidget {
  final Usuario usuario;
  final UsuarioController usuarioController;
  final AuthController? authController;

  const UsuarioDetalleDialog({
    super.key,
    required this.usuario,
    required this.usuarioController,
    this.authController,
  });

  static Future<void> show(
    BuildContext context,
    Usuario usuario,
    UsuarioController controller, {
    AuthController? authController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UsuarioDetalleDialog(
        usuario: usuario,
        usuarioController: controller,
        authController: authController,
      ),
    );
  }

  @override
  State<UsuarioDetalleDialog> createState() => _UsuarioDetalleDialogState();
}

class _UsuarioDetalleDialogState extends State<UsuarioDetalleDialog> {
  bool _isEditing = false;
  late TextEditingController _nombreCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _descCtrl;
  late int _selectedRoleId;
  bool _showPassword = false;

  final _editFormKey = GlobalKey<FormState>();

  bool get _esLectorLogeado => widget.authController?.esLector ?? false;
  bool get _puedeEliminarLogeado => widget.authController?.puedeEliminar ?? true;
  bool get _puedeCambiarRolLogeado =>
      widget.authController == null ||
      widget.authController!.currentUser == null ||
      widget.authController!.esAdmin;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.usuario.nombre);
    _correoCtrl = TextEditingController(text: widget.usuario.correo);
    _passCtrl = TextEditingController(text: widget.usuario.pass);
    _descCtrl = TextEditingController(text: widget.usuario.desc ?? '');
    _selectedRoleId = widget.usuario.roleId;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _guardarCambios() async {
    if (!_editFormKey.currentState!.validate()) return;

    final usuarioActualizado = widget.usuario.copyWith(
      nombre: _nombreCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      pass: _passCtrl.text,
      desc: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      roleId: _selectedRoleId,
    );

    final ok = await widget.usuarioController.actualizarUsuario(
      usuarioActualizado,
      usuarioLogeado: widget.authController?.currentUser,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario actualizado correctamente'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.usuarioController.errorMessage ?? 'Error al actualizar',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _confirmarEliminacion() {
    if (!_puedeEliminarLogeado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo los Administradores tienen permiso para eliminar usuarios'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Eliminar Usuario', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "${widget.usuario.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx); // Cerrar diálogo alerta
              if (widget.usuario.id != null) {
                final ok = await widget.usuarioController.eliminarUsuario(
                  widget.usuario.id!,
                  usuarioLogeado: widget.authController?.currentUser,
                );
                if (mounted && ok) {
                  Navigator.pop(context); // Cerrar modal principal
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuario eliminado'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado con Avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    widget.usuario.iniciales,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.usuario.nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RoleBadge(
                        rol: widget.usuario.rolNombre,
                        roleId: widget.usuario.roleId,
                      ),
                    ],
                  ),
                ),
                if (!_esLectorLogeado)
                  IconButton(
                    icon: Icon(
                      _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                      color: AppTheme.primaryPurple,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                  ),
              ],
            ),
            const Divider(height: 28, color: AppTheme.primaryExtraLight),

            if (_esLectorLogeado)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.roleLectorBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.roleLectorText.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.roleLectorText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Perfil Lector: Tienes acceso en modo solo lectura.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.roleLectorText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenido en modo lectura o modo edición
            if (!_isEditing) ...[
              _infoTile(
                icon: Icons.tag_rounded,
                label: 'ID de Usuario',
                value: '${widget.usuario.id ?? "N/A"}',
              ),
              _infoTile(
                icon: Icons.email_outlined,
                label: 'Correo Electrónico',
                value: widget.usuario.correo,
              ),
              _infoTile(
                icon: Icons.lock_outline_rounded,
                label: 'Contraseña Registrada',
                value: _showPassword ? widget.usuario.pass : '••••••••',
                trailing: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
              if (widget.usuario.desc != null && widget.usuario.desc!.isNotEmpty)
                _infoTile(
                  icon: Icons.notes_rounded,
                  label: 'Descripción / Notas',
                  value: widget.usuario.desc!,
                ),
              if (widget.usuario.createdAt != null)
                _infoTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Fecha de Registro',
                  value: widget.usuario.createdAt!.substring(0, 10),
                ),
              const SizedBox(height: 20),

              // Botón para cambiar mi contraseña si soy el usuario actual
              if (widget.authController != null &&
                  widget.authController!.currentUser?.id == widget.usuario.id) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_reset_rounded, size: 18, color: AppTheme.primaryPurple),
                  label: const Text('Cambiar mi Contraseña', style: TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    CambiarContrasenaDialog.show(context, widget.authController!);
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Botones de acción (visibles si no es Lector)
              if (!_esLectorLogeado)
                Row(
                  children: [
                    if (_puedeEliminarLogeado) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppTheme.errorColor),
                          label: const Text(
                            'Eliminar',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorColor),
                          ),
                          onPressed: _confirmarEliminacion,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Editar'),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
            ] else ...[
              // Formulario de edición
              Form(
                key: _editFormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nombreCtrl,
                      label: 'Nombre Completo * (3 - 36 car.)',
                      prefixIcon: Icons.person_outline_rounded,
                      maxLength: 36,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa un nombre';
                        final t = v.trim();
                        if (t.length < 3) return 'Debe tener al menos 3 caracteres';
                        if (t.length > 36) return 'No puede exceder los 36 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _correoCtrl,
                      label: 'Correo Electrónico * (máx 36 car.)',
                      prefixIcon: Icons.email_outlined,
                      maxLength: 36,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa un correo';
                        final t = v.trim();
                        if (t.length > 36) return 'No puede exceder los 36 caracteres';
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(t)) return 'Formato de correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _passCtrl,
                      label: 'Contraseña * (min 8 car., Mayúscula, número y especial)',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      maxLength: 36,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa la contraseña';
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
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _descCtrl,
                      label: 'Descripción / Notas (máx 36 car.)',
                      prefixIcon: Icons.notes_rounded,
                      maxLines: 2,
                      maxLength: 36,
                      validator: (v) {
                        if (v != null && v.trim().length > 36) {
                          return 'No puede exceder los 36 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Selector de Rol
                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoleId,
                      decoration: InputDecoration(
                        labelText: 'Rol Asignado',
                        helperText: !_puedeCambiarRolLogeado
                            ? '🔒 Solo los Administradores pueden cambiar roles'
                            : null,
                        helperStyle: const TextStyle(color: AppTheme.errorColor),
                        prefixIcon: const Icon(Icons.security_rounded,
                            color: AppTheme.primaryPurple),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Admin (Administrador)')),
                        DropdownMenuItem(value: 2, child: Text('Editor (Edición)')),
                        DropdownMenuItem(value: 3, child: Text('Lector (Solo Consulta)')),
                      ],
                      onChanged: _puedeCambiarRolLogeado
                          ? (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRoleId = val;
                                });
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                            },
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardarCambios,
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryExtraLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
