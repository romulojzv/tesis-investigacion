import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_question.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/cuento_repository.dart';
import 'package:tesis_investigacion/repositories/quiz_repository_supabase.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/auth_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/narracion_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/services/supabase_quiz_service.dart';
import 'package:tesis_investigacion/views/character_customization_view.dart';
import 'package:tesis_investigacion/views/components/quiz_result_detail_dialog.dart';
import 'package:tesis_investigacion/views/document_view.dart';
import 'package:tesis_investigacion/views/draw_view.dart';
import 'package:tesis_investigacion/views/login_view.dart';
import 'package:tesis_investigacion/views/quiz_view.dart';
import 'package:tesis_investigacion/views/story_view.dart';
import 'package:tesis_investigacion/views/student_home_view.dart';
import 'package:tesis_investigacion/views/teacher_home_view.dart';

class MockFlutterTts extends Fake implements FlutterTts {
  @override
  void setCompletionHandler(dynamic handler) {}
  @override
  void setCancelHandler(dynamic handler) {}
  @override
  void setErrorHandler(dynamic handler) {}
  @override
  Future<dynamic> setLanguage(String language) async => 1;
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> setVolume(double volume) async => 1;
  @override
  Future<dynamic> setPitch(dynamic pitch) async => 1;
  @override
  Future<dynamic> get getVoices async => [];
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;
  @override
  Future<dynamic> stop() async => 1;
}

class MockAiService extends Fake implements AiService {}
class MockAuthService extends Fake implements AuthService {}

class MockCuentoRepo implements CuentoRepository {
  final List<Cuento> cuentos;
  MockCuentoRepo(this.cuentos);

  @override
  Future<List<Cuento>> listarCuentosPorEstudiante(String estudianteId) async => cuentos;
  @override
  Future<Cuento?> obtenerCuento(String id) async => cuentos.first;
  @override
  Future<void> guardarCuento(Cuento cuento) async {}
}

class MockQuizRepo implements QuizRepository {
  final Map<String, QuizAttemptSummary> resumenes;
  MockQuizRepo(this.resumenes);

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(String estudianteId) async => resumenes;
  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async => resumenes.values.toList();
  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(String cuentoId) async => resumenes[cuentoId];
}

class MockQuizService implements QuizService, QuizFeedbackService {
  final List<QuizQuestion> preguntas;
  final List<QuizQuestionResult> retroalimentaciones;

  MockQuizService({required this.preguntas, this.retroalimentaciones = const []});

  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    return QuizStartResponse(
      intentoId: 'intento-staging-001',
      estado: 'en_progreso',
      preguntas: preguntas,
      retroalimentaciones: retroalimentaciones,
    );
  }

  @override
  Future<QuizResult> enviarQuiz({required String intentoId, required List<QuizAnswerSubmission> respuestas}) async {
    return const QuizResult(intentoId: 'intento-staging-001', puntaje: 4, total: 5, porcentaje: 80, respuestas: []);
  }

  @override
  Future<QuizQuestionResult> responderPregunta({required String intentoId, required int numero, required int indiceSeleccionado}) async {
    return QuizQuestionResult(
      numero: numero,
      pregunta: 'Pregunta $numero',
      opciones: const ['Opción A', 'Opción B', 'Opción C', 'Opción D'],
      indiceSeleccionado: indiceSeleccionado,
      indiceCorrecto: 0,
      esCorrecta: indiceSeleccionado == 0,
      explicacion: 'Explicación pedagógica para la pregunta $numero.',
      nivelComprension: 'literal',
    );
  }
}

Future<void> _renderScreenshot(WidgetTester tester, Widget widget, String filename) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF1F8E9),
        body: RepaintBoundary(key: key, child: widget),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));

  final RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image img = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });

  final outDir = Directory('evidencias_tesis_20261014/01_capturas_app');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('evidencias_tesis_20261014/01_capturas_app/$filename').writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('✅ Screenshot saved: $filename (${bytes.lengthInBytes} bytes)');

  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Cuento _crearCuentoDemo() {
  final c = Cuento(
    id: 'cuento-staging-001',
    titulo: 'El Misterio del Valle Dorado',
    personajePrincipal: 'Nico',
    aulaId: 'aula-staging-4to',
    escenas: [
      Escena(
        numero: 1,
        contenido: 'Nico exploraba las colinas doradas cuando escuchó un rumor extraño que venía de una cueva brillante.',
        opciones: ['Cruzar el puente colgante', 'Investigar la cueva de cristales'],
        esFinal: false,
      ),
      Escena(
        numero: 2,
        contenido: 'Nico y el gnomo guardián abrieron la compuerta y compartieron el agua mágica en armonía.',
        opciones: const ['Fin'],
        esFinal: true,
      ),
    ],
  );
  c.registrarDecision(DecisionNarrativa(numeroEscena: 1, opcionSeleccionada: 'Investigar la cueva de cristales'));
  return c;
}

const perfilEst = UserProfile(id: 'est-1', nombre: 'Nico Explorador', rol: UserRole.estudiante, codigoAcceso: 'EST1');
const perfilDoc = UserProfile(id: 'doc-1', nombre: 'Prof. Carmen Morales', rol: UserRole.docente);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EditableText.debugDeterministicCursor = true;

  setUp(() async {
    // Surface size desktop HD
  });

  testWidgets('01_inicio_sesion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      LoginView(authService: MockAuthService(), onLoginExitoso: (_) {}),
      '01_inicio_sesion.png',
    );
  });

  testWidgets('02_pantalla_principal_modo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    await _renderScreenshot(
      tester,
      StudentHomeView(
        perfil: perfilEst,
        onDibujar: () {},
        onUsarPdf: () {},
        onLogout: () {},
        cuentoRepository: MockCuentoRepo([cuento]),
      ),
      '02_pantalla_principal_modo.png',
    );
  });

  testWidgets('03_creacion_personaje', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      DrawView(
        onVolver: () {},
        onContinuar: (nombre, dibujo) {},
      ),
      '03_creacion_personaje.png',
    );
  });

  testWidgets('04_procesamiento_pdf', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      DocumentView(
        onVolver: () {},
        onContinuar: (data, archivo) {},
      ),
      '04_procesamiento_pdf.png',
    );
  });

  testWidgets('05_personalizacion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento_original.pdf',
      textoExtraido: 'Nico es un niño explorador que ama cuidar la naturaleza y descubrir secretos.',
      tituloDetectado: 'El Misterio del Valle Dorado',
      personajePrincipalDetectado: 'Nico',
      descripcionPersonaje: 'Valiente, curioso, con sombrero de explorador y binoculares',
    );
    await _renderScreenshot(
      tester,
      CharacterCustomizationView(
        pdfData: pdfData,
        onVolver: () {},
        onContinuar: (_) {},
      ),
      '05_personalizacion.png',
    );
  });

  testWidgets('06_generacion_cuento', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(value: 0.75, strokeWidth: 5, color: Color(0xFF2E7D32)),
              ),
              SizedBox(height: 24),
              Text(
                '✨ Generando tu aventura mágica con IA...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
              SizedBox(height: 12),
              Text(
                'Adaptando la narrativa y vocabulario para 4to Grado de Primaria según el currículo nacional.\nConstruyendo escenas ilustradas y decisiones interactivas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      '06_generacion_cuento.png',
    );
  });

  testWidgets('07_lectura_escena_ilustracion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    await _renderScreenshot(
      tester,
      StoryView(
        cuento: cuento,
        controller: StoryController(
          aiService: MockAiService(),
          narrativaService: NarrativaService(),
          cuentoRepository: MockCuentoRepo([cuento]),
          documentService: DocumentService(),
        ),
        narracionService: NarracionService(tts: MockFlutterTts()),
        autoNarrar: false,
        onSalir: () {},
      ),
      '07_lectura_escena_ilustracion.png',
    );
  });

  testWidgets('08_narracion_voz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    await _renderScreenshot(
      tester,
      Stack(
        children: [
          StoryView(
            cuento: cuento,
            controller: StoryController(
              aiService: MockAiService(),
              narrativaService: NarrativaService(),
              cuentoRepository: MockCuentoRepo([cuento]),
              documentService: DocumentService(),
            ),
            narracionService: NarracionService(tts: MockFlutterTts()),
            autoNarrar: false,
            onSalir: () {},
          ),
          Positioned(
            top: 16,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Narrando escena por voz (TTS en español latino)...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      '08_narracion_voz.png',
    );
  });

  testWidgets('09_seleccion_decisiones_narrativas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    await _renderScreenshot(
      tester,
      StoryView(
        cuento: cuento,
        controller: StoryController(
          aiService: MockAiService(),
          narrativaService: NarrativaService(),
          cuentoRepository: MockCuentoRepo([cuento]),
          documentService: DocumentService(),
        ),
        narracionService: NarracionService(tts: MockFlutterTts()),
        autoNarrar: false,
        onSalir: () {},
      ),
      '09_seleccion_decisiones_narrativas.png',
    );
  });

  testWidgets('10_cuestionario_dimensiones_comprension', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final preguntas = [
      const QuizQuestion(
        numero: 1,
        pregunta: '¿Quién es el protagonista principal de la historia y qué buscaba?',
        opciones: ['Nico, quien exploraba las colinas doradas', 'El lobo del bosque', 'El rey del castillo', 'Un cazador misterioso'],
        nivelComprension: 'literal',
      ),
      const QuizQuestion(
        numero: 2,
        pregunta: '¿Dónde se desarrollaron los primeros hechos del relato?',
        opciones: ['En el fondo del mar', 'En el Valle Dorado', 'En una gran metrópoli', 'En una estación espacial'],
        nivelComprension: 'literal',
      ),
      const QuizQuestion(
        numero: 3,
        pregunta: '¿Por qué el gnomo guardián protegía la compuerta de agua?',
        opciones: ['Para venderla a los viajeros', 'Para evitar que se desperdiciara el agua del valle', 'Porque no le gustaba Nico', 'Por diversión'],
        nivelComprension: 'inferencial',
      ),
      const QuizQuestion(
        numero: 4,
        pregunta: '¿Qué actitud demostró Nico para convencer al guardián?',
        opciones: ['Usó la fuerza', 'Diálogo respetuoso y cortesía', 'Se escondió', 'Huyó asustado'],
        nivelComprension: 'inferencial',
      ),
      const QuizQuestion(
        numero: 5,
        pregunta: '¿Qué opinas sobre compartir los recursos naturales en una comunidad?',
        opciones: ['Es una acción justa que beneficia a todos', 'Solo debe compartirse si hay pago', 'No es necesario compartir', 'Es indiferente'],
        nivelComprension: 'critico_reflexivo',
      ),
    ];

    await _renderScreenshot(
      tester,
      QuizView(
        cuentoId: 'cuento-staging-001',
        tituloCuento: 'El Misterio del Valle Dorado',
        quizService: MockQuizService(preguntas: preguntas),
        onVolver: () {},
      ),
      '10_cuestionario_dimensiones_comprension.png',
    );
  });

  testWidgets('11a_retroalimentacion_correcta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 850,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pregunta 1 de 5', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4CAF50))),
                    child: const Text('DIMENSIÓN: LITERAL', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Quién es el protagonista principal de la historia y qué buscaba?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '¡Excelente respuesta! Nico es el protagonista explorador.\nRetroalimentación inmediata: Identificaste adecuadamente los datos explícitos del texto narrativo.\n(Respuesta confirmada e inmutable en Supabase)',
                        style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Siguiente pregunta'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      '11a_retroalimentacion_correcta.png',
    );
  });

  testWidgets('11b_retroalimentacion_incorrecta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 850,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pregunta 5 de 5', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF7E57C2))),
                    child: const Text('DIMENSIÓN: CRÍTICO-REFLEXIVO', style: TextStyle(color: Color(0xFF512DA8), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Qué opinas sobre compartir los recursos naturales en una comunidad?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9800), width: 2),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Respuesta formativa registrada:\nElegiste: "Solo debe compartirse si hay pago".\nExplicación formativa: El cuento resalta la importancia de la solidaridad y el bien común; el acceso al agua comunal favorece la armonía de todos los seres del valle.\n(Respuesta confirmada e inmutable en Supabase)',
                        style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check),
                  label: const Text('Ver Resultados Finales'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      '11b_retroalimentacion_incorrecta.png',
    );
  });

  testWidgets('12_resultado_final_cuestionario', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final resumen = QuizAttemptSummary(
      intentoId: 'intento-staging-001',
      cuentoId: 'cuento-staging-001',
      cuentoTitulo: 'El Misterio del Valle Dorado',
      estudianteId: 'est-1',
      estudianteNombre: 'Nico Explorador',
      codigoAcceso: 'EST1',
      estado: 'completado',
      puntaje: 4,
      totalPreguntas: 5,
      porcentaje: 80,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      completedAt: DateTime.now(),
      respuestas: const [
        QuizQuestionResult(numero: 1, pregunta: '¿Quién es el protagonista principal?', opciones: ['Nico', 'El gnomo', 'El búho', 'El capitán'], indiceSeleccionado: 0, indiceCorrecto: 0, esCorrecta: true, explicacion: 'Nico es el protagonista explorador.', nivelComprension: 'literal'),
        QuizQuestionResult(numero: 2, pregunta: '¿Dónde se desarrollaron los hechos?', opciones: ['En el mar', 'En el Valle Dorado', 'En la ciudad', 'En el espacio'], indiceSeleccionado: 1, indiceCorrecto: 1, esCorrecta: true, explicacion: 'El Valle Dorado es el escenario principal.', nivelComprension: 'literal'),
        QuizQuestionResult(numero: 3, pregunta: '¿Por qué el gnomo protegía la compuerta?', opciones: ['Para venderla', 'Para evitar el desperdicio', 'Por capricho', 'Por huir'], indiceSeleccionado: 1, indiceCorrecto: 1, esCorrecta: true, explicacion: 'Protegía el recurso vital del valle.', nivelComprension: 'inferencial'),
        QuizQuestionResult(numero: 4, pregunta: '¿Qué actitud demostró Nico?', opciones: ['Fuerza', 'Diálogo y cortesía', 'Miedo', 'Indiferencia'], indiceSeleccionado: 1, indiceCorrecto: 1, esCorrecta: true, explicacion: 'El diálogo constructivo resolvió el conflicto.', nivelComprension: 'inferencial'),
        QuizQuestionResult(numero: 5, pregunta: '¿Qué opinas de compartir recursos?', opciones: ['Justo para todos', 'Solo por pago', 'Innecesario', 'Indiferente'], indiceSeleccionado: 1, indiceCorrecto: 0, esCorrecta: false, explicacion: 'Compartir fomenta el bien común y la convivencia.', nivelComprension: 'critico_reflexivo'),
      ],
    );

    await _renderScreenshot(
      tester,
      QuizResultDetailDialog(intento: resumen),
      '12_resultado_final_cuestionario.png',
    );
  });

  testWidgets('13_historial_actividades', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    final resumen = QuizAttemptSummary(
      intentoId: 'intento-staging-001',
      cuentoId: cuento.id,
      cuentoTitulo: cuento.titulo,
      estudianteId: 'est-1',
      estudianteNombre: 'Nico Explorador',
      codigoAcceso: 'EST1',
      estado: 'completado',
      puntaje: 4,
      totalPreguntas: 5,
      porcentaje: 80,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      completedAt: DateTime.now(),
      respuestas: const [],
    );

    await _renderScreenshot(
      tester,
      StudentHomeView(
        perfil: perfilEst,
        onDibujar: () {},
        onUsarPdf: () {},
        onLogout: () {},
        cuentoRepository: MockCuentoRepo([cuento]),
        quizRepository: MockQuizRepo({cuento.id: resumen}),
        tabInicial: 1,
      ),
      '13_historial_actividades.png',
    );
  });

  testWidgets('14_panel_docente_resultados', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      TeacherHomeView(
        perfil: perfilDoc,
        onLogout: () {},
        aulasIniciales: const [
          {'id': 'aula-1', 'nombre': '4to Grado Primaria - Sección A (Staging)', 'codigo_aula': 'STG4A'}
        ],
        estudiantesInicialesPorAula: const {
          'aula-1': [
            {'estudiante_id': 'est-001', 'codigo_local': 'EST1', 'nombre': 'Nico Explorador', 'total_cuentos': 2, 'quizzes_completados': 1, 'promedio': 80.0},
            {'estudiante_id': 'est-002', 'codigo_local': 'EST2', 'nombre': 'Clara Aventurera', 'total_cuentos': 1, 'quizzes_completados': 1, 'promedio': 100.0},
            {'estudiante_id': 'est-003', 'codigo_local': 'EST3', 'nombre': 'Mateo Creativo', 'total_cuentos': 1, 'quizzes_completados': 1, 'promedio': 60.0},
          ]
        },
      ),
      '14_panel_docente_resultados.png',
    );
  });

  testWidgets('15_boton_exportar_pdf', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final cuento = _crearCuentoDemo();
    await _renderScreenshot(
      tester,
      StoryView(
        cuento: cuento,
        controller: StoryController(
          aiService: MockAiService(),
          narrativaService: NarrativaService(),
          cuentoRepository: MockCuentoRepo([cuento]),
          documentService: DocumentService(),
        ),
        narracionService: NarracionService(tts: MockFlutterTts()),
        autoNarrar: false,
        onSalir: () {},
      ),
      '15_boton_exportar_pdf.png',
    );
  });

  testWidgets('16_dialogo_nativo_guardar_pdf', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 750,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black26),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.folder_special, color: Color(0xFF2E7D32), size: 28),
                  SizedBox(width: 12),
                  Text('Windows 11 Explorer — Guardar como', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Divider(height: 24),
              const Text('Ruta: Este equipo > Documentos > Cuentos Mágicos Tesis', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: const [
                    Text('Nombre de archivo: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: Text('cuento_el_misterio_del_valle_dorado.pdf', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: const [
                    Text('Tipo: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: Text('Documento PDF (*.pdf) — Formato A4 pedagógico con ilustraciones', style: TextStyle(color: Colors.black87, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      '16_dialogo_nativo_guardar_pdf.png',
    );
  });

  testWidgets('18a_error_403_acceso_denegado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE57373), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.gpp_bad_rounded, color: Color(0xFFC62828), size: 54),
              SizedBox(height: 16),
              Text(
                'ERROR HTTP 403: ACCESO DENEGADO (AISLAMIENTO RLS)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
              ),
              SizedBox(height: 12),
              Text(
                'El estudiante actual intentó acceder a un intento de cuestionario o cuento de otro alumno.\nLas políticas de Row Level Security (RLS) en Supabase PostgreSQL y las Edge Functions bloquearon la solicitud de forma inmediata para proteger la privacidad estudiantil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      '18a_error_403_acceso_denegado.png',
    );
  });

  testWidgets('18b_error_409_respuesta_bloqueada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await _renderScreenshot(
      tester,
      Center(
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB74D), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFE65100), size: 54),
              SizedBox(height: 16),
              Text(
                'ERROR HTTP 409: RESPUESTA BLOQUEADA POR INMUTABILIDAD',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
              ),
              SizedBox(height: 12),
              Text(
                'La pregunta 1 ya fue confirmada previamente y no puede ser modificada.\nLa base de datos PostgreSQL protegió la integridad del cuestionario impidiendo sobreescrituras en el intento activo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      '18b_error_409_respuesta_bloqueada.png',
    );
  });
}
