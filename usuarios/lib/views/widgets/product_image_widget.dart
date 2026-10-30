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

    // Reemplazo preventivo para fakestoreapi.com (cuyos servidores bloquean con error 403 de Cloudflare)
    if (finalUrl.contains('fakestoreapi.com')) {
      if (finalUrl.contains('81fPKd') || finalUrl.contains('1')) {
        finalUrl = 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500';
      } else if (finalUrl.contains('71-3Hj') || finalUrl.contains('2')) {
        finalUrl = 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=500';
      } else if (finalUrl.contains('71li-uj') || finalUrl.contains('3')) {
        finalUrl = 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500';
      } else if (finalUrl.contains('71pWzh') || finalUrl.contains('4')) {
        finalUrl = 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500';
      } else if (finalUrl.contains('61IBBV') || finalUrl.contains('5')) {
        finalUrl = 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500';
      } else {
        finalUrl = 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500';
      }
    }

    // 3. Renderizar imagen de red adaptativa optimizada en memoria y scroll
    return _wrapBorder(
      Image.network(
        finalUrl,
        width: width,
        height: height,
        cacheWidth: (width * 2).toInt(),
        fit: fit,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder;
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
