import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/views/character_customization_view.dart';

class MockAiServiceRecordable implements AiService {
  final List<Map<String, dynamic>> llamadas = [];

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Cuento de prueba',
      personajePrincipal: 'Pedro',
      descripcionPersonaje: 'mochila morada, pelo de colores, estatura alta',
      resumen: 'Resumen de prueba',
      escenario: 'Un valle encantado',
      conflictoPrincipal: 'Buscar la gema',
      finalOriginal: 'Encuentra la gema',
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
      'esPersonajeNuevo': esPersonajeNuevo,
    });
    return GeneratedScene(
      contenido: '$personajePrincipal inicia su viaje con su mochila morada.',
      opciones: const ['Cruzar el puente', 'Bajar al río'],
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
      'esPersonajeNuevo': esPersonajeNuevo,
    });
    return GeneratedScene(
      contenido: '$personajePrincipal continuó la aventura según la decisión.',
      opciones: esUltimaEscena ? const [] : const ['Seguir', 'Descansar'],
      esFinal: esUltimaEscena,
    );
  }
}

class MockImageServiceRecordable implements ImageService {
  final List<SolicitudImagenEscena> solicitudes = [];

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    solicitudes.add(solicitud);
    // Retorna un data URI ficticio válido con bytes reconocibles
    final bytes = Uint8List.fromList([
      137, 80, 78, 71, // PNG magic
      solicitud.numeroEscena,
      solicitud.numeroEscena + 10,
    ]);
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}

void main() {
  group('Pruebas de consistencia visual y descripción canónica', () {
    test(
      '1. Descripción nueva no reutiliza descripción del cuento anterior',
      () async {
        final repo = CuentoRepositoryMemoria();
        final mockAi = MockAiServiceRecordable();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: DocumentService(),
          aiService: mockAi,
        );

        final pdfData = PdfStoryData(
          nombreArchivo: 'cuento.pdf',
          textoExtraido: 'Pedro caminaba por el sendero...',
          personajePrincipalDetectado: 'Pedro',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        // Cuento 1 con descripción específica
        final cuento1 = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'cuento-1',
          datosPdf: pdfData,
          personalizacion: CharacterCustomization(
            nombrePersonaje: 'Pedro',
            mode: CharacterMode.newCharacter,
            visualMode: CharacterVisualMode.automatic,
            descripcionPersonaje:
                'mochila morada, pelo de colores, estatura alta',
          ),
        );

        expect(
          cuento1.descripcionPersonaje,
          'mochila morada, pelo de colores, estatura alta',
        );

        // Cuento 2 sin descripción (modo keepOriginal o descripción distinta)
        final cuento2 = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'cuento-2',
          datosPdf: pdfData,
          personalizacion: CharacterCustomization(
            nombrePersonaje: 'Pedro',
            mode: CharacterMode.keepOriginal,
            visualMode: CharacterVisualMode.automatic,
            descripcionPersonaje: null,
          ),
        );

        // Cuento 2 no debe haber heredado nada de cuento 1
        expect(cuento2.descripcionPersonaje, isNull);
        expect(cuento1.descripcionPersonaje, isNotNull);
      },
    );

    testWidgets('2. Hint de descripción no se convierte en valor real', (
      tester,
    ) async {
      CharacterCustomization? resultado;

      final pdfData = PdfStoryData(
        nombreArchivo: 'historia.pdf',
        textoExtraido: 'Había una vez...',
        personajePrincipalDetectado: 'Sam',
        imagenesExtraidas: [],
        estadoImagenes: EstadoImagenesPdf.sinImagenes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        ),
      );

      // Elegir crear mi propio protagonista
      await tester.tap(find.text('Crear mi propio protagonista'));
      await tester.pumpAndSettle();

      // Ingresar únicamente el nombre, dejando la descripción vacía
      final campoNombre = find.widgetWithText(
        TextField,
        'Nombre del nuevo protagonista',
      );
      await tester.enterText(campoNombre, 'Mateo');
      await tester.pumpAndSettle();

      // El hint no debe ser tomado como texto
      final continuarBtn = find.text('Continuar');
      await tester.ensureVisible(continuarBtn);
      await tester.tap(continuarBtn);
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.nombrePersonaje, 'Mateo');
      expect(
        resultado!.descripcionPersonaje,
        isNull,
        reason: 'Si el usuario no escribe descripción, debe ser estrictamente null, nunca el hint',
      );
    });

    test(
      '3. DB round-trip mantiene exactamente descripcionPersonaje',
      () async {
        final repo = CuentoRepositoryMemoria();
        const descripcionExacta =
            'mochila morada, pelo de colores, estatura alta';

        final cuento = Cuento(
          id: 'cuento-roundtrip-test',
          titulo: 'La prueba de la mochila',
          personajePrincipal: 'Pedro',
          descripcionPersonaje: descripcionExacta,
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Pedro dio un paso al frente.',
              opciones: const ['Opción 1'],
            ),
          ],
        );

        await repo.guardarCuento(cuento);
        final recuperado = await repo.obtenerCuento('cuento-roundtrip-test');

        expect(recuperado, isNotNull);
        expect(recuperado!.descripcionPersonaje, equals(descripcionExacta));
      },
    );

    test(
      '4. generar-escena y AiService reciben la descripción correcta',
      () async {
        final repo = CuentoRepositoryMemoria();
        final mockAi = MockAiServiceRecordable();
        final controller = StoryController(
          narrativaService: NarrativaService(),
          cuentoRepository: repo,
          documentService: DocumentService(),
          aiService: mockAi,
        );

        const descEsperada = 'mochila morada, pelo de colores, estatura alta';

        final pdfData = PdfStoryData(
          nombreArchivo: 'cuento.pdf',
          textoExtraido: 'Texto original de Pedro...',
          personajePrincipalDetectado: 'Pedro',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
          id: 'cuento-ia-test',
          datosPdf: pdfData,
          personalizacion: CharacterCustomization(
            nombrePersonaje: 'Pedro',
            mode: CharacterMode.newCharacter,
            visualMode: CharacterVisualMode.automatic,
            descripcionPersonaje: descEsperada,
          ),
        );

        // Verificar escena 1
        expect(mockAi.llamadas.length, 1);
        expect(
          mockAi.llamadas.first['descripcionPersonaje'],
          equals(descEsperada),
        );

        // Avanzar a escena 2
        await controller.generarSiguienteEscena(
          cuento: cuento,
          escenaActual: cuento.escenas.first,
          decision: 'Cruzar el puente',
        );

        expect(mockAi.llamadas.length, 2);
        expect(
          mockAi.llamadas[1]['descripcionPersonaje'],
          equals(descEsperada),
        );
      },
    );

    test(
      '5. Cuento A y cuento B no mezclan descripción en repositorio',
      () async {
        final repo = CuentoRepositoryMemoria();

        final cuentoA = Cuento(
          id: 'cuento-A',
          titulo: 'Historia A',
          personajePrincipal: 'Pedro',
          descripcionPersonaje:
              'mochila morada, pelo de colores, estatura alta',
        );

        final cuentoB = Cuento(
          id: 'cuento-B',
          titulo: 'Historia B',
          personajePrincipal: 'Pedro',
          descripcionPersonaje: 'capa azul y espada de madera',
        );

        await repo.guardarCuento(cuentoA);
        await repo.guardarCuento(cuentoB);

        final recA = await repo.obtenerCuento('cuento-A');
        final recB = await repo.obtenerCuento('cuento-B');

        expect(
          recA!.descripcionPersonaje,
          'mochila morada, pelo de colores, estatura alta',
        );
        expect(recB!.descripcionPersonaje, 'capa azul y espada de madera');
      },
    );

    test('6. Modo automático: escena 1 usa text-to-image y escenas 2-4 usan imagen de escena 1 como referencia', () async {
      final mockImage = MockImageServiceRecordable();
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceRecordable();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
        imageService: mockImage,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Pedro salía al bosque...',
        personajePrincipalDetectado: 'Pedro',
        imagenesExtraidas: [],
        estadoImagenes: EstadoImagenesPdf.sinImagenes,
      );

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-auto-ref',
        datosPdf: pdfData,
        personalizacion: CharacterCustomization(
          nombrePersonaje: 'Pedro',
          mode: CharacterMode.newCharacter,
          visualMode: CharacterVisualMode.automatic,
          descripcionPersonaje:
              'mochila morada, pelo de colores, estatura alta',
        ),
      );

      // Antes de generar escena 1, no hay referencia visual
      expect(cuento.obtenerReferenciaVisualParaEscena(1), isNull);
      expect(cuento.obtenerReferenciaVisualParaEscena(2), isNull);

      // Generar ilustración de escena 1
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );

      expect(mockImage.solicitudes.length, 1);
      expect(
        mockImage.solicitudes[0].referenciaVisualBytes != null,
        isFalse,
        reason: 'Escena 1 en modo automático debe usar text-to-image (sin referencia)',
      );

      // Escena 1 generó la imagen y la registró como referencia canónica
      expect(cuento.referenciaGeneradaEscena1Bytes, isNotNull);

      // Ahora escenas 2, 3 y 4 deben usar la imagen generada de escena 1 como referencia
      expect(
        cuento.obtenerReferenciaVisualParaEscena(2),
        equals(cuento.referenciaGeneradaEscena1Bytes),
      );
      expect(
        cuento.obtenerReferenciaVisualParaEscena(3),
        equals(cuento.referenciaGeneradaEscena1Bytes),
      );
      expect(
        cuento.obtenerReferenciaVisualParaEscena(4),
        equals(cuento.referenciaGeneradaEscena1Bytes),
      );

      // Avanzar a escena 2 y asegurar ilustración
      await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: 'Cruzar el puente',
      );
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 2,
      );

      expect(mockImage.solicitudes.length, 2);
      expect(
        mockImage.solicitudes[1].referenciaVisualBytes != null,
        isTrue,
        reason: 'Escena 2 debe usar la ilustración de escena 1 como referencia',
      );
      expect(
        mockImage.solicitudes[1].referenciaVisualBytes,
        equals(cuento.referenciaGeneradaEscena1Bytes),
      );
    });

    test('7. La referencia base no cambia entre escenas 2-4 (evita drift acumulativo)', () async {
      final mockImage = MockImageServiceRecordable();
      final repo = CuentoRepositoryMemoria();
      final mockAi = MockAiServiceRecordable();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: mockAi,
        imageService: mockImage,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Pedro salía al bosque...',
        personajePrincipalDetectado: 'Pedro',
        imagenesExtraidas: [],
        estadoImagenes: EstadoImagenesPdf.sinImagenes,
      );

      final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-no-drift',
        datosPdf: pdfData,
        personalizacion: CharacterCustomization(
          nombrePersonaje: 'Pedro',
          mode: CharacterMode.newCharacter,
          visualMode: CharacterVisualMode.automatic,
          descripcionPersonaje:
              'mochila morada, pelo de colores, estatura alta',
        ),
      );

      // Generar escena 1
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 1,
      );
      final refEscena1 = cuento.referenciaGeneradaEscena1Bytes;
      expect(refEscena1, isNotNull);

      // Generar escena 2
      await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: 'Cruzar el puente',
      );
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 2,
      );

      // Generar escena 3
      await controller.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: 'Seguir',
      );
      await controller.asegurarIlustracionEscena(
        cuento: cuento,
        numeroEscena: 3,
      );

      // Las solicitudes de escena 2 y 3 deben usar EXACTAMENTE la referencia de escena 1
      expect(
        mockImage.solicitudes[1].referenciaVisualBytes,
        equals(refEscena1),
      );
      expect(
        mockImage.solicitudes[2].referenciaVisualBytes,
        equals(refEscena1),
      );
      // No deben usar la imagen generada en la escena 2 para la escena 3
      expect(
        cuento.obtenerReferenciaVisualParaEscena(3),
        equals(cuento.obtenerReferenciaVisualParaEscena(2)),
      );
    });

    test('8. Dibujo del estudiante / Imagen del PDF tienen prioridad sobre imagen generada', () async {
      final dibujoEstudiante = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

      final cuento = Cuento(
        id: 'cuento-dibujo-prioridad',
        titulo: 'Aventura con dibujo',
        personajePrincipal: 'Pedro',
        descripcionPersonaje: 'mochila morada, pelo de colores, estatura alta',
        referenciaVisualPng: dibujoEstudiante,
      );

      // Simular que de alguna forma se registra una escena 1 generada
      final escena1Bytes = Uint8List.fromList([99, 98, 97]);
      cuento.registrarReferenciaEscena1(escena1Bytes);

      // Para escena 1 y para cualquier escena subsiguiente, debe mantenerse el dibujo del estudiante
      expect(
        cuento.obtenerReferenciaVisualParaEscena(1),
        equals(dibujoEstudiante),
      );
      expect(
        cuento.obtenerReferenciaVisualParaEscena(2),
        equals(dibujoEstudiante),
      );
      expect(
        cuento.obtenerReferenciaVisualParaEscena(3),
        equals(dibujoEstudiante),
      );
      expect(
        cuento.obtenerReferenciaVisualParaEscena(4),
        equals(dibujoEstudiante),
      );
    });

    test('9. Cambios temporales en la escena no modifican la ficha base', () {
      const descBase = 'mochila morada, pelo de colores, estatura alta';
      final cuento = Cuento(
        id: 'cuento-cambio-temp',
        titulo: 'Lluvia en el bosque',
        personajePrincipal: 'Pedro',
        descripcionPersonaje: descBase,
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Empezó a llover fuertemente y Pedro se colocó una capucha amarilla temporal para protegerse.',
            opciones: const ['Buscar refugio'],
          ),
        ],
      );

      // El contenido de la escena describe un cambio temporal (capucha amarilla),
      // pero la ficha canónica permanece intacta.
      expect(cuento.descripcionPersonaje, equals(descBase));

      // Construir prompt de imagen
      final solicitud = SolicitudImagenEscena(
        cuentoId: cuento.id,
        numeroEscena: 1,
        nombreProtagonista: cuento.personajePrincipal,
        descripcionPersonaje: cuento.descripcionPersonaje,
        contenidoEscena: cuento.escenas.first.contenido,
      );

      final prompt = solicitud.construirPrompt();
      expect(
        prompt,
        contains(
          'Rasgos base permanentes del protagonista: mochila morada, pelo de colores, estatura alta',
        ),
      );
      expect(
        prompt,
        contains('Cualquier cambio de ropa o accesorio es puramente temporal'),
      );
      expect(cuento.descripcionPersonaje, equals(descBase));
    });

    test('10. Nombre Pedro no se transforma automáticamente en Pedrito', () {
      final solicitud = SolicitudImagenEscena(
        cuentoId: 'cuento-nombre-estricto',
        numeroEscena: 1,
        nombreProtagonista: 'Pedro',
        descripcionPersonaje: 'mochila morada, pelo de colores, estatura alta',
        contenidoEscena: 'Pedro cruza un río.',
      );

      final prompt = solicitud.construirPrompt();
      expect(prompt, contains('Protagonista: Pedro'));
      expect(prompt, isNot(contains('Pedrito')));
    });
  });
}
