import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentView extends StatefulWidget {
  final VoidCallback onVolver;

  final void Function(String nombreArchivo, Uint8List pdfBytes) onContinuar;

  const DocumentView({
    super.key,
    required this.onVolver,
    required this.onContinuar,
  });

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  String? _nombreArchivo;
  Uint8List? _pdfBytes;

  bool _seleccionando = false;
  bool _procesando = false;

  Future<void> _seleccionarPdf() async {
    if (_seleccionando || _procesando) {
      return;
    }

    setState(() {
      _seleccionando = true;
    });

    try {
      final archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (!mounted) {
        return;
      }

      if (archivo == null) {
        return;
      }

      final extension = archivo.extension?.toLowerCase();

      if (extension != 'pdf') {
        _mostrarError('Selecciona un archivo PDF válido.');
        return;
      }

      final bytes = await archivo.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _mostrarError('El PDF seleccionado está vacío.');
        return;
      }

      if (!_tieneFirmaPdf(bytes)) {
        _mostrarError('El archivo seleccionado no parece ser un PDF válido.');
        return;
      }

      setState(() {
        _nombreArchivo = archivo.name;

        _pdfBytes = Uint8List.fromList(bytes);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('Error al seleccionar PDF: $error');

      _mostrarError('No pudimos abrir el archivo seleccionado.');
    } finally {
      if (mounted) {
        setState(() {
          _seleccionando = false;
        });
      }
    }
  }

  bool _tieneFirmaPdf(Uint8List bytes) {
    if (bytes.length < 5) {
      return false;
    }

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  void _quitarPdf() {
    if (_procesando) {
      return;
    }

    setState(() {
      _nombreArchivo = null;
      _pdfBytes = null;
    });
  }

  void _continuar() {
    if (_procesando) {
      return;
    }

    final archivo = _nombreArchivo;

    final bytes = _pdfBytes;

    if (archivo == null || bytes == null) {
      _mostrarError('Primero selecciona un PDF.');

      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      widget.onContinuar(archivo, Uint8List.fromList(bytes));
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String _formatearTamano(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;

    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(child: Center(child: _buildContenido())),
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
            onPressed: _procesando ? null : widget.onVolver,
            icon: const Icon(Icons.arrow_back_rounded),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📖 Convierte una lectura en una aventura',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E342E),
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Selecciona un PDF y descubre su historia.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF795548)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return Container(
      width: 700,
      margin: const EdgeInsets.all(30),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(blurRadius: 16, spreadRadius: 1, color: Color(0x22000000)),
        ],
      ),
      child: _pdfBytes == null ? _buildSeleccion() : _buildPdfSeleccionado(),
    );
  }

  Widget _buildSeleccion() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            size: 64,
            color: Color(0xFFF39C12),
          ),
        ),

        const SizedBox(height: 30),

        const Text(
          'Selecciona tu lectura',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4E342E),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'La aplicación analizará el contenido '
          'del PDF antes de crear la aventura.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF795548)),
        ),

        const SizedBox(height: 30),

        FilledButton.icon(
          onPressed: _seleccionando ? null : _seleccionarPdf,
          icon: _seleccionando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: Text(_seleccionando ? 'Abriendo...' : 'Seleccionar PDF'),
        ),
      ],
    );
  }

  Widget _buildPdfSeleccionado() {
    final bytes = _pdfBytes!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 55,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          '¡Lectura lista!',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4E342E),
          ),
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                size: 40,
                color: Color(0xFFF39C12),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombreArchivo!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(_formatearTamano(bytes.lengthInBytes)),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Quitar archivo',
                onPressed: _procesando ? null : _quitarPdf,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _procesando ? null : _seleccionarPdf,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Cambiar PDF'),
            ),

            const SizedBox(width: 16),

            FilledButton.icon(
              onPressed: _procesando ? null : _continuar,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_procesando ? 'Analizando...' : 'Analizar historia'),
            ),
          ],
        ),
      ],
    );
  }
}
