import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Widget especializado para desplegar la ilustración de una escena.
/// Soporta tanto URLs remotas (HTTP / HTTPS) como Data URIs temporales
/// en formato Base64 (data:image/webp;base64,... o data:image/png;base64,...).
class IlustracionEscenaWidget extends StatefulWidget {
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
  State<IlustracionEscenaWidget> createState() =>
      _IlustracionEscenaWidgetState();
}

class _IlustracionEscenaWidgetState extends State<IlustracionEscenaWidget> {
  Uint8List? _cachedBytes;
  bool _esDataUri = false;
  bool _esHttp = false;
  bool _errorDecodificacion = false;

  @override
  void initState() {
    super.initState();
    _procesarUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant IlustracionEscenaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _procesarUrl(widget.imageUrl);
    }
  }

  void _procesarUrl(String url) {
    final trimmed = url.trim();
    if (IlustracionEscenaWidget.esDataUri(trimmed)) {
      _esDataUri = true;
      _esHttp = false;
      final bytes = IlustracionEscenaWidget.decodificarDataUri(trimmed);
      if (bytes == null || bytes.isEmpty) {
        _cachedBytes = null;
        _errorDecodificacion = true;
      } else {
        _cachedBytes = bytes;
        _errorDecodificacion = false;
      }
    } else {
      _esDataUri = false;
      _cachedBytes = null;
      _errorDecodificacion = false;
      _esHttp = trimmed.startsWith('http://') || trimmed.startsWith('https://');
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.imageUrl.trim();

    if (_esDataUri) {
      if (_errorDecodificacion || _cachedBytes == null) {
        if (widget.errorBuilder != null) {
          return widget.errorBuilder!(
            context,
            const FormatException('Data URI inválido o no decodificable'),
            null,
          );
        }
        return const SizedBox.shrink();
      }

      return Image.memory(
        _cachedBytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: widget.errorBuilder != null
            ? (context, error, stackTrace) =>
                  widget.errorBuilder!(context, error, stackTrace)
            : null,
      );
    }

    if (_esHttp) {
      return Image.network(
        trimmed,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: widget.errorBuilder != null
            ? (context, error, stackTrace) =>
                  widget.errorBuilder!(context, error, stackTrace)
            : null,
      );
    }

    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(
        context,
        UnsupportedError('Esquema de URL no soportado: $trimmed'),
        null,
      );
    }

    return const SizedBox.shrink();
  }
}
