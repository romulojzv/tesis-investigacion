import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/cuento.dart';
import '../widgets/ilustracion_escena_widget.dart';

/// Servicio para exportar el cuento finalizado a un archivo PDF (RF-30).
/// Diseñado para formato legible y amigable para educación primaria.
/// No realiza cargas a servicios remotos (RF-31 local).
class PdfExportService {
  /// Genera los bytes del archivo PDF a partir de un cuento finalizado.
  /// Lanza [StateError] si el cuento no tiene escenas o la última no es final.
  Future<Uint8List> generarPdf(Cuento cuento) async {
    if (cuento.escenas.isEmpty || !cuento.escenas.last.esFinal) {
      throw StateError('Solo se puede exportar un cuento finalizado.');
    }

    final pdf = PdfDocument();
    pdf.pageSettings.size = PdfPageSize.a4;
    pdf.pageSettings.margins.all = 36.0;

    try {
      final fontTitulo = PdfStandardFont(
        PdfFontFamily.helvetica,
        22,
        style: PdfFontStyle.bold,
      );
      final fontSubtitulo = PdfStandardFont(
        PdfFontFamily.helvetica,
        14,
        style: PdfFontStyle.bold,
      );
      final fontSeccion = PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      );
      final fontCuerpo = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final fontDetalle = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.italic,
      );

      final colorPrincipal = PdfSolidBrush(PdfColor(46, 125, 50)); // Verde bosque
      final colorTextoOscuro = PdfSolidBrush(PdfColor(46, 32, 28)); // Marrón café
      final colorSecundario = PdfSolidBrush(PdfColor(230, 81, 0)); // Naranja cálido
      final colorGris = PdfSolidBrush(PdfColor(117, 117, 117));

      // 1. Portada / Encabezado principal
      final portada = pdf.pages.add();
      final double anchoPagina = portada.getClientSize().width;
      final double altoPagina = portada.getClientSize().height;

      // Marco decorativo en portada
      final penBorde = PdfPen(PdfColor(200, 230, 201), width: 2);
      portada.graphics.drawRectangle(
        pen: penBorde,
        bounds: Rect.fromLTWH(0, 0, anchoPagina, altoPagina),
      );

      double y = 40.0;

      // Encabezado institucional / tesis
      portada.graphics.drawString(
        'Cuentos Mágicos • Aventura Interactiva',
        fontDetalle,
        brush: colorGris,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 35;

      // Título del cuento
      final tituloLimpio = _sanitizarParaPdf(cuento.titulo);
      portada.graphics.drawString(
        tituloLimpio,
        fontTitulo,
        brush: colorPrincipal,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 60),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      y += 65;

      // Protagonista y detalles
      final protagonista = _sanitizarParaPdf(cuento.personajePrincipal);
      portada.graphics.drawString(
        'Protagonista: $protagonista',
        fontSubtitulo,
        brush: colorTextoOscuro,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 25),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 30;

      // Ilustración de portada (referencia visual del personaje o escena 1 si existe)
      Uint8List? imagenPortada = cuento.referenciaVisualPng ??
          cuento.referenciaGeneradaEscena1Bytes ??
          cuento.obtenerImagenBytesEscena(1);

      if (imagenPortada != null && imagenPortada.isNotEmpty) {
        try {
          final bitmap = PdfBitmap(imagenPortada);
          final double maxW = anchoPagina - 80;
          final double maxH = 220;
          final double scaleW = maxW / bitmap.width;
          final double scaleH = maxH / bitmap.height;
          final double scale = (scaleW < scaleH ? scaleW : scaleH).clamp(0.05, 1.0);
          final double drawW = bitmap.width * scale;
          final double drawH = bitmap.height * scale;
          final double drawX = (anchoPagina - drawW) / 2;

          portada.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(drawX, y, drawW, drawH),
          );
          y += drawH + 20;
        } catch (_) {
          // Si el formato de imagen no es decodificable, se continúa sin error
        }
      }

      // Mensaje de felicitación
      portada.graphics.drawString(
        '¡Felicitaciones por completar tu aventura interactiva!',
        fontCuerpo,
        brush: colorSecundario,
        bounds: Rect.fromLTWH(20, altoPagina - 50, anchoPagina - 40, 25),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // 2. Escenas narrativas en orden estricto
      final escenasOrdenadas = [...cuento.escenas]
        ..sort((a, b) => a.numero.compareTo(b.numero));

      for (final escena in escenasOrdenadas) {
        final pagina = pdf.pages.add();
        final double ancho = pagina.getClientSize().width;
        final double alto = pagina.getClientSize().height;
        double yPos = 10.0;

        // Título de la escena
        final esUltima = escena.esFinal;
        final tituloEscena = esUltima
            ? 'Escena ${escena.numero} • Desenlace'
            : 'Escena ${escena.numero}';

        pagina.graphics.drawString(
          tituloEscena,
          fontSubtitulo,
          brush: colorPrincipal,
          bounds: Rect.fromLTWH(0, yPos, ancho, 25),
        );
        yPos += 30;

        // Ilustración de la escena (si está disponible)
        Uint8List? imagenBytes = cuento.obtenerImagenBytesEscena(escena.numero);
        if (imagenBytes == null &&
            escena.imageUrl != null &&
            IlustracionEscenaWidget.esDataUri(escena.imageUrl!)) {
          imagenBytes =
              IlustracionEscenaWidget.decodificarDataUri(escena.imageUrl!);
        }

        if (imagenBytes != null && imagenBytes.isNotEmpty) {
          try {
            final bitmap = PdfBitmap(imagenBytes);
            final double maxW = ancho - 20;
            final double maxH = 200;
            final double scaleW = maxW / bitmap.width;
            final double scaleH = maxH / bitmap.height;
            final double scale = (scaleW < scaleH ? scaleW : scaleH).clamp(0.05, 1.0);
            final double drawW = bitmap.width * scale;
            final double drawH = bitmap.height * scale;
            final double drawX = (ancho - drawW) / 2;

            pagina.graphics.drawImage(
              bitmap,
              Rect.fromLTWH(drawX, yPos, drawW, drawH),
            );
            yPos += drawH + 16;
          } catch (_) {
            // Imagen no soportada o corrupta: mostramos indicador amigable
            yPos = _dibujarPlaceholderImagen(pagina, fontDetalle, colorGris, ancho, yPos);
          }
        } else {
          // Sin imagen para esta escena: indicador limpio que gestiona su ausencia
          yPos = _dibujarPlaceholderImagen(pagina, fontDetalle, colorGris, ancho, yPos);
        }

        // Decisión tomada por el estudiante (si aplica a esta escena)
        final decision = cuento.obtenerDecision(escena.numero);
        if (decision != null &&
            decision.opcionSeleccionada.trim().isNotEmpty) {
          final textoDecision = _sanitizarParaPdf(
            'Decisión elegida: "${decision.opcionSeleccionada}"',
          );

          // Fondo suave para resaltar la decisión
          pagina.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 243, 224)),
            bounds: Rect.fromLTWH(0, yPos, ancho, 24),
          );

          pagina.graphics.drawString(
            textoDecision,
            fontSeccion,
            brush: colorSecundario,
            bounds: Rect.fromLTWH(8, yPos + 4, ancho - 16, 20),
          );
          yPos += 30;
        }

        // Texto narrativo de la escena
        final contenidoLimpio = _sanitizarParaPdf(escena.contenido);
        final elementoTexto = PdfTextElement(
          text: contenidoLimpio,
          font: fontCuerpo,
          brush: colorTextoOscuro,
          format: PdfStringFormat(lineSpacing: 2),
        );

        elementoTexto.draw(
          page: pagina,
          bounds: Rect.fromLTWH(0, yPos, ancho, alto - yPos - 10),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        );
      }

      final List<int> bytes = await pdf.save();
      return Uint8List.fromList(bytes);
    } finally {
      pdf.dispose();
    }
  }

  /// Dibuja un recuadro discreto cuando una escena no dispone de ilustración.
  static double _dibujarPlaceholderImagen(
    PdfPage pagina,
    PdfFont font,
    PdfBrush brush,
    double ancho,
    double yPos,
  ) {
    pagina.graphics.drawRectangle(
      pen: PdfPen(PdfColor(224, 224, 224), width: 1),
      brush: PdfSolidBrush(PdfColor(250, 250, 250)),
      bounds: Rect.fromLTWH(0, yPos, ancho, 26),
    );
    pagina.graphics.drawString(
      '[Escena narrativa sin ilustración adicional]',
      font,
      brush: brush,
      bounds: Rect.fromLTWH(0, yPos + 6, ancho, 20),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    return yPos + 36;
  }

  /// Sanitiza texto para fuentes estándar de PDF (Helvetica), conservando acentos
  /// en español (á, é, í, ó, ú, ñ, ¿, ¡) y reemplazando emojis o símbolos no ASCII-extended.
  static String _sanitizarParaPdf(String texto) {
    if (texto.isEmpty) return '';

    // Reemplazar saltos de línea múltiples o caracteres de control
    var limpio = texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remover secuencias de emojis que no están en el mapa de fuentes estándar Helvetica
    limpio = limpio.replaceAll(
      RegExp(r'[\u{1F300}-\u{1FAFF}|\u{2600}-\u{27BF}]', unicode: true),
      '',
    );

    return limpio.trim();
  }
}
