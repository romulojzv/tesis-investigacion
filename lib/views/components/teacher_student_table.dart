// lib/views/components/teacher_student_table.dart

import 'package:flutter/material.dart';

import '../../models/quiz_attempt_summary.dart';

/// Tabla de estudiantes matriculados en el aula seleccionada.
class TeacherStudentTable extends StatelessWidget {
  final List<Map<String, dynamic>> estudiantes;
  final List<QuizAttemptSummary> intentosDelAula;
  final ValueChanged<Map<String, dynamic>> onSelectEstudiante;

  const TeacherStudentTable({
    super.key,
    required this.estudiantes,
    required this.intentosDelAula,
    required this.onSelectEstudiante,
  });

  @override
  Widget build(BuildContext context) {
    if (estudiantes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE0B2)),
        ),
        child: const Center(
          child: Text(
            'No hay estudiantes registrados en esta aula todavía.',
            style: TextStyle(
              color: Color(0xFF8D6E63),
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Mapa auxiliar: estudianteId -> cantidad de quizzes completados
    final Map<String, int> conteoQuizzes = {};
    for (final q in intentosDelAula) {
      if (q.estaCompletado) {
        conteoQuizzes[q.estudianteId] =
            (conteoQuizzes[q.estudianteId] ?? 0) + 1;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(90),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
            3: FixedColumnWidth(160),
            4: FixedColumnWidth(80),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Fila de encabezado
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8F0),
                border: Border(bottom: BorderSide(color: Color(0xFFFFE0B2))),
              ),
              children: [
                _buildHeaderCell('N° Lista'),
                _buildHeaderCell('Nombre'),
                _buildHeaderCell('Código de acceso'),
                _buildHeaderCell(
                  'Quizzes completados',
                  align: TextAlign.center,
                ),
                _buildHeaderCell('Acción', align: TextAlign.center),
              ],
            ),
            // Filas de estudiantes
            ...estudiantes.map((estudiante) {
              final estId = estudiante['estudiante_id']?.toString() ?? '';
              final numLista = estudiante['codigo_local']?.toString() ?? '';
              final nombre = estudiante['nombre']?.toString() ?? 'Estudiante';
              final codigoAcceso =
                  estudiante['codigo_acceso']?.toString() ?? '';
              final cantQuizzes = conteoQuizzes[estId] ?? 0;

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFFFF3E0))),
                ),
                children: [
                  // N° lista
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      numLista,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF6D4C41),
                      ),
                    ),
                  ),
                  // Nombre
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: InkWell(
                      onTap: () => onSelectEstudiante(estudiante),
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4E342E),
                        ),
                      ),
                    ),
                  ),
                  // Código de acceso
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Text(
                          codigoAcceso,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Quizzes completados
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE0B2)),
                        ),
                        child: Text(
                          '$cantQuizzes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Acción / >
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Color(0xFFF39C12),
                        ),
                        tooltip: 'Ver resultados de $nombre',
                        onPressed: () => onSelectEstudiante(estudiante),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String texto, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        texto,
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF795548),
        ),
      ),
    );
  }
}
