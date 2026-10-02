import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'controllers/story_controller.dart';
import 'models/cuento.dart';
import 'models/escena.dart';
import 'repositories/cuento_repository_memoria.dart';
import 'services/narrativa_service.dart';
import 'views/draw_view.dart';
import 'views/home_view.dart';
import 'views/story_view.dart';

void main() {
  runApp(
    const CuentosMagicosApp(),
  );
}

class CuentosMagicosApp
    extends StatelessWidget {
  const CuentosMagicosApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false,
      title:
          'Cuentos Mágicos',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home:
          const _HomeRouter(),
    );
  }
}

enum AppScreen {
  home,
  drawing,
  story,
}

class _HomeRouter
    extends StatefulWidget {
  const _HomeRouter();

  @override
  State<_HomeRouter>
      createState() =>
          _HomeRouterState();
}

class _HomeRouterState
    extends State<_HomeRouter> {
  AppScreen _pantalla =
      AppScreen.home;

  Cuento? _cuento;

  Uint8List?
      _dibujoReferencia;

  late final NarrativaService
      _narrativaService;

  late final CuentoRepositoryMemoria
      _cuentoRepository;

  late final StoryController
      _storyController;

  @override
  void initState() {
    super.initState();

    _narrativaService =
        NarrativaService();

    _cuentoRepository =
        CuentoRepositoryMemoria();

    _storyController =
        StoryController(
      narrativaService:
          _narrativaService,
      cuentoRepository:
          _cuentoRepository,
    );
  }

  void _irInicio() {
    setState(() {
      _pantalla =
          AppScreen.home;

      _cuento = null;

      _dibujoReferencia =
          null;
    });
  }

  Future<void> _crearCuento(
    String nombrePersonaje,
    Uint8List dibujoPng,
  ) async {
    /*
     * Guardamos temporalmente el dibujo.
     *
     * Cuando implementemos Storage,
     * dejará de vivir solamente
     * en memoria.
     */
    _dibujoReferencia = dibujoPng;

debugPrint(
  'Dibujo de referencia capturado: '
  '${_dibujoReferencia!.lengthInBytes} bytes',
);

    try {
      final cuento =
          await _storyController
              .crearCuentoInicialDemo(
        id: 'cuento-demo',
        nombrePersonaje:
            nombrePersonaje,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cuento =
            cuento;

        _pantalla =
            AppScreen.story;
      });
    } catch (error) {
      debugPrint(
        'Error al crear cuento: '
        '$error',
      );
    }
  }

  Future<void> _narrarDemo(
    Escena escena,
  ) async {
    /*
     * Todavía no tenemos
     * VoiceService / TTS real.
     */
    debugPrint(
      'Narrando escena '
      '${escena.numero}: '
      '${escena.contenido}',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 800,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    switch (_pantalla) {
      case AppScreen.drawing:
        return DrawView(
          onVolver: () {
            setState(() {
              _pantalla =
                  AppScreen.home;
            });
          },

          onContinuar:
              (
                nombre,
                dibujo,
              ) {
            _crearCuento(
              nombre,
              dibujo,
            );
          },
        );

      case AppScreen.story:
        final cuento =
            _cuento;

        if (cuento == null) {
          return _buildHome();
        }

        return StoryView(
          cuento:
              cuento,

          controller:
              _storyController,

          onSalir:
              _irInicio,

          onNarrar:
              _narrarDemo,

          onIrEvaluacion: () {
            debugPrint(
              'Pendiente: QuizView',
            );
          },
        );

      case AppScreen.home:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return HomeView(
      onDibujar: () {
        setState(() {
          _pantalla =
              AppScreen.drawing;
        });
      },

      onUsarPdf: () {
        debugPrint(
          'Pendiente: flujo PDF',
        );
      },
    );
  }
}