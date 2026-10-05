import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/pdf_story_data.dart';

class DocumentService {
  bool validarPdf(Uint8List bytes) {
    if (bytes.length < 5) {
      return false;
    }

    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  Future<PdfStoryData> procesarPdf({
    required String nombreArchivo,
    required Uint8List pdfBytes,
  }) async {
    if (nombreArchivo.trim().isEmpty) {
      throw ArgumentError('El PDF debe tener un nombre válido.');
    }

    if (pdfBytes.isEmpty) {
      throw ArgumentError('El PDF no puede estar vacío.');
    }

    if (!validarPdf(pdfBytes)) {
      throw ArgumentError('El archivo no parece ser un PDF válido.');
    }

    PdfDocument? documento;

    try {
      documento = PdfDocument(inputBytes: pdfBytes);

      final textoExtraido = PdfTextExtractor(documento).extractText();

      final textoLimpio = _limpiarTextoExtraido(textoExtraido);

      if (textoLimpio.isEmpty) {
        throw StateError(
          'No se pudo extraer texto del PDF. '
          'Es posible que el documento contenga '
          'solo imágenes o texto escaneado.',
        );
      }

      final imagenes = extraerImagenes(pdfBytes);
      final estadoInicial = determinarEstadoInicialImagenes(imagenes);

      return PdfStoryData(
        nombreArchivo: nombreArchivo,
        textoExtraido: textoLimpio,
        tituloDetectado: _obtenerTituloTemporal(nombreArchivo),
        imagenesExtraidas: imagenes,
        estadoImagenes: estadoInicial,
      );
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }

      throw StateError('No se pudo procesar el PDF: $error');
    } finally {
      documento?.dispose();
    }
  }

  /// Extrae imágenes incrustadas (JPEG / PNG) del archivo PDF.
  List<Uint8List> extraerImagenes(Uint8List pdfBytes) {
    if (pdfBytes.length < 100) {
      return [];
    }

    final imagenes = <Uint8List>[];
    const maxImagenes = 10;
    const minBytesImagen = 1500;

    int i = 0;
    final len = pdfBytes.length;

    while (i < len - 4 && imagenes.length < maxImagenes) {
      // Detección de cabecera JPEG: 0xFF, 0xD8, 0xFF
      if (pdfBytes[i] == 0xFF &&
          pdfBytes[i + 1] == 0xD8 &&
          pdfBytes[i + 2] == 0xFF) {
        final marker = pdfBytes[i + 3];
        if (marker == 0xE0 ||
            marker == 0xE1 ||
            marker == 0xDB ||
            marker == 0xC0 ||
            marker == 0xEE) {
          final inicio = i;
          int fin = -1;

          int j = i + 4;
          while (j < len - 1) {
            if (pdfBytes[j] == 0xFF && pdfBytes[j + 1] == 0xD9) {
              fin = j + 2;
              break;
            }
            j++;
          }

          if (fin != -1) {
            final tamano = fin - inicio;
            if (tamano >= minBytesImagen) {
              final bytesImagen = Uint8List.sublistView(pdfBytes, inicio, fin);
              final esDuplicado = imagenes.any(
                (img) =>
                    img.length == bytesImagen.length &&
                    _coincidenPrimerosBytes(img, bytesImagen, 32),
              );

              if (!esDuplicado) {
                imagenes.add(Uint8List.fromList(bytesImagen));
              }
            }
            i = fin;
            continue;
          }
        }
      }

      // Detección de cabecera PNG: 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
      if (i < len - 8 &&
          pdfBytes[i] == 0x89 &&
          pdfBytes[i + 1] == 0x50 &&
          pdfBytes[i + 2] == 0x4E &&
          pdfBytes[i + 3] == 0x47 &&
          pdfBytes[i + 4] == 0x0D &&
          pdfBytes[i + 5] == 0x0A &&
          pdfBytes[i + 6] == 0x1A &&
          pdfBytes[i + 7] == 0x0A) {
        final inicio = i;
        int fin = -1;
        int j = i + 8;
        while (j < len - 7) {
          if (pdfBytes[j] == 0x49 &&
              pdfBytes[j + 1] == 0x45 &&
              pdfBytes[j + 2] == 0x4E &&
              pdfBytes[j + 3] == 0x44) {
            fin = j + 8;
            break;
          }
          j++;
        }

        if (fin != -1 && fin <= len) {
          final tamano = fin - inicio;
          if (tamano >= minBytesImagen) {
            final bytesImagen = Uint8List.sublistView(pdfBytes, inicio, fin);
            imagenes.add(Uint8List.fromList(bytesImagen));
          }
          i = fin;
          continue;
        }
      }

      i++;
    }

    return imagenes;
  }

  bool _coincidenPrimerosBytes(Uint8List a, Uint8List b, int n) {
    final limite = n < a.length
        ? (n < b.length ? n : b.length)
        : (a.length < b.length ? a.length : b.length);
    for (int k = 0; k < limite; k++) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  /// Clasifica las imágenes extraídas según su potencial utilidad para el protagonista.
  EstadoImagenesPdf determinarEstadoInicialImagenes(List<Uint8List> imagenes) {
    if (imagenes.isEmpty) {
      return EstadoImagenesPdf.sinImagenes;
    }

    final hayUtiles = imagenes.any((img) => img.length >= 8192);
    if (hayUtiles) {
      return EstadoImagenesPdf.potencialmenteUtiles;
    }

    return EstadoImagenesPdf.noVerificadas;
  }

  String _limpiarTextoExtraido(String texto) {
    var resultado = texto;

    // PostgreSQL no admite el carácter NUL
    // dentro de columnas TEXT.
    resultado = resultado.replaceAll('\u0000', '');

    // Normaliza saltos de línea.
    resultado = resultado.replaceAll('\r\n', '\n');

    resultado = resultado.replaceAll('\r', '\n');

    // Elimina caracteres de control
    // problemáticos, conservando \n y \t.
    resultado = resultado.replaceAll(
      RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      ' ',
    );

    // Reduce espacios y tabulaciones.
    resultado = resultado.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Elimina espacios al inicio y final
    // de cada línea.
    resultado = resultado.split('\n').map((linea) => linea.trim()).join('\n');

    // Evita demasiados saltos seguidos.
    resultado = resultado.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return resultado.trim();
  }

  String _obtenerTituloTemporal(String nombreArchivo) {
    var titulo = nombreArchivo.trim();

    if (titulo.toLowerCase().endsWith('.pdf')) {
      titulo = titulo.substring(0, titulo.length - 4);
    }

    titulo = titulo.replaceAll(RegExp(r'[_-]+'), ' ');

    titulo = titulo.replaceAll(RegExp(r'\s+'), ' ');

    return titulo.trim();
  }
}
