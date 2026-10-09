// lib/views/components/teacher_class_summary.dart

import 'package:flutter/material.dart';

import '../../models/quiz_attempt_summary.dart';

/// Métricas calculadas para un aula escolar.
class AulaMetrics {
  final int totalMatriculados;
  final int participantesUnicos;
  final int sinParticipacion;
  final double porcentajeParticipacion;
  final int totalQuizzesCompletados;

  const AulaMetrics({
    required this.totalMatriculados,
    required this.participantesUnicos,
    required this.sinParticipacion,
    required this.porcentajeParticipacion,
    required this.totalQuizzesCompletados,
  });

  /// Calcula las métricas exactas del aula garantizando la regla:
  /// - Participante: estudiante matriculado con >= 1 quiz completado (cuenta 1 vez).
  /// - Sin participación: matriculados - participantes únicos.
  /// - Porcentaje: participantes / total * 100 (0 % si total == 0, sin división por cero).
  /// - Total quizzes: suma total de intentos completados de alumnos del aula.
  factory AulaMetrics.calcular({
    required List<Map<String, dynamic>> estudiantesMatriculados,
    required List<QuizAttemptSummary> intentosDelAula,
  }) {
    final total = estudiantesMatriculados.length;
    final idsMatriculados = estudiantesMatriculados
        .map((e) => e['estudiante_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // Solo intentos completados de estudiantes matriculados en esta aula
    final intentosValidos = intentosDelAula
        .where(
          (q) => q.estaCompletado && idsMatriculados.contains(q.estudianteId),
        )
        .toList();

    // Estudiantes únicos con al menos 1 quiz completado
    final participantesSet = idsMatriculados.where((id) {
      return intentosValidos.any((q) => q.estudianteId == id);
    }).toSet();

    final participantes = participantesSet.length;
    final sinPart = total >= participantes ? total - participantes : 0;
    final pct = total == 0 ? 0.0 : (participantes / total) * 100.0;

    return AulaMetrics(
      totalMatriculados: total,
      participantesUnicos: participantes,
      sinParticipacion: sinPart,
      porcentajeParticipacion: pct,
      totalQuizzesCompletados: intentosValidos.length,
    );
  }
}

/// Tarjetas de resumen estadístico para el aula seleccionada.
class TeacherClassSummary extends StatelessWidget {
  final AulaMetrics metrics;

  const TeacherClassSummary({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pctStr = metrics.porcentajeParticipacion.toStringAsFixed(
      metrics.porcentajeParticipacion % 1 == 0 ? 0 : 1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final esPantallaEstrecha = constraints.maxWidth < 640;

        final tarjetas = [
          _buildItem(
            icono: Icons.people_outline,
            colorIcono: const Color(0xFFF39C12),
            titulo: 'Total matriculados',
            valor: '${metrics.totalMatriculados}',
            descripcion: 'Estudiantes',
          ),
          _buildItem(
            icono: Icons.person_pin_circle_outlined,
            colorIcono: const Color(0xFF2980B9),
            titulo: 'Estudiantes participantes',
            valor: '${metrics.participantesUnicos}',
            descripcion: 'Con ≥ 1 quiz completado',
          ),
          _buildItem(
            icono: Icons.person_off_outlined,
            colorIcono: const Color(0xFF7F8C8D),
            titulo: 'Sin participación',
            valor: '${metrics.sinParticipacion}',
            descripcion: 'Estudiantes pendientes',
          ),
          _buildItem(
            icono: Icons.pie_chart_outline,
            colorIcono: const Color(0xFF8E44AD),
            titulo: 'Participación',
            valor: '$pctStr %',
            descripcion: 'De la matrícula total',
          ),
          _buildItem(
            icono: Icons.assignment_turned_in_outlined,
            colorIcono: const Color(0xFFD35400),
            titulo: 'Quizzes completados',
            valor: '${metrics.totalQuizzesCompletados}',
            descripcion: 'Intentos finalizados',
          ),
        ];

        if (esPantallaEstrecha) {
          return Column(
            children: tarjetas
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: t,
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tarjetas
              .map(
                (t) => SizedBox(
                  width: (constraints.maxWidth - (12 * 4)) / 5 > 180
                      ? (constraints.maxWidth - (12 * 4)) / 5
                      : 190,
                  child: t,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildItem({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String valor,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: colorIcono),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF795548),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E342E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            descripcion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
          ),
        ],
      ),
    );
  }
}
