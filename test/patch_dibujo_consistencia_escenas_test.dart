import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/narrativa_config.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/auth_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/utils/visual_description_helper.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tesis_investigacion/services/narracion_service.dart';
import 'package:tesis_investigacion/views/story_view.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  void Function()? _completionHandler;
  void Function()? _cancelHandler;
  bool isSpeaking = false;

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

class MockAiServiceTestable implements AiService {
  final List<Map<String, dynamic>> llamadas = [];
  bool simularIaDevuelveEsFinalPrematuro = false;

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Cuento Pollito',
      personajePrincipal: 'Pollito Pepe',
      descripcionPersonaje: 'Pollito amarillo con cabeza roja',
      resumen: 'Aventura del pollito',
      escenario: 'Granja soleada',
      conflictoPrincipal: 'Encontrar el maíz',
      finalOriginal: 'Come felizmente',
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
    llamadas.add({
      'tipo': 'inicial',
      'personajePrincipal': personajePrincipal,
      'descripcionPersonaje': descripcionPersonaje,
    });
    return GeneratedScene(
      contenido: '$personajePrincipal inicia su aventura en la granja.',
      opciones: const ['Ir al corral', 'Explorar el molino'],
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
    llamadas.add({
      'tipo': 'escena',
      'numeroEscena': numeroEscena,
      'personajePrincipal': personajePrincipal,
      'descripcionPersonaje': descripcionPersonaje,
      'esUltimaEscena': esUltimaEscena,
    });

    // Simula si la IA intentara devolver esFinal=true prematuramente en escenas intermedias
    final esFinalRetorno = esUltimaEscena || simularIaDevuelveEsFinalPrematuro;

    await Future.delayed(const Duration(milliseconds: 50));

    return GeneratedScene(
      contenido:
          '$personajePrincipal continuó la historia (Escena $numeroEscena).',
      opciones: esFinalRetorno ? const [] : const ['Opción A', 'Opción B'],
      esFinal: esFinalRetorno,
    );
  }
}

class MockImageServiceTestable implements ImageService {
  final List<SolicitudImagenEscena> solicitudes = [];

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    solicitudes.add(solicitud);
    final bytesFake = Uint8List.fromList([
      137, 80, 78, 71, // PNG
      solicitud.numeroEscena,
      solicitud.numeroEscena + 42,
    ]);
    return 'data:image/png;base64,${base64Encode(bytesFake)}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakePngBytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3, 4]);

  group('A. Flujo de dibujo y persistencia de descripcion_personaje', () {
    test('crearCuentoInicialDemo genera y persiste descripcion_personaje no nula para dibujo', () async {
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceTestable();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
      );

      final cuento = await controller.crearCuentoInicialDemo(
        id: 'cuento-pollito-01',
        nombrePersonaje: 'Pollito Pepe',
        dibujoReferenciaPng: fakePngBytes,
      );

      // A.1: descripcion_personaje no es null ni vacía
      expect(cuento.descripcionPersonaje, isNotNull);
      expect(cuento.descripcionPersonaje!.trim(), isNotEmpty);
      expect(cuento.descripcionPersonaje, contains('pollito'));

      // A.2: se conserva al persistir y recargar
      final recuperado = await repo.obtenerCuento('cuento-pollito-01');
      expect(recuperado, isNotNull);
      expect(recuperado!.descripcionPersonaje, cuento.descripcionPersonaje);

      // A.3: el flujo posterior de generarSiguienteEscena pasa la descripción correcta a la IA
      await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: cuento.escenas.first.opciones.first,
      );

      expect(mockAi.llamadas.length, 1);
      expect(
        mockAi.llamadas.first['descripcionPersonaje'],
        cuento.descripcionPersonaje,
      );
      expect(mockAi.llamadas.first['descripcionPersonaje'], isNot('(null)'));
    });

    test('derivarDescripcionVisualBase genera rasgos estables coherentes', () {
      final descPollito = derivarDescripcionVisualBase(
        nombrePersonaje: 'Mi Pollito',
      );
      expect(descPollito, contains('pollito'));
      expect(descPollito, contains('amarillo'));

      final descConejo = derivarDescripcionVisualBase(
        nombrePersonaje: 'Conejito Blanco',
      );
      expect(descConejo, contains('conejito'));

      final descGeneral = derivarDescripcionVisualBase(
        nombrePersonaje: 'Lucas',
      );
      expect(descGeneral, contains('Lucas'));
    });
  });

  group('B. Control de doble invocación', () {
    test('StoryController bloquea doble invocación concurrente de generarSiguienteEscena', () async {
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceTestable();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
      );

      final cuento = await controller.crearCuentoInicialDemo(
        id: 'cuento-doble-01',
        nombrePersonaje: 'Lucas',
        dibujoReferenciaPng: fakePngBytes,
      );

      final primeraEscena = cuento.escenas.first;

      // Disparo concurrentemente dos llamadas
      final fut1 = controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: primeraEscena,
        decision: primeraEscena.opciones.first,
      );

      // La segunda invocación concurrente debe ser rechazada de inmediato
      expect(
        () => controller.generarSiguienteEscena(
          cuento: cuento,
          escenaActual: primeraEscena,
          decision: primeraEscena.opciones.first,
        ),
        throwsA(isA<StateError>()),
      );

      final res1 = await fut1;
      expect(res1.numero, 2);
      expect(mockAi.llamadas.length, 1);
    });

    testWidgets(
      'StoryView bloquea taps repetidos y realiza exactamente 1 invocación',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = CuentoRepositoryMemoria();
        final mockAi = MockAiServiceTestable();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: DocumentService(),
          aiService: mockAi,
        );

        final cuento = await controller.crearCuentoInicialDemo(
          id: 'cuento-widget-tap',
          nombrePersonaje: 'Lucas',
          dibujoReferenciaPng: fakePngBytes,
        );

        final fakeTts = FakeFlutterTts();
        final narracionService = NarracionService(tts: fakeTts);

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              narracionService: narracionService,
              autoNarrar: false,
              onSalir: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        final opcionBtn = find.text(cuento.escenas.first.opciones.first);
        expect(opcionBtn, findsOneWidget);

        // Doble tap rápido en el botón
        await tester.tap(opcionBtn);
        await tester.tap(opcionBtn);
        await tester.pumpAndSettle();

        // Exactamente 1 llamada a la IA
        expect(mockAi.llamadas.length, 1);
      },
    );
  });

  group('C. Límite de escenas (maxEscenas = 4)', () {
    test('con maxEscenas=4, escenas 1, 2, 3 tienen esFinal=false y escena 4 tiene esFinal=true', () async {
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceTestable();
      // Simulamos que la IA intentó devolver esFinal=true en escena 2
      mockAi.simularIaDevuelveEsFinalPrematuro = true;

      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
        narrativaConfig: const NarrativaConfig(maxEscenas: 4),
      );

      final cuento = await controller.crearCuentoInicialDemo(
        id: 'cuento-4escenas',
        nombrePersonaje: 'Pollito',
        dibujoReferenciaPng: fakePngBytes,
      );

      // Escena 1
      expect(cuento.escenas.first.numero, 1);
      expect(cuento.escenas.first.esFinal, isFalse);

      // Escena 2: la regla dura debe forzar esFinal=false a pesar de simularIaDevuelveEsFinalPrematuro
      final esc2 = await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: cuento.escenas.last.opciones.first,
      );
      expect(esc2.numero, 2);
      expect(esc2.esFinal, isFalse);
      expect(esc2.opciones, isNotEmpty);

      // Escena 3: esFinal=false
      final esc3 = await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: esc2,
        decision: esc2.opciones.first,
      );
      expect(esc3.numero, 3);
      expect(esc3.esFinal, isFalse);
      expect(esc3.opciones, isNotEmpty);

      // Escena 4: esFinal=true
      final esc4 = await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: esc3,
        decision: esc3.opciones.first,
      );
      expect(esc4.numero, 4);
      expect(esc4.esFinal, isTrue);
      expect(esc4.opciones, isEmpty);
    });
  });

  group('D. Consistencia de request de imagen', () {
    test('escena 1 usa dibujo original; escena 2+ incluye referencia original + anchor de escena previa', () async {
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceTestable();
      final mockImage = MockImageServiceTestable();

      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
        imageService: mockImage,
      );

      final cuento = await controller.crearCuentoInicialDemo(
        id: 'cuento-anchor-test',
        nombrePersonaje: 'Pollito Pepe',
        dibujoReferenciaPng: fakePngBytes,
      );

      // Generar ilustración escena 1
      final url1 = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );
      expect(url1, isNotNull);
      expect(mockImage.solicitudes.length, 1);
      // Escena 1: tiene referencia visual original y NO tiene anchor anterior
      expect(
        mockImage.solicitudes[0].referenciaVisualBytes,
        equals(fakePngBytes),
      );
      expect(mockImage.solicitudes[0].referenciaAnteriorBytes, isNull);
      expect(mockImage.solicitudes[0].esModoDibujo, isTrue);
      expect(
        mockImage.solicitudes[0].descripcionPersonaje,
        cuento.descripcionPersonaje,
      );

      // Generar escena 2
      final esc2 = await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: cuento.escenas.first.opciones.first,
      );

      // Generar ilustración escena 2
      final url2 = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 2,
      );
      expect(url2, isNotNull);
      expect(mockImage.solicitudes.length, 2);

      // Escena 2: TIENE referencia original + anchor anterior (escena 1)
      expect(
        mockImage.solicitudes[1].referenciaVisualBytes,
        equals(fakePngBytes),
      );
      expect(mockImage.solicitudes[1].referenciaAnteriorBytes, isNotNull);
      expect(mockImage.solicitudes[1].esModoDibujo, isTrue);
      expect(
        mockImage.solicitudes[1].descripcionPersonaje,
        cuento.descripcionPersonaje,
      );

      // Generar escena 3
      await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: esc2,
        decision: esc2.opciones.first,
      );

      // Generar ilustración escena 3
      final url3 = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 3,
      );
      expect(url3, isNotNull);
      expect(mockImage.solicitudes.length, 3);

      // Escena 3: TIENE referencia original + anchor anterior (escena 2)
      expect(
        mockImage.solicitudes[2].referenciaVisualBytes,
        equals(fakePngBytes),
      );
      expect(mockImage.solicitudes[2].referenciaAnteriorBytes, isNotNull);
      expect(mockImage.solicitudes[2].esModoDibujo, isTrue);
    });

    test(
      'en cuento origen PDF, esModoDibujo se establece estrictamente en false',
      () async {
        final repo = CuentoRepositoryMemoria();
        final mockAi = MockAiServiceTestable();
        final mockImage = MockImageServiceTestable();

        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: DocumentService(),
          aiService: mockAi,
          imageService: mockImage,
        );

        final cuentoPdf = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'cuento-pdf-test',
          datosPdf: PdfStoryData(
            nombreArchivo: 'historia.pdf',
            textoExtraido: 'Había una vez un conejo en el bosque.',
          ),
          personalizacion: CharacterCustomization(
            mode: CharacterMode.keepOriginal,
            visualMode: CharacterVisualMode.automatic,
            nombrePersonaje: 'Conejo Sabio',
          ),
        );

        final url = await controller.asegurarIlustracionEscena(
          cuento: cuentoPdf,
          numeroEscena: 1,
        );
        expect(url, isNotNull);
        expect(mockImage.solicitudes.length, 1);
        expect(mockImage.solicitudes.first.esModoDibujo, isFalse);
      },
    );
  });

  group('E. Normalización de código de acceso a MAYÚSCULAS', () {
    test('normalizarCodigoAcceso recorta y convierte a mayúsculas', () {
      expect(
        AuthService.normalizarCodigoAcceso('  4a26-001  '),
        equals('4A26-001'),
      );
      expect(
        AuthService.normalizarCodigoAcceso('estudiante-c'),
        equals('ESTUDIANTE-C'),
      );
    });
  });
}
