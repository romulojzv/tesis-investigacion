import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generación de PDF demostrativo real para tesis con niveles 2-2-1 y explicaciones pedagógicas completas', () async {
    // 1. Cargar ilustración real de alta resolución
    final fileImg = File('test/fixtures/ilustracion_real.jpg');
    Uint8List? imagenBytes;
    if (fileImg.existsSync()) {
      imagenBytes = fileImg.readAsBytesSync();
    }

    // 2. Construir Cuento con 3 escenas y decisiones narrativas reales
    final cuento = Cuento(
      id: 'cuento-tesis-221',
      titulo: 'El Misterio del Valle Dorado',
      personajePrincipal: 'Nico Explorador',
      referenciaVisualPng: imagenBytes,
    );

    cuento.agregarEscena(
      Escena(
        numero: 1,
        contenido: 'Nico caminaba por los senderos soleados del Valle Dorado cuando escuchó un rumor misterioso cerca del río cristalino. Decidió detenerse y observar atentamente entre los sauces.',
        opciones: ['Acercarse sigilosamente a la orilla del río', 'Subir a la colina para tener mejor vista'],
        esFinal: false,
      ),
    );
    if (imagenBytes != null) cuento.registrarImagenEscena(1, imagenBytes);
    cuento.registrarDecision(
      DecisionNarrativa(
        numeroEscena: 1,
        opcionSeleccionada: 'Acercarse sigilosamente a la orilla del río',
      ),
    );

    cuento.agregarEscena(
      Escena(
        numero: 2,
        contenido: 'Al aproximarse al agua, Nico vio que un pequeño castor estaba intentando colocar una gran rama de abedul en su dique. Con mucha paciencia, Nico lo ayudó a empujar la madera hasta dejarla firme.',
        opciones: ['Descansar junto a los castores', 'Continuar la marcha hacia el molino abandonado'],
        esFinal: false,
      ),
    );
    if (imagenBytes != null) cuento.registrarImagenEscena(2, imagenBytes);
    cuento.registrarDecision(
      DecisionNarrativa(
        numeroEscena: 2,
        opcionSeleccionada: 'Continuar la marcha hacia el molino abandonado',
      ),
    );

    cuento.agregarEscena(
      Escena(
        numero: 3,
        contenido: 'En el molino, los animales de la comarca se reunieron para celebrar la llegada del agua pura que ahora fluía alegremente por todo el valle. Nico sonrió con orgullo sabiendo que la solidaridad hace que cualquier aventura valga la pena.',
        opciones: const [],
        esFinal: true,
      ),
    );
    if (imagenBytes != null) cuento.registrarImagenEscena(3, imagenBytes);

    // 3. Construir Intento de Quiz con distribución 2-2-1 y explicaciones pedagógicas completas y extensas
    final intento = QuizAttemptSummary(
      intentoId: 'int-tesis-valle-221',
      cuentoId: cuento.id,
      cuentoTitulo: cuento.titulo,
      estudianteId: 'est-demo-valle',
      estudianteNombre: 'Nico Explorador',
      codigoAcceso: '4A26-003',
      aulaId: 'aula-valle',
      aulaNombre: '4to Grado A',
      estado: 'completado',
      puntaje: 5,
      totalPreguntas: 5,
      porcentaje: 100,
      createdAt: DateTime(2026, 10, 15, 0, 0),
      completedAt: DateTime(2026, 10, 15, 0, 12),
      respuestas: const [
        QuizQuestionResult(
          numero: 1,
          pregunta: '¿Qué animal estaba intentando colocar una rama en el río según la segunda escena?',
          opciones: ['Un castor trabajador', 'Un zorro astuto', 'Un oso pardo', 'Un conejo veloz'],
          indiceSeleccionado: 0,
          indiceCorrecto: 0,
          esCorrecta: true,
          explicacion: 'En la segunda escena se narra explícitamente que un pequeño castor necesitaba ayuda para colocar una gran rama de abedul en su dique.',
          nivelComprension: 'literal',
        ),
        QuizQuestionResult(
          numero: 2,
          pregunta: '¿Dónde se reunieron finalmente los animales de la comarca para celebrar?',
          opciones: ['En la cueva secreta', 'En el molino abandonado', 'En lo alto de la montaña', 'En la plaza del pueblo'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'El desenlace del cuento describe claramente que todos los animales se reunieron junto al molino para festejar el flujo de agua.',
          nivelComprension: 'literal',
        ),
        QuizQuestionResult(
          numero: 3,
          pregunta: '¿Por qué Nico decidió ayudar al castor en lugar de pasar de largo por el camino?',
          opciones: ['Porque tenía mucho tiempo libre', 'Porque comprendió que la rama era demasiado pesada para un solo animal', 'Porque el castor se lo ordenó', 'Porque le gustaba jugar en el barro'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'A partir de la narración se deduce que Nico reconoció el esfuerzo del castor y empatizó con su dificultad para mover la madera sin apoyo.',
          nivelComprension: 'inferencial',
        ),
        QuizQuestionResult(
          numero: 4,
          pregunta: '¿Qué efecto produjo en el valle que el agua del río volviera a fluir con fuerza?',
          opciones: ['Causó una gran inundación dañina', 'Trajo alegría y bienestar a todos los seres vivos del entorno', 'Hizo que los animales huyeran asustados', 'Secó los campos cercanos'],
          indiceSeleccionado: 1,
          indiceCorrecto: 1,
          esCorrecta: true,
          explicacion: 'Se infiere que la recuperación del agua pura revitalizó el valle y devolvió la tranquilidad y felicidad a toda la comunidad natural.',
          nivelComprension: 'inferencial',
        ),
        QuizQuestionResult(
          numero: 5,
          pregunta: '¿Qué valor humano fundamental nos enseña la actitud de Nico frente a los desafíos de los demás?',
          opciones: [
            'La cooperación desinteresada y el compromiso con el bien común',
            'La competencia para demostrar superioridad',
            'La indiferencia ante las necesidades ajenas',
            'La soledad como camino hacia el éxito'
          ],
          indiceSeleccionado: 0,
          indiceCorrecto: 0,
          esCorrecta: true,
          explicacion: 'La historia invita a reflexionar críticamente sobre cómo la solidaridad y el trabajo en equipo generan un impacto positivo y duradero en nuestra sociedad.',
          nivelComprension: 'critico_reflexivo',
        ),
      ],
    );

    // 4. Generar bytes del PDF con el servicio corregido
    final pdfBytes = await PdfExportService().generarPdf(
      cuento,
      intentoQuiz: intento,
    );

    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.take(4).toList(), [37, 80, 68, 70]); // %PDF

    // 5. Guardar archivo final en carpeta de evidencias
    final outputPath = 'evidencias_tesis_20261014/04_exportacion_pdf/cuento_valle_dorado_evaluacion_completa_221.pdf';
    final outFile = File(outputPath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(pdfBytes);

    // 6. Extraer y verificar texto de todas las páginas del PDF
    final doc = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(doc);
    final textoCompleto = extractor.extractText();
    doc.dispose();

    // Comprobar presencia de niveles 2-2-1
    expect(textoCompleto, contains('Pregunta 1 - Nivel: Literal'));
    expect(textoCompleto, contains('Pregunta 2 - Nivel: Literal'));
    expect(textoCompleto, contains('Pregunta 3 - Nivel: Inferencial'));
    expect(textoCompleto, contains('Pregunta 4 - Nivel: Inferencial'));
    expect(textoCompleto, contains('Pregunta 5 - Nivel: Crítico-reflexivo'));
    expect(textoCompleto, isNot(contains('Nivel: General')));

    // Normalizar texto para verificar que las explicaciones no están cortadas
    final textoNormalizado = textoCompleto.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      textoNormalizado,
      contains('colocar una gran rama de abedul en su dique.'),
    );
    expect(
      textoNormalizado,
      contains('molino para festejar el flujo de agua.'),
    );
    expect(
      textoNormalizado,
      contains('mover la madera sin apoyo.'),
    );
    expect(
      textoNormalizado,
      contains('tranquilidad y felicidad a toda la comunidad natural.'),
    );
    expect(
      textoNormalizado,
      contains('impacto positivo y duradero en nuestra sociedad.'),
    );
  });
}
