// lib/models/quiz_attempt_summary.dart

import 'quiz_result.dart';

/// Resumen de intento de quiz para visualización docente y estadísticas educativas.
class QuizAttemptSummary {
  final String intentoId;
  final String cuentoId;
  final String cuentoTitulo;
  final String estudianteId;
  final String estudianteNombre;
  final String codigoAcceso;
  final String? aulaId;
  final String? aulaNombre;
  final String estado; // 'en_progreso' | 'completado'
  final int? puntaje;
  final int totalPreguntas;
  final num? porcentaje;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<QuizQuestionResult> respuestas;

  const QuizAttemptSummary({
    required this.intentoId,
    required this.cuentoId,
    required this.cuentoTitulo,
    required this.estudianteId,
    required this.estudianteNombre,
    required this.codigoAcceso,
    this.aulaId,
    this.aulaNombre,
    required this.estado,
    this.puntaje,
    this.totalPreguntas = 5,
    this.porcentaje,
    required this.createdAt,
    this.completedAt,
    this.respuestas = const [],
  });

  bool get estaCompletado => estado == 'completado';

  factory QuizAttemptSummary.fromJson(Map<String, dynamic> json) {
    final respRaw =
        (json['quiz_respuestas'] ?? json['respuestas']) as List<dynamic>? ?? [];
    final respuestasList =
        respRaw
            .map((r) => QuizQuestionResult.fromJson(r as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));

    return QuizAttemptSummary(
      intentoId: json['id']?.toString() ?? '',
      cuentoId: json['cuento_id']?.toString() ?? '',
      cuentoTitulo: json['cuentos']?['titulo']?.toString() ?? 'Cuento Mágico',
      estudianteId: json['estudiante_id']?.toString() ?? '',
      estudianteNombre: json['profiles']?['nombre']?.toString() ?? 'Estudiante',
      codigoAcceso: json['profiles']?['codigo_acceso']?.toString() ?? '',
      aulaId: json['aula_id']?.toString(),
      aulaNombre: json['aulas']?['nombre']?.toString(),
      estado: json['estado']?.toString() ?? 'en_progreso',
      puntaje: json['puntaje'] as int?,
      totalPreguntas: json['total_preguntas'] as int? ?? 5,
      porcentaje: json['porcentaje'] as num?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      respuestas: respuestasList,
    );
  }
}
