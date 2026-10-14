// lib/services/supabase_quiz_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_question.dart';
import '../models/quiz_result.dart';

/// Respuesta inicial de la función generar-quiz.
class QuizStartResponse {
  final String intentoId;
  final String estado; // 'en_progreso' | 'completado'
  final List<QuizQuestion> preguntas;
  final QuizResult? resultadoExistente;
  final List<QuizQuestionResult> retroalimentaciones;

  const QuizStartResponse({
    required this.intentoId,
    required this.estado,
    this.preguntas = const [],
    this.resultadoExistente,
    this.retroalimentaciones = const [],
  });

  bool get estaCompletado => estado == 'completado';
}

/// Contrato abstracto para el servicio de Quiz de comprensión lectora.
abstract class QuizService {
  Future<QuizStartResponse> generarQuiz(String cuentoId);
  Future<QuizResult> enviarQuiz({
    required String intentoId,
    required List<QuizAnswerSubmission> respuestas,
  });
}

/// Calificación y retroalimentación inmediata por pregunta con persistencia en el servidor.
abstract class QuizFeedbackService {
  Future<QuizQuestionResult> responderPregunta({
    required String intentoId,
    required int numero,
    required int indiceSeleccionado,
  });
}

/// Implementación de producción contra Edge Functions de Supabase con JWT y RLS.
class SupabaseQuizService implements QuizService, QuizFeedbackService {
  final SupabaseClient client;

  SupabaseQuizService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  String _obtenerTokenSesionActiva() {
    final session = client.auth.currentSession;
    if (session == null) {
      throw StateError(
        'No hay una sesión activa. Inicie sesión como estudiante para acceder al quiz.',
      );
    }
    if (session.isExpired) {
      throw StateError(
        'La sesión ha expirado. Por favor, vuelva a iniciar sesión.',
      );
    }
    return session.accessToken;
  }

  Map<String, dynamic> _validarRespuesta(dynamic data) {
    if (data == null) {
      throw StateError('La función del servidor devolvió una respuesta vacía.');
    }
    if (data is! Map<String, dynamic>) {
      throw StateError('Formato de respuesta inesperado del servidor: $data');
    }
    if (data.containsKey('error')) {
      final errorMsg = data['error']?.toString() ?? 'Error desconocido';
      final detalle = data['detalle']?.toString();
      throw StateError(
        detalle != null && detalle.isNotEmpty
            ? '$errorMsg: $detalle'
            : errorMsg,
      );
    }
    return data;
  }

  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    final token = _obtenerTokenSesionActiva();

    debugPrint(
      '[SupabaseQuizService] Solicitando quiz a generar-quiz para cuento: $cuentoId',
    );

    try {
      final response = await client.functions
          .invoke(
            'generar-quiz',
            headers: {'Authorization': 'Bearer $token'},
            body: {'cuentoId': cuentoId},
          )
          .timeout(const Duration(seconds: 40));

      debugPrint(
        '[SupabaseQuizService] generar-quiz respondió HTTP status: ${response.status}',
      );

      final json = _validarRespuesta(response.data);
      final intentoId = json['intentoId']?.toString() ?? '';
      final estado = json['estado']?.toString() ?? 'en_progreso';

      if (estado == 'completado') {
        final resultado = QuizResult.fromJson(json);
        return QuizStartResponse(
          intentoId: intentoId,
          estado: 'completado',
          resultadoExistente: resultado,
        );
      }

      final preguntasRaw = json['preguntas'] as List<dynamic>? ?? [];
      final preguntas = preguntasRaw
          .map((p) => QuizQuestion.fromJson(p as Map<String, dynamic>))
          .toList();

      final retroalimentacionesRaw =
          json['retroalimentaciones'] as List<dynamic>? ?? [];
      final retroalimentaciones = retroalimentacionesRaw
          .map((e) => QuizQuestionResult.fromJson(e as Map<String, dynamic>))
          .toList();

      return QuizStartResponse(
        intentoId: intentoId,
        estado: 'en_progreso',
        preguntas: preguntas,
        retroalimentaciones: retroalimentaciones,
      );
    } on FunctionException catch (fe) {
      debugPrint(
        '[SupabaseQuizService] Error HTTP ${fe.status} en generar-quiz: ${fe.details}',
      );
      if (fe.status == 401) {
        throw StateError(
          'Sesión no autorizada o expirada. Inicie sesión nuevamente.',
        );
      }
      if (fe.status == 403) {
        throw StateError(
          'Acceso denegado. El quiz está disponible exclusivamente para estudiantes propietarios del cuento.',
        );
      }
      final detalle = fe.details is Map
          ? fe.details['error']?.toString()
          : null;
      throw StateError(
        detalle ?? 'Error al invocar generar-quiz (HTTP ${fe.status})',
      );
    } catch (e) {
      if (e is StateError) rethrow;
      debugPrint('[SupabaseQuizService] Error invocando generar-quiz: $e');
      throw StateError('Fallo al obtener el quiz de comprensión: $e');
    }
  }

  @override
  Future<QuizQuestionResult> responderPregunta({
    required String intentoId,
    required int numero,
    required int indiceSeleccionado,
  }) async {
    if (numero < 1 ||
        numero > 5 ||
        indiceSeleccionado < 0 ||
        indiceSeleccionado > 3) {
      throw ArgumentError('Pregunta o alternativa fuera de rango.');
    }

    final token = _obtenerTokenSesionActiva();
    try {
      final response = await client.functions
          .invoke(
            'responder-pregunta',
            headers: {'Authorization': 'Bearer $token'},
            body: {
              'intentoId': intentoId,
              'numero': numero,
              'indiceSeleccionado': indiceSeleccionado,
            },
          )
          .timeout(const Duration(seconds: 30));

      return QuizQuestionResult.fromJson(_validarRespuesta(response.data));
    } on FunctionException catch (fe) {
      debugPrint(
        '[SupabaseQuizService] Error HTTP ${fe.status} en responder-pregunta: ${fe.details}',
      );
      if (fe.status == 401) {
        throw StateError(
          'Sesión no autorizada o expirada. Inicie sesión nuevamente.',
        );
      }
      if (fe.status == 403) {
        throw StateError(
          'Acceso denegado. El intento no pertenece al estudiante autenticado.',
        );
      }
      final detalle = fe.details is Map
          ? fe.details['error']?.toString()
          : null;
      throw StateError(
        detalle ??
            'No fue posible comprobar la respuesta (HTTP ${fe.status}).',
      );
    } catch (e) {
      if (e is StateError) rethrow;
      throw StateError('Error al registrar la respuesta: $e');
    }
  }

  @override
  Future<QuizResult> enviarQuiz({
    required String intentoId,
    required List<QuizAnswerSubmission> respuestas,
  }) async {
    final token = _obtenerTokenSesionActiva();

    if (respuestas.length != 5) {
      throw ArgumentError('Se deben enviar exactamente las 5 respuestas.');
    }

    debugPrint(
      '[SupabaseQuizService] Enviando respuestas a enviar-quiz para intento: $intentoId',
    );

    try {
      final response = await client.functions
          .invoke(
            'enviar-quiz',
            headers: {'Authorization': 'Bearer $token'},
            body: {
              'intentoId': intentoId,
              'respuestas': respuestas.map((r) => r.toJson()).toList(),
            },
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        '[SupabaseQuizService] enviar-quiz respondió HTTP status: ${response.status}',
      );

      final json = _validarRespuesta(response.data);
      return QuizResult.fromJson(json);
    } on FunctionException catch (fe) {
      debugPrint(
        '[SupabaseQuizService] Error HTTP ${fe.status} en enviar-quiz: ${fe.details}',
      );
      if (fe.status == 401) {
        throw StateError(
          'Sesión no autorizada o expirada. Inicie sesión nuevamente.',
        );
      }
      if (fe.status == 403) {
        throw StateError(
          'Acceso denegado. El intento no pertenece al estudiante autenticado.',
        );
      }
      final detalle = fe.details is Map
          ? fe.details['error']?.toString()
          : null;
      throw StateError(
        detalle ?? 'Error al invocar enviar-quiz (HTTP ${fe.status})',
      );
    } catch (e) {
      if (e is StateError) rethrow;
      debugPrint('[SupabaseQuizService] Error invocando enviar-quiz: $e');
      throw StateError('Fallo al enviar las respuestas del quiz: $e');
    }
  }
}
