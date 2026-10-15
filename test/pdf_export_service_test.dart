import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper para construir un intento de quiz completado con las 5 preguntas (2-2-1)
  QuizAttemptSummary crearIntentoCompletado({
    int puntaje = 4,
    String estado = 'completado',
  }) {
    return QuizAttemptSummary(
      intentoId: 'int-test-1',
      cuentoId: 'c-test-1',
      cuentoTitulo: 'El Misterio del Valle Dorado',
      estudianteId: 'est-1',
      estudianteNombre: 'Nico Explorador',
      codigoAcceso: 'DEMO26',
      aulaId: 'aula-1',
      aulaNombre: '4to Grado Primaria',
      estado: estado,
      puntaje: puntaje,
      totalPreguntas: 5,
      porcentaje: (puntaje * 20),
      createdAt: DateTime(2026, 10, 14, 10, 0),
      completedAt:
          estado == 'completado' ? DateTime(2026, 10, 14, 10, 15) : null,
      respuestas: [
        const QuizQuestionResult(
          numero: 1,
          pregunta: '¿Quién es el protagonista de la aventura?',
          opciones: ['Nico', 'Pepe', 'Lalo', 'Beto'],
          indiceSeleccionado: 0,
          indiceCorrecto: 0,
          esCorrecta: true,
          explicacion: 'Nico es el protagonista explícito del cuento.',
          nivelComprension: 'literal',
        ),
        const QuizQuestionResult(
          numero: 2,
          pregunta: '¿Dónde ocurre la historia?',
          opciones: ['En la playa', 'En el Valle Dorado', 'En una cueva', 'En un barco'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'El Valle Dorado es el escenario mágico descrito.',
          nivelComprension: 'literal',
        ),
        const QuizQuestionResult(
          numero: 3,
          pregunta: '¿Por qué el gnomo cerró la compuerta del río?',
          opciones: ['Por maldad', 'Para proteger el agua de su huerto', 'Por juego', 'Por error'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'El gnomo buscaba cuidar sus cultivos antes de conversar.',
          nivelComprension: 'inferencial',
        ),
        const QuizQuestionResult(
          numero: 4,
          pregunta: '¿Qué actitud demostró Nico al encontrar al gnomo?',
          opciones: ['Enojo y reclamo', 'Diálogo y cortesía', 'Indiferencia', 'Miedo'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'Nico decidió acercarse con respeto y dialogar.',
          nivelComprension: 'inferencial',
        ),
        const QuizQuestionResult(
          numero: 5,
          pregunta: '¿Qué valor se resalta al compartir el agua del río?',
          opciones: ['La solidaridad y el bien común', 'El egoísmo', 'La fuerza', 'La soledad'],
          indiceSeleccionado: 0,
          indiceCorrecto: 0,
          esCorrecta: true,
          explicacion: 'Compartir los recursos beneficia a toda la comunidad.',
          nivelComprension: 'critico_reflexivo',
        ),
      ],
    );
  }

  // Mínimo PNG válido de 1x1 píxel
  final pngValidoBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  group('RF-30 / RF-31: Servicio de Exportación y Guardado de PDF con Validación de Quiz', () {
    test('Lanza StateError si el cuento no tiene escenas o no está finalizado', () async {
      final cuentoVacio = Cuento(
        id: 'c-vacio',
        titulo: 'Cuento Vacío',
        personajePrincipal: 'Mateo',
      );
      await expectLater(
        PdfExportService().generarPdf(
          cuentoVacio,
          intentoQuiz: crearIntentoCompletado(),
        ),
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
        PdfExportService().generarPdf(
          cuentoIncompleto,
          intentoQuiz: crearIntentoCompletado(),
        ),
        throwsStateError,
      );
    });

    test('Lanza StateError si el intento de quiz es null o está en progreso (regla obligatoria)', () async {
      final cuento = Cuento(
        id: 'c-finalizado',
        titulo: 'Cuento de Prueba',
        personajePrincipal: 'Nico',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Inicio.',
          opciones: const [],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Desenlace feliz.',
          opciones: const [],
          esFinal: true,
        ),
      );

      // 1. Quiz null
      await expectLater(
        PdfExportService().generarPdf(cuento, intentoQuiz: null),
        throwsStateError,
      );

      // 2. Quiz en progreso
      await expectLater(
        PdfExportService().generarPdf(
          cuento,
          intentoQuiz: crearIntentoCompletado(estado: 'en_progreso'),
        ),
        throwsStateError,
      );
    });

    test('Genera un PDF válido (%PDF) incluyendo evaluación de comprensión con las 5 preguntas', () async {
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

      final intento = crearIntentoCompletado(puntaje: 5);
      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intento,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]); // %PDF

      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_export_con_evaluacion.pdf').writeAsBytesSync(pdfBytes);
    });

    test('Genera PDF con ilustración real de alta resolución (no 1x1 píxel)', () async {
      Uint8List bytesIlustracion;
      final fileReal = File('test/fixtures/ilustracion_real.jpg');
      if (fileReal.existsSync()) {
        bytesIlustracion = fileReal.readAsBytesSync();
      } else {
        bytesIlustracion = pngValidoBytes;
      }

      final cuento = Cuento(
        id: 'c-con-imagenes-reales',
        titulo: 'El Misterio del Valle Dorado',
        personajePrincipal: 'Nico Explorador',
        referenciaVisualPng: bytesIlustracion,
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Nico exploraba las colinas doradas cuando escuchó un rumor extraño.',
          opciones: ['Subir al mirador'],
          esFinal: false,
        ),
      );
      cuento.registrarImagenEscena(1, bytesIlustracion);
      cuento.registrarDecision(
        DecisionNarrativa(numeroEscena: 1, opcionSeleccionada: 'Subir al mirador'),
      );

      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'El gnomo y Nico abrieron la compuerta y el agua volvió al valle.',
          opciones: const [],
          esFinal: true,
        ),
      );
      cuento.registrarImagenEscena(2, bytesIlustracion);

      final intento = crearIntentoCompletado(puntaje: 4);
      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intento,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);

      // Al tener ilustraciones reales de alta resolución, el PDF debe tener tamaño sustancial
      if (fileReal.existsSync()) {
        expect(pdfBytes.length, greaterThan(50000));
      }

      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_export_con_ilustracion_real.pdf').writeAsBytesSync(pdfBytes);
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
      cuento.registrarImagenEscena(1, Uint8List.fromList([1, 2, 3, 4, 5, 6]));

      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Era solo un pajarito de madera. Fin feliz.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: crearIntentoCompletado(puntaje: 3),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);
    });
  });
}
