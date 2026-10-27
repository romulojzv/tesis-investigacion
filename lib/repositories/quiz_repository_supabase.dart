// lib/repositories/quiz_repository_supabase.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_attempt_summary.dart';

abstract class QuizRepository {
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente();
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  );
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(String cuentoId);
}

class QuizRepositorySupabase implements QuizRepository {
  final SupabaseClient client;

  QuizRepositorySupabase({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async {
    try {
      final data = await client
          .from('quiz_intentos')
          .select('''
            id,
            cuento_id,
            estudiante_id,
            aula_id,
            estado,
            puntaje,
            total_preguntas,
            porcentaje,
            created_at,
            completed_at,
            cuentos ( titulo ),
            profiles:estudiante_id ( nombre, codigo_acceso ),
            aulas ( nombre ),
            quiz_respuestas (
              numero_pregunta,
              pregunta,
              opciones,
              indice_seleccionado,
              indice_correcto,
              es_correcta,
              explicacion,
              nivel_comprension
            )
          ''')
          .eq('estado', 'completado')
          .order('completed_at', ascending: false);

      final listado = <QuizAttemptSummary>[];
      for (final item in (data as List<dynamic>)) {
        listado.add(QuizAttemptSummary.fromJson(item as Map<String, dynamic>));
      }
      return listado;
    } catch (e) {
      debugPrint(
        '[QuizRepositorySupabase] Error cargando resultados docente: $e',
      );
      rethrow;
    }
  }

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async {
    try {
      final data = await client
          .from('quiz_intentos')
          .select('''
            id,
            cuento_id,
            estudiante_id,
            aula_id,
            estado,
            puntaje,
            total_preguntas,
            porcentaje,
            created_at,
            completed_at,
            cuentos ( titulo ),
            profiles:estudiante_id ( nombre, codigo_acceso ),
            aulas ( nombre ),
            quiz_respuestas (
              numero_pregunta,
              pregunta,
              opciones,
              indice_seleccionado,
              indice_correcto,
              es_correcta,
              explicacion,
              nivel_comprension
            )
          ''')
          .eq('estudiante_id', estudianteId)
          .order('completed_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false);

      final mapa = <String, QuizAttemptSummary>{};
      for (final item in (data as List<dynamic>)) {
        final summary = QuizAttemptSummary.fromJson(
          item as Map<String, dynamic>,
        );
        final existente = mapa[summary.cuentoId];
        // Regla: Si no existe, se añade. Si el existente no está completado pero el actual sí, se prioriza el completado.
        if (existente == null) {
          mapa[summary.cuentoId] = summary;
        } else if (!existente.estaCompletado && summary.estaCompletado) {
          mapa[summary.cuentoId] = summary;
        }
      }
      return mapa;
    } catch (e) {
      debugPrint(
        '[QuizRepositorySupabase] Error cargando resumenes quiz estudiante: $e',
      );
      return {};
    }
  }

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async {
    try {
      final data = await client
          .from('quiz_intentos')
          .select('''
            id,
            cuento_id,
            estudiante_id,
            aula_id,
            estado,
            puntaje,
            total_preguntas,
            porcentaje,
            created_at,
            completed_at,
            cuentos ( titulo ),
            profiles:estudiante_id ( nombre, codigo_acceso ),
            aulas ( nombre ),
            quiz_respuestas (
              numero_pregunta,
              pregunta,
              opciones,
              indice_seleccionado,
              indice_correcto,
              es_correcta,
              explicacion,
              nivel_comprension
            )
          ''')
          .eq('cuento_id', cuentoId)
          .order('completed_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false);

      final lista = data as List<dynamic>?;
      if (lista == null || lista.isEmpty) return null;

      // Regla consistente: seleccionar preferentemente el último intento completado y autorizado
      final filas = lista.cast<Map<String, dynamic>>();
      Map<String, dynamic>? completado;
      for (final item in filas) {
        if (item['estado'] == 'completado') {
          completado = item;
          break;
        }
      }
      final elegido = completado ?? filas.first;
      return QuizAttemptSummary.fromJson(elegido);
    } catch (e) {
      debugPrint(
        '[QuizRepositorySupabase] Error cargando resumen quiz por cuento: $e',
      );
      return null;
    }
  }
}
