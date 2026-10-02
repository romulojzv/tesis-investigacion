import 'package:flutter/material.dart';

import '../controllers/story_controller.dart';
import '../models/cuento.dart';
import '../models/escena.dart';

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

  final Future<void> Function(
    Escena escena,
  ) onNarrar;

  final VoidCallback onSalir;

  final VoidCallback? onIrEvaluacion;

  const StoryView({
    super.key,
    required this.cuento,
    required this.controller,
    required this.onNarrar,
    required this.onSalir,
    this.onIrEvaluacion,
  });

  @override
  State<StoryView> createState() =>
      _StoryViewState();
}

class _StoryViewState
    extends State<StoryView> {
  int _indiceEscenaActual = 0;

  StoryStatus _status =
      StoryStatus.reading;

  String? _opcionSeleccionada;
  String? _mensajeError;

  Escena get _escenaActual {
    return widget
        .cuento
        .escenas[_indiceEscenaActual];
  }

  bool get _puedeRetroceder {
    return _indiceEscenaActual > 0;
  }

  bool get _puedeAvanzar {
    return _indiceEscenaActual <
        widget.cuento.escenas.length - 1;
  }

  bool get _esUltimaEscenaGenerada {
    return _indiceEscenaActual ==
        widget.cuento.escenas.length - 1;
  }

  bool get _estaProcesando {
    return _status ==
            StoryStatus.generatingScene ||
        _status ==
            StoryStatus.narrating;
  }

  @override
  void initState() {
    super.initState();

    if (widget.cuento.escenas.isNotEmpty) {
      _actualizarEstadoEscena();
    }
  }

  void _actualizarEstadoEscena() {
    final escena = _escenaActual;

    if (escena.esFinal) {
      _status =
          StoryStatus.finished;

      return;
    }

    if (_esUltimaEscenaGenerada) {
      _status =
          StoryStatus.waitingDecision;
    } else {
      _status =
          StoryStatus.reading;
    }
  }

  void _retroceder() {
    if (!_puedeRetroceder ||
        _estaProcesando) {
      return;
    }

    setState(() {
      _indiceEscenaActual--;

      _opcionSeleccionada = null;
      _mensajeError = null;

      _actualizarEstadoEscena();
    });
  }

  void _avanzar() {
    if (!_puedeAvanzar ||
        _estaProcesando) {
      return;
    }

    setState(() {
      _indiceEscenaActual++;

      _opcionSeleccionada = null;
      _mensajeError = null;

      _actualizarEstadoEscena();
    });
  }

  Future<void> _narrarEscena() async {
    if (_estaProcesando) {
      return;
    }

    final estadoAnterior =
        _status;

    setState(() {
      _status =
          StoryStatus.narrating;
    });

    try {
      await widget.onNarrar(
        _escenaActual,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            estadoAnterior;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            StoryStatus.error;

        _mensajeError =
            'No pudimos reproducir la narración.';
      });
    }
  }

  Future<void> _seleccionarOpcion(
    String opcion,
  ) async {
    if (!_esUltimaEscenaGenerada ||
        _estaProcesando ||
        _escenaActual.esFinal) {
      return;
    }

    final escenaOrigen =
        _escenaActual;

    setState(() {
      _opcionSeleccionada =
          opcion;

      _mensajeError = null;

      _status =
          StoryStatus.generatingScene;
    });

    try {
      await widget.controller
          .generarSiguienteEscena(
        cuento:
            widget.cuento,
        escenaActual:
            escenaOrigen,
        decision:
            opcion,
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
        _indiceEscenaActual =
            widget.cuento.escenas.length - 1;

        _opcionSeleccionada =
            null;

        _mensajeError =
            null;

        _actualizarEstadoEscena();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            StoryStatus.error;

        _mensajeError =
            'La magia se detuvo un momento. '
            'No pudimos crear la siguiente '
            'parte de tu aventura.';
      });
    }
  }

  void _reintentar() {
    final opcion =
        _opcionSeleccionada;

    if (opcion == null) {
      setState(() {
        _mensajeError = null;

        _actualizarEstadoEscena();
      });

      return;
    }

    _seleccionarOpcion(
      opcion,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (widget.cuento.escenas.isEmpty) {
      return _buildSinEscenas();
    }

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFFFF8F0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  30,
                  5,
                  30,
                  18,
                ),
                child:
                    _buildContenido(),
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
      padding:
          const EdgeInsets.fromLTRB(
        28,
        18,
        28,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip:
                'Salir del cuento',
            onPressed:
                _estaProcesando
                    ? null
                    : widget.onSalir,
            icon: const Icon(
              Icons.home_rounded,
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip:
                'Página anterior',
            onPressed:
                _puedeRetroceder &&
                        !_estaProcesando
                    ? _retroceder
                    : null,
            icon: const Icon(
              Icons
                  .arrow_back_ios_new_rounded,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              children: [
                Text(
                  widget.cuento.titulo,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 25,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(
                      0xFF4E342E,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'Escena '
                  '${_indiceEscenaActual + 1} '
                  'de '
                  '${widget.cuento.escenas.length}',
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF795548,
                    ),
                  ),
                ),
              ],
            ),
          ),

          FilledButton.tonalIcon(
            onPressed:
                _estaProcesando
                    ? null
                    : _narrarEscena,
            icon: Icon(
              _status ==
                      StoryStatus
                          .narrating
                  ? Icons
                      .volume_up_rounded
                  : Icons
                      .replay_rounded,
            ),
            label: Text(
              _status ==
                      StoryStatus
                          .narrating
                  ? 'Narrando...'
                  : 'Narrar de nuevo',
            ),
          ),

          const SizedBox(width: 12),

          IconButton(
            tooltip:
                'Página siguiente',
            onPressed:
                _puedeAvanzar &&
                        !_estaProcesando
                    ? _avanzar
                    : null,
            icon: const Icon(
              Icons
                  .arrow_forward_ios_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color:
                Color(
              0x22000000,
            ),
          ),
        ],
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child:
                _buildImagen(),
          ),

          Container(
            width: 1,
            color:
                const Color(
              0xFFE0E0E0,
            ),
          ),

          Expanded(
            flex: 5,
            child:
                _buildTexto(),
          ),
        ],
      ),
    );
  }

  Widget _buildImagen() {
    final imageUrl =
        _escenaActual.imageUrl;

    if (imageUrl == null ||
        imageUrl.trim().isEmpty) {
      return Container(
        color:
            const Color(
          0xFFFFF3E0,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                Icons
                    .auto_awesome_rounded,
                size: 80,
                color:
                    Color(
                  0xFFF39C12,
                ),
              ),
              SizedBox(
                height: 16,
              ),
              Text(
                'Aquí aparecerá la\n'
                'ilustración de la escena',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color:
                      Color(
                    0xFF795548,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder:
          (
            context,
            error,
            stackTrace,
          ) {
        return const Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                Icons
                    .broken_image_outlined,
                size: 60,
              ),
              SizedBox(
                height: 12,
              ),
              Text(
                'No pudimos cargar '
                'la ilustración.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTexto() {
    return Padding(
      padding:
          const EdgeInsets.all(
        38,
      ),
      child:
          SingleChildScrollView(
        child: SelectableText(
          _escenaActual.contenido,
          style:
              const TextStyle(
            fontSize: 23,
            height: 1.7,
            color:
                Color(
              0xFF3E2723,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParteInferior() {
    if (_status ==
        StoryStatus
            .generatingScene) {
      return _buildGenerando();
    }

    if (_status ==
        StoryStatus.error) {
      return _buildError();
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
        padding:
            const EdgeInsets
                .fromLTRB(
          30,
          0,
          30,
          22,
        ),
        child: Container(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFFFF3E0,
            ),
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),
          ),
          child: const Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              Icon(
                Icons
                    .history_rounded,
              ),
              SizedBox(
                width: 10,
              ),
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
    final opciones =
        _escenaActual.opciones;

    if (opciones.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets
                .fromLTRB(
          30,
          0,
          30,
          22,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFFFF3E0,
            ),
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),
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
      padding:
          const EdgeInsets.fromLTRB(
        30,
        0,
        30,
        22,
      ),
      child: Column(
        children: [
          const Text(
            '✨ ¿Qué debería hacer ahora?',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(
                0xFF4E342E,
              ),
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Wrap(
            alignment:
                WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children:
                opciones.map(
              (opcion) {
                return FilledButton
                    .tonal(
                  onPressed:
                      _estaProcesando
                          ? null
                          : () {
                              _seleccionarOpcion(
                                opcion,
                              );
                            },
                  style:
                      FilledButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          25,
                      vertical:
                          18,
                    ),
                  ),
                  child: Text(
                    opcion,
                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerando() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        30,
        0,
        30,
        22,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          20,
        ),
        decoration: BoxDecoration(
          color:
              const Color(
            0xFFFFF3E0,
          ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child:
                  CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            Flexible(
              child: Text(
                _opcionSeleccionada ==
                        null
                    ? 'Creando la siguiente '
                        'parte de tu aventura...'
                    : '✨ '
                        '"${_opcionSeleccionada!}" '
                        'está cambiando '
                        'la historia...',
                style:
                    const TextStyle(
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        30,
        0,
        30,
        22,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          20,
        ),
        decoration: BoxDecoration(
          color:
              const Color(
            0xFFFFEBEE,
          ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons
                  .auto_awesome_rounded,
              size: 32,
            ),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child: Text(
                _mensajeError ??
                    'Ocurrió un problema.',
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            FilledButton(
              onPressed:
                  _reintentar,
              child: const Text(
                'Reintentar',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinal() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        30,
        0,
        30,
        22,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          20,
        ),
        decoration: BoxDecoration(
          color:
              const Color(
            0xFFE8F5E9,
          ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              '🎉 ¡Has llegado al final '
              'de esta aventura!',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            if (widget
                    .onIrEvaluacion !=
                null) ...[
              const SizedBox(
                width: 25,
              ),

              FilledButton.icon(
                onPressed:
                    widget
                        .onIrEvaluacion,
                icon: const Icon(
                  Icons.quiz_rounded,
                ),
                label:
                    const Text(
                  'Ir a las preguntas',
                ),
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              'El cuento todavía '
              'no tiene escenas.',
            ),

            const SizedBox(
              height: 15,
            ),

            FilledButton(
              onPressed:
                  widget.onSalir,
              child:
                  const Text(
                'Volver',
              ),
            ),
          ],
        ),
      ),
    );
  }
}