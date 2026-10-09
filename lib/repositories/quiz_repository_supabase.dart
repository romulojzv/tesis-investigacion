// lib/repositories/quiz_repository_supabase.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_attempt_summary.dart';

abstract class QuizRepository {
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente();
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
              explicacion
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
}
