import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Widget especializado para desplegar la ilustración de una escena.
/// Soporta tanto URLs remotas (HTTP / HTTPS) como Data URIs temporales
/// en formato Base64 (data:image/webp;base64,... o data:image/png;base64,...).
class IlustracionEscenaWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;

  const IlustracionEscenaWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width = double.infinity,
    this.height = double.infinity,
    this.errorBuilder,
  });

  /// Determina si una URL corresponde a un Data URI base64
  static bool esDataUri(String url) {
    return url.trim().toLowerCase().startsWith('data:image/');
  }

  /// Intenta decodificar los bytes de un Data URI base64
  static Uint8List? decodificarDataUri(String dataUri) {
    final trimmed = dataUri.trim();
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex == -1) return null;

    final base64Part = trimmed
        .substring(commaIndex + 1)
        .replaceAll(RegExp(r'\s+'), '');
    if (base64Part.isEmpty) return null;

    try {
      final bytes = base64Decode(base64Part);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();

    if (esDataUri(trimmed)) {
      final bytes = decodificarDataUri(trimmed);
      if (bytes == null || bytes.isEmpty) {
        if (errorBuilder != null) {
          return errorBuilder!(
            context,
            const FormatException('Data URI inválido o no decodificable'),
            null,
          );
        }
        return const SizedBox.shrink();
      }

      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder != null
            ? (context, error, stackTrace) =>
                  errorBuilder!(context, error, stackTrace)
            : null,
      );
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder != null
            ? (context, error, stackTrace) =>
                  errorBuilder!(context, error, stackTrace)
            : null,
      );
    }

    if (errorBuilder != null) {
      return errorBuilder!(
        context,
        UnsupportedError('Esquema de URL no soportado: $trimmed'),
        null,
      );
    }

    return const SizedBox.shrink();
  }
}
