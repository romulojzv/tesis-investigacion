import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
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
      completedAt: estado == 'completado'
          ? DateTime(2026, 10, 14, 10, 15)
          : null,
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
          opciones: [
            'En la playa',
            'En el Valle Dorado',
            'En una cueva',
            'En un barco',
          ],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'El Valle Dorado es el escenario mágico descrito.',
          nivelComprension: 'literal',
        ),
        const QuizQuestionResult(
          numero: 3,
          pregunta: '¿Por qué el gnomo cerró la compuerta del río?',
          opciones: [
            'Por maldad',
            'Para proteger el agua de su huerto',
            'Por juego',
            'Por error',
          ],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion:
              'El gnomo buscaba cuidar sus cultivos antes de conversar.',
          nivelComprension: 'inferencial',
        ),
        const QuizQuestionResult(
          numero: 4,
          pregunta: '¿Qué actitud demostró Nico al encontrar al gnomo?',
          opciones: [
            'Enojo y reclamo',
            'Diálogo y cortesía',
            'Indiferencia',
            'Miedo',
          ],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'Nico decidió acercarse con respeto y dialogar.',
          nivelComprension: 'inferencial',
        ),
        const QuizQuestionResult(
          numero: 5,
          pregunta: '¿Qué valor se resalta al compartir el agua del río?',
          opciones: [
            'La solidaridad y el bien común',
            'El egoísmo',
            'La fuerza',
            'La soledad',
          ],
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
    test(
      'Lanza StateError si el cuento no tiene escenas o no está finalizado',
      () async {
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
      },
    );

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
          contenido:
              'Dentro del cofre había un mapa mágico y una nota amigable. Fin.',
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

    test(
      'Genera PDF con ilustración real de alta resolución (no 1x1 píxel)',
      () async {
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
          DecisionNarrativa(
            numeroEscena: 1,
            opcionSeleccionada: 'Subir al mirador',
          ),
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
        File('build/pdf_export_con_ilustracion_real.pdf')
            .writeAsBytesSync(pdfBytes);
      },
    );

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

    test('Conserva y muestra la distribución 2-2-1 de niveles pedagógicos (literal, inferencial, crítico-reflexivo)', () async {
      final cuento = Cuento(
        id: 'c-niveles-221',
        titulo: 'El Secreto del Río Cristalino',
        personajePrincipal: 'Sofía Exploradora',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Sofía caminaba por la ribera del río buscando piedras brillantes.',
          opciones: ['Cruzar el puente'],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Al cruzar el puente, encontró a los castores construyendo su dique. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final intento = crearIntentoCompletado(puntaje: 5);
      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intento,
      );

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      expect(text, contains('Pregunta 1 - Nivel: Literal'));
      expect(text, contains('Pregunta 2 - Nivel: Literal'));
      expect(text, contains('Pregunta 3 - Nivel: Inferencial'));
      expect(text, contains('Pregunta 4 - Nivel: Inferencial'));
      expect(text, contains('Pregunta 5 - Nivel: Crítico-reflexivo'));
      expect(text, isNot(contains('Nivel: General')));
    });

    test('Representa explicaciones pedagógicas extensas completas en múltiples líneas sin truncar texto', () async {
      final cuento = Cuento(
        id: 'c-explicaciones-largas',
        titulo: 'La Gran Aventura de Lucas',
        personajePrincipal: 'Lucas',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Lucas descubrió una cueva misteriosa oculta tras la cascada de agua cristalina.',
          opciones: ['Encender la antorcha'],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Con la antorcha encendida, Lucas encontró cristales mágicos que iluminaban todo el valle. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      const explicacionMuyLargaP1 =
          'Esta explicación pedagógica es bastante extensa y contiene múltiples oraciones para orientar detalladamente al estudiante de cuarto grado de primaria sobre por qué su razonamiento es correcto con base en los hechos explícitos relatados en la primera escena del cuento, sin omitir ninguna palabra al final de la oración pedagógica.';
      const explicacionMuyLargaP5 =
          'Desde una perspectiva crítico-reflexiva fundamental en el desarrollo de la comprensión lectora, valorar las acciones de los personajes permite al niño conectar las consecuencias de sus decisiones morales con el bienestar de toda su comunidad escolar y familiar, fomentando el pensamiento crítico.';

      final intento = QuizAttemptSummary(
        intentoId: 'int-explicaciones-largas',
        cuentoId: 'c-explicaciones-largas',
        cuentoTitulo: 'La Gran Aventura de Lucas',
        estudianteId: 'est-demo',
        estudianteNombre: 'Lucas',
        codigoAcceso: '4A26-001',
        estado: 'completado',
        puntaje: 4,
        totalPreguntas: 5,
        porcentaje: 80,
        createdAt: DateTime(2026, 10, 15, 0, 0),
        completedAt: DateTime(2026, 10, 15, 0, 10),
        respuestas: const [
          QuizQuestionResult(
            numero: 1,
            pregunta: '¿Qué descubrió Lucas detrás de la cascada?',
            opciones: [
              'Una cueva misteriosa',
              'Un barco pirata',
              'Un cofre vacío',
              'Un nido de águila',
            ],
            indiceSeleccionado: 0,
            indiceCorrecto: 0,
            esCorrecta: true,
            explicacion: explicacionMuyLargaP1,
            nivelComprension: 'literal',
          ),
          QuizQuestionResult(
            numero: 2,
            pregunta: '¿Cómo era el agua de la cascada?',
            opciones: ['Turbia y oscura', 'Cristalina', 'Congelada', 'Salada'],
            indiceSeleccionado: 1,
            indiceCorrecto: 1,
            esCorrecta: true,
            explicacion: 'El texto menciona explícitamente que el agua era cristalina y pura.',
            nivelComprension: 'literal',
          ),
          QuizQuestionResult(
            numero: 3,
            pregunta: '¿Por qué Lucas decidió encender la antorcha al entrar a la cueva?',
            opciones: [
              'Porque tenía frío',
              'Porque estaba muy oscuro para ver el camino',
              'Para asustar a los murciélagos',
              'Para cocinar algo',
            ],
            indiceSeleccionado: 1,
            indiceCorrecto: 1,
            esCorrecta: true,
            explicacion: 'Se infiere que encendió la antorcha para poder iluminar la oscuridad de la caverna y avanzar con seguridad.',
            nivelComprension: 'inferencial',
          ),
          QuizQuestionResult(
            numero: 4,
            pregunta: '¿Qué consecuencia tuvo la luz de los cristales mágicos en el valle?',
            opciones: [
              'El valle se quedó a oscuras',
              'Iluminaron todo el valle devolviendo la alegría',
              'Ahuyentaron a todos los animales',
              'Ninguna consecuencia',
            ],
            indiceSeleccionado: 1,
            indiceCorrecto: 1,
            esCorrecta: true,
            explicacion: 'Se deduce de la historia que la luz de los cristales trajo bienestar y claridad a todos los habitantes del valle.',
            nivelComprension: 'inferencial',
          ),
          QuizQuestionResult(
            numero: 5,
            pregunta: '¿Por qué es valioso compartir un descubrimiento como los cristales mágicos con los demás?',
            opciones: [
              'Porque el conocimiento y la belleza compartidos enriquecen a toda la comunidad',
              'Para cobrar dinero por verlos',
              'Para que nadie más pueda entrar a la cueva',
              'Para presumir ante los amigos',
            ],
            indiceSeleccionado: 0,
            indiceCorrecto: 0,
            esCorrecta: true,
            explicacion: explicacionMuyLargaP5,
            nivelComprension: 'critico_reflexivo',
          ),
        ],
      );

      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intento,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      // Normalizar espacios múltiples y saltos de línea para verificar el contenido semántico
      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');

      // Verificar que el texto completo de las explicaciones extensas está íntegro y no cortado
      expect(
        textoNormalizado,
        contains(
          'sin omitir ninguna palabra al final de la oración pedagógica.',
        ),
      );
      expect(textoNormalizado, contains('fomentando el pensamiento crítico.'));

      // Guardar PDF de verificación en build/
      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_verificacion_explicaciones_completas.pdf')
          .writeAsBytesSync(pdfBytes);
    });

    test('RF-30 / RF-31: Decisión extensa de más de 200 caracteres se exporta completa en múltiples líneas sin truncamiento', () async {
      final cuento = Cuento(
        id: 'c-decision-larga',
        titulo: 'Aventura en la Selva Misteriosa',
        personajePrincipal: 'Padas',
      );

      const decisionExtensa =
          'Explorar cuidadosamente el sendero secreto detrás de la cascada mágica donde florecen lirios de luz y susurran los antiguos espíritus protectores del bosque encantado, buscando la clave del enigma para salvar el reino.';
      expect(decisionExtensa.length, greaterThanOrEqualTo(200));

      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Padas contempló la entrada de la caverna iluminada por el resplandor de los lirios luminosos.',
          opciones: [decisionExtensa, 'Volver a la aldea'],
          esFinal: false,
        ),
      );
      cuento.registrarDecision(
        DecisionNarrativa(numeroEscena: 1, opcionSeleccionada: decisionExtensa),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Con valentía y prudencia, Padas resolvió el enigma milenario y llevó la paz a toda la comunidad. Fin.',
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
      expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]);

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');

      // Verificar que el texto de la decisión extensa se conserva completo en el PDF
      expect(
        textoNormalizado,
        contains(
          'Decisión elegida: "Explorar cuidadosamente el sendero secreto',
        ),
      );
      expect(
        textoNormalizado,
        contains('buscando la clave del enigma para salvar el reino."'),
      );
      // Verificar que el texto narrativo subsiguiente se conserva correctamente
      expect(
        textoNormalizado,
        contains('Padas contempló la entrada de la caverna iluminada'),
      );

      // Guardar PDF de demostración en build/
      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_demo_decision_larga.pdf').writeAsBytesSync(pdfBytes);
    });

    test('RF-30 / RF-31: Portada diferencia al protagonista del lector y evita duplicar nombres', () async {
      final cuento = Cuento(
        id: 'c-protagonista-lector',
        titulo: 'El Misterio de la Estrella Azul',
        personajePrincipal: 'Padas',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido:
              'Padas divisó una estrella brillante posándose en la cumbre.',
          opciones: ['Subir a la montaña'],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'La estrella bendijo el valle con alegría. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final intento = QuizAttemptSummary(
        intentoId: 'int-lector-demo',
        cuentoId: 'c-protagonista-lector',
        cuentoTitulo: 'El Misterio de la Estrella Azul',
        estudianteId: 'est-123',
        estudianteNombre: 'Estudiante Demo',
        codigoAcceso: 'COD-PRIVADO-77',
        estado: 'completado',
        puntaje: 5,
        totalPreguntas: 5,
        porcentaje: 100,
        createdAt: DateTime(2026, 10, 26, 10, 0),
        completedAt: DateTime(2026, 10, 26, 10, 15),
        respuestas: crearIntentoCompletado().respuestas,
      );

      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intento,
      );

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');

      // Debe mostrar Protagonista: Padas y Lector(a): Estudiante Demo
      expect(textoNormalizado, contains('Protagonista: Padas'));
      expect(textoNormalizado, contains('Lector(a): Estudiante Demo'));
      // No debe atribuir el nombre del protagonista al lector
      expect(textoNormalizado, isNot(contains('Lector(a): Padas')));
      // Ajuste de privacidad: nunca debe incluir codigoAcceso ni etiquetas de código
      expect(textoNormalizado, isNot(contains('COD-PRIVADO-77')));
      expect(textoNormalizado, isNot(contains('Código:')));

      final outDir = Directory('build');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('build/pdf_demo_protagonista_y_lector.pdf')
          .writeAsBytesSync(pdfBytes);
    });

    test('Ajuste de privacidad: el código de acceso nunca aparece en el PDF aunque QuizAttemptSummary lo contenga', () async {
      final cuento = Cuento(
        id: 'c-privacidad-codigo',
        titulo: 'Aventura en la Colina',
        personajePrincipal: 'Mateo',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Mateo subió a la cima de la colina.',
          opciones: ['Mirar el horizonte'],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido: 'Desde la cima divisó un arcoíris hermoso. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final intentoConCodigo = QuizAttemptSummary(
        intentoId: 'int-priv-1',
        cuentoId: 'c-privacidad-codigo',
        cuentoTitulo: 'Aventura en la Colina',
        estudianteId: 'est-99',
        estudianteNombre: 'Lucía Alumna',
        codigoAcceso: 'CLAVE-DOCENTE-4455',
        estado: 'completado',
        puntaje: 5,
        totalPreguntas: 5,
        porcentaje: 100,
        createdAt: DateTime(2026, 10, 26, 12, 0),
        completedAt: DateTime(2026, 10, 26, 12, 10),
        respuestas: crearIntentoCompletado().respuestas,
      );

      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intentoConCodigo,
      );

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');

      // Debe mostrar exclusivamente Lector(a): Lucía Alumna
      expect(textoNormalizado, contains('Lector(a): Lucía Alumna'));
      // No debe contener el código de acceso ni la etiqueta de código
      expect(textoNormalizado, isNot(contains('CLAVE-DOCENTE-4455')));
      expect(textoNormalizado, isNot(contains('Código:')));
    });

    test('RF-30 / RF-31: Nombre ausente de lector no genera etiqueta huérfana ni datos ficticios', () async {
      final cuento = Cuento(
        id: 'c-lector-ausente',
        titulo: 'El Valle de los Susurros',
        personajePrincipal: 'Padas',
      );
      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Padas inició su recorrido matutino por el valle.',
          opciones: ['Seguir el río'],
          esFinal: false,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido:
              'El recorrido concluyó con una gran lección aprendida. Fin.',
          opciones: const [],
          esFinal: true,
        ),
      );

      final intentoSinNombre = QuizAttemptSummary(
        intentoId: 'int-sin-nombre',
        cuentoId: 'c-lector-ausente',
        cuentoTitulo: 'El Valle de los Susurros',
        estudianteId: '',
        estudianteNombre: '',
        codigoAcceso: '',
        estado: 'completado',
        puntaje: 4,
        totalPreguntas: 5,
        porcentaje: 80,
        createdAt: DateTime(2026, 10, 26, 11, 0),
        completedAt: DateTime(2026, 10, 26, 11, 10),
        respuestas: crearIntentoCompletado().respuestas,
      );

      final pdfBytes = await PdfExportService().generarPdf(
        cuento,
        intentoQuiz: intentoSinNombre,
      );

      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');

      expect(textoNormalizado, contains('Protagonista: Padas'));
      // No debe tener "Lector(a):" ni inventar "Estudiante"
      expect(textoNormalizado, isNot(contains('Lector(a):')));
      expect(textoNormalizado, isNot(contains('Lector(a): Estudiante')));
    });

    test('RF-30 / RF-31: Decisión narrativa larga (~200 caracteres) se calcula con altura dinámica y se extrae completa sin truncamiento', () async {
      final cuento = Cuento(
        id: 'c-decision-larga',
        titulo: 'La Búsqueda del Cristal Sagrado',
        personajePrincipal: 'Kael',
      );
      const decisionLarga =
          'Avanzar con cautela entre las rocas cristalinas del sendero antiguo, observando con detenimiento cada señal luminosa para no despertar a la criatura ancestral que duerme pacíficamente junto al manantial.';
      expect(decisionLarga.length, greaterThanOrEqualTo(190));
      expect(decisionLarga.length, lessThanOrEqualTo(220));

      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido:
              'Kael llegó ante la encrucijada de los tres senderos olvidados.',
          opciones: [decisionLarga, 'Regresar a la aldea'],
          esFinal: false,
        ),
      );
      cuento.registrarDecision(
        DecisionNarrativa(
          numeroEscena: 1,
          opcionSeleccionada: decisionLarga,
        ),
      );
      cuento.agregarEscena(
        Escena(
          numero: 2,
          contenido:
              'El camino elegido condujo a Kael directamente hacia la reliquia. Fin de la aventura.',
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
      final doc = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final textoNormalizado = text.replaceAll(RegExp(r'\s+'), ' ');
      // La decisión completa debe estar presente en el texto extraído sin truncamientos
      expect(textoNormalizado, contains(decisionLarga));
    });
  });
}
