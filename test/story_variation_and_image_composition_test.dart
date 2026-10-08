import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';

class FakeAiService implements AiService {
  int llamadasGenerarEscena = 0;
  int llamadasGenerarEscenaInicial = 0;

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Cuento de Prueba',
      tituloOriginal: 'Original',
      personajePrincipal: 'Leo',
      descripcionPersonaje: 'Un león valiente con melena dorada',
      resumen: 'Una aventura en la selva',
      escenario: 'La gran selva verde',
      conflictoPrincipal: 'El río se secó',
      finalOriginal: 'Encontraron el manantial',
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
    return const GeneratedScene(
      contenido: 'Leo comienza su viaje por la selva en busca del manantial.',
      opciones: ['Cruzar el puente de lianas', 'Bordear la colina'],
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
      contenido:
          'Escena $numeroEscena: $personajePrincipal siguió la decisión: $decisionActual.',
      opciones: const ['Avanzar', 'Esperar'],
      esFinal: esUltimaEscena,
    );
  }
}

class MockImageService implements ImageService {
  int llamadasGeneracion = 0;
  final List<SolicitudImagenEscena> solicitudes = [];

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    llamadasGeneracion++;
    solicitudes.add(solicitud);
    return 'data:image/webp;base64,UklGRkAAAABXRUJQVlA4IDQAAADwAQCdASoBAAEAAQAcJaACdLoAAP7/2QAA';
  }
}

void main() {
  group('Variación de Escena 1 y Composición Visual de Escenas 2-4', () {
    late NarrativaService narrativaService;
    late CuentoRepositoryMemoria repo;
    late FakeAiService aiService;
    late DocumentService docService;
    late MockImageService imageService;
    late StoryController controller;

    setUp(() {
      narrativaService = NarrativaService();
      repo = CuentoRepositoryMemoria();
      aiService = FakeAiService();
      docService = DocumentService();
      imageService = MockImageService();
      controller = StoryController(
        narrativaService: narrativaService,
        cuentoRepository: repo,
        documentService: docService,
        aiService: aiService,
        imageService: imageService,
      );
    });

    test('STORY-VAR-01: Dos protagonistas/contextos diferentes no reciben una introducción fija idéntica', () {
      final escenaPollito = narrativaService.crearEscenaInicialDemo(
        nombrePersonaje: 'Pepe',
        descripcionPersonaje:
            'Un pollito amarillo con plumas suaves y pico naranja',
      );

      final escenaCaballero = narrativaService.crearEscenaInicialDemo(
        nombrePersonaje: 'Padas',
        descripcionPersonaje:
            'Un valiente caballero con armadura plateada y capa azul',
      );

      expect(escenaPollito.contenido, isNot(equals(escenaCaballero.contenido)));
      expect(
        escenaPollito.contenido,
        isNot(contains('abrió los ojos y descubrió un lugar lleno de luces')),
      );
      expect(
        escenaCaballero.contenido,
        isNot(contains('abrió los ojos y descubrió un lugar lleno de luces')),
      );
    });

    test('STORY-VAR-02: La primera escena utiliza información disponible del personaje/contexto', () {
      final escenaAve = narrativaService.crearEscenaInicialDemo(
        nombrePersonaje: 'Piolín',
        descripcionPersonaje: 'Un canario pequeño de plumas amarillas',
      );
      expect(
        escenaAve.contenido.contains('granja') ||
            escenaAve.contenido.contains('huerto') ||
            escenaAve.contenido.contains('jardín') ||
            escenaAve.contenido.contains('pico') ||
            escenaAve.contenido.contains('semillas'),
        isTrue,
      );

      final escenaRobot = narrativaService.crearEscenaInicialDemo(
        nombrePersonaje: 'Tuerquitas',
        descripcionPersonaje:
            'Un robot con engranajes dorados y antena luminosa',
      );
      expect(
        escenaRobot.contenido.contains('taller') ||
            escenaRobot.contenido.contains('ciudad futura') ||
            escenaRobot.contenido.contains('luces') ||
            escenaRobot.contenido.contains('antena'),
        isTrue,
      );
    });

    test('IMG-SCENE-01: El prompt de imagen contiene el contenido de la escena actual', () {
      const solicitud = SolicitudImagenEscena(
        cuentoId: 'c1',
        numeroEscena: 3,
        contenidoEscena: 'Se escondió detrás de un arbusto y vio hojas musicales formando una espiral dorada.',
        nombreProtagonista: 'Pepe',
      );

      final prompt = solicitud.construirPrompt();
      expect(prompt, contains('Se escondió detrás de un arbusto'));
      expect(prompt, contains('hojas musicales formando una espiral dorada'));
    });

    test('IMG-SCENE-02: El prompt establece que la referencia previa es para IDENTIDAD, no para copiar pose/fondo/composición', () {
      const solicitud = SolicitudImagenEscena(
        cuentoId: 'c1',
        numeroEscena: 2,
        contenidoEscena: 'Pepe salta sobre una roca brillante en el arroyo.',
        nombreProtagonista: 'Pepe',
      );

      final prompt = solicitud.construirPrompt();
      expect(
        prompt,
        contains('The previous image is a CHARACTER IDENTITY reference only'),
      );
      expect(
        prompt,
        contains(
          'Do not copy its pose, camera angle, background, scenery, or composition',
        ),
      );
      expect(
        prompt,
        contains(
          'Create a genuinely new illustration that depicts the CURRENT scene text',
        ),
      );
      expect(
        prompt,
        contains('same pose, same camera framing, same background'),
      );
    });

    test('IMG-SCENE-03: Dos escenas con textos distintos producen prompts visuales distintos', () {
      const sol1 = SolicitudImagenEscena(
        cuentoId: 'c1',
        numeroEscena: 2,
        contenidoEscena: 'Pepe camina bajo los girasoles gigantes.',
        nombreProtagonista: 'Pepe',
      );

      const sol2 = SolicitudImagenEscena(
        cuentoId: 'c1',
        numeroEscena: 3,
        contenidoEscena:
            'Pepe navega en una cáscara de nuez por el río cristalino.',
        nombreProtagonista: 'Pepe',
      );

      final prompt1 = sol1.construirPrompt();
      final prompt2 = sol2.construirPrompt();

      expect(prompt1, isNot(equals(prompt2)));
      expect(prompt1, contains('girasoles gigantes'));
      expect(prompt2, contains('cáscara de nuez'));
    });

    test('IMG-SCENE-04: Se preservan identidad, colores, forma y detalles distintivos en el prompt', () {
      const sol = SolicitudImagenEscena(
        cuentoId: 'c1',
        numeroEscena: 2,
        contenidoEscena: 'Lucas encuentra un mapa.',
        nombreProtagonista: 'Lucas',
        descripcionPersonaje:
            'Dinosaurio verde con crestas amarillas y ojos grandes',
        esModoDibujo: true,
      );

      final prompt = sol.construirPrompt();
      expect(
        prompt,
        contains('Dinosaurio verde con crestas amarillas y ojos grandes'),
      );
      expect(prompt, contains('conserva fielmente la identidad, silueta'));
      expect(prompt, contains('colores dominantes'));
      expect(prompt, contains('detalles distintivos'));
    });

    test('IMG-SCENE-05: No se añade una llamada adicional a Pollinations por escena', () async {
      final dibujoBytes = Uint8List.fromList([1, 2, 3, 4]);
      final cuento = await controller.crearCuentoInicialDemo(
        id: 'c1',
        nombrePersonaje: 'Pepe',
        dibujoReferenciaPng: dibujoBytes,
      );

      expect(imageService.llamadasGeneracion, 0);

      // Solicitar ilustración para escena 1
      final url1 = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(url1, isNotNull);
      expect(imageService.llamadasGeneracion, 1);

      // Si se vuelve a llamar para la misma escena, NO genera nueva llamada
      final urlReutilizada = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(urlReutilizada, equals(url1));
      expect(imageService.llamadasGeneracion, 1);
    });

    test('IMG-SCENE-06: Modo dibujo sigue usando dibujo original + continuidad visual', () async {
      final dibujoBytes = Uint8List.fromList([10, 20, 30, 40]);
      final cuento = await controller.crearCuentoInicialDemo(
        id: 'c-dibujo',
        nombrePersonaje: 'Pollito',
        dibujoReferenciaPng: dibujoBytes,
        descripcionPersonaje: 'Pollito amarillo con gorrito azul',
      );

      // Generar escena 1
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(
        imageService.solicitudes.first.referenciaVisualBytes,
        equals(dibujoBytes),
      );
      expect(imageService.solicitudes.first.esModoDibujo, isTrue);

      // Agregar escena 2
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Pollito entra en el establo iluminado.',
          opciones: const ['Subir a la paja', 'Saludar a la vaca'],
        ),
      );

      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 2,
      );

      final solEscena2 = imageService.solicitudes[1];
      expect(solEscena2.referenciaVisualBytes, equals(dibujoBytes));
      expect(solEscena2.referenciaAnteriorBytes, isNotNull);
      expect(solEscena2.esModoDibujo, isTrue);
    });

    test(
      'STORY-VAR-02 & IMG-SCENE-07: PDF / automático no se rompen',
      () async {
        final cuentoPdf = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'c-pdf',
          datosPdf: PdfStoryData(
            nombreArchivo: 'selva.pdf',
            textoExtraido: 'Había una vez un león...',
            tituloDetectado: 'La gran selva',
            resumen: 'Un león busca agua',
            escenario: 'Selva tropical',
            conflictoPrincipal: 'Sequía en el río',
            finalOriginal: 'Lluvia mágica',
          ),
          personalizacion: CharacterCustomization(
            mode: CharacterMode.newCharacter,
            visualMode: CharacterVisualMode.automatic,
            nombrePersonaje: 'Leo',
          ),
        );

        expect(cuentoPdf.escenas.length, 1);
        expect(cuentoPdf.escenas.first.numero, 1);
        expect(cuentoPdf.escenas.first.contenido, contains('Leo'));

        // Ilustrar escena 1 PDF
        final url = await controller.asegurarIlustracionEscena(
          cuento: cuentoPdf,
          numeroEscena: 1,
        );

        expect(url, isNotNull);
        expect(imageService.solicitudes.last.esModoDibujo, isFalse);
      },
    );
  });
}
