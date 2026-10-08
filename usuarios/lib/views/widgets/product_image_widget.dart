import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Widget robusto para renderizar imágenes de productos desde cualquier URL (HTTP, HTTPS, Base64 o URLs sin esquema)
class ProductImageWidget extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width = 90,
    this.height = 90,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String cleanUrl = imageUrl.trim();

    Widget placeholder = Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF2E2938) : AppTheme.primaryExtraLight,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppTheme.primaryPurple,
          size: 32,
        ),
      ),
    );

    if (cleanUrl.isEmpty) {
      return _wrapBorder(placeholder);
    }

    // 1. Manejo de imágenes Base64 (data:image/...)
    if (cleanUrl.startsWith('data:image/')) {
      try {
        final base64Data = cleanUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return _wrapBorder(
          Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      } catch (_) {
        return _wrapBorder(placeholder);
      }
    }

    // 2. Normalizar URL sin protocolo HTTP/HTTPS
    String finalUrl = cleanUrl;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    // 3. Renderizar imagen de red adaptativa con cargador y respaldo de error
    return _wrapBorder(
      Image.network(
        finalUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: isDark ? const Color(0xFF2E2938) : AppTheme.primaryExtraLight,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryPurple.withAlpha(150),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return placeholder;
        },
      ),
    );
  }

  Widget _wrapBorder(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }
}
