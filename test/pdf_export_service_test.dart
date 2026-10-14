import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mínimo PNG válido de 1x1 píxel para pruebas de bitmap
  final pngValidoBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  group('RF-30 / RF-31: Servicio de Exportación y Guardado de PDF', () {
    test('Lanza StateError si el cuento no tiene escenas o no está finalizado', () async {
      final cuentoVacio = Cuento(
        id: 'c-vacio',
        titulo: 'Cuento Vacío',
        personajePrincipal: 'Mateo',
      );
      await expectLater(
        PdfExportService().generarPdf(cuentoVacio),
        throwsStateError,
      );

      final cuentoIncompleto = Cuento(
        id: 'c-incompleto',
        titulo: 'Aventura en el Bosque',
        personajePrincipal: 'Sofía',
      );
      cuentoIncompleto.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Sofía empezó su viaje.',
          opciones: ['Ir por el río', 'Ir por la montaña'],
          esFinal: false,
        ),
      );
      await expectLater(
        PdfExportService().generarPdf(cuentoIncompleto),
        throwsStateError,
      );
    });

    test('Genera un PDF válido con cabecera estándar (%PDF) sin imágenes', () async {
      final cuento = Cuento(
        id: 'c-sin-imagenes',
        titulo: 'El Gran Descubrimiento',
        personajePrincipal: 'Valentina',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Valentina encontró un cofre brillante en su habitación.',
          opciones: ['Abrirlo', 'Esperar a mamá'],
          esFinal: false,
        ),
      );
      cuento.registrarDecision(
        DecisionNarrativa(numeroEscena: 1, opcionSeleccionada: 'Abrirlo'),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Dentro del cofre había un mapa mágico y una nota amigable. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final pdfBytes = await PdfExportService().generarPdf(cuento);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);

      // Guardar en disco para verificación en Windows 11
      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_export_sin_imagenes.pdf').writeAsBytesSync(pdfBytes);
    });

    test('Genera PDF incluyendo portada e ilustraciones de escenas válidas', () async {
      final cuento = Cuento(
        id: 'c-con-imagenes',
        titulo: 'La Ardilla Sabia',
        personajePrincipal: 'Leo',
        referenciaVisualPng: pngValidoBytes,
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Leo conoció a la ardilla bajo un sauce.',
          opciones: ['Saludarla con una sonrisa'],
          esFinal: false,
        ),
      );
      cuento.registrarImagenEscena(1, pngValidoBytes);

      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Juntos protegieron el nido de los pájaros. Colorín colorado.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final pdfBytes = await PdfExportService().generarPdf(cuento);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);

      // Guardar en disco para verificación en Windows 11
      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_export_con_imagenes.pdf').writeAsBytesSync(pdfBytes);
    });

    test('Tolerancia a fallos: genera PDF aun con imagen corrupta o data-uri inválido', () async {
      final cuento = Cuento(
        id: 'c-imagen-corrupta',
        titulo: 'El Misterio del Reloj',
        personajePrincipal: 'Camila',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Camila escuchó un tictac extraño.',
          opciones: const [],
          imageUrl: 'data:image/png;base64,datos-corruptos-no-validos',
          esFinal: false,
        ),
      );
      // Simular bytes no reconocibles como PNG/JPEG
      cuento.registrarImagenEscena(1, Uint8List.fromList([1, 2, 3, 4, 5, 6]));

      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Era solo un pajarito de madera. Fin feliz.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final pdfBytes = await PdfExportService().generarPdf(cuento);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);
    });
  });
}
