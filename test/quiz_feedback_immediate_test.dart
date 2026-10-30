// test/quiz_feedback_immediate_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/quiz_question.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/services/supabase_quiz_service.dart';
import 'package:tesis_investigacion/views/quiz_view.dart';

class MockQuizFeedbackServiceImpl implements QuizService, QuizFeedbackService {
  final List<QuizQuestionResult> responderCalls = [];
  final Map<int, QuizQuestionResult> responsesToReturn = {};
  QuizStartResponse? customStartResponse;

  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    if (customStartResponse != null) {
      return customStartResponse!;
    }
    return QuizStartResponse(
      intentoId: 'intento-uuid-1234',
      estado: 'en_progreso',
      preguntas: List.generate(
        5,
        (i) => QuizQuestion(
          numero: i + 1,
          pregunta: '¿Pregunta de prueba ${i + 1}?',
          opciones: [
            'Opción A${i + 1}',
            'Opción B${i + 1}',
            'Opción C${i + 1}',
            'Opción D${i + 1}',
          ],
          nivelComprension: i < 2
              ? 'literal'
              : (i < 4 ? 'inferencial' : 'critico_reflexivo'),
        ),
      ),
    );
  }

  @override
  Future<QuizQuestionResult> responderPregunta({
    required String intentoId,
    required int numero,
    required int indiceSeleccionado,
  }) async {
    final resp =
        responsesToReturn[numero] ??
        QuizQuestionResult(
          numero: numero,
          pregunta: '¿Pregunta de prueba $numero?',
          opciones: [
            'Opción A$numero',
            'Opción B$numero',
            'Opción C$numero',
            'Opción D$numero',
          ],
          indiceSeleccionado: indiceSeleccionado,
          indiceCorrecto: 1, // B es la correcta por defecto
          esCorrecta: indiceSeleccionado == 1,
          explicacion: indiceSeleccionado == 1
              ? '¡Excelente! La historia lo menciona con claridad.'
              : 'Recuerda que en el cuento ocurrió otra situación.',
          nivelComprension: numero < 3
              ? 'literal'
              : (numero < 5 ? 'inferencial' : 'critico_reflexivo'),
        );
    responderCalls.add(resp);
    return resp;
  }

  @override
  Future<QuizResult> enviarQuiz({
    required String intentoId,
    required List<QuizAnswerSubmission> respuestas,
  }) async {
    throw UnimplementedError(
      'No debe llamarse en flujo de retroalimentación inmediata.',
    );
  }
}

void main() {
  Widget crearWidgetPrueba(QuizService service) {
    return MaterialApp(
      home: QuizView(
        cuentoId: 'cuento-123',
        tituloCuento: 'El Bosque de Fantasía',
        quizService: service,
        onVolver: () {},
      ),
    );
  }

  group('RF-26: Retroalimentación inmediata y persistencia por pregunta', () {
    testWidgets(
      'Muestra nivel de comprensión y permite seleccionar alternativa',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        expect(find.text('Nivel: Literal'), findsOneWidget);
        expect(find.text('¿Pregunta de prueba 1?'), findsOneWidget);
        expect(find.text('Opción A1'), findsOneWidget);
        expect(find.text('Comprobar respuesta'), findsOneWidget);
      },
    );

    testWidgets(
      'Confirmar respuesta correcta muestra banner verde y explicación para primaria',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        // Seleccionar opción correcta (B = índice 1)
        await tester.tap(find.text('Opción B1'));
        await tester.pumpAndSettle();

        // Pulsar "Comprobar respuesta"
        await tester.tap(find.text('Comprobar respuesta'));
        await tester.pumpAndSettle();

        // Verificar que se invocó responderPregunta en el servidor
        expect(mock.responderCalls.length, 1);
        expect(mock.responderCalls.first.numero, 1);
        expect(mock.responderCalls.first.indiceSeleccionado, 1);

        // Verificar retroalimentación inmediata en la UI
        expect(find.text('¡Correcto! 🌟'), findsOneWidget);
        expect(
          find.text('¡Excelente! La historia lo menciona con claridad.'),
          findsOneWidget,
        );
        expect(
          find.text('Lee esta explicación antes de continuar.'),
          findsOneWidget,
        );

        // El botón ahora debe ser "Siguiente"
        expect(find.text('Siguiente'), findsOneWidget);
      },
    );

    testWidgets(
      'Inmutabilidad: respuesta confirmada bloquea cambios de selección',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        // Seleccionar y confirmar opción B
        await tester.tap(find.text('Opción B1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Comprobar respuesta'));
        await tester.pumpAndSettle();

        expect(mock.responderCalls.length, 1);

        // Intentar tocar opción A u otra alternativa
        await tester.tap(find.text('Opción A1'));
        await tester.pumpAndSettle();

        // La llamada al servicio no debe repetirse
        expect(mock.responderCalls.length, 1);
      },
    );

    testWidgets(
      'Respuesta incorrecta muestra banner explicativo y revela alternativa correcta',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        // Seleccionar opción incorrecta (A = índice 0)
        await tester.tap(find.text('Opción A1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Comprobar respuesta'));
        await tester.pumpAndSettle();

        expect(find.text('Revisemos tu respuesta 💡'), findsOneWidget);
        expect(
          find.text('Recuerda que en el cuento ocurrió otra situación.'),
          findsOneWidget,
        );
        expect(find.text('Respuesta correcta: Opción B1'), findsOneWidget);
      },
    );

    testWidgets(
      'Reanudación: cuestionario con respuestas previas carga estado y avanza a la pendiente',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        // Simular que la pregunta 1 ya fue respondida previamente en Supabase
        mock.customStartResponse = QuizStartResponse(
          intentoId: 'intento-reanudado',
          estado: 'en_progreso',
          preguntas: List.generate(
            5,
            (i) => QuizQuestion(
              numero: i + 1,
              pregunta: '¿Pregunta ${i + 1}?',
              opciones: ['A', 'B', 'C', 'D'],
              nivelComprension: i == 0 ? 'literal' : 'inferencial',
            ),
          ),
          retroalimentaciones: [
            const QuizQuestionResult(
              numero: 1,
              pregunta: '¿Pregunta 1?',
              opciones: ['A', 'B', 'C', 'D'],
              indiceSeleccionado: 1,
              indiceCorrecto: 1,
              esCorrecta: true,
              explicacion: 'Explicación guardada',
              nivelComprension: 'literal',
            ),
          ],
        );

        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        // Debe posicionarse directamente en la pregunta 2 (primer pendiente)
        expect(find.text('Pregunta 2 de 5'), findsOneWidget);
        expect(find.text('¿Pregunta 2?'), findsOneWidget);
        expect(find.text('Comprobar respuesta'), findsOneWidget);

        // Si retrocede a la 1, debe ver que ya está respondida y con su feedback
        await tester.tap(find.text('Anterior'));
        await tester.pumpAndSettle();

        expect(find.text('Pregunta 1 de 5'), findsOneWidget);
        expect(find.text('¡Correcto! 🌟'), findsOneWidget);
        expect(find.text('Explicación guardada'), findsOneWidget);
      },
    );

    testWidgets(
      'Finalización: al responder la pregunta 5 permite ver el resultado final',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        // Simular que preguntas 1 a 4 ya están respondidas
        mock.customStartResponse = QuizStartResponse(
          intentoId: 'intento-casi-listo',
          estado: 'en_progreso',
          preguntas: List.generate(
            5,
            (i) => QuizQuestion(
              numero: i + 1,
              pregunta: '¿Pregunta ${i + 1}?',
              opciones: [
                'Opc ${i + 1}A',
                'Opc ${i + 1}B',
                'Opc ${i + 1}C',
                'Opc ${i + 1}D',
              ],
              nivelComprension: i == 4 ? 'critico_reflexivo' : 'literal',
            ),
          ),
          retroalimentaciones: List.generate(
            4,
            (i) => QuizQuestionResult(
              numero: i + 1,
              pregunta: '¿Pregunta ${i + 1}?',
              opciones: [
                'Opc ${i + 1}A',
                'Opc ${i + 1}B',
                'Opc ${i + 1}C',
                'Opc ${i + 1}D',
              ],
              indiceSeleccionado: 1,
              indiceCorrecto: 1,
              esCorrecta: true,
              explicacion: 'Correcto',
              nivelComprension: 'literal',
            ),
          ),
        );

        await tester.pumpWidget(crearWidgetPrueba(mock));
        await tester.pumpAndSettle();

        // Debe estar en pregunta 5
        expect(find.text('Pregunta 5 de 5'), findsOneWidget);
        expect(find.text('Nivel: Crítico-reflexivo'), findsOneWidget);

        // Responder pregunta 5 seleccionando Opc 5B
        await tester.tap(find.text('Opc 5B'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Comprobar respuesta'));
        await tester.pumpAndSettle();

        // Tras confirmar la 5, el botón debe ser "Ver mi resultado"
        expect(find.text('Ver mi resultado'), findsOneWidget);

        // Simular que el backend completó el intento
        mock.customStartResponse = QuizStartResponse(
          intentoId: 'intento-casi-listo',
          estado: 'completado',
          resultadoExistente: const QuizResult(
            intentoId: 'intento-casi-listo',
            puntaje: 5,
            total: 5,
            porcentaje: 100,
            respuestas: [],
          ),
        );

        await tester.tap(find.text('Ver mi resultado'));
        await tester.pumpAndSettle();

        // Debe mostrar la vista de resultados globales
        expect(find.text('Resultado de Comprensión'), findsOneWidget);
        expect(find.text('Puntaje: 5 de 5'), findsOneWidget);
      },
    );

    testWidgets(
      'QuizView: recibe estudianteNombre del perfil autenticado y habilita exportación PDF de cuento',
      (tester) async {
        final mock = MockQuizFeedbackServiceImpl();
        mock.customStartResponse = QuizStartResponse(
          intentoId: 'intento-completado-1',
          estado: 'completado',
          resultadoExistente: const QuizResult(
            intentoId: 'intento-completado-1',
            puntaje: 5,
            total: 5,
            porcentaje: 100,
            respuestas: [],
          ),
        );

        final cuento = Cuento(
          id: 'c-test-123',
          titulo: 'Cuento de Fantasía',
          personajePrincipal: 'Padas',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'c-test-123',
              tituloCuento: 'Cuento de Fantasía',
              quizService: mock,
              onVolver: () {},
              cuento: cuento,
              estudianteNombre: 'Estudiante Demo',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Debe mostrar la vista de resultados y el botón de exportación de cuento con resultados
        expect(find.text('Resultado de Comprensión'), findsOneWidget);
        expect(find.text('Exportar Cuento en PDF'), findsOneWidget);

        final quizViewFinder = find.byType(QuizView);
        expect(quizViewFinder, findsOneWidget);
        final quizViewWidget = tester.widget<QuizView>(quizViewFinder);
        expect(quizViewWidget.estudianteNombre, equals('Estudiante Demo'));
        expect(quizViewWidget.cuento?.personajePrincipal, equals('Padas'));
      },
    );
  });
}
