import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/views/character_customization_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Generador de imagen JPEG 100% válida para decodificación en Flutter
  Uint8List crearJpegValido({int tamanoMinimo = 8500}) {
    final baseJpeg = <int>[
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x01,
      0x00,
      0x48,
      0x00,
      0x48,
      0x00,
      0x00,
      0xFF,
      0xDB,
      0x00,
      0x43,
      0x00,
      0x08,
      0x06,
      0x06,
      0x07,
      0x06,
      0x05,
      0x08,
      0x07,
      0x07,
      0x07,
      0x09,
      0x09,
      0x08,
      0x0A,
      0x0C,
      0x14,
      0x0D,
      0x0C,
      0x0B,
      0x0B,
      0x0C,
      0x19,
      0x12,
      0x13,
      0x0F,
      0x14,
      0x1D,
      0x1A,
      0x1F,
      0x1E,
      0x1D,
      0x1A,
      0x1C,
      0x1C,
      0x20,
      0x24,
      0x2E,
      0x27,
      0x20,
      0x22,
      0x2C,
      0x23,
      0x1C,
      0x1C,
      0x28,
      0x37,
      0x29,
      0x2C,
      0x30,
      0x31,
      0x34,
      0x34,
      0x34,
      0x1F,
      0x27,
      0x39,
      0x3D,
      0x38,
      0x32,
      0x3C,
      0x2E,
      0x33,
      0x34,
      0x32,
      0xFF,
      0xC0,
      0x00,
      0x0B,
      0x08,
      0x00,
      0x01,
      0x00,
      0x01,
      0x01,
      0x01,
      0x11,
      0x00,
      0xFF,
      0xC4,
      0x00,
      0x1F,
      0x00,
      0x00,
      0x01,
      0x05,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0A,
      0x0B,
      0xFF,
      0xDA,
      0x00,
      0x08,
      0x01,
      0x01,
      0x00,
      0x00,
      0x3F,
      0x00,
      0xBF,
      0x00,
      0xFF,
      0xD9,
    ];

    if (tamanoMinimo <= baseJpeg.length) {
      return Uint8List.fromList(baseJpeg);
    }

    final diff = tamanoMinimo - baseJpeg.length;
    final builder = BytesBuilder();
    builder.add(baseJpeg.sublist(0, 20));
    // Comentario COM (0xFF 0xFE) con padding
    builder.add([0xFF, 0xFE, (diff >> 8) & 0xFF, diff & 0xFF]);
    builder.add(List.filled(diff > 2 ? diff - 2 : 0, 0x20));
    builder.add(baseJpeg.sublist(20));
    return builder.toBytes();
  }

  void configurarVentanaGrande(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('Fase 3: Detección y Extracción de Imágenes en DocumentService', () {
    late DocumentService service;

    setUp(() {
      service = DocumentService();
    });

    test('1. PDF sin imágenes produce lista vacía y estado sinImagenes', () {
      final pdfBytes = Uint8List.fromList([
        0x25,
        0x50,
        0x44,
        0x46,
        0x2D,
        0x31,
        0x2E,
        0x34,
        0x74,
        0x65,
        0x78,
        0x74,
        0x6F,
        0x20,
        0x73,
        0x69,
      ]);

      final imagenes = service.extraerImagenes(pdfBytes);
      final estado = service.determinarEstadoInicialImagenes(imagenes);

      expect(imagenes, isEmpty);
      expect(estado, EstadoImagenesPdf.sinImagenes);
    });

    test('2. PDF con imágenes extraíbles detecta y extrae JPEG embebido', () {
      final jpegBytes = crearJpegValido(tamanoMinimo: 8500);
      final pdfSimulado = BytesBuilder();
      pdfSimulado.add([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);
      pdfSimulado.add(jpegBytes);
      pdfSimulado.add([0x25, 0x25, 0x45, 0x4F, 0x46]);

      final imagenes = service.extraerImagenes(pdfSimulado.toBytes());
      final estado = service.determinarEstadoInicialImagenes(imagenes);

      expect(imagenes.length, 1);
      expect(imagenes.first.length, greaterThanOrEqualTo(8500));
      expect(estado, EstadoImagenesPdf.potencialmenteUtiles);
    });

    test(
      '3. Clasifica imágenes menores a 8KB como noVerificadas inicialmente',
      () {
        final jpegPequeno = crearJpegValido(tamanoMinimo: 2500);
        final imagenes = [jpegPequeno];

        final estado = service.determinarEstadoInicialImagenes(imagenes);
        expect(estado, EstadoImagenesPdf.noVerificadas);
      },
    );
  });

  group('Fase 3: Escenarios de Personalización y Opciones Visuales', () {
    testWidgets(
      'Escenario 1: PDF sin imágenes deshabilita opción de fotos PDF pero mantiene automático y dibujo',
      (tester) async {
        configurarVentanaGrande(tester);

        final pdfSinImagenes = PdfStoryData(
          nombreArchivo: 'historia_sin_foto.pdf',
          textoExtraido: 'Había una vez un conejo curioso...',
          personajePrincipalDetectado: 'Tambor',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfSinImagenes,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        expect(find.text('Tomar referencias visuales del PDF'), findsOneWidget);
        expect(find.text('Crear un diseño automáticamente'), findsOneWidget);
        expect(find.text('Dibujar mi propio personaje'), findsOneWidget);
        expect(
          find.text(
            'El PDF no contiene imágenes utilizables del protagonista.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Escenario 2: PDF con imágenes extraíbles permite seleccionar y confirmar protagonista',
      (tester) async {
        configurarVentanaGrande(tester);
        final imagen1 = crearJpegValido(tamanoMinimo: 8500);
        CharacterCustomization? resultado;

        final pdfConImagenes = PdfStoryData(
          nombreArchivo: 'historia_con_fotos.pdf',
          textoExtraido: 'Ranj buscaba agua en el pozo seco.',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: [imagen1],
          estadoImagenes: EstadoImagenesPdf.potencialmenteUtiles,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfConImagenes,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        );

        expect(
          find.text('Ilustraciones detectadas en el PDF (1)'),
          findsOneWidget,
        );

        // Tocar la imagen miniatura para seleccionarla
        final thumbnailFinder = find.byKey(const ValueKey('imagen_extraida_0'));
        expect(thumbnailFinder, findsOneWidget);
        await tester.ensureVisible(thumbnailFinder);
        await tester.tap(thumbnailFinder);
        await tester.pumpAndSettle();

        expect(find.text('Ilustración seleccionada'), findsOneWidget);

        final continuarBtn = find.text('Continuar');
        await tester.ensureVisible(continuarBtn);
        await tester.tap(continuarBtn);
        await tester.pumpAndSettle();

        expect(resultado, isNotNull);
        expect(resultado!.visualMode, CharacterVisualMode.pdfImages);
        expect(resultado!.imagenReferencia, isNotNull);
        expect(resultado!.nombrePersonaje, 'Ranj');
      },
    );

    testWidgets(
      'Escenario 3: PDF con imágenes decorativas permite descartarlas y ofrece diseño automático/dibujo',
      (tester) async {
        configurarVentanaGrande(tester);
        final imagenDecorativa = crearJpegValido(tamanoMinimo: 3000);
        CharacterCustomization? resultado;

        final pdfConDecoraciones = PdfStoryData(
          nombreArchivo: 'historia_decorativa.pdf',
          textoExtraido: 'El bosque encantado tenía flores...',
          personajePrincipalDetectado: 'Hada Verde',
          imagenesExtraidas: [imagenDecorativa],
          estadoImagenes: EstadoImagenesPdf.noVerificadas,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfConDecoraciones,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        );

        final descartarBtn = find.text(
          'Ninguna es el protagonista (son decorativas)',
        );
        await tester.ensureVisible(descartarBtn);
        await tester.tap(descartarBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Las imágenes del PDF fueron descartadas como decorativas.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Las imágenes fueron descartadas como decorativas o de fondo.',
          ),
          findsOneWidget,
        );

        final continuarBtn = find.text('Continuar');
        await tester.ensureVisible(continuarBtn);
        await tester.tap(continuarBtn);
        await tester.pumpAndSettle();

        expect(resultado, isNotNull);
        expect(resultado!.visualMode, CharacterVisualMode.automatic);
        expect(resultado!.imagenReferencia, isNull);
        expect(resultado!.estadoDisenoAutomatico, 'pendiente');
      },
    );

    testWidgets(
      'Escenario 4: PDF con imágenes no verificadas exige validación al forzar modo pdfImages',
      (tester) async {
        configurarVentanaGrande(tester);
        final imagen1 = crearJpegValido(tamanoMinimo: 4000);

        final pdfNoVerificado = PdfStoryData(
          nombreArchivo: 'historia_duda.pdf',
          textoExtraido: 'Había un misterio en el pueblo...',
          personajePrincipalDetectado: 'Inspector',
          imagenesExtraidas: [imagen1],
          estadoImagenes: EstadoImagenesPdf.noVerificadas,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfNoVerificado,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        final opcionPdf = find.text('Tomar referencias visuales del PDF');
        await tester.ensureVisible(opcionPdf);
        await tester.tap(opcionPdf);
        await tester.pumpAndSettle();

        final continuarBtn = find.text('Continuar');
        await tester.ensureVisible(continuarBtn);
        await tester.tap(continuarBtn);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Debes seleccionar o confirmar cuál imagen del PDF representa al protagonista.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Escenario 5: PDF con protagonista textual identificado pero sin ilustraciones permite mantener, renombrar o crear',
      (tester) async {
        configurarVentanaGrande(tester);

        final pdfSinFotosConTexto = PdfStoryData(
          nombreArchivo: 'missing_water.pdf',
          textoExtraido: 'The Case of the Missing Water. Ranj wondered...',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfSinFotosConTexto,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        expect(find.text('Mantener al protagonista original'), findsOneWidget);
        expect(find.text('Cambiar únicamente su nombre'), findsOneWidget);
        expect(find.text('Crear mi propio protagonista'), findsOneWidget);
        expect(find.text('MANTENER AL PROTAGONISTA ORIGINAL'), findsNothing);
        expect(find.text('CAMBIAR ÚNICAMENTE SU NOMBRE'), findsNothing);
        expect(find.text('CREAR MI PROPIO PROTAGONISTA'), findsNothing);
        expect(find.text('Continuaremos con Ranj.'), findsOneWidget);
        expect(
          find.text(
            'Será el mismo personaje del cuento, pero podrás elegir otro nombre.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Crearás un personaje diferente con su propio nombre y apariencia para vivir la aventura.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Escenario 7: Opción "Cambiar únicamente su nombre" muestra solo campo de nombre',
      (tester) async {
        configurarVentanaGrande(tester);

        final pdfData = PdfStoryData(
          nombreArchivo: 'historia.pdf',
          textoExtraido: 'Ranj exploraba el bosque...',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        await tester.tap(find.text('Cambiar únicamente su nombre'));
        await tester.pumpAndSettle();

        expect(find.text('Nuevo nombre del protagonista'), findsOneWidget);
        expect(find.text('Ejemplo: Pedro'), findsOneWidget);
        expect(find.text('Descripción breve del personaje'), findsNothing);
      },
    );

    testWidgets(
      'Escenario 8: Opción "Crear mi propio protagonista" muestra nombre y descripción separados sin concatenar',
      (tester) async {
        configurarVentanaGrande(tester);
        CharacterCustomization? resultado;

        final pdfData = PdfStoryData(
          nombreArchivo: 'historia.pdf',
          textoExtraido: 'Ranj exploraba el bosque...',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        );

        await tester.tap(find.text('Crear mi propio protagonista'));
        await tester.pumpAndSettle();

        expect(find.text('Nombre del nuevo protagonista'), findsOneWidget);
        expect(find.text('Ejemplo: Luna'), findsOneWidget);
        expect(find.text('Descripción breve del personaje'), findsOneWidget);

        // Ingresar Pepe y descripción
        final campoNombre = find.widgetWithText(
          TextField,
          'Nombre del nuevo protagonista',
        );
        final campoDesc = find.widgetWithText(
          TextField,
          'Descripción breve del personaje',
        );

        await tester.enterText(campoNombre, '  Pepe   ');
        await tester.enterText(campoDesc, '  Lleva una mochila roja.  ');
        await tester.pumpAndSettle();

        final continuarBtn = find.text('Continuar');
        await tester.ensureVisible(continuarBtn);
        await tester.tap(continuarBtn);
        await tester.pumpAndSettle();

        expect(resultado, isNotNull);
        expect(resultado!.nombrePersonaje, 'Pepe');
        expect(resultado!.nombrePersonaje, isNot(contains('mochila roja')));
        expect(resultado!.descripcionPersonaje, 'Lleva una mochila roja.');
        expect(resultado!.mode, CharacterMode.newCharacter);
      },
    );

    testWidgets(
      'Escenario 9: Cambiar entre modos limpia y no contamina la descripción anterior',
      (tester) async {
        configurarVentanaGrande(tester);
        CharacterCustomization? resultado;

        final pdfData = PdfStoryData(
          nombreArchivo: 'historia.pdf',
          textoExtraido: 'Ranj exploraba el bosque...',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: [],
          estadoImagenes: EstadoImagenesPdf.sinImagenes,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        );

        // 1. Elegir crear nuevo protagonista con descripción
        await tester.tap(find.text('Crear mi propio protagonista'));
        await tester.pumpAndSettle();

        final campoNombre = find.widgetWithText(
          TextField,
          'Nombre del nuevo protagonista',
        );
        final campoDesc = find.widgetWithText(
          TextField,
          'Descripción breve del personaje',
        );
        await tester.enterText(campoNombre, 'Luna');
        await tester.enterText(campoDesc, 'mochila roja');
        await tester.pumpAndSettle();

        // 2. Cambiar de opinión a "Cambiar únicamente su nombre"
        await tester.tap(find.text('Cambiar únicamente su nombre'));
        await tester.pumpAndSettle();

        // El campo de descripción ya no existe en la UI
        expect(find.text('Descripción breve del personaje'), findsNothing);

        final campoRenombrar = find.widgetWithText(
          TextField,
          'Nuevo nombre del protagonista',
        );
        await tester.enterText(campoRenombrar, 'Pedro');
        await tester.pumpAndSettle();

        final continuarBtn = find.text('Continuar');
        await tester.ensureVisible(continuarBtn);
        await tester.tap(continuarBtn);
        await tester.pumpAndSettle();

        expect(resultado, isNotNull);
        expect(resultado!.mode, CharacterMode.renameOriginal);
        expect(resultado!.nombrePersonaje, 'Pedro');
        // La descripción de Luna NO se envió
        expect(resultado!.descripcionPersonaje, isNull);
      },
    );

    testWidgets(
      'Escenario 6: Galería horizontal incluye botones laterales, scrollbar y permite avanzar',
      (tester) async {
        configurarVentanaGrande(tester);

        // Crear 10 imágenes para asegurar scroll horizontal
        final imagenes = List.generate(
          10,
          (_) => crearJpegValido(tamanoMinimo: 8500),
        );

        final pdfConMuchasFotos = PdfStoryData(
          nombreArchivo: 'historia_muchas_fotos.pdf',
          textoExtraido: 'Ranj explorando...',
          personajePrincipalDetectado: 'Ranj',
          imagenesExtraidas: imagenes,
          estadoImagenes: EstadoImagenesPdf.potencialmenteUtiles,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfConMuchasFotos,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verificar presencia de botones de desplazamiento
        final btnRetroceder = find.byKey(
          const ValueKey('btn_galeria_retroceder'),
        );
        final btnAvanzar = find.byKey(const ValueKey('btn_galeria_avanzar'));

        expect(btnRetroceder, findsOneWidget);
        expect(btnAvanzar, findsOneWidget);

        // Al inicio, el botón de retroceso debe estar deshabilitado (offset 0)
        final widgetRetroceder = tester.widget<IconButton>(btnRetroceder);
        expect(widgetRetroceder.onPressed, isNull);

        // El botón de avanzar debe estar habilitado
        final widgetAvanzar = tester.widget<IconButton>(btnAvanzar);
        expect(widgetAvanzar.onPressed, isNotNull);

        // Verificar que existe el Scrollbar horizontal
        expect(find.byType(Scrollbar), findsWidgets);

        // Tocar la primera imagen para seleccionarla
        final thumb0 = find.byKey(const ValueKey('imagen_extraida_0'));
        expect(thumb0, findsOneWidget);
        await tester.tap(thumb0);
        await tester.pumpAndSettle();
        expect(find.text('Ilustración seleccionada'), findsOneWidget);

        // Avanzar la galería usando el botón derecho
        await tester.tap(btnAvanzar);
        await tester.pumpAndSettle();

        // Al haber avanzado, el botón de retroceso ahora debe estar habilitado
        final widgetRetrocederDespues = tester.widget<IconButton>(
          btnRetroceder,
        );
        expect(widgetRetrocederDespues.onPressed, isNotNull);

        // La selección de imagen se conserva
        expect(find.text('Ilustración seleccionada'), findsOneWidget);
      },
    );
  });
}
