import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
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

  Widget crearApp({required Cuento cuento, bool modoHistorico = false}) {
    return MaterialApp(
      home: StoryView(
        cuento: cuento,
        controller: storyController,
        narracionService: narracionService,
        autoNarrar: false,
        modoHistorico: modoHistorico,
        onSalir: () {},
      ),
    );
  }

  group('RF-30 & RF-31: Botón Exportar PDF en StoryView', () {
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

    testWidgets('Muestra botón Exportar PDF cuando la escena es final', (tester) async {
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

      await tester.pumpWidget(crearApp(cuento: cuentoFinalizado));
      await tester.pumpAndSettle();

      expect(find.text('Exportar PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('Muestra botón Exportar PDF en modo historial si la escena es final', (tester) async {
      final cuentoHistorial = Cuento(
        id: 'cuento-historial',
        titulo: 'Cuento Recordado',
        personajePrincipal: 'Sam',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Fin del relato histórico.',
            opciones: ['Terminar'],
            esFinal: true,
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(crearApp(cuento: cuentoHistorial, modoHistorico: true));
      await tester.pumpAndSettle();

      expect(find.text('Exportar PDF'), findsOneWidget);
    });
  });
}
