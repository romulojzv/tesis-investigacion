import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/narracion_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/views/story_view.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  @override
  void setCompletionHandler(dynamic handler) {}
  @override
  void setCancelHandler(dynamic handler) {}
  @override
  void setErrorHandler(dynamic handler) {}
  @override
  Future<dynamic> setLanguage(String language) async => 1;
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> setVolume(double volume) async => 1;
  @override
  Future<dynamic> setPitch(double pitch) async => 1;
  @override
  Future<dynamic> get getVoices async => [];
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;
  @override
  Future<dynamic> stop() async => 1;
}

class FakeAiService extends Fake implements AiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterTts fakeTts;
  late NarracionService narracionService;
  late StoryController storyController;

  setUp(() {
    fakeTts = FakeFlutterTts();
    narracionService = NarracionService(tts: fakeTts);
    storyController = StoryController(
      aiService: FakeAiService(),
      narrativaService: NarrativaService(),
      cuentoRepository: CuentoRepositoryMemoria(),
      documentService: DocumentService(),
    );
  });

  Widget crearApp({
    required Cuento cuento,
    bool modoHistorico = false,
    QuizAttemptSummary? intentoQuiz,
  }) {
    return MaterialApp(
      home: StoryView(
        cuento: cuento,
        controller: storyController,
        narracionService: narracionService,
        autoNarrar: false,
        modoHistorico: modoHistorico,
        intentoQuiz: intentoQuiz,
        onSalir: () {},
      ),
    );
  }

  QuizAttemptSummary crearIntento({required String estado}) {
    return QuizAttemptSummary(
      intentoId: 'int-123',
      cuentoId: 'cuento-1',
      cuentoTitulo: 'Cuento de Prueba',
      estudianteId: 'est-1',
      estudianteNombre: 'Nico Explorador',
      codigoAcceso: 'DEMO26',
      estado: estado,
      puntaje: estado == 'completado' ? 5 : null,
      totalPreguntas: 5,
      porcentaje: estado == 'completado' ? 100 : null,
      createdAt: DateTime.now(),
      completedAt: estado == 'completado' ? DateTime.now() : null,
    );
  }

  group('RF-30 & RF-31: Botón Exportar PDF en StoryView con Control de Quiz', () {
    testWidgets('No muestra botón Exportar PDF si la escena NO es final', (tester) async {
      final cuentoNoFinal = Cuento(
        id: 'cuento-no-final',
        titulo: 'Cuento en Progreso',
        personajePrincipal: 'Leo',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Leo da sus primeros pasos en el bosque misterioso.',
            opciones: ['Ir por la izquierda', 'Ir por la derecha'],
            esFinal: false,
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(crearApp(cuento: cuentoNoFinal));
      await tester.pumpAndSettle();

      expect(find.text('Exportar PDF'), findsNothing);
    });

    testWidgets('Botón Exportar PDF está deshabilitado y muestra advertencia si el quiz no está completado', (tester) async {
      final cuentoFinalizado = Cuento(
        id: 'cuento-final',
        titulo: 'El Gran Tesoro',
        personajePrincipal: 'Valeria',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Valeria abrió el cofre y encontró la gema de la sabiduría.',
            opciones: ['Fin de la aventura'],
            esFinal: true,
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Caso 1: Sin intento de quiz iniciado
      await tester.pumpWidget(crearApp(cuento: cuentoFinalizado, intentoQuiz: null));
      await tester.pumpAndSettle();

      expect(find.text('Exportar PDF'), findsOneWidget);
      // El botón debe estar deshabilitado (onPressed == null)
      final botonDeshabilitado = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Exportar PDF'),
      );
      expect(botonDeshabilitado.onPressed, isNull);

      // Debe mostrar la advertencia pedagógica clara
      expect(
        find.text('Completa primero las preguntas para descargar tu cuento con los resultados'),
        findsOneWidget,
      );

      // Caso 2: Intento de quiz en progreso
      final intentoEnProgreso = crearIntento(estado: 'en_progreso');
      await tester.pumpWidget(crearApp(cuento: cuentoFinalizado, intentoQuiz: intentoEnProgreso));
      await tester.pumpAndSettle();

      final botonEnProgreso = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Exportar PDF'),
      );
      expect(botonEnProgreso.onPressed, isNull);
      expect(
        find.text('Completa primero las preguntas para descargar tu cuento con los resultados'),
        findsOneWidget,
      );
    });

    testWidgets('Botón Exportar PDF está habilitado cuando el quiz está completado', (tester) async {
      final cuentoFinalizado = Cuento(
        id: 'cuento-final',
        titulo: 'El Gran Tesoro',
        personajePrincipal: 'Valeria',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Valeria abrió el cofre y encontró la gema de la sabiduría.',
            opciones: ['Fin de la aventura'],
            esFinal: true,
          ),
        ],
      );

      final intentoCompletado = crearIntento(estado: 'completado');

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(crearApp(cuento: cuentoFinalizado, intentoQuiz: intentoCompletado));
      await tester.pumpAndSettle();

      expect(find.text('Exportar PDF'), findsOneWidget);
      final botonHabilitado = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Exportar PDF'),
      );
      expect(botonHabilitado.onPressed, isNotNull);

      // La advertencia de bloqueo ya no debe aparecer
      expect(
        find.text('Completa primero las preguntas para descargar tu cuento con los resultados'),
        findsNothing,
      );
    });
  });
}
