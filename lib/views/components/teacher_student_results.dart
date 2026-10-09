// lib/views/components/teacher_student_results.dart

import 'package:flutter/material.dart';

import '../../models/quiz_attempt_summary.dart';
import '../../utils/date_formatter.dart';

/// Vista de resultados de quizzes de un estudiante seleccionado.
class TeacherStudentResults extends StatelessWidget {
  final Map<String, dynamic> estudiante;
  final List<QuizAttemptSummary> quizzes;
  final VoidCallback onVolver;
  final ValueChanged<QuizAttemptSummary> onVerDetalle;

  const TeacherStudentResults({
    super.key,
    required this.estudiante,
    required this.quizzes,
    required this.onVolver,
    required this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = estudiante['nombre']?.toString() ?? 'Estudiante';
    final codigoAcceso = estudiante['codigo_acceso']?.toString() ?? '';
    final numLista = estudiante['codigo_local']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra superior con botón volver
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: onVolver,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver a estudiantes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6D4C41),
                side: const BorderSide(color: Color(0xFFFFCC80)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Text(
                '${quizzes.length} quiz(zes) completado(s)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Encabezado del estudiante
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFFE0B2),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFFF39C12),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultados de $nombre',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código de acceso: $codigoAcceso • N° Lista: $numLista',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF795548),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Listado de quizzes completados
        if (quizzes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 40,
                    color: Color(0xFFBCAAA4),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Aún no tiene resultados de comprensión.',
                    style: TextStyle(
                      color: Color(0xFF795548),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...quizzes.map((intento) {
            final fecha = intento.completedAt ?? intento.createdAt;
            final fechaStr = DateFormatter.formatearFechaHoraLocal(fecha);
            final puntaje = intento.puntaje ?? 0;
            final total = intento.totalPreguntas;
            final porcentaje = intento.porcentaje != null
                ? (intento.porcentaje is double
                      ? (intento.porcentaje as double).toStringAsFixed(0)
                      : intento.porcentaje.toString())
                : ((puntaje / (total > 0 ? total : 1)) * 100).toStringAsFixed(
                    0,
                  );

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0B2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Badge neutral de puntaje
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$puntaje/$total',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                        ),
                        Text(
                          '$porcentaje %',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D4C41),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Título del cuento y fecha local
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intento.cuentoTitulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resultado: $puntaje/$total · $porcentaje % • $fechaStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón ver respuestas
                  OutlinedButton.icon(
                    onPressed: () => onVerDetalle(intento),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver respuestas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF39C12),
                      side: const BorderSide(color: Color(0xFFF39C12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
