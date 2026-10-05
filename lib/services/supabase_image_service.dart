import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_service.dart';

/// Implementación de [ImageService] que delega la generación a la Supabase
/// Edge Function 'generar-imagen', la cual interactúa de forma segura con
/// Pollinations AI sin exponer credenciales en la aplicación Flutter.
class SupabaseImageService implements ImageService {
  final SupabaseClient client;

  SupabaseImageService({required this.client});

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    final body = <String, dynamic>{
      'cuentoId': solicitud.cuentoId,
      'numeroEscena': solicitud.numeroEscena,
      'personajePrincipal': solicitud.nombreProtagonista,
      'contenidoEscena': solicitud.contenidoEscena,
    };

    if (solicitud.descripcionPersonaje != null &&
        solicitud.descripcionPersonaje!.trim().isNotEmpty) {
      body['descripcionPersonaje'] = solicitud.descripcionPersonaje!.trim();
    }

    if (solicitud.escenario != null && solicitud.escenario!.trim().isNotEmpty) {
      body['escenario'] = solicitud.escenario!.trim();
    }

    if (solicitud.referenciaVisualBytes != null &&
        solicitud.referenciaVisualBytes!.isNotEmpty) {
      body['referenciaVisualBase64'] = base64Encode(
        solicitud.referenciaVisualBytes!,
      );
    }

    debugPrint(
      '[SupabaseImageService] Solicitando ilustración a generar-imagen: '
      'cuento=${solicitud.cuentoId}, escena=${solicitud.numeroEscena}, '
      'conReferencia=${solicitud.referenciaVisualBytes != null}',
    );

    try {
      final response = await client.functions
          .invoke('generar-imagen', body: body)
          .timeout(const Duration(seconds: 45));

      debugPrint(
        '[SupabaseImageService] Edge Function respondió HTTP status: ${response.status}',
      );

      final json = _validarRespuesta(response.data);

      final imageUrl = json['imageUrl'] as String?;
      final imagePath = json['imagePath'] as String?;
      final storageGuardado = json['storageGuardado'] as bool? ?? false;
      final flujo = json['flujo'] as String?;

      final previewUrl = imageUrl != null
          ? (imageUrl.startsWith('data:')
                ? 'Data URI (longitud ${imageUrl.length} caracteres)'
                : imageUrl)
          : 'null';

      debugPrint(
        '[SupabaseImageService] Ilustración recibida con éxito: '
        'flujo=$flujo, path=$imagePath, storageGuardado=$storageGuardado, url=$previewUrl',
      );

      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw StateError(
          'La función generar-imagen no retornó una imageUrl válida.',
        );
      }

      return imageUrl;
    } catch (e) {
      debugPrint('[SupabaseImageService] Error generando ilustración: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _validarRespuesta(dynamic data) {
    if (data == null) {
      throw StateError('El servicio de imágenes no devolvió datos.');
    }

    if (data is! Map) {
      throw StateError(
        'La respuesta del servicio de imágenes tiene un formato inválido.',
      );
    }

    final json = Map<String, dynamic>.from(data);

    if (json['error'] != null) {
      final detalle = json['detalle'] != null ? ': ${json['detalle']}' : '';
      throw StateError('${json['error']}$detalle');
    }

    return json;
  }
}
