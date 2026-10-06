import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/character_customization.dart';
import '../models/pdf_story_data.dart';

class CharacterCustomizationView extends StatefulWidget {
  final PdfStoryData pdfData;

  final VoidCallback onVolver;

  final void Function(CharacterCustomization customization) onContinuar;

  const CharacterCustomizationView({
    super.key,
    required this.pdfData,
    required this.onVolver,
    required this.onContinuar,
  });

  @override
  State<CharacterCustomizationView> createState() =>
      _CharacterCustomizationViewState();
}

class _CharacterCustomizationViewState
    extends State<CharacterCustomizationView> {
  late CharacterMode _modo;

  late CharacterVisualMode _modoVisual;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  String? _error;

  late EstadoImagenesPdf _estadoImagenes;
  Uint8List? _imagenSeleccionada;
  int? _indiceImagenSeleccionada;
  final ScrollController _galleryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _galleryScrollController.addListener(_onGalleryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    _modo = widget.pdfData.tienePersonajeDetectado
        ? CharacterMode.keepOriginal
        : CharacterMode.newCharacter;

    _estadoImagenes = widget.pdfData.estadoImagenes;
    _imagenSeleccionada = widget.pdfData.imagenSeleccionadaPersonaje;

    if ((_estadoImagenes == EstadoImagenesPdf.confirmadasPersonaje ||
            _estadoImagenes == EstadoImagenesPdf.potencialmenteUtiles ||
            _estadoImagenes == EstadoImagenesPdf.noVerificadas) &&
        widget.pdfData.imagenesExtraidas.isNotEmpty) {
      _modoVisual = CharacterVisualMode.pdfImages;
    } else {
      _modoVisual = CharacterVisualMode.automatic;
    }
  }

  String get _personajeDetectado {
    final personaje = widget.pdfData.personajePrincipalDetectado;

    if (personaje == null || personaje.trim().isEmpty) {
      return 'Pendiente de análisis con IA';
    }

    return personaje.trim();
  }

  @override
  void dispose() {
    _galleryScrollController.removeListener(_onGalleryScroll);
    _galleryScrollController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _onGalleryScroll() {
    if (mounted) setState(() {});
  }

  bool get _puedeDesplazarIzquierda {
    if (!_galleryScrollController.hasClients) return false;
    return _galleryScrollController.offset > 1.0;
  }

  bool get _puedeDesplazarDerecha {
    if (!_galleryScrollController.hasClients) return false;
    final position = _galleryScrollController.position;
    return position.maxScrollExtent > 1.0 &&
        position.pixels < (position.maxScrollExtent - 1.0);
  }

  void _desplazarGaleriaIzquierda() {
    if (!_galleryScrollController.hasClients) return;
    final position = _galleryScrollController.position;
    final nuevoOffset = (position.pixels - 306.0).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _galleryScrollController.animateTo(
      nuevoOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _desplazarGaleriaDerecha() {
    if (!_galleryScrollController.hasClients) return;
    final position = _galleryScrollController.position;
    final nuevoOffset = (position.pixels + 306.0).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _galleryScrollController.animateTo(
      nuevoOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _continuar() {
    String nombre;
    String? descripcion;

    switch (_modo) {
      case CharacterMode.keepOriginal:
        final detectado = widget.pdfData.personajePrincipalDetectado;

        if (detectado == null || detectado.trim().isEmpty) {
          setState(() {
            _error = 'No se ha detectado un protagonista.';
          });

          return;
        }

        nombre = CharacterCustomization.sanitizarNombre(detectado);
        descripcion = null;
        break;

      case CharacterMode.renameOriginal:
        nombre = CharacterCustomization.sanitizarNombre(_nombreController.text);

        if (nombre.isEmpty) {
          setState(() {
            _error = 'Escribe el nuevo nombre del protagonista.';
          });

          return;
        }

        descripcion = null;
        break;

      case CharacterMode.newCharacter:
        nombre = CharacterCustomization.sanitizarNombre(_nombreController.text);

        if (nombre.isEmpty) {
          setState(() {
            _error = 'Escribe el nombre del nuevo protagonista.';
          });

          return;
        }

        final desc = _descripcionController.text.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        descripcion = desc.isNotEmpty ? desc : null;
        break;
    }

    if (_modoVisual == CharacterVisualMode.pdfImages) {
      if (_imagenSeleccionada == null) {
        setState(() {
          _error = 'Debes seleccionar o confirmar cuál imagen del PDF representa al protagonista.';
        });

        return;
      }
    }

    setState(() {
      _error = null;
    });

    debugPrint(
      '[DIAGNÓSTICO A] Al pulsar Continuar: '
      'nombrePersonaje="$nombre", '
      'descripcionPersonaje="${descripcion ?? '(null)'}", '
      'mode=$_modo, '
      'visualMode=$_modoVisual',
    );

    widget.onContinuar(
      CharacterCustomization(
        mode: _modo,
        visualMode: _modoVisual,
        nombrePersonaje: nombre,
        personajeOriginal: widget.pdfData.personajePrincipalDetectado,
        descripcionPersonaje: descripcion,
        imagenReferencia: _modoVisual == CharacterVisualMode.pdfImages
            ? _imagenSeleccionada
            : null,
        estadoDisenoAutomatico: _modoVisual == CharacterVisualMode.automatic
            ? 'pendiente'
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 10, 40, 35),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        _buildInfoHistoria(),

                        const SizedBox(height: 22),

                        _buildPersonaje(),

                        const SizedBox(height: 22),

                        _buildVisual(),

                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          _buildError(),
                        ],

                        const SizedBox(height: 28),

                        FilledButton.icon(
                          onPressed: _continuar,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 14,
                            ),
                            child: Text('Continuar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: widget.onVolver,
            icon: const Icon(Icons.arrow_back_rounded),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ Personaliza tu protagonista',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Puedes conservar el protagonista '
                  'del cuento o crear uno propio.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF795548)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHistoria() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 38,
              color: Color(0xFFF39C12),
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historia seleccionada',
                  style: TextStyle(fontSize: 14, color: Color(0xFF795548)),
                ),

                const SizedBox(height: 5),

                Text(
                  widget.pdfData.tituloDetectado ??
                      widget.pdfData.nombreArchivo,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Protagonista detectado: '
                  '$_personajeDetectado',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaje() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Quién vivirá esta aventura?',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E342E),
            ),
          ),

          const SizedBox(height: 16),

          RadioGroup<CharacterMode>(
            groupValue: _modo,
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _modo = value;
                _error = null;

                if (_modo == CharacterMode.keepOriginal) {
                  _nombreController.clear();
                  _descripcionController.clear();
                } else if (_modo == CharacterMode.renameOriginal) {
                  // Limpiar descripción de personaje nuevo para no contaminar
                  _descripcionController.clear();
                }
              });
            },
            child: Column(
              children: [
                RadioListTile<CharacterMode>(
                  value: CharacterMode.keepOriginal,
                  enabled: widget.pdfData.tienePersonajeDetectado,
                  title: const Text('Mantener al protagonista original'),
                  subtitle: Text(
                    widget.pdfData.tienePersonajeDetectado
                        ? 'Continuaremos con $_personajeDetectado.'
                        : 'La detección automática se habilitará '
                              'con el análisis de IA.',
                  ),
                ),

                RadioListTile<CharacterMode>(
                  value: CharacterMode.renameOriginal,
                  enabled: widget.pdfData.tienePersonajeDetectado,
                  title: const Text('Cambiar únicamente su nombre'),
                  subtitle: const Text(
                    'Será el mismo personaje del cuento, pero podrás elegir otro nombre.',
                  ),
                ),

                RadioListTile<CharacterMode>(
                  value: CharacterMode.newCharacter,
                  title: const Text('Crear mi propio protagonista'),
                  subtitle: const Text(
                    'Crearás un personaje diferente con su propio nombre y apariencia para vivir la aventura.',
                  ),
                ),
              ],
            ),
          ),

          if (_modo == CharacterMode.renameOriginal) ...[
            const SizedBox(height: 12),

            TextField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nuevo nombre del protagonista',
                hintText: 'Ejemplo: Pedro',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else if (_modo == CharacterMode.newCharacter) ...[
            const SizedBox(height: 12),

            TextField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del nuevo protagonista',
                hintText: 'Ejemplo: Luna',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _descripcionController,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción breve del personaje',
                hintText: 'Ejemplo: Lleva una capa azul, tiene ojos vivaces y es muy curiosa.',
                helperText: '1 a 2 frases breves sobre su apariencia o características.',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.description_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisual() {
    final imagenesDisponibles = widget.pdfData.imagenesExtraidas;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo quieres que se vea?',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E342E),
            ),
          ),
          const SizedBox(height: 10),
          RadioGroup<CharacterVisualMode>(
            groupValue: _modoVisual,
            onChanged: (value) {
              if (value == null) {
                return;
              }

              if (value == CharacterVisualMode.pdfImages &&
                  (_estadoImagenes == EstadoImagenesPdf.sinImagenes ||
                      _estadoImagenes == EstadoImagenesPdf.descartadas)) {
                return;
              }

              setState(() {
                _modoVisual = value;
                if (value != CharacterVisualMode.pdfImages) {
                  _imagenSeleccionada = null;
                  _indiceImagenSeleccionada = null;
                }
                _error = null;
              });
            },
            child: Column(
              children: [
                RadioListTile<CharacterVisualMode>(
                  value: CharacterVisualMode.pdfImages,
                  enabled:
                      _estadoImagenes != EstadoImagenesPdf.sinImagenes &&
                      _estadoImagenes != EstadoImagenesPdf.descartadas,
                  title: const Text('Tomar referencias visuales del PDF'),
                  subtitle: Text(_obtenerSubtituloOpcionPdf()),
                ),
                RadioListTile<CharacterVisualMode>(
                  value: CharacterVisualMode.automatic,
                  title: const Text('Crear un diseño automáticamente'),
                  subtitle: const Text(
                    'La IA describirá y adaptará al protagonista según el cuento '
                    '(diseño visual automático pendiente de generación externa).',
                  ),
                ),
                RadioListTile<CharacterVisualMode>(
                  value: CharacterVisualMode.drawing,
                  title: const Text('Dibujar mi propio personaje'),
                  subtitle: const Text(
                    'Tu dibujo en el lienzo servirá como referencia para el personaje.',
                  ),
                ),
              ],
            ),
          ),
          if ((_modoVisual == CharacterVisualMode.pdfImages ||
                  _estadoImagenes == EstadoImagenesPdf.descartadas) &&
              imagenesDisponibles.isNotEmpty) ...[
            const Divider(height: 32),
            _buildSeccionImagenesPdf(imagenesDisponibles),
          ],
        ],
      ),
    );
  }

  String _obtenerSubtituloOpcionPdf() {
    switch (_estadoImagenes) {
      case EstadoImagenesPdf.sinImagenes:
        return 'El PDF no contiene imágenes utilizables del protagonista.';
      case EstadoImagenesPdf.descartadas:
        return 'Las imágenes fueron descartadas como decorativas o de fondo.';
      case EstadoImagenesPdf.confirmadasPersonaje:
        return 'Se usará la ilustración original seleccionada del protagonista.';
      case EstadoImagenesPdf.potencialmenteUtiles:
      case EstadoImagenesPdf.noVerificadas:
        return 'Requiere validar o seleccionar la imagen del protagonista abajo.';
    }
  }

  Widget _buildSeccionImagenesPdf(List<Uint8List> imagenes) {
    if (_estadoImagenes == EstadoImagenesPdf.descartadas) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hide_image_outlined, color: Colors.grey),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Las imágenes del PDF fueron descartadas como decorativas.',
                style: TextStyle(fontSize: 14, color: Color(0xFF616161)),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _estadoImagenes =
                      widget.pdfData.imagenesExtraidas.any(
                        (img) => img.length >= 8192,
                      )
                      ? EstadoImagenesPdf.potencialmenteUtiles
                      : EstadoImagenesPdf.noVerificadas;
                });
              },
              child: const Text('Revisar imágenes'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_rounded,
              color: Color(0xFFE65100),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Ilustraciones detectadas en el PDF (${imagenes.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF4E342E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Toca la imagen que corresponda a tu protagonista para seleccionarla como referencia:',
          style: TextStyle(fontSize: 13, color: Color(0xFF795548)),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              key: const ValueKey('btn_galeria_retroceder'),
              tooltip: 'Ver imágenes anteriores',
              onPressed: _puedeDesplazarIzquierda
                  ? _desplazarGaleriaIzquierda
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 114,
                child: ScrollConfiguration(
                  behavior: const _GaleriaScrollBehavior(),
                  child: Scrollbar(
                    controller: _galleryScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: ListView.separated(
                      controller: _galleryScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 14),
                      itemCount: imagenes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final imgBytes = imagenes[index];
                        final esSeleccionada =
                            _imagenSeleccionada == imgBytes ||
                            _indiceImagenSeleccionada == index;

                        return InkWell(
                          key: ValueKey('imagen_extraida_$index'),
                          onTap: () {
                            setState(() {
                              _indiceImagenSeleccionada = index;
                              _imagenSeleccionada = imgBytes;
                              _estadoImagenes =
                                  EstadoImagenesPdf.confirmadasPersonaje;
                              _modoVisual = CharacterVisualMode.pdfImages;
                              _error = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: esSeleccionada
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFFE0E0E0),
                                width: esSeleccionada ? 3 : 1,
                              ),
                              boxShadow: esSeleccionada
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFE65100)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  imgBytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                if (esSeleccionada)
                                  Container(
                                    color: const Color(0xFFE65100)
                                        .withValues(alpha: 0.2),
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(4),
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Color(0xFFE65100),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const ValueKey('btn_galeria_avanzar'),
              tooltip: 'Ver más imágenes',
              onPressed: _puedeDesplazarDerecha
                  ? _desplazarGaleriaDerecha
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          spacing: 12,
          children: [
            if (_estadoImagenes == EstadoImagenesPdf.confirmadasPersonaje)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Ilustración seleccionada',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _estadoImagenes = EstadoImagenesPdf.descartadas;
                  _imagenSeleccionada = null;
                  _indiceImagenSeleccionada = null;
                  if (_modoVisual == CharacterVisualMode.pdfImages) {
                    _modoVisual = CharacterVisualMode.automatic;
                  }
                });
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text(
                'Ninguna es el protagonista (son decorativas)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),

          const SizedBox(width: 12),

          Expanded(child: Text(_error!)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x18000000),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _GaleriaScrollBehavior extends MaterialScrollBehavior {
  const _GaleriaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
