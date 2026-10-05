import 'dart:typed_data';

import 'services/supabase_ai_service.dart';
import 'services/supabase_image_service.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/story_controller.dart';
import 'models/character_customization.dart';
import 'models/cuento.dart';
import 'models/escena.dart';
import 'models/pdf_story_data.dart';
import 'repositories/cuento_repository_supabase.dart';
import 'services/document_service.dart';
import 'services/narrativa_service.dart';
import 'views/character_customization_view.dart';
import 'views/document_view.dart';
import 'views/draw_view.dart';
import 'views/home_view.dart';
import 'views/story_view.dart';

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

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const CuentosMagicosApp());
}

class CuentosMagicosApp extends StatelessWidget {
  const CuentosMagicosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cuentos Mágicos',
      theme: ThemeData(useMaterial3: true),
      home: const _HomeRouter(),
    );
  }
}

enum AppScreen { home, drawing, document, characterCustomization, story }

class _HomeRouter extends StatefulWidget {
  const _HomeRouter();

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

  late final SupabaseAiService _aiService;

  late final NarrativaService _narrativaService;

  late final DocumentService _documentService;

  late final CuentoRepositorySupabase _cuentoRepository;

  late final StoryController _storyController;

  @override
  void initState() {
    super.initState();

    _narrativaService = NarrativaService();

    _documentService = DocumentService();

    _cuentoRepository = CuentoRepositorySupabase(
      client: Supabase.instance.client,
    );
    _aiService = SupabaseAiService(client: Supabase.instance.client);
    _storyController = StoryController(
      narrativaService: _narrativaService,
      cuentoRepository: _cuentoRepository,
      documentService: _documentService,
      aiService: _aiService,
      imageService: SupabaseImageService(client: Supabase.instance.client),
    );
  }

  // =========================================================
  // INICIO
  // =========================================================

  void _irInicio() {
    setState(() {
      _pantalla = AppScreen.home;

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
    Uint8List dibujoPng,
  ) async {
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

  void _alFinalizarDibujo(String nombrePersonaje, Uint8List dibujoPng) {
    if (_dibujoDesdePdf) {
      _crearCuentoPdfConDibujo(nombrePersonaje, dibujoPng);

      return;
    }

    _crearCuentoDesdeDibujo(nombrePersonaje, dibujoPng);
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
    switch (_pantalla) {
      // =====================================================
      // DIBUJO
      // =====================================================

      case AppScreen.drawing:
        final personalizacion = _personalizacionPdf;

        return DrawView(
          /*
           * Si llegamos desde PDF:
           * se entrega el nombre ya elegido.
           *
           * Si llegamos desde Home:
           * será null y DrawView preguntará
           * el nombre normalmente.
           */
          nombrePersonajeFijo: _dibujoDesdePdf
              ? personalizacion?.nombrePersonaje
              : null,

          onVolver: _volverDesdeDibujo,

          onContinuar: (nombre, dibujo) {
            _alFinalizarDibujo(nombre, dibujo);
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
          return _buildHome();
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
          return _buildHome();
        }

        return StoryView(
          cuento: cuento,
          controller: _storyController,
          onSalir: _irInicio,
          onNarrar: _narrarDemo,
          onIrEvaluacion: () {
            debugPrint('Pendiente: QuizView');
          },
        );

      // =====================================================
      // HOME
      // =====================================================

      case AppScreen.home:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return HomeView(
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
    );
  }
}
