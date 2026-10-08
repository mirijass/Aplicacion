import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Campo de texto personalizado con estilo pastel moderno, bordes redondeados y soporte adaptativo para Modo Oscuro
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;
  final bool readOnly;
  final int? maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.maxLength,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = AppTheme.getTextMain(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: textMain,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          readOnly: widget.readOnly,
          maxLength: widget.maxLength,
          style: TextStyle(
            color: textMain,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFFA098B0) : AppTheme.textLight,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              color: isDark ? AppTheme.pastelMauve : AppTheme.primaryPurple,
              size: 20,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark ? AppTheme.primaryLight : AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
