// test/quiz_module_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_question.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/quiz_repository_supabase.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/services/supabase_quiz_service.dart';
import 'package:tesis_investigacion/views/quiz_view.dart';
import 'package:tesis_investigacion/views/story_view.dart';
import 'package:tesis_investigacion/views/teacher_home_view.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';

class _DummyAiService extends Fake implements AiService {}

class MockQuizService implements QuizService {
  QuizStartResponse? startResponse;
  QuizResult? submitResult;
  Object? errorToThrowOnStart;
  Object? errorToThrowOnSubmit;
  List<QuizAnswerSubmission>? lastSubmittedAnswers;
  String? lastSubmittedIntentoId;

  MockQuizService({this.startResponse, this.submitResult});

  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    if (errorToThrowOnStart != null) throw errorToThrowOnStart!;
    return startResponse ??
        QuizStartResponse(
          intentoId: 'intento-123',
          estado: 'en_progreso',
          preguntas: List.generate(
            5,
            (i) => QuizQuestion(
              numero: i + 1,
              pregunta: '¿Pregunta número ${i + 1} de la historia?',
              opciones: [
                'Alternativa A${i + 1}',
                'Alternativa B${i + 1}',
                'Alternativa C${i + 1}',
                'Alternativa D${i + 1}',
              ],
            ),
          ),
        );
  }

  @override
  Future<QuizResult> enviarQuiz({
    required String intentoId,
    required List<QuizAnswerSubmission> respuestas,
  }) async {
    if (errorToThrowOnSubmit != null) throw errorToThrowOnSubmit!;
    lastSubmittedIntentoId = intentoId;
    lastSubmittedAnswers = respuestas;

    return submitResult ??
        QuizResult(
          intentoId: intentoId,
          puntaje: 4,
          total: 5,
          porcentaje: 80,
          respuestas: List.generate(
            5,
            (i) => QuizQuestionResult(
              numero: i + 1,
              pregunta: '¿Pregunta número ${i + 1} de la historia?',
              opciones: [
                'Alternativa A${i + 1}',
                'Alternativa B${i + 1}',
                'Alternativa C${i + 1}',
                'Alternativa D${i + 1}',
              ],
              indiceSeleccionado: i == 4 ? 0 : 1,
              indiceCorrecto: 1,
              esCorrecta: i != 4,
              explicacion: 'Explicación de la pregunta ${i + 1}.',
            ),
          ),
        );
  }
}

class MockQuizRepository implements QuizRepository {
  List<QuizAttemptSummary> resultados;
  MockQuizRepository({this.resultados = const []});

  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async {
    return resultados;
  }

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async {
    return {for (final r in resultados) r.cuentoId: r};
  }

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async {
    try {
      return resultados.firstWhere((r) => r.cuentoId == cuentoId);
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuizView Widget Tests', () {
    testWidgets('1. QuizView muestra 1 de 5 y estructura inicial', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockService = MockQuizService();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El Bosque Mágico',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      // Esperar carga asíncrona de generarQuiz
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Comprueba lo que recuerdas'), findsOneWidget);
      expect(find.text('Pregunta 1 de 5'), findsOneWidget);
      expect(find.text('¿Pregunta número 1 de la historia?'), findsOneWidget);
      expect(find.text('Alternativa A1'), findsOneWidget);
      expect(find.text('Alternativa B1'), findsOneWidget);
      expect(find.text('Alternativa C1'), findsOneWidget);
      expect(find.text('Alternativa D1'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('2. No permite avanzar sin seleccionar ninguna alternativa', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockService = MockQuizService();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El Bosque Mágico',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tocar siguiente sin haber seleccionado opción
      await tester.tap(find.text('Siguiente'));
      await tester.pump();

      // Debe mostrar advertencia y seguir en Pregunta 1
      expect(
        find.text('Por favor, selecciona una respuesta para continuar.'),
        findsOneWidget,
      );
      expect(find.text('Pregunta 1 de 5'), findsOneWidget);
    });

    testWidgets('3. Conserva selección al volver atrás y avanzar de nuevo', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockService = MockQuizService();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El Bosque Mágico',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Seleccionar Alternativa B1 (índice 1) en Pregunta 1
      await tester.tap(find.text('Alternativa B1'));
      await tester.pump();

      // Avanzar a la Pregunta 2
      await tester.tap(find.text('Siguiente'));
      await tester.pump();

      expect(find.text('Pregunta 2 de 5'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);

      // Volver a la Pregunta 1
      await tester.tap(find.text('Anterior'));
      await tester.pump();

      expect(find.text('Pregunta 1 de 5'), findsOneWidget);
      // Avanzar de nuevo sin tocar nada debe funcionar porque ya está seleccionada B1
      await tester.tap(find.text('Siguiente'));
      await tester.pump();

      expect(find.text('Pregunta 2 de 5'), findsOneWidget);
    });

    testWidgets(
      '4. NO muestra si la respuesta es correcta ni explicación antes de finalizar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El Bosque Mágico',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Seleccionar una opción
        await tester.tap(find.text('Alternativa A1'));
        await tester.pump();

        // Verificar que no existen indicadores de resultado
        expect(find.text('✓ Correcta'), findsNothing);
        expect(find.text('✗ Incorrecta'), findsNothing);
        expect(find.textContaining('Explicación:'), findsNothing);
      },
    );

    testWidgets(
      '5. En la pregunta 5 muestra "Finalizar preguntas" y envía exactamente 5 respuestas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El Bosque Mágico',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Responder preguntas 1 a 4
        for (var i = 1; i <= 4; i++) {
          await tester.tap(find.text('Alternativa B$i'));
          await tester.pump();
          await tester.tap(find.text('Siguiente'));
          await tester.pump();
        }

        // Ahora estamos en la pregunta 5
        expect(find.text('Pregunta 5 de 5'), findsOneWidget);
        expect(find.text('Finalizar preguntas'), findsOneWidget);

        // Seleccionar opción en la pregunta 5
        await tester.tap(find.text('Alternativa A5'));
        await tester.pump();

        // Tocar Finalizar preguntas
        await tester.tap(find.text('Finalizar preguntas'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verificar que mockService recibió exactamente 5 respuestas
        expect(mockService.lastSubmittedAnswers, isNotNull);
        expect(mockService.lastSubmittedAnswers!.length, 5);
        expect(mockService.lastSubmittedAnswers![0].numero, 1);
        expect(mockService.lastSubmittedAnswers![0].indiceSeleccionado, 1);
        expect(mockService.lastSubmittedAnswers![4].numero, 5);
        expect(mockService.lastSubmittedAnswers![4].indiceSeleccionado, 0);
      },
    );

    testWidgets(
      '6. Muestra puntaje del servidor, desglose, revisión y explicaciones al finalizar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService(
          submitResult: QuizResult(
            intentoId: 'intento-123',
            puntaje: 4,
            total: 5,
            porcentaje: 80,
            respuestas: [
              for (var i = 1; i <= 5; i++)
                QuizQuestionResult(
                  numero: i,
                  pregunta: '¿Pregunta número $i de la historia?',
                  opciones: [
                    'Alternativa A$i',
                    'Alternativa B$i',
                    'Alternativa C$i',
                    'Alternativa D$i',
                  ],
                  indiceSeleccionado: i == 5 ? 0 : 1,
                  indiceCorrecto: 1,
                  esCorrecta: i != 5,
                  explicacion: 'Explicación detallada de la pregunta $i.',
                ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El Bosque Mágico',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Responder las 5 preguntas
        for (var i = 1; i <= 5; i++) {
          await tester.tap(find.text('Alternativa B$i'));
          await tester.pump();
          if (i < 5) {
            await tester.tap(find.text('Siguiente'));
            await tester.pump();
          } else {
            await tester.tap(find.text('Finalizar preguntas'));
            await tester.pump();
          }
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Vista de resultados
        expect(find.text('Resultado de Comprensión'), findsOneWidget);
        expect(find.text('Puntaje: 4 de 5'), findsOneWidget);
        expect(find.text('80 % de aciertos'), findsOneWidget);
        expect(find.text('Revisión de respuestas:'), findsOneWidget);
        expect(find.textContaining('Volver'), findsOneWidget);

        // Indicadores visuales de acierto y error
        expect(find.text('✓ Correcta'), findsWidgets);
        expect(find.text('✗ Incorrecta'), findsWidgets);

        // Explicación visible tras finalizar
        expect(
          find.text('Explicación detallada de la pregunta 1.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('7. Manejo de error 401 Unauthorized', (tester) async {
      final mockService = MockQuizService();
      mockService.errorToThrowOnStart = StateError(
        'Tu sesión no es válida o ha expirado.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El Bosque Mágico',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Tu sesión no es válida o ha expirado.'),
        findsOneWidget,
      );
    });

    testWidgets('8. Manejo de error 403 Forbidden', (tester) async {
      final mockService = MockQuizService();
      mockService.errorToThrowOnStart = StateError(
        'No tienes permiso para acceder a esta evaluación.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El Bosque Mágico',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('No tienes permiso para acceder a esta evaluación.'),
        findsOneWidget,
      );
    });
  });

  group('StoryView Quiz Navigation Tests', () {
    testWidgets(
      '9. Botón "Ir a las preguntas" llama al callback onIrEvaluacion',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final cuento = Cuento(
          id: 'c1',
          titulo: 'Aventura Final',
          personajePrincipal: 'Leo',
          textoFuente: 'Historia',
          escenas: [
            Escena(
              numero: 4,
              contenido: 'Escena 4 final',
              opciones: const [],
              esFinal: true,
            ),
          ],
        );

        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: CuentoRepositoryMemoria(),
          documentService: DocumentService(),
          aiService: _DummyAiService(),
        );

        bool evaluacionPulsada = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              autoNarrar: false,
              onSalir: () {},
              onIrEvaluacion: () {
                evaluacionPulsada = true;
              },
            ),
          ),
        );

        await tester.pump();

        // Verificar que el botón "Ir a las preguntas" esté presente en la escena final
        final botonIrPreguntas = find.text('Ir a las preguntas');
        expect(botonIrPreguntas, findsOneWidget);

        await tester.tap(botonIrPreguntas);
        await tester.pump();

        expect(evaluacionPulsada, isTrue);
      },
    );
  });

  group('TeacherHomeView Quiz Results Tests', () {
    final perfilDocente = UserProfile(
      id: 'docente-1',
      nombre: 'Profesor Carlos',
      rol: UserRole.docente,
    );

    testWidgets(
      '10. TeacherHomeView muestra estado vacío cuando no hay resultados',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repoVacio = MockQuizRepository(resultados: []);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repoVacio,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Resultados de Comprensión Lectora 📊'),
          findsOneWidget,
        );
        expect(
          find.text('No hay resultados de comprensión todavía.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '11. TeacherHomeView muestra resultados y abre diálogo de detalle',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final intentoSummary = QuizAttemptSummary(
          intentoId: 'intento-1',
          cuentoId: 'cuento-1',
          cuentoTitulo: 'La aventura de Lucas',
          estudianteId: 'est-1',
          estudianteNombre: 'Estudiante C',
          codigoAcceso: '4A01',
          estado: 'completado',
          puntaje: 4,
          totalPreguntas: 5,
          porcentaje: 80,
          createdAt: DateTime(2026, 10, 8, 10, 30),
          completedAt: DateTime(2026, 10, 8, 10, 35),
          respuestas: [
            const QuizQuestionResult(
              numero: 1,
              pregunta: '¿Qué encontró Lucas?',
              opciones: ['Un perro', 'Un gato', 'Un pez', 'Un pájaro'],
              indiceSeleccionado: 1,
              indiceCorrecto: 1,
              esCorrecta: true,
              explicacion: 'Encontró a su gato en el árbol.',
            ),
          ],
        );

        final repoConResultados = MockQuizRepository(
          resultados: [intentoSummary],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repoConResultados,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Resultados de Comprensión Lectora 📊'),
          findsOneWidget,
        );
        expect(find.text('1 resultado(s)'), findsOneWidget);

        // Seleccionar estudiante en la tabla jerárquica
        final itemEstudiante = find.text('Estudiante C');
        expect(itemEstudiante, findsOneWidget);
        await tester.tap(itemEstudiante);
        await tester.pump();

        // Vista de resultados del estudiante
        expect(find.text('Resultados de Estudiante C'), findsOneWidget);
        expect(find.text('La aventura de Lucas'), findsOneWidget);
        expect(find.text('4/5'), findsOneWidget);
        expect(find.text('80 %'), findsOneWidget);

        // Abrir detalle
        final btnVerRespuestas = find.text('Ver respuestas');
        expect(btnVerRespuestas, findsOneWidget);
        await tester.tap(btnVerRespuestas);
        await tester.pump();

        // Diálogo de detalle
        expect(find.text('Detalle: La aventura de Lucas'), findsOneWidget);
        expect(find.text('Pregunta 1'), findsOneWidget);
        expect(find.text('¿Qué encontró Lucas?'), findsOneWidget);
        expect(
          find.text('Explicación: Encontró a su gato en el árbol.'),
          findsOneWidget,
        );
        expect(find.text('Cerrar'), findsOneWidget);

        await tester.tap(find.text('Cerrar'));
        await tester.pump();
        expect(find.text('Detalle: La aventura de Lucas'), findsNothing);
      },
    );
  });
}
