import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/views/story_view.dart';

class MockImageService implements ImageService {
  int llamadasGenerar = 0;
  final List<SolicitudImagenEscena> solicitudesRecibidas = [];
  bool fallar = false;
  Duration delay = Duration.zero;

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    llamadasGenerar++;
    solicitudesRecibidas.add(solicitud);
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (fallar) {
      throw StateError('Error simulado al generar imagen');
    }
    return 'https://supabase.co/storage/v1/object/public/cuentos/${solicitud.cuentoId}/escenas/escena_${solicitud.numeroEscena}.webp';
  }
}

class FakeAiServiceImageTest implements AiService {
  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Historia de prueba',
      personajePrincipal: 'Pepe',
      descripcionPersonaje: 'Lleva mochila roja',
      resumen: 'Resumen',
      escenario: 'Colina',
      conflictoPrincipal: 'Agua',
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
    return GeneratedScene(
      contenido: 'Pepe comienza su aventura.',
      opciones: const ['Subir la colina', 'Buscar en el bosque'],
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
    return GeneratedScene(
      contenido: 'Pepe continúa la historia en la escena $numeroEscena.',
      opciones: esUltimaEscena ? const [] : const ['Opción A', 'Opción B'],
      esFinal: esUltimaEscena,
    );
  }
}

void main() {
  group('Arquitectura y ciclo de vida de imágenes por escena', () {
    late CuentoRepositoryMemoria repository;
    late MockImageService mockImageService;
    late StoryController controller;

    setUp(() {
      repository = CuentoRepositoryMemoria();
      mockImageService = MockImageService();
      controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: FakeAiServiceImageTest(),
        imageService: mockImageService,
      );
    });

    test('escena con imageUrl existente NO solicita generación (reutilización estricta)', () async {
      final cuento = Cuento(
        id: 'cuento-reutilizar-img',
        titulo: 'Aventura',
        personajePrincipal: 'Pepe',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Escena con imagen previa',
            imageUrl: 'https://example.com/existente.webp',
          ),
        ],
      );

      final url = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(url, 'https://example.com/existente.webp');
      // Nunca debe llamar al ImageService si ya existe la imagen
      expect(mockImageService.llamadasGenerar, 0);
    });

    test(
      'solicitudes concurrentes duplicadas para la misma escena se bloquean',
      () async {
        mockImageService.delay = const Duration(milliseconds: 100);

        final cuento = Cuento(
          id: 'cuento-concurrente-img',
          titulo: 'Aventura',
          personajePrincipal: 'Pepe',
          escenas: [Escena(numero: 1, contenido: 'Escena sin imagen aún')],
        );

        // Lanzamos dos solicitudes casi simultáneas (simulando doble clic)
        final future1 = controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: 1,
        );
        final future2 = controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: 1,
        );

        final resultados = await Future.wait([future1, future2]);

        // Solo una llamada real al servicio
        expect(mockImageService.llamadasGenerar, 1);
        // Una llamada obtuvo la URL y la duplicada fue bloqueada (retorna null o la previa)
        expect(resultados.any((r) => r != null), isTrue);
      },
    );

    test('fallo de generación de imagen NO bloquea la historia', () async {
      mockImageService.fallar = true;

      final cuento = Cuento(
        id: 'cuento-error-img',
        titulo: 'Aventura',
        personajePrincipal: 'Pepe',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Escena donde la imagen falla',
            opciones: const ['Seguir adelante'],
          ),
        ],
      );

      // La solicitud de imagen retorna null sin arrojar excepción que rompa el flujo
      final url = await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );
      expect(url, isNull);

      // La narrativa sigue funcionando y puede generarse la escena 2
      final escena2 = await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: 'Seguir adelante',
      );

      expect(escena2.numero, 2);
      expect(cuento.escenas.length, 2);
    });

    test('máximo 1 imagen por escena y máximo 4 por cuento completo', () async {
      final cuento = Cuento(
        id: 'cuento-limite-4-img',
        titulo: 'Aventura',
        personajePrincipal: 'Pepe',
        descripcionPersonaje: 'Lleva una mochila roja',
      );

      // Generar 4 escenas progresivamente
      for (var i = 1; i <= 4; i++) {
        final escena = Escena(
          numero: i,
          contenido: 'Contenido de la escena $i',
          esFinal: i == 4,
        );
        cuento.agregarEscena(escena);

        // Asegurar imagen para esta escena
        final url = await controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: i,
        );
        expect(url, isNotNull);
        expect(url, contains('escena_$i.webp'));
      }

      expect(mockImageService.llamadasGenerar, 4);
      expect(cuento.escenas.length, 4);

      // Volver a consultar todas las escenas (por ejemplo, al releer)
      for (var i = 1; i <= 4; i++) {
        await controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: i,
        );
      }

      // No se generaron imágenes extras
      expect(mockImageService.llamadasGenerar, 4);
    });

    testWidgets(
      'StoryView maneja navegación atrás/adelante sin regenerar imágenes existentes',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cuento = Cuento(
          id: 'cuento-ui-img',
          titulo: 'La aventura de Pepe',
          personajePrincipal: 'Pepe',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Pepe observó la colina alta.',
              imageUrl: 'https://example.com/escena_1.webp',
            ),
            Escena(
              numero: 2,
              contenido: 'Pepe llegó a la cima.',
              imageUrl: 'https://example.com/escena_2.webp',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              autoNarrar: false,
              onSalir: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Al tener ya imagen en ambas escenas, cero llamadas de generación
        expect(mockImageService.llamadasGenerar, 0);

        // Avanzar a la escena 2
        final botonAvanzar = find.byTooltip('Página siguiente');
        expect(botonAvanzar, findsOneWidget);
        await tester.tap(botonAvanzar);
        await tester.pumpAndSettle();

        // Retroceder a la escena 1
        final botonRetroceder = find.byTooltip('Página anterior');
        expect(botonRetroceder, findsOneWidget);
        await tester.tap(botonRetroceder);
        await tester.pumpAndSettle();

        // No se generaron llamadas innecesarias
        expect(mockImageService.llamadasGenerar, 0);
      },
    );

    testWidgets(
      'StoryView muestra error si falla la imagen y permite reintentar manualmente',
      (tester) async {
        mockImageService.fallar = true;

        final cuento = Cuento(
          id: 'cuento-ui-error',
          titulo: 'La aventura de Pepe',
          personajePrincipal: 'Pepe',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Pepe exploró el bosque.',
              opciones: const ['Avanzar'],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              cuento: cuento,
              controller: controller,
              autoNarrar: false,
              onSalir: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No pudimos crear la ilustración.'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);

        // El servicio se recupera y el usuario presiona Reintentar
        mockImageService.fallar = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(mockImageService.llamadasGenerar, 2);
        expect(cuento.escenas.first.imageUrl, isNotNull);
      },
    );
  });
}
