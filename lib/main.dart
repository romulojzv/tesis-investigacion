import 'dart:typed_data';

import 'services/image_service.dart';
import 'services/supabase_ai_service.dart';
import 'services/supabase_image_service.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/story_controller.dart';
import 'models/character_customization.dart';
import 'models/cuento.dart';
import 'models/escena.dart';
import 'models/generated_scene.dart';
import 'models/pdf_story_data.dart';
import 'models/story_analysis.dart';
import 'repositories/cuento_repository.dart';
import 'repositories/cuento_repository_memoria.dart';
import 'repositories/cuento_repository_supabase.dart';
import 'services/ai_service.dart';
import 'services/document_service.dart';
import 'services/narrativa_service.dart';
import 'models/user_profile.dart';
import 'models/quiz_question.dart';
import 'models/quiz_result.dart';
import 'models/quiz_attempt_summary.dart';
import 'repositories/quiz_repository_supabase.dart';
import 'services/auth_service.dart';
import 'services/supabase_quiz_service.dart';
import 'views/auth_gate.dart';
import 'views/character_customization_view.dart';
import 'views/document_view.dart';
import 'views/draw_view.dart';
import 'views/quiz_view.dart';
import 'views/story_view.dart';
import 'views/student_home_view.dart';

/// Prepara y limpia determinísticamente la sesión local al inicio cuando FORCE_LOGIN_ON_START=true.
/// Limpia tanto las claves en almacenamiento persistido (SharedPreferences) para que
/// recoverSession() no restaure nada en segundo plano, como la sesión en memoria mediante signOut(scope: local).
Future<void> prepararSesionInicial({
  bool forceLoginOnStart = true,
  AuthService? authService,
}) async {
  if (!forceLoginOnStart) return;

  if (authService != null) {
    await authService.limpiarSesionLocalAlInicio();
    return;
  }

  // 1. Limpieza preventiva de SharedPreferences antes o durante arranque
  try {
    final prefs = await SharedPreferences.getInstance();
    final claves = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('sb-') ||
              k.contains('auth-token') ||
              k.contains('supabase'),
        )
        .toList();
    for (final k in claves) {
      await prefs.remove(k);
    }
  } catch (e) {
    debugPrint('[Startup] Error limpiando almacenamiento local previo: $e');
  }

  // 2. SignOut local explícito en cliente Supabase
  try {
    if (Supabase.instance.isInitialized) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
  } catch (e) {
    debugPrint('[Startup] Error en signOut local de Supabase: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  debugPrint(
    'SUPABASE URL cargada: '
    '${supabaseUrl.isNotEmpty}',
  );

  debugPrint(
    'SUPABASE KEY cargada: '
    '${supabasePublishableKey.isNotEmpty}',
  );

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL o '
      'SUPABASE_PUBLISHABLE_KEY.',
    );
  }

  const forceLoginOnStart = bool.fromEnvironment(
    'FORCE_LOGIN_ON_START',
    defaultValue: true,
  );

  // Limpieza en disco previa a Supabase.initialize para anular recoverSession() asíncrono
  if (forceLoginOnStart) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claves = prefs
          .getKeys()
          .where(
            (k) =>
                k.startsWith('sb-') ||
                k.contains('auth-token') ||
                k.contains('supabase'),
          )
          .toList();
      for (final k in claves) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[Startup] Error limpiando almacenamiento local previo: $e');
    }
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  // Limpieza en memoria post Supabase.initialize
  if (forceLoginOnStart) {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('Error al limpiar sesión local en arranque: $e');
    }
  }

  runApp(const CuentosMagicosApp());
}

class CuentosMagicosApp extends StatelessWidget {
  final AuthService? authService;
  final CuentoRepository? cuentoRepository;
  final AiService? aiService;
  final ImageService? imageService;
  final NarrativaService? narrativaService;
  final DocumentService? documentService;
  final QuizService? quizService;
  final QuizRepository? quizRepository;
  final Future<void>? initializationFuture;

  const CuentosMagicosApp({
    super.key,
    this.authService,
    this.cuentoRepository,
    this.aiService,
    this.imageService,
    this.narrativaService,
    this.documentService,
    this.quizService,
    this.quizRepository,
    this.initializationFuture,
  });

  @override
  Widget build(BuildContext context) {
    final home = _HomeRouter(
      authService: authService,
      cuentoRepository: cuentoRepository,
      aiService: aiService,
      imageService: imageService,
      narrativaService: narrativaService,
      documentService: documentService,
      quizService: quizService,
      quizRepository: quizRepository,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cuentos Mágicos',
      theme: ThemeData(useMaterial3: true),
      home: initializationFuture == null
          ? home
          : FutureBuilder<void>(
              future: initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    backgroundColor: Color(0xFFFFF8F0),
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF39C12),
                      ),
                    ),
                  );
                }
                return home;
              },
            ),
    );
  }
}

enum AppScreen { home, drawing, document, characterCustomization, story, quiz }

class _FallbackAiService implements AiService {
  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async => StoryAnalysis(
    titulo: 'Cuento',
    personajePrincipal: 'Personaje',
    descripcionPersonaje: '',
    resumen: '',
    escenario: '',
    conflictoPrincipal: '',
    finalOriginal: '',
  );

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
  }) async => GeneratedScene(
    contenido: 'Inicio',
    opciones: const ['Opción 1'],
    esFinal: false,
  );

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
  }) async => GeneratedScene(
    contenido: 'Escena $numeroEscena',
    opciones: esUltimaEscena ? const [] : const ['Opción 1'],
    esFinal: esUltimaEscena,
  );
}

class _FallbackQuizService implements QuizService {
  @override
  Future<QuizStartResponse> generarQuiz(String cuentoId) async {
    return QuizStartResponse(
      intentoId: 'mock-intento',
      estado: 'en_progreso',
      preguntas: [
        for (var i = 1; i <= 5; i++)
          QuizQuestion(
            numero: i,
            pregunta: 'Pregunta $i de comprensión',
            opciones: const ['Opción A', 'Opción B', 'Opción C', 'Opción D'],
          ),
      ],
    );
  }

  @override
  Future<QuizResult> enviarQuiz({
    required String intentoId,
    required List<QuizAnswerSubmission> respuestas,
  }) async {
    return QuizResult(
      intentoId: intentoId,
      puntaje: 5,
      total: 5,
      porcentaje: 100,
      respuestas: [
        for (var i = 1; i <= 5; i++)
          QuizQuestionResult(
            numero: i,
            pregunta: 'Pregunta $i de comprensión',
            opciones: const ['Opción A', 'Opción B', 'Opción C', 'Opción D'],
            indiceSeleccionado: 0,
            indiceCorrecto: 0,
            esCorrecta: true,
            explicacion: 'Explicación de la pregunta $i',
          ),
      ],
    );
  }
}

class _FallbackQuizRepository implements QuizRepository {
  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async =>
      const [];

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async => const {};

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async => null;
}

class _HomeRouter extends StatefulWidget {
  final AuthService? authService;
  final CuentoRepository? cuentoRepository;
  final AiService? aiService;
  final ImageService? imageService;
  final NarrativaService? narrativaService;
  final DocumentService? documentService;
  final QuizService? quizService;
  final QuizRepository? quizRepository;

  const _HomeRouter({
    this.authService,
    this.cuentoRepository,
    this.aiService,
    this.imageService,
    this.narrativaService,
    this.documentService,
    this.quizService,
    this.quizRepository,
  });

  @override
  State<_HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<_HomeRouter> {
  AppScreen _pantalla = AppScreen.home;

  Cuento? _cuento;

  PdfStoryData? _pdfProcesado;

  CharacterCustomization? _personalizacionPdf;

  /*
   * Indica si DrawView se abrió desde
   * el flujo normal o desde un PDF.
   */
  bool _dibujoDesdePdf = false;

  bool _procesandoPdf = false;
  bool _creandoCuento = false;

  bool _esModoHistorico = false;
  int _studentHomeTab = 0;
  QuizAttemptSummary? _intentoQuizActual;

  late final AiService _aiService;

  late final NarrativaService _narrativaService;

  late final DocumentService _documentService;

  late final CuentoRepository _cuentoRepository;

  late final StoryController _storyController;

  late final AuthService _authService;

  late final QuizService _quizService;

  late final QuizRepository _quizRepository;

  @override
  void initState() {
    super.initState();

    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }

    _authService =
        widget.authService ??
        (client != null ? AuthService(client: client) : AuthService());

    _narrativaService = widget.narrativaService ?? NarrativaService();

    _documentService = widget.documentService ?? DocumentService();

    _cuentoRepository =
        widget.cuentoRepository ??
        (client != null
            ? CuentoRepositorySupabase(client: client)
            : CuentoRepositoryMemoria());
    _aiService =
        widget.aiService ??
        (client != null
            ? SupabaseAiService(client: client)
            : _FallbackAiService());
    _storyController = StoryController(
      narrativaService: _narrativaService,
      cuentoRepository: _cuentoRepository,
      documentService: _documentService,
      aiService: _aiService,
      imageService:
          widget.imageService ??
          (client != null ? SupabaseImageService(client: client) : null),
    );
    _quizService =
        widget.quizService ??
        (client != null
            ? SupabaseQuizService(client: client)
            : _FallbackQuizService());
    _quizRepository =
        widget.quizRepository ??
        (client != null
            ? QuizRepositorySupabase(client: client)
            : _FallbackQuizRepository());
  }

  // =========================================================
  // INICIO
  // =========================================================

  void _irInicio({int tab = 0}) {
    setState(() {
      _pantalla = AppScreen.home;
      _studentHomeTab = tab;
      _esModoHistorico = false;
      _intentoQuizActual = null;

      _cuento = null;

      _pdfProcesado = null;

      _personalizacionPdf = null;

      _dibujoDesdePdf = false;

      _procesandoPdf = false;

      _creandoCuento = false;
    });
  }

  // =========================================================
  // DIBUJO NORMAL
  // =========================================================

  Future<void> _crearCuentoDesdeDibujo(
    String nombrePersonaje,
    Uint8List dibujoPng, {
    String? descripcionPersonaje,
  }) async {
    if (_creandoCuento) {
      return;
    }

    _creandoCuento = true;

    try {
      final id = 'cuento-${DateTime.now().microsecondsSinceEpoch}';

      final cuento = await _storyController.crearCuentoInicialDemo(
        id: id,
        nombrePersonaje: nombrePersonaje,
        dibujoReferenciaPng: dibujoPng,
        descripcionPersonaje: descripcionPersonaje,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cuento = cuento;

        _pantalla = AppScreen.story;
      });
    } catch (error) {
      _mostrarError('No pudimos crear el cuento.', error);
    } finally {
      _creandoCuento = false;
    }
  }

  // =========================================================
  // PROCESAR PDF
  // =========================================================

  Future<void> _procesarPdf(String nombreArchivo, Uint8List pdfBytes) async {
    if (_procesandoPdf) {
      return;
    }

    _procesandoPdf = true;

    try {
      final datos = await _storyController.procesarPdf(
        nombreArchivo: nombreArchivo,
        pdfBytes: pdfBytes,
      );

      if (!mounted) {
        return;
      }

      debugPrint(
        'PDF procesado: '
        '${datos.textoExtraido.length} caracteres extraídos.',
      );

      setState(() {
        _pdfProcesado = datos;

        _personalizacionPdf = null;

        _pantalla = AppScreen.characterCustomization;
      });
    } catch (error) {
      _mostrarError('No pudimos analizar el PDF.', error);
    } finally {
      _procesandoPdf = false;
    }
  }

  // =========================================================
  // PERSONALIZACIÓN
  // =========================================================

  Future<void> _confirmarPersonalizacionPdf(
    CharacterCustomization personalizacion,
  ) async {
    if (_creandoCuento) {
      return;
    }

    final datosPdf = _pdfProcesado;

    if (datosPdf == null) {
      _mostrarError(
        'No hay un PDF procesado.',
        StateError('PdfStoryData es null.'),
      );

      return;
    }

    _personalizacionPdf = personalizacion;

    switch (personalizacion.visualMode) {
      // =====================================================
      // DISEÑO AUTOMÁTICO
      // =====================================================

      case CharacterVisualMode.automatic:
        await _crearCuentoPdf(
          datosPdf: datosPdf,
          personalizacion: personalizacion,
        );

        break;

      // =====================================================
      // DIBUJAR PERSONAJE
      // =====================================================

      case CharacterVisualMode.drawing:
        if (!mounted) {
          return;
        }

        setState(() {
          _dibujoDesdePdf = true;

          _pantalla = AppScreen.drawing;
        });

        break;

      // =====================================================
      // IMÁGENES DEL PDF
      // =====================================================

      case CharacterVisualMode.pdfImages:
        final imagen = personalizacion.imagenReferencia;
        if (imagen == null) {
          _mostrarError(
            'No se seleccionó una imagen del PDF.',
            StateError('imagenReferencia es null.'),
          );
          return;
        }

        await _crearCuentoPdf(
          datosPdf: datosPdf,
          personalizacion: personalizacion,
          imagenReferenciaPng: imagen,
        );

        break;
    }
  }

  // =========================================================
  // CREAR CUENTO PDF SIN DIBUJO
  // =========================================================

  Future<void> _crearCuentoPdf({
    required PdfStoryData datosPdf,
    required CharacterCustomization personalizacion,
    Uint8List? imagenReferenciaPng,
  }) async {
    if (_creandoCuento) {
      return;
    }

    _creandoCuento = true;

    try {
      final id = 'cuento-${DateTime.now().microsecondsSinceEpoch}';

      final cuento = await _storyController.crearCuentoDesdePdfProcesadoDemo(
        id: id,
        datosPdf: datosPdf,
        personalizacion: personalizacion,
        dibujoReferenciaPng: imagenReferenciaPng,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cuento = cuento;

        _dibujoDesdePdf = false;

        _pantalla = AppScreen.story;
      });
    } catch (error) {
      _mostrarError('No pudimos crear la aventura.', error);
    } finally {
      _creandoCuento = false;
    }
  }

  // =========================================================
  // FINALIZAR DIBUJO DEL PERSONAJE DEL PDF
  // =========================================================

  Future<void> _crearCuentoPdfConDibujo(
    String nombrePersonaje,
    Uint8List dibujoPng,
  ) async {
    if (_creandoCuento) {
      return;
    }

    final datosPdf = _pdfProcesado;

    final personalizacion = _personalizacionPdf;

    if (datosPdf == null || personalizacion == null) {
      _mostrarError(
        'Se perdió la información del PDF.',
        StateError(
          'No existe información suficiente '
          'para continuar el flujo.',
        ),
      );

      return;
    }

    /*
     * Protección adicional:
     * DrawView debe devolver el mismo nombre
     * que fue elegido anteriormente.
     */
    if (nombrePersonaje.trim() != personalizacion.nombrePersonaje.trim()) {
      _mostrarError(
        'El nombre del personaje no coincide.',
        StateError(
          'El nombre fue modificado durante '
          'el flujo de dibujo.',
        ),
      );

      return;
    }

    _creandoCuento = true;

    try {
      final id = 'cuento-${DateTime.now().microsecondsSinceEpoch}';

      final cuento = await _storyController.crearCuentoDesdePdfProcesadoDemo(
        id: id,
        datosPdf: datosPdf,
        personalizacion: personalizacion,
        dibujoReferenciaPng: dibujoPng,
      );

      if (!mounted) {
        return;
      }

      debugPrint(
        'Dibujo almacenado: '
        '${dibujoPng.lengthInBytes} bytes.',
      );

      setState(() {
        _cuento = cuento;

        _dibujoDesdePdf = false;

        _pantalla = AppScreen.story;
      });
    } catch (error) {
      _mostrarError(
        'No pudimos crear la aventura '
        'con tu personaje.',
        error,
      );
    } finally {
      _creandoCuento = false;
    }
  }

  // =========================================================
  // CALLBACK GENERAL DEL DIBUJO
  // =========================================================

  void _alFinalizarDibujo(
    String nombrePersonaje,
    Uint8List dibujoPng, {
    String? descripcionPersonaje,
  }) {
    if (_dibujoDesdePdf) {
      _crearCuentoPdfConDibujo(nombrePersonaje, dibujoPng);

      return;
    }

    _crearCuentoDesdeDibujo(
      nombrePersonaje,
      dibujoPng,
      descripcionPersonaje: descripcionPersonaje,
    );
  }

  // =========================================================
  // VOLVER DESDE DIBUJO
  // =========================================================

  void _volverDesdeDibujo() {
    if (_creandoCuento) {
      return;
    }

    if (_dibujoDesdePdf) {
      setState(() {
        _dibujoDesdePdf = false;

        _pantalla = AppScreen.characterCustomization;
      });

      return;
    }

    setState(() {
      _pantalla = AppScreen.home;
    });
  }

  // =========================================================
  // ERROR
  // =========================================================

  void _mostrarError(String mensaje, Object error) {
    debugPrint('$mensaje Error: $error');

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // =========================================================
  // NARRACIÓN TEMPORAL
  // =========================================================

  Future<void> _narrarDemo(Escena escena) async {
    debugPrint(
      'Narrando escena '
      '${escena.numero}: '
      '${escena.contenido}',
    );

    await Future.delayed(const Duration(milliseconds: 800));
  }

  // =========================================================
  // INTERFAZ / NAVEGACIÓN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      authService: _authService,
      studentBuilder: (context, perfil) {
        return _buildStudentFlow(perfil);
      },
    );
  }

  Widget _buildStudentFlow(UserProfile perfil) {
    switch (_pantalla) {
      // =====================================================
      // DIBUJO
      // =====================================================

      case AppScreen.drawing:
        final personalizacion = _personalizacionPdf;

        return DrawView(
          nombrePersonajeFijo: _dibujoDesdePdf
              ? personalizacion?.nombrePersonaje
              : null,

          onVolver: _volverDesdeDibujo,

          onContinuar: (nombre, dibujo) {
            _alFinalizarDibujo(nombre, dibujo);
          },

          onContinuarConDescripcion: (nombre, dibujo, descripcion) {
            _alFinalizarDibujo(
              nombre,
              dibujo,
              descripcionPersonaje: descripcion,
            );
          },
        );

      // =====================================================
      // PDF
      // =====================================================

      case AppScreen.document:
        return DocumentView(
          onVolver: () {
            if (_procesandoPdf) {
              return;
            }

            setState(() {
              _pantalla = AppScreen.home;
            });
          },
          onContinuar: (archivo, pdfBytes) {
            _procesarPdf(archivo, pdfBytes);
          },
        );

      // =====================================================
      // PERSONALIZAR PERSONAJE
      // =====================================================

      case AppScreen.characterCustomization:
        final datos = _pdfProcesado;

        if (datos == null) {
          return _buildStudentHome(perfil);
        }

        return CharacterCustomizationView(
          pdfData: datos,

          onVolver: () {
            setState(() {
              _pantalla = AppScreen.document;
            });
          },

          onContinuar: _confirmarPersonalizacionPdf,
        );

      // =====================================================
      // CUENTO
      // =====================================================

      case AppScreen.story:
        final cuento = _cuento;

        if (cuento == null) {
          return _buildStudentHome(perfil);
        }

        return StoryView(
          cuento: cuento,
          controller: _storyController,
          modoHistorico: _esModoHistorico,
          intentoQuiz: _intentoQuizActual,
          onSalir: () => _irInicio(tab: _esModoHistorico ? 1 : 0),
          onNarrar: _narrarDemo,
          onIrEvaluacion: () async {
            if (!_esModoHistorico) {
              try {
                await _cuentoRepository.guardarCuento(cuento);
              } catch (e) {
                debugPrint('Aviso guardando cuento previo al quiz: $e');
              }
            }
            if (mounted) {
              setState(() {
                _pantalla = AppScreen.quiz;
              });
            }
          },
        );

      // =====================================================
      // QUIZ DE COMPRENSIÓN
      // =====================================================

      case AppScreen.quiz:
        final cuento = _cuento;

        if (cuento == null) {
          return _buildStudentHome(perfil);
        }

        return QuizView(
          cuentoId: cuento.id,
          tituloCuento: cuento.titulo,
          quizService: _quizService,
          onVolver: () => _irInicio(tab: 1),
          onFinalizado: () => _irInicio(tab: 1),
        );

      // =====================================================
      // HOME ESTUDIANTE
      // =====================================================

      case AppScreen.home:
        return _buildStudentHome(perfil);
    }
  }

  Widget _buildStudentHome(UserProfile perfil) {
    return StudentHomeView(
      perfil: perfil,
      cuentoRepository: _cuentoRepository,
      quizRepository: _quizRepository,
      tabInicial: _studentHomeTab,
      onDibujar: () {
        setState(() {
          _dibujoDesdePdf = false;
          _pantalla = AppScreen.drawing;
        });
      },
      onUsarPdf: () {
        setState(() {
          _dibujoDesdePdf = false;
          _pantalla = AppScreen.document;
        });
      },
      onAbrirCuento: (cuento) async {
        QuizAttemptSummary? summary;
        try {
          summary = await _quizRepository.obtenerResumenQuizPorCuento(
            cuento.id,
          );
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _cuento = cuento;
          _esModoHistorico = true;
          _intentoQuizActual = summary;
          _pantalla = AppScreen.story;
        });
      },
      onVerResultado: (cuento, intento) {
        setState(() {
          _cuento = cuento;
          _esModoHistorico = true;
          _intentoQuizActual = intento;
          _pantalla = AppScreen.quiz;
        });
      },
      onLogout: () async {
        await _authService.logout();
        _irInicio();
      },
    );
  }
}
