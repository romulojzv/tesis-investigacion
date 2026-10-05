import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/views/character_customization_view.dart';

void main() {
  final testPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  PdfStoryData crearPdfPrueba({
    EstadoImagenesPdf estado = EstadoImagenesPdf.confirmadasPersonaje,
    List<Uint8List>? imagenes,
  }) {
    return PdfStoryData(
      nombreArchivo: 'historia_galeria.pdf',
      textoExtraido: 'Pepe exploraba una colina verde...',
      personajePrincipalDetectado: 'Pepe',
      imagenesExtraidas: imagenes ?? [testPngBytes],
      estadoImagenes: estado,
      imagenSeleccionadaPersonaje:
          estado == EstadoImagenesPdf.confirmadasPersonaje
          ? testPngBytes
          : null,
    );
  }

  void configurarVentana(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Galería condicional en CharacterCustomizationView', () {
    testWidgets('muestra la galería solo cuando está en modo pdfImages', (
      tester,
    ) async {
      configurarVentana(tester);
      final pdfData = crearPdfPrueba();

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterCustomizationView(
            pdfData: pdfData,
            onVolver: () {},
            onContinuar: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Al iniciar con imágenes confirmadas, el modo es pdfImages y la galería se muestra
      expect(
        find.text('Ilustraciones detectadas en el PDF (1)'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('imagen_extraida_0')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('btn_galeria_retroceder')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('btn_galeria_avanzar')), findsOneWidget);
    });

    testWidgets(
      'al seleccionar "Crear un diseño automáticamente" oculta la galería por completo',
      (tester) async {
        configurarVentana(tester);
        final pdfData = crearPdfPrueba();

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Inicialmente se ve la galería
        expect(
          find.text('Ilustraciones detectadas en el PDF (1)'),
          findsOneWidget,
        );

        // Seleccionar "Crear un diseño automáticamente"
        final opcionAutomatico = find.text('Crear un diseño automáticamente');
        await tester.tap(opcionAutomatico);
        await tester.pumpAndSettle();

        // La galería y las miniaturas desaparecen de la vista
        expect(
          find.text('Ilustraciones detectadas en el PDF (1)'),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('imagen_extraida_0')), findsNothing);
        expect(
          find.byKey(const ValueKey('btn_galeria_retroceder')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('btn_galeria_avanzar')), findsNothing);
      },
    );

    testWidgets(
      'al seleccionar "Dibujar mi propio personaje" oculta la galería por completo',
      (tester) async {
        configurarVentana(tester);
        final pdfData = crearPdfPrueba();

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (_) {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Seleccionar "Dibujar mi propio personaje"
        final opcionDibujar = find.text('Dibujar mi propio personaje');
        await tester.tap(opcionDibujar);
        await tester.pumpAndSettle();

        // La galería desaparece
        expect(
          find.text('Ilustraciones detectadas en el PDF (1)'),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('imagen_extraida_0')), findsNothing);
      },
    );

    testWidgets(
      'cambiar de pdfImages a automatic elimina e ignora la referencia visual previa',
      (tester) async {
        configurarVentana(tester);
        final pdfData = crearPdfPrueba();
        CharacterCustomization? resultado;

        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCustomizationView(
              pdfData: pdfData,
              onVolver: () {},
              onContinuar: (c) => resultado = c,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Cambiar a "Crear un diseño automáticamente"
        await tester.tap(find.text('Crear un diseño automáticamente'));
        await tester.pumpAndSettle();

        // Presionar Continuar
        final botonContinuar = find.text('Continuar');
        await tester.ensureVisible(botonContinuar);
        await tester.pumpAndSettle();
        await tester.tap(botonContinuar);
        await tester.pumpAndSettle();

        expect(resultado, isNotNull);
        expect(resultado!.visualMode, CharacterVisualMode.automatic);
        // La referencia visual debe ser NULL obligatoriamente
        expect(resultado!.imagenReferencia, isNull);
        expect(resultado!.estadoDisenoAutomatico, 'pendiente');
      },
    );
  });
}
