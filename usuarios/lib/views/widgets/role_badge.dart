import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Widget visual para representar el rol del usuario con un diseño pastel moderno
class RoleBadge extends StatelessWidget {
  final String? rol;
  final int? roleId;
  final bool compact;

  const RoleBadge({
    super.key,
    this.rol,
    this.roleId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar el rol normalizado
    String rolTexto = (rol ?? '').toLowerCase();
    if (rolTexto.isEmpty) {
      switch (roleId) {
        case 1:
          rolTexto = 'admin';
          break;
        case 2:
          rolTexto = 'editor';
          break;
        case 3:
        default:
          rolTexto = 'lector';
          break;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color textColor;
    IconData iconData;
    String label;

    switch (rolTexto) {
      case 'admin':
        bgColor = isDark ? const Color(0xFF311B92) : AppTheme.roleAdminBg;
        textColor = isDark ? const Color(0xFFD1C4E9) : AppTheme.roleAdminText;
        iconData = Icons.admin_panel_settings_rounded;
        label = 'Admin';
        break;
      case 'editor':
        bgColor = isDark ? const Color(0xFF4A148C) : AppTheme.roleEditorBg;
        textColor = isDark ? const Color(0xFFE1BEE7) : AppTheme.roleEditorText;
        iconData = Icons.edit_note_rounded;
        label = 'Editor';
        break;
      case 'lector':
      default:
        bgColor = isDark ? const Color(0xFF1A237E) : AppTheme.roleLectorBg;
        textColor = isDark ? const Color(0xFFC5CAE9) : AppTheme.roleLectorText;
        iconData = Icons.visibility_rounded;
        label = 'Lector';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: compact ? 12 : 15,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
