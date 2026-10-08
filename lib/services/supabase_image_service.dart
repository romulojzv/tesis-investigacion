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

  String _obtenerTokenSesionActiva() {
    final session = client.auth.currentSession;
    if (session == null) {
      throw ImageAuthException(
        statusCode: 401,
        message: 'No hay una sesión activa. Inicie sesión como estudiante para generar ilustraciones.',
      );
    }
    if (session.isExpired) {
      throw ImageAuthException(
        statusCode: 401,
        message: 'La sesión ha expirado. Por favor, vuelva a iniciar sesión.',
      );
    }
    return session.accessToken;
  }

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    final token = _obtenerTokenSesionActiva();

    final body = <String, dynamic>{
      'cuentoId': solicitud.cuentoId,
      'numeroEscena': solicitud.numeroEscena,
      'personajePrincipal': solicitud.nombreProtagonista,
      'contenidoEscena': solicitud.contenidoEscena,
      'esModoDibujo': solicitud.esModoDibujo,
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

    if (solicitud.referenciaAnteriorBytes != null &&
        solicitud.referenciaAnteriorBytes!.isNotEmpty) {
      body['referenciaAnchorBase64'] = base64Encode(
        solicitud.referenciaAnteriorBytes!,
      );
    }

    debugPrint(
      '[SupabaseImageService] Solicitando ilustración a generar-imagen: '
      'cuento=${solicitud.cuentoId}, escena=${solicitud.numeroEscena}, '
      'conReferencia=${solicitud.referenciaVisualBytes != null}, '
      'conAnchor=${solicitud.referenciaAnteriorBytes != null}',
    );

    try {
      final response = await client.functions
          .invoke(
            'generar-imagen',
            headers: {'Authorization': 'Bearer $token'},
            body: body,
          )
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
    } on FunctionException catch (fe) {
      debugPrint(
        '[SupabaseImageService] Error HTTP ${fe.status} en generar-imagen: ${fe.details}',
      );
      if (fe.status == 401) {
        throw ImageAuthException(
          statusCode: 401,
          message: 'Sesión no autorizada o expirada al generar ilustración.',
        );
      }
      if (fe.status == 403) {
        throw ImageAuthException(
          statusCode: 403,
          message: 'Acceso denegado. Generación de imágenes disponible exclusivamente para estudiantes.',
        );
      }
      rethrow;
    } on ImageAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseImageService] Error generando ilustración: $e');
      final errStr = e.toString();
      if (errStr.contains('Sesión no válida o expirada') ||
          errStr.contains('Sesión no autorizada') ||
          errStr.contains('JWT expired')) {
        throw ImageAuthException(
          statusCode: 401,
          message: e is StateError
              ? e.message
              : 'Sesión no autorizada o expirada al generar ilustración.',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _validarRespuesta(dynamic data) {
    if (data == null) {
      throw StateError('El servicio de imágenes no devolvió datos.');
    }

    if (data is! Map) {
      throw StateError('La respuesta del servidor no tiene un formato válido.');
    }

    final json = Map<String, dynamic>.from(data);

    if (json['error'] != null) {
      final mensaje = json['error'].toString();
      final detalle = json['detalle']?.toString();
      final textoCompleto = (detalle != null && detalle.isNotEmpty)
          ? '$mensaje: $detalle'
          : mensaje;

      if (mensaje.contains('Sesión no válida o expirada') ||
          mensaje.contains('JWT expired') ||
          mensaje.contains('Token inválido')) {
        throw ImageAuthException(statusCode: 401, message: textoCompleto);
      }
      if (mensaje.contains('Acceso denegado') ||
          mensaje.contains('exclusivamente para estudiantes')) {
        throw ImageAuthException(statusCode: 403, message: textoCompleto);
      }

      throw StateError(textoCompleto);
    }

    return json;
  }
}
