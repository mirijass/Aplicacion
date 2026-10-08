import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import 'widgets/custom_text_field.dart';

/// Diálogo modal para cambiar la contraseña del usuario actualmente autenticado
class CambiarContrasenaDialog extends StatefulWidget {
  final AuthController authController;

  const CambiarContrasenaDialog({
    super.key,
    required this.authController,
  });

  static Future<void> show(BuildContext context, AuthController authController) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CambiarContrasenaDialog(authController: authController),
    );
  }

  @override
  State<CambiarContrasenaDialog> createState() => _CambiarContrasenaDialogState();
}

class _CambiarContrasenaDialogState extends State<CambiarContrasenaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passActualCtrl = TextEditingController();
  final _passNuevaCtrl = TextEditingController();
  final _passConfirmarCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passActualCtrl.dispose();
    _passNuevaCtrl.dispose();
    _passConfirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final ok = await widget.authController.cambiarContrasena(
      passActual: _passActualCtrl.text,
      passNueva: _passNuevaCtrl.text,
      passConfirmar: _passConfirmarCtrl.text,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Contraseña actualizada con éxito!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      final error = widget.authController.errorMessage ?? 'Error al cambiar la contraseña';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = AppTheme.getTextMain(context);

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
            // Handle bar arriba
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

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2140) : AppTheme.primaryExtraLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambiar Contraseña',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Actualiza tu clave de acceso de forma segura',
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

            // Formulario
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _passActualCtrl,
                    label: 'Contraseña Actual *',
                    hint: 'Ingresa tu contraseña actual',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Ingresa tu contraseña actual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _passNuevaCtrl,
                    label: 'Nueva Contraseña *',
                    hint: 'Mínimo 8 car., Mayúscula, número y especial',
                    prefixIcon: Icons.key_rounded,
                    isPassword: true,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Ingresa la nueva contraseña';
                      }
                      if (v.length < 8) {
                        return 'Debe tener al menos 8 caracteres';
                      }
                      if (v.length > 36) {
                        return 'No puede exceder los 36 caracteres';
                      }
                      final tieneMayuscula = v.contains(RegExp(r'[A-Z]'));
                      final tieneNumero = v.contains(RegExp(r'[0-9]'));
                      final tieneEspecial = v.contains(RegExp(r'[^a-zA-Z0-9]'));
                      if (!tieneMayuscula || !tieneNumero || !tieneEspecial) {
                        return 'Debe incluir al menos una mayúscula, un número y un carácter especial';
                      }
                      if (v == _passActualCtrl.text) {
                        return 'Debe ser diferente a la contraseña actual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _passConfirmarCtrl,
                    label: 'Confirmar Nueva Contraseña *',
                    hint: 'Repite la nueva contraseña',
                    prefixIcon: Icons.check_circle_outline_rounded,
                    isPassword: true,
                    maxLength: 36,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirma la nueva contraseña';
                      }
                      if (v != _passNuevaCtrl.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Botones de acción
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
                              : const Text(
                                  'Guardar Clave',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
