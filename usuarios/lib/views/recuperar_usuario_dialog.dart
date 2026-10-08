import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/mail_helper.dart';
import '../utils/app_theme.dart';
import 'widgets/custom_text_field.dart';

/// Modal para la Recuperación del Nombre de Usuario mediante Correo Electrónico
class RecuperarUsuarioDialog extends StatefulWidget {
  const RecuperarUsuarioDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const RecuperarUsuarioDialog(),
    );
  }

  @override
  State<RecuperarUsuarioDialog> createState() => _RecuperarUsuarioDialogState();
}

class _RecuperarUsuarioDialogState extends State<RecuperarUsuarioDialog> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _recuperarUsuario() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = await DBHelper().getUsuarioByCorreo(email);
      if (!mounted) return;
      Navigator.pop(context);

      if (user != null) {
        // Enviar correo con el nombre de usuario / cuenta
        final mensaje = 'Hola ${user.nombre},\n\nTu nombre de usuario registrado en la plataforma es: "${user.nombre}".\nTu rol asignado es: "${user.rolTexto}".';
        final html = '''
        <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px;">
          <h2 style="color: #7E57C2; margin-top: 0;">Recuperación de Nombre de Usuario</h2>
          <p>Hola <strong>${user.nombre}</strong>,</p>
          <p>Has solicitado recordar los datos de tu cuenta. Tu información registrada es:</p>
          <ul>
            <li><strong>Nombre / Identificador:</strong> ${user.nombre}</li>
            <li><strong>Correo:</strong> ${user.correo}</li>
            <li><strong>Perfil / Rol:</strong> ${user.rolTexto}</li>
          </ul>
        </div>
        ''';

        try {
          await MailHelper.sendEmail(email, 'Recordatorio de Nombre de Usuario - Mi App', mensaje, htmlContent: html);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se ha enviado la información de tu cuenta al correo $email'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No existe una cuenta registrada con ese correo electrónico.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_search_rounded, color: AppTheme.primaryPurple),
          SizedBox(width: 8),
          Text('Recuperar Nombre de Usuario', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingresa tu correo electrónico. Te enviaremos tu nombre de usuario e información registrada.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailCtrl,
            label: 'Correo Electrónico',
            hint: 'ej. juan@gmail.com',
            prefixIcon: Icons.email_outlined,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _recuperarUsuario,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enviar Usuario'),
        ),
      ],
    );
  }
}
