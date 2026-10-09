// lib/views/components/quiz_result_detail_dialog.dart

import 'package:flutter/material.dart';

import '../../models/quiz_attempt_summary.dart';
import '../../models/quiz_result.dart';

/// Diálogo de detalle de respuestas de un quiz para el docente.
class QuizResultDetailDialog extends StatelessWidget {
  final QuizAttemptSummary intento;

  const QuizResultDetailDialog({super.key, required this.intento});

  static Future<void> mostrar(
    BuildContext context,
    QuizAttemptSummary intento,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => QuizResultDetailDialog(intento: intento),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ordenar siempre por numero_pregunta ascendente (conservando numero como dato de dominio)
    final respuestasOrdenadas = List<QuizQuestionResult>.from(
      intento.respuestas,
    )..sort((a, b) => a.numero.compareTo(b.numero));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: Color(0xFFF39C12)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Detalle: ${intento.cuentoTitulo}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E342E),
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 540),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner del estudiante y puntaje
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Text(
                  'Estudiante: ${intento.estudianteNombre} (${intento.codigoAcceso}) • Puntaje: ${intento.puntaje ?? 0}/${intento.totalPreguntas}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (respuestasOrdenadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No se encontraron respuestas registradas para este intento.',
                      style: TextStyle(color: Color(0xFF795548)),
                    ),
                  ),
                )
              else
                ...respuestasOrdenadas.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  // La etiqueta corresponde a la pregunta ordenada (1..5)
                  final numDisplay = r.numero > 0 ? r.numero : (idx + 1);
                  final esCorrecta = r.esCorrecta;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: esCorrecta
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFFFCDD2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado de la pregunta: "Pregunta X" + indicador ✓/✗
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pregunta $numDisplay',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.pregunta,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: esCorrecta
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    esCorrecta
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color: esCorrecta
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    esCorrecta
                                        ? '✓ Correcta'
                                        : '✗ Respuesta incorrecta',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: esCorrecta
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 4 alternativas
                        ...List.generate(r.opciones.length, (optIdx) {
                          final esSeleccionada = r.indiceSeleccionado == optIdx;
                          final esLaCorrecta = r.indiceCorrecto == optIdx;

                          Color fondoColor = Colors.transparent;
                          Color bordeColor = const Color(0xFFEEEEEE);
                          Color textoColor = const Color(0xFF555555);
                          FontWeight peso = FontWeight.normal;

                          if (esSeleccionada && esLaCorrecta) {
                            fondoColor = const Color(0xFFE8F5E9);
                            bordeColor = const Color(0xFF81C784);
                            textoColor = const Color(0xFF1B5E20);
                            peso = FontWeight.bold;
                          } else if (esSeleccionada && !esLaCorrecta) {
                            fondoColor = const Color(0xFFFFEBEE);
                            bordeColor = const Color(0xFFE57373);
                            textoColor = const Color(0xFFB71C1C);
                            peso = FontWeight.bold;
                          } else if (esLaCorrecta) {
                            fondoColor = const Color(0xFFF1F8E9);
                            bordeColor = const Color(0xFFAED581);
                            textoColor = const Color(0xFF33691E);
                            peso = FontWeight.w600;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: fondoColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: bordeColor),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${String.fromCharCode(65 + optIdx)}) ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textoColor,
                                    fontSize: 13,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    r.opciones[optIdx],
                                    style: TextStyle(
                                      color: textoColor,
                                      fontWeight: peso,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (esSeleccionada && esLaCorrecta)
                                  const Text(
                                    '✓ Seleccionada (Correcta)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  )
                                else if (esSeleccionada)
                                  const Text(
                                    '✗ Seleccionada por estudiante',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC62828),
                                    ),
                                  )
                                else if (esLaCorrecta)
                                  const Text(
                                    '✓ Respuesta correcta',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF33691E),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        // Explicación
                        if (r.explicacion.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Explicación: ${r.explicacion}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5D4037),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF39C12),
          ),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
