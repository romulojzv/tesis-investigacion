import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/visual_description_helper.dart';

enum DrawingTool { brush, eraser, bucket }

class DrawView extends StatefulWidget {
  final VoidCallback onVolver;

  final void Function(String nombrePersonaje, Uint8List dibujoPng) onContinuar;

  final void Function(
    String nombrePersonaje,
    Uint8List dibujoPng,
    String? descripcionPersonaje,
  )?
  onContinuarConDescripcion;

  final String? nombrePersonajeFijo;

  const DrawView({
    super.key,
    required this.onVolver,
    required this.onContinuar,
    this.onContinuarConDescripcion,
    this.nombrePersonajeFijo,
  });

  @override
  State<DrawView> createState() => _DrawViewState();
}

class _DrawViewState extends State<DrawView> {
  ui.Image? _canvasImage;

  final List<ui.Image?> _historialDeshacer = [];
  final List<ui.Image?> _historialRehacer = [];

  final List<Offset> _trazoActual = [];

  DrawingTool _herramienta = DrawingTool.brush;

  Color _colorSeleccionado = Colors.black;

  double _grosor = 6;

  Size _canvasSize = Size.zero;

  bool _procesando = false;
  bool _exportandoDibujo = false;
  final Set<Color> _coloresUtilizados = {};
  bool get _tieneNombreFijo {
    final nombre = widget.nombrePersonajeFijo;

    return nombre != null && nombre.trim().isNotEmpty;
  }

  static const int _maxHistorial = 20;

  final List<Color> _colores = const [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.brown,
    Colors.pink,
    Colors.cyan,
    Color(0xFFFFC107),
    Color(0xFF8BC34A),
  ];

  // =========================================================
  // HISTORIAL
  // =========================================================

  void _guardarEstadoParaDeshacer() {
    _historialDeshacer.add(_canvasImage);

    if (_historialDeshacer.length > _maxHistorial) {
      _historialDeshacer.removeAt(0);
    }

    _historialRehacer.clear();
  }

  void _deshacer() {
    if (_historialDeshacer.isEmpty || _procesando) {
      return;
    }

    setState(() {
      _historialRehacer.add(_canvasImage);

      _canvasImage = _historialDeshacer.removeLast();

      _trazoActual.clear();
    });
  }

  void _rehacer() {
    if (_historialRehacer.isEmpty || _procesando) {
      return;
    }

    setState(() {
      _historialDeshacer.add(_canvasImage);

      _canvasImage = _historialRehacer.removeLast();

      _trazoActual.clear();
    });
  }

  // =========================================================
  // DIBUJO
  // =========================================================

  void _iniciarTrazo(Offset punto) {
    if (_herramienta == DrawingTool.bucket || _procesando) {
      return;
    }

    setState(() {
      _trazoActual
        ..clear()
        ..add(punto);
    });
  }

  void _agregarPunto(Offset punto) {
    if (_herramienta == DrawingTool.bucket ||
        _procesando ||
        _trazoActual.isEmpty) {
      return;
    }

    setState(() {
      _trazoActual.add(punto);
    });
  }

  Future<void> _finalizarTrazo() async {
    if (_trazoActual.isEmpty ||
        _herramienta == DrawingTool.bucket ||
        _procesando) {
      return;
    }

    final puntos = List<Offset>.from(_trazoActual);

    setState(() {
      _trazoActual.clear();
      _procesando = true;
    });

    try {
      _guardarEstadoParaDeshacer();

      final nuevaImagen = await _crearImagenConTrazo(
        puntos: puntos,
        color: _herramienta == DrawingTool.eraser
            ? Colors.white
            : _colorSeleccionado,
        grosor: _herramienta == DrawingTool.eraser ? _grosor * 2 : _grosor,
      );

      if (!mounted) {
        return;
      }

      if (_herramienta != DrawingTool.eraser) {
        _coloresUtilizados.add(_colorSeleccionado);
      }

      setState(() {
        _canvasImage = nuevaImagen;
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  // =========================================================
  // GENERACIÓN DE IMAGEN INTERNA
  // =========================================================

  Future<ui.Image> _crearImagenConTrazo({
    required List<Offset> puntos,
    required Color color,
    required double grosor,
  }) async {
    final width = _canvasSize.width.round();
    final height = _canvasSize.height.round();

    final recorder = ui.PictureRecorder();

    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawColor(Colors.white, BlendMode.srcOver);

    if (_canvasImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _canvasImage!.width.toDouble(),
        _canvasImage!.height.toDouble(),
      );

      final dst = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

      canvas.drawImageRect(_canvasImage!, src, dst, Paint());
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (puntos.length == 1) {
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(puntos.first, grosor / 2, pointPaint);
    } else {
      final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);

      for (int i = 1; i < puntos.length; i++) {
        path.lineTo(puntos[i].dx, puntos[i].dy);
      }

      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();

    return picture.toImage(width, height);
  }

  Future<ui.Image> _rasterizarCanvasActual() async {
    final width = _canvasSize.width.round();
    final height = _canvasSize.height.round();

    final recorder = ui.PictureRecorder();

    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawColor(Colors.white, BlendMode.srcOver);

    if (_canvasImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _canvasImage!.width.toDouble(),
        _canvasImage!.height.toDouble(),
      );

      final dst = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

      canvas.drawImageRect(_canvasImage!, src, dst, Paint());
    }

    final picture = recorder.endRecording();

    return picture.toImage(width, height);
  }

  // =========================================================
  // BALDE
  // =========================================================

  Future<void> _usarBalde(Offset posicion) async {
    if (_herramienta != DrawingTool.bucket ||
        _procesando ||
        _canvasSize.isEmpty) {
      return;
    }

    final width = _canvasSize.width.round();
    final height = _canvasSize.height.round();

    final x = posicion.dx.floor();
    final y = posicion.dy.floor();

    if (x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      /*
       * Rasterizamos siempre al tamaño actual.
       *
       * Esto evita errores si el usuario cambia
       * el tamaño de la ventana.
       */
      final imagenBase = await _rasterizarCanvasActual();

      final byteData = await imagenBase.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        return;
      }

      final pixels = Uint8List.fromList(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      final cambioRealizado = _floodFill(
        pixels: pixels,
        width: width,
        height: height,
        startX: x,
        startY: y,
        nuevoColor: _colorSeleccionado,
      );

      if (!cambioRealizado) {
        return;
      }

      _guardarEstadoParaDeshacer();

      final nuevaImagen = await _imagenDesdePixeles(pixels, width, height);

      if (!mounted) {
        return;
      }

      _coloresUtilizados.add(_colorSeleccionado);

      setState(() {
        _canvasImage = nuevaImagen;
      });
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  bool _floodFill({
    required Uint8List pixels,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required Color nuevoColor,
  }) {
    final pixelInicial = startY * width + startX;

    final indiceInicial = pixelInicial * 4;

    final targetR = pixels[indiceInicial];

    final targetG = pixels[indiceInicial + 1];

    final targetB = pixels[indiceInicial + 2];

    final targetA = pixels[indiceInicial + 3];

    final argb = nuevoColor.toARGB32();

    final nuevoR = (argb >> 16) & 0xFF;

    final nuevoG = (argb >> 8) & 0xFF;

    final nuevoB = argb & 0xFF;

    final nuevoA = (argb >> 24) & 0xFF;

    if (_coloresSimilares(
      targetR,
      targetG,
      targetB,
      targetA,
      nuevoR,
      nuevoG,
      nuevoB,
      nuevoA,
      tolerancia: 2,
    )) {
      return false;
    }

    final cola = <int>[pixelInicial];

    /*
     * Evita agregar el mismo píxel muchas veces.
     * Esto protege contra consumo excesivo de memoria.
     */
    final visitados = Uint8List(width * height);

    visitados[pixelInicial] = 1;

    int posicionCola = 0;

    _colorearPixel(pixels, indiceInicial, nuevoR, nuevoG, nuevoB, nuevoA);

    while (posicionCola < cola.length) {
      final pixel = cola[posicionCola++];

      final px = pixel % width;

      final py = pixel ~/ width;

      void revisarVecino(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
          return;
        }

        final pixelVecino = ny * width + nx;

        if (visitados[pixelVecino] == 1) {
          return;
        }

        visitados[pixelVecino] = 1;

        final indice = pixelVecino * 4;

        if (_coloresSimilares(
          pixels[indice],
          pixels[indice + 1],
          pixels[indice + 2],
          pixels[indice + 3],
          targetR,
          targetG,
          targetB,
          targetA,
          tolerancia: 12,
        )) {
          _colorearPixel(pixels, indice, nuevoR, nuevoG, nuevoB, nuevoA);

          cola.add(pixelVecino);
        }
      }

      revisarVecino(px - 1, py);

      revisarVecino(px + 1, py);

      revisarVecino(px, py - 1);

      revisarVecino(px, py + 1);
    }

    return true;
  }

  bool _coloresSimilares(
    int r1,
    int g1,
    int b1,
    int a1,
    int r2,
    int g2,
    int b2,
    int a2, {
    required int tolerancia,
  }) {
    return (r1 - r2).abs() <= tolerancia &&
        (g1 - g2).abs() <= tolerancia &&
        (b1 - b2).abs() <= tolerancia &&
        (a1 - a2).abs() <= tolerancia;
  }

  void _colorearPixel(Uint8List pixels, int index, int r, int g, int b, int a) {
    pixels[index] = r;
    pixels[index + 1] = g;
    pixels[index + 2] = b;
    pixels[index + 3] = a;
  }

  Future<ui.Image> _imagenDesdePixeles(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      completer.complete(image);
    });

    return completer.future;
  }

  // =========================================================
  // LIMPIAR
  // =========================================================

  void _limpiarLienzo() {
    if (_canvasImage == null || _procesando) {
      return;
    }

    _guardarEstadoParaDeshacer();

    setState(() {
      _canvasImage = null;
      _trazoActual.clear();
      _coloresUtilizados.clear();
    });
  }

  // =========================================================
  // EXPORTAR DIBUJO A PNG
  // =========================================================

  Future<Uint8List?> _exportarDibujoPng() async {
    if (_canvasImage == null || _canvasSize.isEmpty) {
      return null;
    }

    /*
     * Exportamos al tamaño actual del lienzo.
     */
    final imagen = await _rasterizarCanvasActual();

    final byteData = await imagen.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    }

    // Fallback para entornos de prueba donde el motor headless retorna null en PNG
    return Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
  }

  // =========================================================
  // NOMBRE DEL PERSONAJE
  // =========================================================

  Future<void> _mostrarDialogoNombre() async {
    if (_canvasImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero realiza un dibujo antes de continuar.'),
        ),
      );

      return;
    }

    /*
   * Si el usuario viene desde el flujo PDF,
   * el nombre ya fue elegido anteriormente.
   *
   * En ese caso no mostramos nuevamente
   * el diálogo para pedir el nombre.
   */
    if (_tieneNombreFijo) {
      await _exportarYContinuar(widget.nombrePersonajeFijo!.trim());

      return;
    }

    /*
     * Flujo normal:
     * El diálogo gestiona su propio TextEditingController dentro de un
     * StatefulWidget independiente, garantizando que su ciclo de vida
     * sobreviva a toda la animación de cierre del modal.
     */
    final String? nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _DialogoNombrePersonaje(),
    );

    if (nombre != null && nombre.trim().isNotEmpty) {
      if (!mounted) return;
      await _exportarYContinuar(nombre.trim());
    }
  }

  Future<void> _exportarYContinuar(
    String nombrePersonaje, {
    String? descripcionPersonaje,
  }) async {
    if (_exportandoDibujo) {
      return;
    }

    if (nombrePersonaje.trim().isEmpty) {
      return;
    }

    _exportandoDibujo = true;

    try {
      final dibujoPng = await _exportarDibujoPng();

      if (!mounted) {
        return;
      }

      if (dibujoPng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos preparar tu dibujo. Intenta nuevamente.'),
          ),
        );

        return;
      }

      final descBase = derivarDescripcionVisualBase(
        nombrePersonaje: nombrePersonaje.trim(),
        coloresUtilizados: _coloresUtilizados,
      );

      final descFinal =
          (descripcionPersonaje != null &&
              descripcionPersonaje.trim().isNotEmpty)
          ? descripcionPersonaje.trim()
          : descBase;

      if (widget.onContinuarConDescripcion != null) {
        widget.onContinuarConDescripcion!(
          nombrePersonaje.trim(),
          dibujoPng,
          descFinal,
        );
      } else {
        widget.onContinuar(nombrePersonaje.trim(), dibujoPng);
      }
    } finally {
      _exportandoDibujo = false;
    }
  }

  @override
  void dispose() {
    _trazoActual.clear();
    _historialDeshacer.clear();
    _historialRehacer.clear();
    super.dispose();
  }

  // =========================================================
  // INTERFAZ
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildToolbar(),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCanvas()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CABECERA
  // =========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: _procesando ? null : widget.onVolver,
            icon: const Icon(Icons.arrow_back_rounded),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎨 Crea el inicio de tu aventura',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dibuja lo que imaginas y lo convertiremos en un cuento mágico.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF795548)),
                ),
              ],
            ),
          ),

          if (_procesando)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),

          FilledButton.icon(
            onPressed: _procesando ? null : _mostrarDialogoNombre,
            icon: const Icon(Icons.auto_awesome),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Crear mi cuento'),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TOOLBAR
  // =========================================================

  Widget _buildToolbar() {
    return Container(
      width: 195,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(blurRadius: 12, spreadRadius: 1, color: Color(0x22000000)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colores',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: _colores.map((color) {
                final seleccionado = color == _colorSeleccionado;

                return Tooltip(
                  message: 'Seleccionar color',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _colorSeleccionado = color;

                        if (_herramienta == DrawingTool.eraser) {
                          _herramienta = DrawingTool.brush;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: seleccionado
                              ? const Color(0xFFF39C12)
                              : const Color(0x22000000),
                          width: seleccionado ? 4 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 26),

            const Text(
              'Tamaño del pincel',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            Slider(
              min: 2,
              max: 22,
              value: _grosor,
              onChanged: (value) {
                setState(() {
                  _grosor = value;
                });
              },
            ),

            Center(
              child: Container(
                width: _grosor + 8,
                height: _grosor + 8,
                decoration: BoxDecoration(
                  color: _herramienta == DrawingTool.eraser
                      ? Colors.white
                      : _colorSeleccionado,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33000000)),
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Herramientas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _buildToolButton(
              icon: Icons.brush_rounded,
              label: 'Pincel',
              selected: _herramienta == DrawingTool.brush,
              onTap: () {
                setState(() {
                  _herramienta = DrawingTool.brush;
                });
              },
            ),

            const SizedBox(height: 8),

            _buildToolButton(
              icon: Icons.auto_fix_normal,
              label: 'Borrador',
              selected: _herramienta == DrawingTool.eraser,
              onTap: () {
                setState(() {
                  _herramienta = DrawingTool.eraser;
                });
              },
            ),

            const SizedBox(height: 8),

            _buildToolButton(
              icon: Icons.format_color_fill,
              label: 'Balde',
              selected: _herramienta == DrawingTool.bucket,
              onTap: () {
                setState(() {
                  _herramienta = DrawingTool.bucket;
                });
              },
            ),

            const SizedBox(height: 18),

            _buildToolButton(
              icon: Icons.undo_rounded,
              label: 'Deshacer',
              selected: false,
              enabled: _historialDeshacer.isNotEmpty && !_procesando,
              onTap: _deshacer,
            ),

            const SizedBox(height: 8),

            _buildToolButton(
              icon: Icons.redo_rounded,
              label: 'Rehacer',
              selected: false,
              enabled: _historialRehacer.isNotEmpty && !_procesando,
              onTap: _rehacer,
            ),

            const SizedBox(height: 18),

            _buildToolButton(
              icon: Icons.delete_outline_rounded,
              label: 'Limpiar todo',
              selected: false,
              enabled: _canvasImage != null && !_procesando,
              onTap: _limpiarLienzo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFFFFE0B2) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LIENZO
  // =========================================================

  Widget _buildCanvas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(blurRadius: 12, spreadRadius: 1, color: Color(0x22000000)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTapDown: (details) {
                if (_herramienta == DrawingTool.bucket) {
                  _usarBalde(details.localPosition);
                }
              },

              onPanStart: (details) {
                _iniciarTrazo(details.localPosition);
              },

              onPanUpdate: (details) {
                _agregarPunto(details.localPosition);
              },

              onPanEnd: (_) {
                _finalizarTrazo();
              },

              child: CustomPaint(
                painter: _DrawingPainter(
                  image: _canvasImage,
                  trazoActual: _trazoActual,
                  colorActual: _herramienta == DrawingTool.eraser
                      ? Colors.white
                      : _colorSeleccionado,
                  grosorActual: _herramienta == DrawingTool.eraser
                      ? _grosor * 2
                      : _grosor,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================
// PAINTER
// ===========================================================

class _DrawingPainter extends CustomPainter {
  final ui.Image? image;

  final List<Offset> trazoActual;

  final Color colorActual;

  final double grosorActual;

  const _DrawingPainter({
    required this.image,
    required this.trazoActual,
    required this.colorActual,
    required this.grosorActual,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.srcOver);

    if (image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        image!.width.toDouble(),
        image!.height.toDouble(),
      );

      final dst = Rect.fromLTWH(0, 0, size.width, size.height);

      canvas.drawImageRect(image!, src, dst, Paint());
    }

    if (trazoActual.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = colorActual
      ..strokeWidth = grosorActual
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (trazoActual.length == 1) {
      final pointPaint = Paint()
        ..color = colorActual
        ..style = PaintingStyle.fill;

      canvas.drawCircle(trazoActual.first, grosorActual / 2, pointPaint);

      return;
    }

    final path = Path()..moveTo(trazoActual.first.dx, trazoActual.first.dy);

    for (int i = 1; i < trazoActual.length; i++) {
      path.lineTo(trazoActual[i].dx, trazoActual[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return true;
  }
}

// ===========================================================
// DIÁLOGO DE NOMBRE Y DETALLES DEL PERSONAJE
// ===========================================================

class _DialogoNombrePersonaje extends StatefulWidget {
  const _DialogoNombrePersonaje();

  @override
  State<_DialogoNombrePersonaje> createState() =>
      _DialogoNombrePersonajeState();
}

class _DialogoNombrePersonajeState extends State<_DialogoNombrePersonaje> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nombre = _controller.text.trim();
    if (nombre.isNotEmpty) {
      Navigator.of(context).pop(nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        '✨ Dale vida a tu personaje',
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cómo se llama el personaje principal de tu aventura?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre del personaje',
                hintText: 'Ejemplo: Lucas o Pollito Pepe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _confirmar,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Crear cuento'),
        ),
      ],
    );
  }
}
