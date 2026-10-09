import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/story_controller.dart';
import '../models/cuento.dart';
import '../models/escena.dart';
import '../models/quiz_attempt_summary.dart';
import '../services/image_service.dart';
import '../services/narracion_service.dart';
import '../widgets/ilustracion_escena_widget.dart';

enum StoryStatus {
  reading,
  narrating,
  waitingDecision,
  generatingScene,
  error,
  finished,
}

class StoryView extends StatefulWidget {
  final Cuento cuento;
  final StoryController controller;

  final Future<void> Function(Escena escena)? onNarrar;
  final NarracionService? narracionService;
  final bool autoNarrar;
  final bool modoHistorico;
  final QuizAttemptSummary? intentoQuiz;

  final VoidCallback onSalir;
  final VoidCallback? onIrEvaluacion;

  const StoryView({
    super.key,
    required this.cuento,
    required this.controller,
    this.onNarrar,
    this.narracionService,
    required this.onSalir,
    this.onIrEvaluacion,
    this.autoNarrar = true,
    this.modoHistorico = false,
    this.intentoQuiz,
  });

  @override
  State<StoryView> createState() => _StoryViewState();
}

enum EstadoImagenEscena { sinImagen, generando, cargada, error }

class _StoryViewState extends State<StoryView> {
  int _indiceEscenaActual = 0;

  StoryStatus _status = StoryStatus.reading;

  bool _generandoSiguienteEscena = false;
  String? _opcionSeleccionada;
  String? _mensajeError;

  late final NarracionService _narracionService;

  ControladorReveladoTexto? _controladorRevelado;
  late final ValueNotifier<String> _textoReveladoNotifier;
  final Set<int> _escenasLeidas = {};

  final Map<int, EstadoImagenEscena> _estadosImagen = {};
  final Map<int, ImageAuthException> _erroresAuthImagen = {};
  Timer? _timerAutoNarracion;

  Escena get _escenaActual {
    return widget.cuento.escenas[_indiceEscenaActual];
  }

  bool get _puedeRetroceder {
    return _indiceEscenaActual > 0;
  }

  bool get _puedeAvanzar {
    return _indiceEscenaActual < widget.cuento.escenas.length - 1;
  }

  bool get _esUltimaEscenaGenerada {
    return _indiceEscenaActual == widget.cuento.escenas.length - 1;
  }

  bool get _estaProcesando {
    return _generandoSiguienteEscena ||
        _status == StoryStatus.generatingScene ||
        _status == StoryStatus.narrating;
  }

  @override
  void initState() {
    super.initState();

    _textoReveladoNotifier = ValueNotifier<String>('');

    _narracionService = widget.narracionService ?? NarracionService();
    _narracionService.onEstadoCambio = (estado) {
      if (mounted) {
        setState(() {
          if (estado == EstadoNarracion.reproduciendo) {
            _status = StoryStatus.narrating;
          } else if (_status == StoryStatus.narrating) {
            _actualizarEstadoEscena();
          }
        });
      }
    };
    _narracionService.inicializar();

    if (widget.cuento.escenas.isNotEmpty) {
      _textoReveladoNotifier.value = _escenaActual.contenido;
      _prepararEscenaActual();
    }
  }

  @override
  void dispose() {
    _timerAutoNarracion?.cancel();
    _controladorRevelado?.dispose();
    _narracionService.dispose();
    _textoReveladoNotifier.dispose();
    super.dispose();
  }

  void _actualizarEstadoEscena() {
    final escena = _escenaActual;

    if (escena.esFinal) {
      _status = StoryStatus.finished;
      return;
    }

    if (_esUltimaEscenaGenerada) {
      _status = StoryStatus.waitingDecision;
    } else {
      _status = StoryStatus.reading;
    }
  }

  void _prepararEscenaActual() {
    _actualizarEstadoEscena();

    final escena = _escenaActual;
    final yaLeida = _escenasLeidas.contains(escena.numero);

    // Si hay ImageService y la escena no tiene imagen, iniciar carga asíncrona sin bloquear lectura
    // En modo histórico: NO regenerar imágenes automáticamente (Requirement T, HISTORY-13, HISTORY-14)
    if (!widget.modoHistorico &&
        widget.controller.imageService != null &&
        (escena.imageUrl == null || escena.imageUrl!.trim().isEmpty) &&
        _estadosImagen[escena.numero] != EstadoImagenEscena.error &&
        _estadosImagen[escena.numero] != EstadoImagenEscena.generando) {
      _solicitarGeneracionImagen();
    }

    if (yaLeida) {
      // Al retroceder o volver a una escena ya leída, se muestra completa inmediatamente
      _textoReveladoNotifier.value = escena.contenido;
      _controladorRevelado?.detener(mostrarTextoCompleto: true);
    } else {
      if (widget.autoNarrar) {
        _controladorRevelado?.detener(mostrarTextoCompleto: false);
        _controladorRevelado = ControladorReveladoTexto(
          textoCompleto: escena.contenido,
          velocidad: _narracionService.velocidad,
          palabrasPorMinutoBase:
              widget.controller.narrativaConfig.palabrasPorMinutoBase,
          velocidadTtsBase: widget.controller.narrativaConfig.velocidadTtsBase,
          intervaloVisualMinimoMs:
              widget.controller.narrativaConfig.intervaloVisualMinimoMs,
          factorAjusteRevelado:
              widget.controller.narrativaConfig.factorAjusteRevelado,
        );
        _textoReveladoNotifier.value = _controladorRevelado!.textoVisible;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _timerAutoNarracion?.cancel();
          _timerAutoNarracion = Timer(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            if (_escenaActual.numero == escena.numero &&
                !_narracionService.estaReproduciendo) {
              _iniciarNarracionYRevelado();
            }
          });
        });
      } else {
        _textoReveladoNotifier.value = escena.contenido;
      }
    }
  }

  Future<void> _iniciarNarracionYRevelado() async {
    if (_status == StoryStatus.generatingScene) return;
    if (_narracionService.estaReproduciendo) return;

    final escena = _escenaActual;
    _escenasLeidas.add(escena.numero);

    _controladorRevelado?.detener(mostrarTextoCompleto: false);
    _controladorRevelado = ControladorReveladoTexto(
      textoCompleto: escena.contenido,
      velocidad: _narracionService.velocidad,
      palabrasPorMinutoBase:
          widget.controller.narrativaConfig.palabrasPorMinutoBase,
      velocidadTtsBase: widget.controller.narrativaConfig.velocidadTtsBase,
      intervaloVisualMinimoMs:
          widget.controller.narrativaConfig.intervaloVisualMinimoMs,
      factorAjusteRevelado:
          widget.controller.narrativaConfig.factorAjusteRevelado,
    );

    _textoReveladoNotifier.value = _controladorRevelado!.textoVisible;
    setState(() {
      _status = StoryStatus.narrating;
      _mensajeError = null;
    });

    _controladorRevelado!.iniciar(
      onTick: (texto) {
        if (mounted && _escenaActual.numero == escena.numero) {
          _textoReveladoNotifier.value = texto;
        }
      },
      onCompleto: () {
        if (mounted && _escenaActual.numero == escena.numero) {
          _textoReveladoNotifier.value = escena.contenido;
        }
      },
    );

    try {
      if (widget.onNarrar != null) {
        widget.onNarrar!(escena);
      }
      await _narracionService.narrarTextoCompleto(escena.contenido);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = StoryStatus.error;
          _mensajeError = 'No pudimos reproducir la narración.';
        });
      }
    } finally {
      _controladorRevelado?.mostrarTodo();
      if (mounted && _escenaActual.numero == escena.numero) {
        _textoReveladoNotifier.value = escena.contenido;
        setState(() {
          _actualizarEstadoEscena();
        });
      }
    }
  }

  Future<void> _detenerNarracion() async {
    await _narracionService.detener();
    _controladorRevelado?.mostrarTodo();
    if (mounted) {
      _textoReveladoNotifier.value = _escenaActual.contenido;
      setState(() {
        _actualizarEstadoEscena();
      });
    }
  }

  void _retroceder() {
    if (!_puedeRetroceder || _estaProcesando) {
      return;
    }

    _detenerNarracion();

    setState(() {
      _indiceEscenaActual--;
      _opcionSeleccionada = null;
      _mensajeError = null;
      _prepararEscenaActual();
    });
  }

  void _avanzar() {
    if (!_puedeAvanzar || _estaProcesando) {
      return;
    }

    _detenerNarracion();

    setState(() {
      _indiceEscenaActual++;
      _opcionSeleccionada = null;
      _mensajeError = null;
      _prepararEscenaActual();
    });
  }

  Future<void> _narrarEscena() async {
    if (_status == StoryStatus.generatingScene) {
      return;
    }

    if (_status == StoryStatus.narrating ||
        _narracionService.estaReproduciendo) {
      await _detenerNarracion();
      return;
    }

    await _iniciarNarracionYRevelado();
  }

  Future<void> _reiniciarNarracion() async {
    if (_status == StoryStatus.generatingScene) return;
    await _detenerNarracion();
    await _iniciarNarracionYRevelado();
  }

  void _abrirAjustesVoz() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final voces = _narracionService.vocesDisponibles;
            final vozActual = _narracionService.vozSeleccionada;
            final velocidadActual = _narracionService.velocidad;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    color: Color(0xFFE65100),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Ajustes de Narración',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Velocidad de lectura:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('🐢', style: TextStyle(fontSize: 20)),
                        Expanded(
                          child: Slider(
                            value: velocidadActual,
                            min: 0.25,
                            max: 0.85,
                            divisions: 6,
                            label:
                                '${(velocidadActual * 2).toStringAsFixed(1)}x',
                            onChanged: (nuevaVel) async {
                              await _narracionService.cambiarVelocidad(
                                nuevaVel,
                              );
                              _controladorRevelado?.actualizarVelocidad(
                                nuevaVel,
                              );
                              setDialogState(() {});
                              setState(() {});
                            },
                          ),
                        ),
                        const Text('🐇', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Voz del narrador (Windows):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (voces.isEmpty)
                      const Text(
                        'Se utilizará la voz en español predeterminada de Windows.',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      )
                    else
                      DropdownButtonFormField<VozInfo>(
                        initialValue: voces.contains(vozActual)
                            ? vozActual
                            : voces.first,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        items: voces.map((v) {
                          return DropdownMenuItem<VozInfo>(
                            value: v,
                            child: Text(
                              v.etiqueta,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevaVoz) async {
                          if (nuevaVoz != null) {
                            await _narracionService.cambiarVoz(nuevaVoz);
                            setDialogState(() {});
                            setState(() {});
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _seleccionarOpcion(String opcion) async {
    if (_generandoSiguienteEscena ||
        !_esUltimaEscenaGenerada ||
        _estaProcesando ||
        _escenaActual.esFinal) {
      return;
    }

    _generandoSiguienteEscena = true;

    await _detenerNarracion();

    final escenaOrigen = _escenaActual;

    setState(() {
      _opcionSeleccionada = opcion;

      _mensajeError = null;

      _status = StoryStatus.generatingScene;
    });

    try {
      await widget.controller.generarSiguienteEscena(
        cuento: widget.cuento,
        escenaActual: escenaOrigen,
        decision: opcion,
      );

      if (!mounted) {
        return;
      }

      /*
       * El Controller ya agregó y guardó
       * la nueva escena.
       *
       * La View solo cambia qué escena muestra.
       */
      setState(() {
        _indiceEscenaActual = widget.cuento.escenas.length - 1;

        _opcionSeleccionada = null;

        _mensajeError = null;

        _prepararEscenaActual();
      });
    } catch (error, stackTrace) {
      debugPrint('Error al generar siguiente escena: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _status = StoryStatus.error;

        _mensajeError =
            'No pudimos crear la siguiente parte '
            'de tu aventura. '
            'Puedes intentarlo otra vez.';
      });
    } finally {
      _generandoSiguienteEscena = false;
    }
  }

  void _reintentar() {
    final opcion = _opcionSeleccionada;

    if (opcion == null) {
      setState(() {
        _mensajeError = null;

        _actualizarEstadoEscena();
      });

      return;
    }

    _seleccionarOpcion(opcion);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cuento.escenas.isEmpty) {
      return _buildSinEscenas();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 5, 30, 18),
                child: _buildContenido(),
              ),
            ),

            _buildParteInferior(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Salir del cuento',
            onPressed: _status == StoryStatus.generatingScene
                ? null
                : () {
                    _detenerNarracion();
                    widget.onSalir();
                  },
            icon: const Icon(Icons.home_rounded),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Página anterior',
            onPressed: _puedeRetroceder && !_estaProcesando
                ? _retroceder
                : null,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              children: [
                Text(
                  widget.cuento.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),

                const SizedBox(height: 3),

                Builder(
                  builder: (context) {
                    final maxEscenas =
                        widget.controller.narrativaConfig.maxEscenas;
                    final totalMostrado =
                        (widget.cuento.escenas.isNotEmpty &&
                            widget.cuento.escenas.last.esFinal)
                        ? widget.cuento.escenas.length
                        : maxEscenas;
                    return Text(
                      'Escena '
                      '${_indiceEscenaActual + 1} '
                      'de '
                      '$totalMostrado',
                      style: const TextStyle(color: Color(0xFF795548)),
                    );
                  },
                ),
              ],
            ),
          ),

          FilledButton.tonalIcon(
            onPressed: _status == StoryStatus.generatingScene
                ? null
                : _narrarEscena,
            icon: Icon(
              _status == StoryStatus.narrating
                  ? Icons.stop_circle_rounded
                  : Icons.volume_up_rounded,
            ),
            label: Text(
              _status == StoryStatus.narrating ? 'Detener' : 'Escuchar',
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Narrar de nuevo',
            onPressed: _status == StoryStatus.generatingScene
                ? null
                : _reiniciarNarracion,
            icon: const Icon(Icons.replay_rounded),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Ajustes de voz y velocidad',
            onPressed: _abrirAjustesVoz,
            icon: const Icon(Icons.settings_voice_rounded),
          ),

          const SizedBox(width: 12),

          IconButton(
            tooltip: 'Página siguiente',
            onPressed: _puedeAvanzar && !_estaProcesando ? _avanzar : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x22000000))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(flex: 5, child: _buildImagen()),

          Container(width: 1, color: const Color(0xFFE0E0E0)),

          Expanded(flex: 5, child: _buildTexto()),
        ],
      ),
    );
  }

  Future<void> _solicitarGeneracionImagen({
    bool forzarReintento = false,
  }) async {
    final escena = _escenaActual;
    final numero = escena.numero;

    if (!forzarReintento &&
        escena.imageUrl != null &&
        escena.imageUrl!.trim().isNotEmpty) {
      return;
    }

    if (widget.controller.imageService == null) {
      return;
    }

    if (widget.controller.estaGenerandoImagen(widget.cuento.id, numero)) {
      return;
    }

    if (mounted) {
      setState(() {
        _estadosImagen[numero] = EstadoImagenEscena.generando;
      });
    }

    try {
      final url = await widget.controller.asegurarIlustracionEscena(
        cuento: widget.cuento,
        numeroEscena: numero,
        forzarReintento: forzarReintento,
      );

      if (!mounted) return;

      setState(() {
        if (url != null && url.isNotEmpty) {
          _estadosImagen[numero] = EstadoImagenEscena.cargada;
          _erroresAuthImagen.remove(numero);
        } else {
          _estadosImagen[numero] = EstadoImagenEscena.error;
        }
      });
    } on ImageAuthException catch (authErr) {
      if (!mounted) return;
      setState(() {
        _estadosImagen[numero] = EstadoImagenEscena.error;
        _erroresAuthImagen[numero] = authErr;
      });

      if (authErr.statusCode == 401) {
        _manejarSesionExpirada(authErr.message);
      } else if (authErr.statusCode == 403) {
        _mostrarErrorAccesoDenegado(authErr.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estadosImagen[numero] = EstadoImagenEscena.error;
      });
    }
  }

  void _manejarSesionExpirada(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu sesión ha expirado o no es válida. Por favor, inicia sesión nuevamente.',
        ),
        backgroundColor: Color(0xFFC62828),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    widget.onSalir();
  }

  void _mostrarErrorAccesoDenegado(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFFC62828),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildImagen() {
    return RepaintBoundary(child: _buildImagenContenido());
  }

  Widget _buildImagenContenido() {
    final escena = _escenaActual;
    final tieneUrl =
        escena.imageUrl != null && escena.imageUrl!.trim().isNotEmpty;
    final estado = _estadosImagen[escena.numero] == EstadoImagenEscena.generando
        ? EstadoImagenEscena.generando
        : (tieneUrl
              ? EstadoImagenEscena.cargada
              : (_estadosImagen[escena.numero] ??
                    EstadoImagenEscena.sinImagen));

    switch (estado) {
      case EstadoImagenEscena.generando:
        return Container(
          color: const Color(0xFFFFF8E1),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFF39C12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Generando ilustración...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dibujando la escena de ${widget.cuento.personajePrincipal}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        );

      case EstadoImagenEscena.error:
        final authError = _erroresAuthImagen[escena.numero];
        final esErrorAuth = authError != null;

        return Container(
          color: const Color(0xFFFFF3E0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  esErrorAuth
                      ? Icons.lock_clock_rounded
                      : Icons.broken_image_rounded,
                  size: 60,
                  color: const Color(0xFFD32F2F),
                ),
                const SizedBox(height: 14),
                Text(
                  esErrorAuth
                      ? (authError.statusCode == 401
                            ? 'Sesión no válida o expirada.'
                            : 'Acceso denegado.')
                      : 'No pudimos crear la ilustración.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 14),
                if (!esErrorAuth)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _solicitarGeneracionImagen(forzarReintento: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                  )
                else if (authError.statusCode == 401)
                  FilledButton.tonalIcon(
                    onPressed: () => _manejarSesionExpirada(authError.message),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Iniciar sesión'),
                  ),
              ],
            ),
          ),
        );

      case EstadoImagenEscena.cargada:
        if (tieneUrl) {
          return IlustracionEscenaWidget(
            key: ValueKey('ilustracion_${widget.cuento.id}_${escena.numero}'),
            imageUrl: escena.imageUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 60,
                      color: Color(0xFF795548),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La ilustración se creó, pero no pudo mostrarse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _solicitarGeneracionImagen(forzarReintento: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            },
          );
        }
        return _buildPlaceholderSinImagen();

      case EstadoImagenEscena.sinImagen:
        return _buildPlaceholderSinImagen();
    }
  }

  Widget _buildPlaceholderSinImagen() {
    return Container(
      color: const Color(0xFFFFF3E0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 80,
              color: Color(0xFFF39C12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aquí aparecerá la\n'
              'ilustración de la escena',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Color(0xFF795548)),
            ),
            if (!widget.modoHistorico &&
                widget.controller.imageService != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => _solicitarGeneracionImagen(),
                icon: const Icon(Icons.brush_rounded, size: 18),
                label: const Text('Crear ilustración'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTexto() {
    return ValueListenableBuilder<String>(
      valueListenable: _textoReveladoNotifier,
      builder: (context, textoVisible, _) {
        final textoAMostrar = textoVisible.isNotEmpty
            ? textoVisible
            : _escenaActual.contenido;

        return Padding(
          padding: const EdgeInsets.all(38),
          child: SingleChildScrollView(
            child: SelectableText(
              textoAMostrar,
              style: const TextStyle(
                fontSize: 23,
                height: 1.7,
                color: Color(0xFF3E2723),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParteInferior() {
    if (_status == StoryStatus.generatingScene) {
      return _buildGenerando();
    }

    if (_status == StoryStatus.error) {
      return _buildError();
    }

    if (widget.modoHistorico) {
      if (_escenaActual.esFinal) {
        return _buildFinal();
      }

      final decision = widget.cuento.decisiones
          .where((d) => d.numeroEscena == _escenaActual.numero)
          .firstOrNull;

      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFE65100)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  decision != null
                      ? 'Decisión tomada: "${decision.opcionSeleccionada}"'
                      : 'Estás leyendo tu aventura guardada.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D4C41),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_escenaActual.esFinal) {
      return _buildFinal();
    }

    /*
     * Si es una escena anterior,
     * solamente permitimos leerla.
     *
     * No se puede crear otra rama.
     */
    if (!_esUltimaEscenaGenerada) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded),
              SizedBox(width: 10),
              Text(
                'Estás viendo una parte '
                'anterior de tu aventura.',
              ),
            ],
          ),
        ),
      );
    }

    return _buildOpciones();
  }

  Widget _buildOpciones() {
    final opciones = _escenaActual.opciones;

    if (opciones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              'Esta escena todavía '
              'no tiene rutas disponibles.',
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
      child: Column(
        children: [
          Text(
            _status == StoryStatus.narrating
                ? '🎧 Escuchando la narración...'
                : '✨ ¿Qué debería hacer ahora?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _status == StoryStatus.narrating
                  ? const Color(0xFFE65100)
                  : const Color(0xFF4E342E),
            ),
          ),

          if (_status == StoryStatus.narrating) ...[
            const SizedBox(height: 5),
            const Text(
              'Las decisiones se habilitarán al terminar o al pulsar Detener.',
              style: TextStyle(fontSize: 14, color: Color(0xFF8D6E63)),
            ),
          ],

          const SizedBox(height: 13),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: opciones.map((opcion) {
              return FilledButton.tonal(
                onPressed: (_estaProcesando || _generandoSiguienteEscena)
                    ? null
                    : () {
                        _seleccionarOpcion(opcion);
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 18,
                  ),
                ),
                child: Text(opcion, style: const TextStyle(fontSize: 16)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerando() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),

            const SizedBox(width: 16),

            Flexible(
              child: Text(
                _opcionSeleccionada == null
                    ? 'Creando la siguiente '
                          'parte de tu aventura...'
                    : '✨ '
                          '"${_opcionSeleccionada!}" '
                          'está cambiando '
                          'la historia...',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 32),

            const SizedBox(width: 16),

            Expanded(child: Text(_mensajeError ?? 'Ocurrió un problema.')),

            const SizedBox(width: 16),

            FilledButton(
              onPressed: _reintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinal() {
    String etiquetaBoton = 'Ir a las preguntas';
    IconData iconoBoton = Icons.quiz_rounded;

    if (widget.intentoQuiz != null) {
      if (widget.intentoQuiz!.estado == 'en_progreso') {
        etiquetaBoton = 'Continuar preguntas';
        iconoBoton = Icons.pending_actions_rounded;
      } else if (widget.intentoQuiz!.estado == 'completado') {
        etiquetaBoton = 'Ver mi resultado';
        iconoBoton = Icons.analytics_outlined;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🎉 ¡Has llegado al final de esta aventura!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.onIrEvaluacion != null) ...[
              const SizedBox(width: 25),
              FilledButton.icon(
                onPressed: () {
                  _detenerNarracion();
                  widget.onIrEvaluacion?.call();
                },
                icon: Icon(iconoBoton),
                label: Text(etiquetaBoton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSinEscenas() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'El cuento todavía '
              'no tiene escenas.',
            ),

            const SizedBox(height: 15),

            FilledButton(
              onPressed: widget.onSalir,
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
