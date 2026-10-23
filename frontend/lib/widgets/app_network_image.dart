import 'dart:convert';
import 'package:flutter/material.dart';

/// Widget universal para renderizar imágenes tanto desde URLs HTTP/HTTPS (Firebase Storage)
/// como desde Data URIs Base64 (almacenadas 100% gratis en Cloud Firestore)
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url?.trim() ?? '';
    final placeholder = errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.menu_book_rounded, color: Colors.grey, size: 28),
          ),
        );

    if (cleanUrl.isEmpty) {
      return placeholder;
    }

    // Caso 1: Imagen codificada en Base64 (Almacenamiento directo en Firestore)
    if (cleanUrl.startsWith('data:image') || !cleanUrl.startsWith('http')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        final base64String = commaIndex != -1 ? cleanUrl.substring(commaIndex + 1) : cleanUrl;
        final bytes = base64Decode(base64String.trim());
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    }

    // Caso 2: URL HTTP / HTTPS estándar de Firebase Storage o Unsplash
    return Image.network(
      cleanUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}

/// Helper para obtener un ImageProvider compatible con CircleAvatar tanto para Base64 como HTTP
ImageProvider appImageProvider(String? url, {String defaultFallback = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c'}) {
  final cleanUrl = url?.trim() ?? '';
  if (cleanUrl.isEmpty) {
    return NetworkImage(defaultFallback);
  }

  if (cleanUrl.startsWith('data:image') || !cleanUrl.startsWith('http')) {
    try {
      final commaIndex = cleanUrl.indexOf(',');
      final base64String = commaIndex != -1 ? cleanUrl.substring(commaIndex + 1) : cleanUrl;
      final bytes = base64Decode(base64String.trim());
      return MemoryImage(bytes);
    } catch (_) {
      return NetworkImage(defaultFallback);
    }
  }

  return NetworkImage(cleanUrl);
}
