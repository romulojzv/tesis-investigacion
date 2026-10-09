// lib/views/quiz_view.dart

import 'package:flutter/material.dart';

import '../models/quiz_question.dart';
import '../models/quiz_result.dart';
import '../services/supabase_quiz_service.dart';

class QuizView extends StatefulWidget {
  final String cuentoId;
  final String tituloCuento;
  final QuizService quizService;
  final VoidCallback onVolver;
  final VoidCallback? onFinalizado;
  final QuizResult? resultadoInicial;

  const QuizView({
    super.key,
    required this.cuentoId,
    required this.tituloCuento,
    required this.quizService,
    required this.onVolver,
    this.onFinalizado,
    this.resultadoInicial,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  String? _intentoId;
  List<QuizQuestion> _preguntas = [];
  int _indiceActual = 0;

  // Mapa de selecciones del estudiante: {numeroPregunta: indiceOpcionSeleccionada}
  final Map<int, int> _selecciones = {};

  // Resultado recibido del servidor
  QuizResult? _resultado;

  @override
  void initState() {
    super.initState();
    if (widget.resultadoInicial != null) {
      _resultado = widget.resultadoInicial;
      _intentoId = widget.resultadoInicial!.intentoId;
      _cargando = false;
    } else {
      _iniciarQuiz();
    }
  }

  Future<void> _iniciarQuiz() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final respuesta = await widget.quizService.generarQuiz(widget.cuentoId);

      if (mounted) {
        setState(() {
          _intentoId = respuesta.intentoId;
          if (respuesta.estaCompletado &&
              respuesta.resultadoExistente != null) {
            _resultado = respuesta.resultadoExistente;
          } else {
            _preguntas = respuesta.preguntas;
          }
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is StateError) {
            _error = e.message;
          } else {
            _error = e
                .toString()
                .replaceFirst('Exception: ', '')
                .replaceFirst('Bad state: ', '');
          }
          _cargando = false;
        });
      }
    }
  }

  void _seleccionarOpcion(int indiceOpcion) {
    if (_preguntas.isEmpty || _enviando) return;
    final preguntaActual = _preguntas[_indiceActual];
    setState(() {
      _selecciones[preguntaActual.numero] = indiceOpcion;
    });
  }

  void _irAnterior() {
    if (_indiceActual > 0) {
      setState(() {
        _indiceActual--;
      });
    }
  }

  void _irSiguiente() {
    if (_preguntas.isEmpty) return;
    final preguntaActual = _preguntas[_indiceActual];
    if (!_selecciones.containsKey(preguntaActual.numero)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una respuesta para continuar.'),
          backgroundColor: Color(0xFFE65100),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_indiceActual < _preguntas.length - 1) {
      setState(() {
        _indiceActual++;
      });
    }
  }

  Future<void> _finalizarQuiz() async {
    final preguntaActual = _preguntas[_indiceActual];
    if (!_selecciones.containsKey(preguntaActual.numero)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecciona una respuesta antes de finalizar.',
          ),
          backgroundColor: Color(0xFFE65100),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selecciones.length < _preguntas.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún tienes preguntas sin responder.'),
          backgroundColor: Color(0xFFE65100),
        ),
      );
      return;
    }

    setState(() {
      _enviando = true;
    });

    try {
      final respuestasParaEnviar = _preguntas.map((p) {
        return QuizAnswerSubmission(
          numero: p.numero,
          indiceSeleccionado: _selecciones[p.numero]!,
        );
      }).toList();

      final resultado = await widget.quizService.enviarQuiz(
        intentoId: _intentoId!,
        respuestas: respuestasParaEnviar,
      );

      if (mounted) {
        setState(() {
          _resultado = resultado;
          _enviando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al calificar el quiz: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.tituloCuento,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4E342E),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E342E)),
          onPressed: widget.onVolver,
        ),
      ),
      body: SafeArea(child: _buildContenidoPrincipal()),
    );
  }

  Widget _buildContenidoPrincipal() {
    if (_cargando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFF39C12)),
            const SizedBox(height: 20),
            Text(
              'Preparando las preguntas de tu aventura...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.brown.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.quiz_outlined,
                size: 56,
                color: Color(0xFFE65100),
              ),
              const SizedBox(height: 16),
              Text(
                'No pudimos preparar las preguntas en este momento.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF795548)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _iniciarQuiz,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF39C12),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultado != null) {
      return _buildVistaResultado();
    }

    if (_preguntas.isEmpty) {
      return const Center(
        child: Text('No hay preguntas disponibles para este cuento.'),
      );
    }

    return _buildVistaPreguntas();
  }

  Widget _buildVistaPreguntas() {
    final total = _preguntas.length;
    final actual = _indiceActual + 1;
    final pregunta = _preguntas[_indiceActual];
    final seleccionActual = _selecciones[pregunta.numero];

    return Column(
      children: [
        // Barra superior de progreso
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comprueba lo que recuerdas 🧠',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pregunta $actual de $total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: actual / total,
                backgroundColor: const Color(0xFFFFE0B2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFF39C12),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Contenido de la pregunta
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de la pregunta
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFFFE0B2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    pregunta.pregunta,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Lista de alternativas (A, B, C, D)
                ...List.generate(pregunta.opciones.length, (index) {
                  final letra = String.fromCharCode(65 + index); // A, B, C, D
                  final textoOpcion = pregunta.opciones[index];
                  final estaSeleccionada = seleccionActual == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: _enviando ? null : () => _seleccionarOpcion(index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: estaSeleccionada
                              ? const Color(0xFFFFF3E0)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: estaSeleccionada
                                ? const Color(0xFFF39C12)
                                : const Color(0xFFE0E0E0),
                            width: estaSeleccionada ? 2 : 1,
                          ),
                          boxShadow: [
                            if (estaSeleccionada)
                              BoxShadow(
                                color: const Color(0xFFF39C12)
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: estaSeleccionada
                                    ? const Color(0xFFF39C12)
                                    : const Color(0xFFF5F5F5),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                letra,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: estaSeleccionada
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                textoOpcion,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: estaSeleccionada
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: const Color(0xFF3E2723),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Barra inferior de navegación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_indiceActual > 0)
                OutlinedButton.icon(
                  onPressed: _enviando ? null : _irAnterior,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6D4C41),
                    side: const BorderSide(color: Color(0xFFD7CCC8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                )
              else
                const SizedBox(width: 90),

              if (_indiceActual < total - 1)
                ElevatedButton.icon(
                  onPressed: _enviando ? null : _irSiguiente,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Siguiente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _enviando ? null : _finalizarQuiz,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    _enviando ? 'Corrigiendo...' : 'Finalizar preguntas',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVistaResultado() {
    final res = _resultado!;
    final puntaje = res.puntaje;
    final total = res.total;
    final porcentaje = res.porcentaje;

    String mensajeAliento;
    IconData iconoAliento;
    Color colorAliento;

    if (puntaje == 5) {
      mensajeAliento =
          '¡Extraordinario! ¡Comprendiste toda la historia a la perfección! 🌟';
      iconoAliento = Icons.emoji_events;
      colorAliento = const Color(0xFFF39C12);
    } else if (puntaje >= 3) {
      mensajeAliento =
          '¡Muy bien hecho! Tienes una gran memoria y atención lectora. 👏';
      iconoAliento = Icons.thumb_up_alt_rounded;
      colorAliento = const Color(0xFF2E7D32);
    } else {
      mensajeAliento =
          '¡Buen intento! Sigue leyendo y descubriendo nuevas aventuras. 📚';
      iconoAliento = Icons.auto_stories;
      colorAliento = const Color(0xFF1976D2);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta de Puntaje Global
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorAliento.withValues(alpha: 0.12), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorAliento.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(iconoAliento, size: 52, color: colorAliento),
                const SizedBox(height: 12),
                const Text(
                  'Resultado de Comprensión',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puntaje: $puntaje de $total',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: colorAliento,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$porcentaje % de aciertos',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mensajeAliento,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6D4C41),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Título de Revisión
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Color(0xFF4E342E)),
              SizedBox(width: 8),
              Text(
                'Revisión de respuestas:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Lista de Preguntas con Corrección y Explicación
          ...res.respuestas.map((r) {
            final esCorrecta = r.esCorrecta;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: esCorrecta
                      ? const Color(0xFF81C784)
                      : const Color(0xFFE57373),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado de estado de la pregunta con Icono y Texto
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: esCorrecta
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              esCorrecta ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: esCorrecta
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              esCorrecta ? '✓ Correcta' : '✗ Incorrecta',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: esCorrecta
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Pregunta ${r.numero}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Texto de la pregunta
                  Text(
                    r.pregunta,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Respuesta del estudiante
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu respuesta: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.opcionSeleccionadaTexto,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: esCorrecta
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Si falló, mostrar la respuesta correcta
                  if (!esCorrecta) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Respuesta correcta: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.opcionCorrectaTexto,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Explicación pedagógica
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            r.explicacion,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5D4037),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Botón final para volver
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onFinalizado?.call();
                widget.onVolver();
              },
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Volver a Mis aventuras'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF39C12),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
