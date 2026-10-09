// test/quiz_history_and_drawing_test.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_question.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/cuento_repository.dart';
import 'package:tesis_investigacion/repositories/quiz_repository_supabase.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/services/supabase_quiz_service.dart';
import 'package:tesis_investigacion/utils/date_formatter.dart';
import 'package:tesis_investigacion/views/quiz_view.dart';
import 'package:tesis_investigacion/views/story_view.dart';
import 'package:tesis_investigacion/views/student_home_view.dart';

// ============================================================================
// MOCKS & STUBS
// ============================================================================

class MockAiService implements AiService {
  int llamadasGenerarEscena = 0;
  int llamadasGenerarEscenaInicial = 0;
  int llamadasAnalizarHistoria = 0;

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    llamadasAnalizarHistoria++;
    return StoryAnalysis(
      titulo: 'El misterio del agua desaparecida',
      personajePrincipal: 'Ranj',
      descripcionPersonaje: 'Ranj es una joven curiosa y alegre con lentes.',
      resumen: 'El agua del pueblo ha desaparecido.',
      escenario: 'Una aldea soleada.',
      conflictoPrincipal: 'Buscar la fuente del agua.',
      finalOriginal: 'Ranj encuentra el río subterráneo.',
    );
  }

  @override
  Future<GeneratedScene> generarEscenaInicial({
    required String titulo,
    required String personajePrincipal,
    String? personajeOriginal,
    bool esPersonajeNuevo = false,
    required String textoFuente,
    required String resumenOriginal,
    required String escenarioOriginal,
    required String conflictoPrincipal,
    required String finalOriginal,
    String? descripcionPersonaje,
  }) async {
    llamadasGenerarEscenaInicial++;
    return GeneratedScene(
      contenido: 'Escena 1 inicial del cuento',
      opciones: const ['Buscar pistas', 'Ir al pozo'],
      esFinal: false,
    );
  }

  @override
  Future<GeneratedScene> generarEscena({
    required String titulo,
    required String personajePrincipal,
    String? personajeOriginal,
    bool esPersonajeNuevo = false,
    String? descripcionPersonaje,
    required String textoFuente,
    required String resumenOriginal,
    required String escenarioOriginal,
    required String conflictoPrincipal,
    required String finalOriginal,
    required String contextoNarrativo,
    required String decisionActual,
    required int numeroEscena,
    bool esUltimaEscena = false,
  }) async {
    llamadasGenerarEscena++;
    return GeneratedScene(
      contenido: 'Escena $numeroEscena generada',
      opciones: esUltimaEscena ? const [] : const ['Opción A', 'Opción B'],
      esFinal: esUltimaEscena,
    );
  }
}

class MockImageService implements ImageService {
  int llamadasGenerarIlustracion = 0;
  List<SolicitudImagenEscena> solicitudes = [];

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    llamadasGenerarIlustracion++;
    solicitudes.add(solicitud);
    return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  }
}

class MockDocumentService extends Fake implements DocumentService {}

class MockCuentoRepositoryMem implements CuentoRepository {
  final Map<String, Cuento> cuentosGuardados = {};
  int llamadasObtenerCuento = 0;
  int llamadasListar = 0;

  @override
  Future<void> guardarCuento(Cuento cuento) async {
    cuentosGuardados[cuento.id] = cuento;
  }

  @override
  Future<Cuento?> obtenerCuento(String id) async {
    llamadasObtenerCuento++;
    return cuentosGuardados[id];
  }

  @override
  Future<List<Cuento>> listarCuentosPorEstudiante(String estudianteId) async {
    llamadasListar++;
    // Simula listarCuentosPorEstudiante devolviendo encabezados sin escenas cargadas
    return cuentosGuardados.values
        .where((c) => c.estudianteId == estudianteId)
        .map(
          (c) => Cuento(
            id: c.id,
            titulo: c.titulo,
            personajePrincipal: c.personajePrincipal,
            origen: c.origen,
            estudianteId: c.estudianteId,
            aulaId: c.aulaId,
            escenas: const [], // Encabezado resumido sin escenas
          ),
        )
        .toList();
  }
}

class MockQuizService implements QuizService {
  int llamadasGenerar = 0;
  int llamadasEnviar = 0;
  QuizStartResponse? startResponse;
  QuizResult? resultToReturn;

  MockQuizService({this.startResponse, this.resultToReturn});

  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    llamadasGenerar++;
    return startResponse ??
        QuizStartResponse(
          intentoId: 'intento-mock',
          estado: 'en_progreso',
          preguntas: List.generate(
            5,
            (i) => QuizQuestion(
              numero: i + 1,
              pregunta: '¿Pregunta ${i + 1} sobre el misterio del agua?',
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
    llamadasEnviar++;
    return resultToReturn ??
        QuizResult(
          intentoId: intentoId,
          puntaje: 1,
          total: 5,
          porcentaje: 20,
          respuestas: [
            QuizQuestionResult(
              numero: 1,
              pregunta: '¿Pregunta 1 sobre el misterio del agua?',
              opciones: const [
                'Alternativa A1',
                'Alternativa B1',
                'Alternativa C1',
                'Alternativa D1',
              ],
              indiceSeleccionado: 1,
              indiceCorrecto: 1,
              esCorrecta: true,
              explicacion:
                  'Correcto, Ranj investigó las huellas cerca del pozo.',
            ),
            for (var i = 2; i <= 5; i++)
              QuizQuestionResult(
                numero: i,
                pregunta: '¿Pregunta $i sobre el misterio del agua?',
                opciones: [
                  'Alternativa A$i',
                  'Alternativa B$i',
                  'Alternativa C$i',
                  'Alternativa D$i',
                ],
                indiceSeleccionado: 0,
                indiceCorrecto: 2,
                esCorrecta: false,
                explicacion:
                    'La respuesta correcta es la C$i porque el río era subterráneo.',
              ),
          ],
        );
  }
}

class MockQuizRepositoryImpl implements QuizRepository {
  final Map<String, QuizAttemptSummary> intentos = {};

  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async {
    return intentos.values.toList();
  }

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async {
    return {
      for (final i in intentos.values.where(
        (x) => x.estudianteId == estudianteId,
      ))
        i.cuentoId: i,
    };
  }

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async {
    return intentos[cuentoId];
  }
}

// ============================================================================
// MAIN TESTS
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --------------------------------------------------------------------------
  // TIME TESTS (TIME-01, TIME-02)
  // --------------------------------------------------------------------------
  group('TIME ZONE TESTS', () {
    test('TIME-01: Timestamp UTC se convierte mediante hora local para presentación', () {
      final utcDate = DateTime.parse('2026-10-09T00:35:00Z');
      final formattedLocal = DateFormatter.formatearFechaHoraLocal(utcDate);

      final expectedLocal = utcDate.toLocal();
      final expectedDay = expectedLocal.day.toString().padLeft(2, '0');
      final expectedMonth = expectedLocal.month.toString().padLeft(2, '0');
      final expectedYear = expectedLocal.year.toString();
      final expectedHour = expectedLocal.hour.toString().padLeft(2, '0');
      final expectedMin = expectedLocal.minute.toString().padLeft(2, '0');
      final expectedString =
          '$expectedDay/$expectedMonth/$expectedYear $expectedHour:$expectedMin';

      expect(formattedLocal, equals(expectedString));
    });

    test('TIME-02: No se altera timestamp de base de datos al formatear', () {
      final originalUtc = DateTime.parse('2026-10-09T00:35:00Z');
      expect(originalUtc.isUtc, isTrue);

      final _ = DateFormatter.formatearFechaHoraLocal(originalUtc);

      // El objeto original permanece inalterado y en UTC
      expect(originalUtc.isUtc, isTrue);
      expect(originalUtc.toIso8601String(), equals('2026-10-09T00:35:00.000Z'));
    });
  });

  // --------------------------------------------------------------------------
  // QUIZ RESULT TESTS (QUIZ-RESULT-01 .. 07)
  // --------------------------------------------------------------------------
  group('QUIZ RESULT VIEW TESTS', () {
    testWidgets(
      'QUIZ-RESULT-01: Finalizar 5 preguntas NO navega inmediatamente al Home',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var finalizadoLlamado = false;
        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockService,
              onVolver: () {},
              onFinalizado: () {
                finalizadoLlamado = true;
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Responder 5 preguntas
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

        // Comprobar que onFinalizado NO fue llamado inmediatamente tras el submit
        expect(finalizadoLlamado, isFalse);

        // Comprobar que seguimos en la vista del Quiz mostrando el resultado
        expect(find.text('Resultado de Comprensión'), findsOneWidget);
      },
    );

    testWidgets('QUIZ-RESULT-02: Resultado muestra puntaje X de 5', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockService = MockQuizService();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El misterio del agua desaparecida',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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

      expect(find.text('Puntaje: 1 de 5'), findsOneWidget);
    });

    testWidgets('QUIZ-RESULT-03: Resultado muestra porcentaje (20 %)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockService = MockQuizService();

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(
            cuentoId: 'cuento-1',
            tituloCuento: 'El misterio del agua desaparecida',
            quizService: mockService,
            onVolver: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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

      expect(find.text('20 % de aciertos'), findsOneWidget);
    });

    testWidgets(
      'QUIZ-RESULT-04: Después de finalizar se pueden revisar las 5 respuestas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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

        expect(find.text('Revisión de respuestas:'), findsOneWidget);
        for (var i = 1; i <= 5; i++) {
          expect(find.text('Pregunta $i'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'QUIZ-RESULT-05: Respuesta incorrecta muestra selección, correcta y explicación',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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

        // Preguntas 2-5 son incorrectas
        expect(find.text('✗ Incorrecta'), findsWidgets);
        expect(find.text('Tu respuesta: '), findsWidgets);
        expect(find.text('Alternativa A2'), findsOneWidget);
        expect(find.text('Respuesta correcta: '), findsWidgets);
        expect(find.text('Alternativa C2'), findsOneWidget);
        expect(
          find.textContaining(
            'La respuesta correcta es la C2 porque el río era subterráneo.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'QUIZ-RESULT-06: Respuesta correcta también se identifica claramente',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockService,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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

        // Pregunta 1 fue correcta
        expect(find.text('✓ Correcta'), findsWidgets);
        expect(
          find.textContaining(
            'Correcto, Ranj investigó las huellas cerca del pozo.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'QUIZ-RESULT-07: Solo botón explícito de salida vuelve al Home/Mis aventuras',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var finalizadoLlamado = false;
        var volverLlamado = false;
        final mockService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-1',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockService,
              onVolver: () {
                volverLlamado = true;
              },
              onFinalizado: () {
                finalizadoLlamado = true;
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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

        expect(volverLlamado, isFalse);
        expect(finalizadoLlamado, isFalse);

        // Ahora pulsamos explícitamente el botón "Volver a Mis aventuras"
        final botonVolver = find.text('Volver a Mis aventuras');
        expect(botonVolver, findsOneWidget);
        await tester.ensureVisible(botonVolver);
        await tester.pumpAndSettle();
        await tester.tap(botonVolver);
        await tester.pump();

        expect(volverLlamado, isTrue);
        expect(finalizadoLlamado, isTrue);
      },
    );
  });

  // --------------------------------------------------------------------------
  // PDF + DRAWING TESTS (PDF-DRAW-01 .. 06)
  // --------------------------------------------------------------------------
  group('PDF + DRAWING CONSISTENCY TESTS', () {
    final pdfDataMock = PdfStoryData(
      nombreArchivo: 'el_misterio_del_agua.pdf',
      textoExtraido: 'Había una vez en un pueblo un misterio...',
      tituloDetectado: 'El misterio del agua desaparecida',
      personajePrincipalDetectado: 'Ranj',
      descripcionPersonaje:
          'Ranj es una joven curiosa y risueña que usa falda azul.',
      resumen: 'El agua del pueblo ha desaparecido.',
      escenario: 'Una aldea.',
      conflictoPrincipal: 'Buscar agua.',
      finalOriginal: 'Ranj encuentra el manantial.',
    );

    test('PDF-DRAW-01: Mantener personaje + dibujo conserva nombre/personaje original narrativo', () async {
      final aiService = MockAiService();
      final imageService = MockImageService();
      final repo = MockCuentoRepositoryMem();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: MockDocumentService(),
        aiService: aiService,
        imageService: imageService,
      );

      final customization = CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.drawing,
        nombrePersonaje: 'Ranj',
        personajeOriginal: 'Ranj',
      );

      final dibujoPatoBytes = Uint8List.fromList([9, 8, 7, 6]);

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pato-ranj',
        datosPdf: pdfDataMock,
        personalizacion: customization,
        dibujoReferenciaPng: dibujoPatoBytes,
      );

      // Identidad narrativa intacta:
      expect(cuento.personajePrincipal, equals('Ranj'));
      expect(cuento.personajeOriginal, equals('Ranj'));
      expect(cuento.esPersonajeNuevo, isFalse);
      expect(cuento.esModoDibujo, isTrue);
      expect(cuento.origen, equals(CuentoOrigen.pdf));
    });

    test('PDF-DRAW-02: Mantener personaje + dibujo usa PNG del estudiante como referencia visual', () async {
      final aiService = MockAiService();
      final imageService = MockImageService();
      final repo = MockCuentoRepositoryMem();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: MockDocumentService(),
        aiService: aiService,
        imageService: imageService,
      );

      final customization = CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.drawing,
        nombrePersonaje: 'Ranj',
        personajeOriginal: 'Ranj',
      );

      final dibujoPatoBytes = Uint8List.fromList([9, 8, 7, 6]);

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pato-ranj',
        datosPdf: pdfDataMock,
        personalizacion: customization,
        dibujoReferenciaPng: dibujoPatoBytes,
      );

      expect(cuento.referenciaVisualPng, equals(dibujoPatoBytes));

      // Generar ilustración para la escena 1
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(imageService.llamadasGenerarIlustracion, equals(1));
      final sol = imageService.solicitudes.first;
      expect(sol.esModoDibujo, isTrue);
      expect(sol.referenciaVisualBytes, equals(dibujoPatoBytes));
    });

    test('PDF-DRAW-03: Descripción física original del PDF no debe sobreescribir el dibujo', () async {
      final aiService = MockAiService();
      final imageService = MockImageService();
      final repo = MockCuentoRepositoryMem();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: MockDocumentService(),
        aiService: aiService,
        imageService: imageService,
      );

      final customization = CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.drawing,
        nombrePersonaje: 'Ranj',
        personajeOriginal: 'Ranj',
      );

      final dibujoPatoBytes = Uint8List.fromList([9, 8, 7, 6]);

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pato-ranj',
        datosPdf: pdfDataMock,
        personalizacion: customization,
        dibujoReferenciaPng: dibujoPatoBytes,
      );

      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      final sol = imageService.solicitudes.first;
      final descr = sol.descripcionPersonaje;
      // No debe contener los rasgos físicos humanos del PDF ("joven curiosa y risueña que usa falda azul")
      expect(descr?.contains('falda azul') ?? false, isFalse);
    });

    test(
      'PDF-DRAW-04: Modo imagen PDF continúa funcionando con la imagen del PDF',
      () async {
        final aiService = MockAiService();
        final imageService = MockImageService();
        final repo = MockCuentoRepositoryMem();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: MockDocumentService(),
          aiService: aiService,
          imageService: imageService,
        );

        final imagenPdfOriginal = Uint8List.fromList([11, 22, 33]);
        final customization = CharacterCustomization(
          mode: CharacterMode.keepOriginal,
          visualMode: CharacterVisualMode.pdfImages,
          nombrePersonaje: 'Ranj',
          personajeOriginal: 'Ranj',
          imagenReferencia: imagenPdfOriginal,
        );

        final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'cuento-pdf-img',
          datosPdf: pdfDataMock,
          personalizacion: customization,
          dibujoReferenciaPng: imagenPdfOriginal,
        );

        expect(cuento.esModoDibujo, isFalse);
        expect(cuento.referenciaVisualPng, equals(imagenPdfOriginal));

        await controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: 1,
        );

        final sol = imageService.solicitudes.first;
        expect(sol.esModoDibujo, isFalse);
        expect(sol.referenciaVisualBytes, equals(imagenPdfOriginal));
      },
    );

    test('PDF-DRAW-05: Modo automático continúa funcionando sin referencia visual fija obligatoria', () async {
      final aiService = MockAiService();
      final imageService = MockImageService();
      final repo = MockCuentoRepositoryMem();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: MockDocumentService(),
        aiService: aiService,
        imageService: imageService,
      );

      final customization = CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Ranj',
        personajeOriginal: 'Ranj',
      );

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pdf-auto',
        datosPdf: pdfDataMock,
        personalizacion: customization,
      );

      expect(cuento.esModoDibujo, isFalse);
      expect(cuento.referenciaVisualPng, isNull);

      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      final sol = imageService.solicitudes.first;
      expect(sol.esModoDibujo, isFalse);
      expect(sol.referenciaVisualBytes, isNull);
    });

    test('PDF-DRAW-06: No aumenta número de llamadas a Pollinations', () async {
      final aiService = MockAiService();
      final imageService = MockImageService();
      final repo = MockCuentoRepositoryMem();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: MockDocumentService(),
        aiService: aiService,
        imageService: imageService,
      );

      final customization = CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.drawing,
        nombrePersonaje: 'Ranj',
        personajeOriginal: 'Ranj',
      );

      final dibujoBytes = Uint8List.fromList([5, 6, 7]);

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-calls-check',
        datosPdf: pdfDataMock,
        personalizacion: customization,
        dibujoReferenciaPng: dibujoBytes,
      );

      // crearCuentoDesdePdfProcesadoDemo no ilustra todavía (solo genera la escena con texto IA)
      expect(imageService.llamadasGenerarIlustracion, equals(0));

      // 1 llamada por escena ilustrada
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );
      expect(imageService.llamadasGenerarIlustracion, equals(1));
    });
  });

  // --------------------------------------------------------------------------
  // MIS AVENTURAS / HISTORIAL TESTS (HISTORY-01 .. 14)
  // --------------------------------------------------------------------------
  group('MIS AVENTURAS / HISTORIAL TESTS', () {
    final perfilEstudiante = UserProfile(
      id: 'estudiante-1',
      nombre: 'Mateo',
      rol: UserRole.estudiante,
      codigoAcceso: 'MAT123',
    );

    testWidgets(
      'HISTORY-01: listarCuentosPorEstudiante devuelve resumen sin escenas, pero al abrir se llama obtenerCuento(id)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = MockCuentoRepositoryMem();
        final cuentoCompleto = Cuento(
          id: 'cuento-100',
          titulo: 'El misterio del agua desaparecida',
          personajePrincipal: 'Ranj',
          origen: CuentoOrigen.pdf,
          estudianteId: 'estudiante-1',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Ranj observó el pozo seco.',
              opciones: const [],
            ),
            Escena(
              numero: 2,
              contenido: 'Ranj siguió las huellas.',
              opciones: const [],
            ),
          ],
        );
        await repo.guardarCuento(cuentoCompleto);

        Cuento? cuentoAbierto;
        await tester.pumpWidget(
          MaterialApp(
            home: StudentHomeView(
              perfil: perfilEstudiante,
              onDibujar: () {},
              onUsarPdf: () {},
              onAbrirCuento: (c) {
                cuentoAbierto = c;
              },
              onLogout: () {},
              cuentoRepository: repo,
              tabInicial: 1,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verificamos que se listó la tarjeta
        expect(find.text('El misterio del agua desaparecida'), findsOneWidget);

        // Tocamos la tarjeta
        await tester.tap(find.text('El misterio del agua desaparecida'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verificamos que se llamó a obtenerCuento y que cuentoAbierto tiene escenas completas
        expect(repo.llamadasObtenerCuento, equals(1));
        expect(cuentoAbierto, isNotNull);
        expect(cuentoAbierto!.escenas.length, equals(2));
      },
    );

    test('HISTORY-02: Un cuento completo recuperado contiene sus escenas persistidas', () async {
      final repo = MockCuentoRepositoryMem();
      final cuento = Cuento(
        id: 'cuento-200',
        titulo: 'Aventura 2',
        personajePrincipal: 'Pato',
        estudianteId: 'estudiante-1',
        escenas: [
          Escena(numero: 1, contenido: 'Escena 1', opciones: const []),
          Escena(numero: 2, contenido: 'Escena 2', opciones: const []),
          Escena(numero: 3, contenido: 'Escena 3', opciones: const []),
          Escena(
            numero: 4,
            contenido: 'Escena 4',
            opciones: const [],
            esFinal: true,
          ),
        ],
      );
      await repo.guardarCuento(cuento);

      final recuperado = await repo.obtenerCuento('cuento-200');
      expect(recuperado, isNotNull);
      expect(recuperado!.escenas.length, equals(4));
      expect(recuperado.escenas[3].esFinal, isTrue);
    });

    testWidgets(
      'HISTORY-03 & 04: Abrir historia no llama Gemini ni Pollinations',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final aiService = MockAiService();
        final imageService = MockImageService();
        final repo = MockCuentoRepositoryMem();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: MockDocumentService(),
          aiService: aiService,
          imageService: imageService,
        );

        final cuento = Cuento(
          id: 'cuento-historia-1',
          titulo: 'Historia guardada',
          personajePrincipal: 'Ranj',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Escena 1 guardada',
              opciones: const ['Opción A', 'Opción B'],
              imageUrl: 'https://example.com/img1.png',
            ),
            Escena(
              numero: 2,
              contenido: 'Escena 2 guardada',
              opciones: const ['Opción C', 'Opción D'],
              imageUrl: 'https://example.com/img2.png',
            ),
          ],
          decisiones: [
            DecisionNarrativa(
              numeroEscena: 1,
              opcionSeleccionada: 'Opción A elegida',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              modoHistorico: true,
              onSalir: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Navegar a la escena 2
        await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
        await tester.pump();

        // Ninguna llamada a Gemini
        expect(aiService.llamadasGenerarEscena, equals(0));
        expect(aiService.llamadasGenerarEscenaInicial, equals(0));
        // Ninguna llamada a Pollinations
        expect(imageService.llamadasGenerarIlustracion, equals(0));
      },
    );

    testWidgets('HISTORY-05: No permite cambiar decisiones históricas', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: MockCuentoRepositoryMem(),
        documentService: MockDocumentService(),
        aiService: MockAiService(),
      );

      final cuento = Cuento(
        id: 'cuento-historia-2',
        titulo: 'Historia con decisiones',
        personajePrincipal: 'Ranj',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Escena 1 guardada',
            opciones: const ['Buscar pistas', 'Preguntar al sabio'],
          ),
          Escena(
            numero: 2,
            contenido: 'Escena 2 guardada',
            opciones: const [],
            esFinal: true,
          ),
        ],
        decisiones: [
          DecisionNarrativa(
            numeroEscena: 1,
            opcionSeleccionada: 'Buscar pistas',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StoryView(
            cuento: cuento,
            controller: controller,
            modoHistorico: true,
            onSalir: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Muestra la decisión histórica tomada en modo solo lectura
      expect(
        find.textContaining('Decisión tomada: "Buscar pistas"'),
        findsOneWidget,
      );

      // No muestra botones para tomar nuevas opciones
      expect(find.text('Preguntar al sabio'), findsNothing);
    });

    testWidgets('HISTORY-06: Cuento sin Quiz muestra "Preguntas pendientes"', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repoCuentos = MockCuentoRepositoryMem();
      final repoQuiz = MockQuizRepositoryImpl();

      await repoCuentos.guardarCuento(
        Cuento(
          id: 'cuento-sin-quiz',
          titulo: 'Cuento Sin Quiz',
          personajePrincipal: 'Ranj',
          estudianteId: 'estudiante-1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentHomeView(
            perfil: perfilEstudiante,
            onDibujar: () {},
            onUsarPdf: () {},
            onLogout: () {},
            cuentoRepository: repoCuentos,
            quizRepository: repoQuiz,
            tabInicial: 1,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Preguntas pendientes'), findsOneWidget);
    });

    testWidgets(
      'HISTORY-07: Quiz en progreso muestra "Preguntas en progreso"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repoCuentos = MockCuentoRepositoryMem();
        final repoQuiz = MockQuizRepositoryImpl();

        await repoCuentos.guardarCuento(
          Cuento(
            id: 'cuento-en-progreso',
            titulo: 'Cuento En Progreso',
            personajePrincipal: 'Ranj',
            estudianteId: 'estudiante-1',
          ),
        );

        repoQuiz.intentos['cuento-en-progreso'] = QuizAttemptSummary(
          intentoId: 'i-prog',
          cuentoId: 'cuento-en-progreso',
          cuentoTitulo: 'Cuento En Progreso',
          estudianteId: 'estudiante-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: 'MAT123',
          estado: 'en_progreso',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StudentHomeView(
              perfil: perfilEstudiante,
              onDibujar: () {},
              onUsarPdf: () {},
              onLogout: () {},
              cuentoRepository: repoCuentos,
              quizRepository: repoQuiz,
              tabInicial: 1,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Preguntas en progreso'), findsOneWidget);
      },
    );

    testWidgets('HISTORY-08: Quiz completado muestra "Resultado: X/5 · XX %"', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repoCuentos = MockCuentoRepositoryMem();
      final repoQuiz = MockQuizRepositoryImpl();

      await repoCuentos.guardarCuento(
        Cuento(
          id: 'cuento-comp',
          titulo: 'El misterio del agua desaparecida',
          personajePrincipal: 'Ranj',
          estudianteId: 'estudiante-1',
        ),
      );

      repoQuiz.intentos['cuento-comp'] = QuizAttemptSummary(
        intentoId: 'i-comp',
        cuentoId: 'cuento-comp',
        cuentoTitulo: 'El misterio del agua desaparecida',
        estudianteId: 'estudiante-1',
        estudianteNombre: 'Mateo',
        codigoAcceso: 'MAT123',
        estado: 'completado',
        puntaje: 1,
        totalPreguntas: 5,
        porcentaje: 20,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentHomeView(
            perfil: perfilEstudiante,
            onDibujar: () {},
            onUsarPdf: () {},
            onLogout: () {},
            cuentoRepository: repoCuentos,
            quizRepository: repoQuiz,
            tabInicial: 1,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Resultado: 1/5 · 20 %'), findsOneWidget);
    });

    testWidgets(
      'HISTORY-09: Quiz completado permite abrir "Ver mi resultado"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repoCuentos = MockCuentoRepositoryMem();
        final repoQuiz = MockQuizRepositoryImpl();

        final cuento = Cuento(
          id: 'cuento-comp',
          titulo: 'El misterio del agua desaparecida',
          personajePrincipal: 'Ranj',
          estudianteId: 'estudiante-1',
        );
        await repoCuentos.guardarCuento(cuento);

        final intento = QuizAttemptSummary(
          intentoId: 'i-comp',
          cuentoId: 'cuento-comp',
          cuentoTitulo: 'El misterio del agua desaparecida',
          estudianteId: 'estudiante-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: 'MAT123',
          estado: 'completado',
          puntaje: 1,
          totalPreguntas: 5,
          porcentaje: 20,
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
        );
        repoQuiz.intentos['cuento-comp'] = intento;

        Cuento? cuentoResultado;
        QuizAttemptSummary? intentoResultado;

        await tester.pumpWidget(
          MaterialApp(
            home: StudentHomeView(
              perfil: perfilEstudiante,
              onDibujar: () {},
              onUsarPdf: () {},
              onVerResultado: (c, i) {
                cuentoResultado = c;
                intentoResultado = i;
              },
              onLogout: () {},
              cuentoRepository: repoCuentos,
              quizRepository: repoQuiz,
              tabInicial: 1,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final botonVer = find.text('Ver mi resultado');
        expect(botonVer, findsOneWidget);

        await tester.tap(botonVer);
        await tester.pump();

        expect(cuentoResultado?.id, equals('cuento-comp'));
        expect(intentoResultado?.intentoId, equals('i-comp'));
      },
    );

    testWidgets(
      'HISTORY-10 & 11: Ver resultado histórico no crea otro intento ni llama Gemini',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final resultadoExistente = QuizResult(
          intentoId: 'i-guardado',
          puntaje: 1,
          total: 5,
          porcentaje: 20,
          respuestas: [
            QuizQuestionResult(
              numero: 1,
              pregunta: '¿Pregunta 1?',
              opciones: const ['A', 'B', 'C', 'D'],
              indiceSeleccionado: 0,
              indiceCorrecto: 0,
              esCorrecta: true,
              explicacion: 'Explicación 1',
            ),
          ],
        );

        final mockQuizService = MockQuizService();

        await tester.pumpWidget(
          MaterialApp(
            home: QuizView(
              cuentoId: 'cuento-comp',
              tituloCuento: 'El misterio del agua desaparecida',
              quizService: mockQuizService,
              resultadoInicial: resultadoExistente,
              onVolver: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Como resultadoInicial ya estaba provisto, no se hace generarQuiz ni enviarQuiz
        expect(mockQuizService.llamadasGenerar, equals(0));
        expect(mockQuizService.llamadasEnviar, equals(0));
        expect(find.text('Puntaje: 1 de 5'), findsOneWidget);
      },
    );

    testWidgets(
      'HISTORY-12: Al terminar Quiz y volver a Mis aventuras se refresca el resultado',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repoCuentos = MockCuentoRepositoryMem();
        final repoQuiz = MockQuizRepositoryImpl();

        await repoCuentos.guardarCuento(
          Cuento(
            id: 'cuento-refresco',
            titulo: 'El misterio del agua',
            personajePrincipal: 'Ranj',
            estudianteId: 'estudiante-1',
          ),
        );

        // Inicialmente en progreso
        repoQuiz.intentos['cuento-refresco'] = QuizAttemptSummary(
          intentoId: 'i-prog',
          cuentoId: 'cuento-refresco',
          cuentoTitulo: 'El misterio del agua',
          estudianteId: 'estudiante-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: 'MAT123',
          estado: 'en_progreso',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StudentHomeView(
              perfil: perfilEstudiante,
              onDibujar: () {},
              onUsarPdf: () {},
              onLogout: () {},
              cuentoRepository: repoCuentos,
              quizRepository: repoQuiz,
              tabInicial: 1,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Preguntas en progreso'), findsOneWidget);

        // El servidor completa el quiz
        repoQuiz.intentos['cuento-refresco'] = QuizAttemptSummary(
          intentoId: 'i-prog',
          cuentoId: 'cuento-refresco',
          cuentoTitulo: 'El misterio del agua',
          estudianteId: 'estudiante-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: 'MAT123',
          estado: 'completado',
          puntaje: 1,
          totalPreguntas: 5,
          porcentaje: 20,
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
        );

        // Al regresar del quiz se recrea la vista
        await tester.pumpWidget(
          MaterialApp(
            home: StudentHomeView(
              key: const ValueKey('retorno-despues-de-quiz'),
              perfil: perfilEstudiante,
              onDibujar: () {},
              onUsarPdf: () {},
              onLogout: () {},
              cuentoRepository: repoCuentos,
              quizRepository: repoQuiz,
              tabInicial: 1,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Resultado: 1/5 · 20 %'), findsOneWidget);
      },
    );

    testWidgets(
      'HISTORY-13: Abrir un cuento histórico reutiliza imágenes persistidas y NO solicita regeneración',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final imageService = MockImageService();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: MockCuentoRepositoryMem(),
          documentService: MockDocumentService(),
          aiService: MockAiService(),
          imageService: imageService,
        );

        final cuento = Cuento(
          id: 'c-historico-img',
          titulo: 'Cuento con fotos',
          personajePrincipal: 'Ranj',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Escena con imagen guardada',
              imageUrl: 'https://example.com/foto1.png',
              opciones: const [],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              modoHistorico: true,
              onSalir: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(imageService.llamadasGenerarIlustracion, equals(0));
      },
    );

    testWidgets(
      'HISTORY-14: Si una imagen histórica no existe, abrir el cuento NO llama Pollinations',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final imageService = MockImageService();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: MockCuentoRepositoryMem(),
          documentService: MockDocumentService(),
          aiService: MockAiService(),
          imageService: imageService,
        );

        final cuento = Cuento(
          id: 'c-sin-foto',
          titulo: 'Cuento sin foto',
          personajePrincipal: 'Ranj',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Escena sin imagen',
              imageUrl: null,
              opciones: const [],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              modoHistorico: true,
              onSalir: () {},
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No debe llamar a generar imagen en modo histórico
        expect(imageService.llamadasGenerarIlustracion, equals(0));
      },
    );
  });
}
