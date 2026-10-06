import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/narracion_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/views/story_view.dart';
import 'package:tesis_investigacion/widgets/ilustracion_escena_widget.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  void Function()? _completionHandler;
  void Function()? _cancelHandler;
  bool isSpeaking = false;
  final List<String> textosHablados = [];

  @override
  void setCompletionHandler(dynamic handler) {
    _completionHandler = handler as void Function()?;
  }

  @override
  void setCancelHandler(dynamic handler) {
    _cancelHandler = handler as void Function()?;
  }

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
  Future<dynamic> speak(String text, {bool focus = false}) async {
    isSpeaking = true;
    textosHablados.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isSpeaking = false;
    _cancelHandler?.call();
    return 1;
  }

  void completarHabla() {
    isSpeaking = false;
    _completionHandler?.call();
  }
}

class FakeAiService extends Fake implements AiService {
  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Test',
      personajePrincipal: 'Leo',
      descripcionPersonaje: 'Desc',
      resumen: 'Resumen',
      escenario: 'Bosque',
      conflictoPrincipal: 'Conflicto',
      finalOriginal: 'Final',
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
    return const GeneratedScene(
      contenido: 'Escena 1',
      opciones: ['Opcion A', 'Opcion B'],
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
    return const GeneratedScene(
      contenido: 'Siguiente escena generada',
      opciones: ['Seguir'],
      esFinal: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pngBytesEscena1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );
  final dataUriEscena1 =
      'data:image/png;base64,${base64Encode(pngBytesEscena1)}';

  final pngBytesEscena2 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
  final dataUriEscena2 =
      'data:image/png;base64,${base64Encode(pngBytesEscena2)}';

  late FakeFlutterTts fakeTts;
  late NarracionService narracionService;
  late StoryController storyController;
  late Cuento cuento;

  setUp(() {
    fakeTts = FakeFlutterTts();
    narracionService = NarracionService(tts: fakeTts);
    storyController = StoryController(
      aiService: FakeAiService(),
      narrativaService: NarrativaService(),
      cuentoRepository: CuentoRepositoryMemoria(),
      documentService: DocumentService(),
    );

    cuento = Cuento(
      id: 'cuento_test_1',
      titulo: 'Aventura en el Bosque',
      personajePrincipal: 'Leo',
      escenas: [
        Escena(
          numero: 1,
          contenido: 'Leo caminaba despacio por el sendero iluminado por luciérnagas doradas.',
          imageUrl: dataUriEscena1,
          opciones: ['Seguir el río', 'Entrar a la cueva'],
        ),
        Escena(
          numero: 2,
          contenido: 'Al llegar a la orilla del río cristalino, escuchó una dulce melodía.',
          imageUrl: dataUriEscena2,
          opciones: ['Cruzar el puente'],
          esFinal: true,
        ),
      ],
    );
  });

  Widget crearStoryView({bool autoNarrar = false}) {
    return MaterialApp(
      home: StoryView(
        cuento: cuento,
        controller: storyController,
        narracionService: narracionService,
        autoNarrar: autoNarrar,
        onSalir: () {},
      ),
    );
  }

  testWidgets(
    'actualizaciones del texto revelado letra a letra no eliminan ni parpadean la imagen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(crearStoryView(autoNarrar: false));
      await tester.pump();

      // Verificar que la ilustración aparece inmediatamente
      expect(find.byType(IlustracionEscenaWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final imgInicial = tester.widget<Image>(find.byType(Image));
      final bytesIniciales = (imgInicial.image as MemoryImage).bytes;
      expect(bytesIniciales, equals(pngBytesEscena1));

      // Comprobar que la ilustración está aislada en un RepaintBoundary
      final repaintBoundaryFinder = find.ancestor(
        of: find.byType(IlustracionEscenaWidget),
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaryFinder, findsWidgets);

      // Comprobar key estable basada en cuentoId y numeroEscena
      final widgetIlustracion = tester.widget<IlustracionEscenaWidget>(
        find.byType(IlustracionEscenaWidget),
      );
      expect(
        widgetIlustracion.key,
        equals(const ValueKey('ilustracion_cuento_test_1_1')),
      );

      // Iniciar la narración y revelado
      await tester.tap(find.text('Escuchar'));
      await tester.pump();

      // Simular múltiples ticks del revelado progresivo (letras apareciendo)
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 35));

        // En cada tick individual: la imagen DEBE seguir existiendo y siendo visible
        expect(find.byType(IlustracionEscenaWidget), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        final imgDurante = tester.widget<Image>(find.byType(Image));
        final bytesDurante = (imgDurante.image as MemoryImage).bytes;

        // La instancia de bytes no debe recrearse ni cambiar
        expect(
          identical(bytesIniciales, bytesDurante),
          isTrue,
          reason: 'Los bytes de la imagen no deben recargarse en cada letra',
        );
      }

      // Detener TTS y narración
      fakeTts.completarHabla();
      await tester.pump();

      expect(find.byType(IlustracionEscenaWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('iniciar y detener TTS no altera ni recrea la ilustración', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(crearStoryView(autoNarrar: false));
    await tester.pump();

    final imgInicial = tester.widget<Image>(find.byType(Image));
    final bytesIniciales = (imgInicial.image as MemoryImage).bytes;

    // 1. Iniciar narración
    await tester.tap(find.text('Escuchar'));
    await tester.pump();
    expect(fakeTts.isSpeaking, isTrue);
    expect(find.byType(IlustracionEscenaWidget), findsOneWidget);

    // 2. Detener narración con el botón Detener
    await tester.tap(find.text('Detener'));
    await tester.pump();
    expect(fakeTts.isSpeaking, isFalse);

    final imgTrasDetener = tester.widget<Image>(find.byType(Image));
    expect(
      identical(bytesIniciales, (imgTrasDetener.image as MemoryImage).bytes),
      isTrue,
    );

    // 3. Volver a narrar usando replay ("Narrar de nuevo")
    await tester.tap(find.byTooltip('Narrar de nuevo'));
    await tester.pump();
    expect(fakeTts.isSpeaking, isTrue);

    final imgTrasReplay = tester.widget<Image>(find.byType(Image));
    expect(
      identical(bytesIniciales, (imgTrasReplay.image as MemoryImage).bytes),
      isTrue,
    );

    // Detener
    fakeTts.completarHabla();
    await tester.pump();
    expect(find.byType(IlustracionEscenaWidget), findsOneWidget);
  });

  testWidgets(
    'imageUrl estable conserva la misma imagen, y cambiar a otra escena sí actualiza la imagen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(crearStoryView(autoNarrar: false));
      await tester.pump();

      // Escena 1
      expect(
        find.text(
          'Leo caminaba despacio por el sendero iluminado por luciérnagas doradas.',
        ),
        findsOneWidget,
      );
      final imgEscena1 = tester.widget<Image>(find.byType(Image));
      final bytesEscena1 = (imgEscena1.image as MemoryImage).bytes;
      expect(bytesEscena1, equals(pngBytesEscena1));

      final ilustracionEscena1 = tester.widget<IlustracionEscenaWidget>(
        find.byType(IlustracionEscenaWidget),
      );
      expect(
        ilustracionEscena1.key,
        equals(const ValueKey('ilustracion_cuento_test_1_1')),
      );

      // Avanzar a la escena 2 usando el botón "Página siguiente"
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();

      // Escena 2
      expect(
        find.text(
          'Al llegar a la orilla del río cristalino, escuchó una dulce melodía.',
        ),
        findsOneWidget,
      );
      expect(find.byType(IlustracionEscenaWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final imgEscena2 = tester.widget<Image>(find.byType(Image));
      final bytesEscena2 = (imgEscena2.image as MemoryImage).bytes;
      expect(bytesEscena2, equals(pngBytesEscena2));
      expect(identical(bytesEscena1, bytesEscena2), isFalse);

      final ilustracionEscena2 = tester.widget<IlustracionEscenaWidget>(
        find.byType(IlustracionEscenaWidget),
      );
      expect(
        ilustracionEscena2.key,
        equals(const ValueKey('ilustracion_cuento_test_1_2')),
      );

      // Retroceder a la escena 1
      await tester.tap(find.byTooltip('Página anterior'));
      await tester.pumpAndSettle();

      final imgEscena1Vuelta = tester.widget<Image>(find.byType(Image));
      final bytesEscena1Vuelta = (imgEscena1Vuelta.image as MemoryImage).bytes;
      expect(bytesEscena1Vuelta, equals(pngBytesEscena1));
    },
  );
}
