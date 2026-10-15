import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/cuento.dart';
import '../models/quiz_attempt_summary.dart';
import '../models/quiz_result.dart';
import '../widgets/ilustracion_escena_widget.dart';

/// Servicio para exportar el cuento finalizado a un archivo PDF (RF-30 y RF-31).
///
/// Reglas de negocio obligatorias:
/// - El estudiante únicamente podrá exportar cuando haya finalizado el cuento y
///   completado las cinco preguntas de comprensión con registro 'completado'.
/// - Incluye portada, escenas con ilustraciones reales, decisiones tomadas,
///   y la sección completa de evaluación: 5 preguntas con niveles pedagógicos
///   (literal, inferencial, crítico-reflexivo), alternativas seleccionadas,
///   respuestas correctas, explicaciones formativas y puntaje/porcentaje final.
class PdfExportService {
  /// Genera los bytes del archivo PDF a partir de un cuento y su intento de quiz completado.
  /// Lanza [StateError] si el cuento no tiene escenas, no es final o el quiz no está completado.
  Future<Uint8List> generarPdf(
    Cuento cuento, {
    required QuizAttemptSummary? intentoQuiz,
  }) async {
    if (cuento.escenas.isEmpty || !cuento.escenas.last.esFinal) {
      throw StateError('Solo se puede exportar un cuento finalizado.');
    }

    if (intentoQuiz == null || !intentoQuiz.estaCompletado) {
      throw StateError(
        'Solo se puede exportar el PDF cuando el cuestionario esté completado.',
      );
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
      final fontCuerpoNegrita = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.bold,
      );
      final fontDetalle = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.italic,
      );
      final fontPequena = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final fontPequenaNegrita = PdfStandardFont(
        PdfFontFamily.helvetica,
        9,
        style: PdfFontStyle.bold,
      );

      final colorPrincipal = PdfSolidBrush(PdfColor(46, 125, 50)); // Verde bosque
      final colorTextoOscuro = PdfSolidBrush(PdfColor(46, 32, 28)); // Marrón café
      final colorSecundario = PdfSolidBrush(PdfColor(230, 81, 0)); // Naranja cálido
      final colorGris = PdfSolidBrush(PdfColor(117, 117, 117));
      final colorAcierto = PdfSolidBrush(PdfColor(46, 125, 50)); // Verde acierto
      final colorError = PdfSolidBrush(PdfColor(198, 40, 40)); // Rojo error

      // =======================================================================
      // 1. PORTADA CON DATOS GENERALES Y RESUMEN
      // =======================================================================
      final portada = pdf.pages.add();
      final double anchoPagina = portada.getClientSize().width;
      final double altoPagina = portada.getClientSize().height;

      // Marco decorativo en portada
      final penBorde = PdfPen(PdfColor(200, 230, 201), width: 2);
      portada.graphics.drawRectangle(
        pen: penBorde,
        bounds: Rect.fromLTWH(0, 0, anchoPagina, altoPagina),
      );

      double y = 30.0;

      // Encabezado institucional
      portada.graphics.drawString(
        'Cuentos Mágicos • Aventura Interactiva y Comprensión Lectora',
        fontDetalle,
        brush: colorGris,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 26;

      // Título del cuento
      final tituloLimpio = _sanitizarParaPdf(cuento.titulo);
      portada.graphics.drawString(
        tituloLimpio,
        fontTitulo,
        brush: colorPrincipal,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 50),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      y += 54;

      // Protagonista y datos del estudiante
      final protagonista = _sanitizarParaPdf(cuento.personajePrincipal);
      portada.graphics.drawString(
        'Protagonista: $protagonista',
        fontSubtitulo,
        brush: colorTextoOscuro,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 22),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 24;

      final estudiante = _sanitizarParaPdf(intentoQuiz.estudianteNombre);
      final codigo = _sanitizarParaPdf(intentoQuiz.codigoAcceso);
      final datosEstudiante = codigo.isNotEmpty
          ? 'Lector(a): $estudiante (Código: $codigo)'
          : 'Lector(a): $estudiante';
      portada.graphics.drawString(
        datosEstudiante,
        fontCuerpo,
        brush: colorTextoOscuro,
        bounds: Rect.fromLTWH(20, y, anchoPagina - 40, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 24;

      // Ilustración de portada (referencia visual o escena 1)
      Uint8List? imagenPortada = cuento.referenciaVisualPng ??
          cuento.referenciaGeneradaEscena1Bytes ??
          cuento.obtenerImagenBytesEscena(1);

      if (imagenPortada != null && imagenPortada.isNotEmpty) {
        try {
          final bitmap = PdfBitmap(imagenPortada);
          final double maxW = anchoPagina - 80;
          final double maxH = 200;
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
          y += drawH + 16;
        } catch (_) {
          // Si el formato de imagen no es decodificable, se continúa sin error
        }
      }

      // Tarjeta de resumen de evaluación en la portada
      final puntaje = intentoQuiz.puntaje ?? 0;
      final totalPreg = intentoQuiz.totalPreguntas;
      final num porcentajeNum = intentoQuiz.porcentaje ?? ((puntaje / (totalPreg > 0 ? totalPreg : 1)) * 100);
      final porcentajeTexto = porcentajeNum is double
          ? porcentajeNum.toStringAsFixed(0)
          : porcentajeNum.toString();

      portada.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(232, 245, 233)),
        pen: PdfPen(PdfColor(165, 214, 167), width: 1),
        bounds: Rect.fromLTWH(40, altoPagina - 90, anchoPagina - 80, 54),
      );

      portada.graphics.drawString(
        'Evaluación de Comprensión Lectora Completada',
        fontSeccion,
        brush: colorPrincipal,
        bounds: Rect.fromLTWH(45, altoPagina - 84, anchoPagina - 90, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      portada.graphics.drawString(
        'Resultado Oficial: $puntaje de $totalPreg preguntas correctas ($porcentajeTexto % de aciertos)',
        fontCuerpoNegrita,
        brush: colorTextoOscuro,
        bounds: Rect.fromLTWH(45, altoPagina - 62, anchoPagina - 90, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // =======================================================================
      // 2. ESCENAS NARRATIVAS EN ORDEN ESTRICTO
      // =======================================================================
      final escenasOrdenadas = [...cuento.escenas]
        ..sort((a, b) => a.numero.compareTo(b.numero));

      for (final escena in escenasOrdenadas) {
        final pagina = pdf.pages.add();
        final double ancho = pagina.getClientSize().width;
        final double alto = pagina.getClientSize().height;
        double yPos = 14.0;

        // Título de la escena
        final esUltima = escena.esFinal;
        final tituloEscena = esUltima
            ? 'Escena ${escena.numero} • Desenlace'
            : 'Escena ${escena.numero}';

        pagina.graphics.drawString(
          tituloEscena,
          fontSubtitulo,
          brush: colorPrincipal,
          bounds: Rect.fromLTWH(0, yPos, ancho, 24),
        );
        yPos += 28;

        // Ilustración de la escena
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
            yPos += drawH + 14;
          } catch (_) {
            yPos = _dibujarPlaceholderImagen(pagina, fontDetalle, colorGris, ancho, yPos);
          }
        } else {
          yPos = _dibujarPlaceholderImagen(pagina, fontDetalle, colorGris, ancho, yPos);
        }

        // Decisión tomada por el estudiante
        final decision = cuento.obtenerDecision(escena.numero);
        if (decision != null && decision.opcionSeleccionada.trim().isNotEmpty) {
          final textoDecision = _sanitizarParaPdf(
            'Decisión elegida: "${decision.opcionSeleccionada}"',
          );

          pagina.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 243, 224)),
            pen: PdfPen(PdfColor(255, 204, 128), width: 0.8),
            bounds: Rect.fromLTWH(0, yPos, ancho, 22),
          );

          pagina.graphics.drawString(
            textoDecision,
            fontPequenaNegrita,
            brush: colorSecundario,
            bounds: Rect.fromLTWH(8, yPos + 4, ancho - 16, 16),
          );
          yPos += 28;
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

      // =======================================================================
      // 3. SECCIÓN DE EVALUACIÓN Y COMPRENSIÓN LECTORA (RF-22 / RF-26 / RF-30)
      // =======================================================================
      PdfPage paginaEval = pdf.pages.add();
      double anchoEval = paginaEval.getClientSize().width;
      double altoEval = paginaEval.getClientSize().height;
      double yEval = 14.0;

      // Encabezado de la sección de evaluación
      paginaEval.graphics.drawString(
        'Resultados de Comprensión Lectora',
        fontTitulo,
        brush: colorPrincipal,
        bounds: Rect.fromLTWH(0, yEval, anchoEval, 28),
      );
      yEval += 32;

      // Banner con puntaje y porcentaje
      paginaEval.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(241, 248, 233)),
        pen: PdfPen(PdfColor(200, 230, 201), width: 1),
        bounds: Rect.fromLTWH(0, yEval, anchoEval, 46),
      );

      final msgDesempeno = puntaje == 5
          ? '¡Excelente! Comprensión completa de la historia.'
          : (puntaje >= 3
              ? '¡Buen trabajo! Demostraste una buena retención y análisis lector.'
              : '¡Continúa practicando tu comprensión con nuevas lecturas!');

      paginaEval.graphics.drawString(
        'Puntaje Final: $puntaje de $totalPreg ($porcentajeTexto % de aciertos)',
        fontSubtitulo,
        brush: colorPrincipal,
        bounds: Rect.fromLTWH(12, yEval + 6, anchoEval - 24, 18),
      );
      paginaEval.graphics.drawString(
        _sanitizarParaPdf(msgDesempeno),
        fontDetalle,
        brush: colorTextoOscuro,
        bounds: Rect.fromLTWH(12, yEval + 26, anchoEval - 24, 16),
      );
      yEval += 56;

      // Listado de las 5 preguntas ordenadas por número
      final respuestasOrdenadas = List<QuizQuestionResult>.from(
        intentoQuiz.respuestas,
      )..sort((a, b) => a.numero.compareTo(b.numero));

      for (final resp in respuestasOrdenadas) {
        final nivelNombre = _formatearNivel(resp.nivelComprension);
        final esCorrecta = resp.esCorrecta;
        final estadoTexto = esCorrecta ? '[Correcta]' : '[Incorrecta]';
        final brushEstado = esCorrecta ? colorAcierto : colorError;

        final textoPregunta = _sanitizarParaPdf(resp.pregunta);
        final sizePreg = fontCuerpoNegrita.measureString(
          textoPregunta,
          layoutArea: Size(anchoEval, 1000),
        );

        final explicacionLimpia = resp.explicacion.trim().isNotEmpty
            ? _sanitizarParaPdf('Explicación pedagógica: ${resp.explicacion.trim()}')
            : '';
        final sizeExpl = explicacionLimpia.isNotEmpty
            ? fontDetalle.measureString(
                explicacionLimpia,
                layoutArea: Size(anchoEval - 20, 1000),
              )
            : Size.zero;
        final double alturaCajaExpl = explicacionLimpia.isNotEmpty
            ? (sizeExpl.height + 14)
            : 0;

        // Estimar altura total que requerirá la pregunta completa
        final double alturaEstimadaPregunta =
            22 +
            sizePreg.height +
            8 +
            (resp.opciones.length * 16) +
            (alturaCajaExpl > 0 ? (alturaCajaExpl + 10) : 8) +
            14;

        // Si la pregunta no cabe completa y ya hay contenido en la página, iniciar nueva página
        if (yEval + alturaEstimadaPregunta > altoEval - 20 && yEval > 50) {
          paginaEval = pdf.pages.add();
          anchoEval = paginaEval.getClientSize().width;
          altoEval = paginaEval.getClientSize().height;
          yEval = 14.0;
        }

        // Fila 1: Número, nivel de comprensión y estado de acierto
        paginaEval.graphics.drawString(
          'Pregunta ${resp.numero} - Nivel: $nivelNombre',
          fontSeccion,
          brush: colorTextoOscuro,
          bounds: Rect.fromLTWH(0, yEval, anchoEval - 100, 18),
        );
        paginaEval.graphics.drawString(
          estadoTexto,
          fontSeccion,
          brush: brushEstado,
          bounds: Rect.fromLTWH(anchoEval - 95, yEval, 95, 18),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yEval += 22;

        // Fila 2: Texto de la pregunta con ajuste de líneas
        final elemPregunta = PdfTextElement(
          text: textoPregunta,
          font: fontCuerpoNegrita,
          brush: colorTextoOscuro,
          format: PdfStringFormat(lineSpacing: 2),
        );
        final layoutPreg = elemPregunta.draw(
          page: paginaEval,
          bounds: Rect.fromLTWH(0, yEval, anchoEval, altoEval - yEval - 10),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        );
        if (layoutPreg != null) {
          if (layoutPreg.page != paginaEval) {
            paginaEval = layoutPreg.page;
            anchoEval = paginaEval.getClientSize().width;
            altoEval = paginaEval.getClientSize().height;
          }
          yEval = layoutPreg.bounds.bottom + 8;
        } else {
          yEval += sizePreg.height + 8;
        }

        // Fila 3: Opciones con selección y respuesta correcta
        for (int i = 0; i < resp.opciones.length; i++) {
          final letra = String.fromCharCode(65 + i);
          final textoOp = _sanitizarParaPdf(resp.opciones[i]);
          final fueSeleccionada = (i == resp.indiceSeleccionado);
          final esOpcionCorrecta = (i == resp.indiceCorrecto);

          String indicador = '';
          PdfBrush brushOpcion = colorTextoOscuro;
          PdfFont fontOpcion = fontPequena;

          if (fueSeleccionada && esOpcionCorrecta) {
            indicador = ' (Tu respuesta - Correcta)';
            brushOpcion = colorAcierto;
            fontOpcion = fontPequenaNegrita;
          } else if (fueSeleccionada) {
            indicador = ' (Tu respuesta)';
            brushOpcion = colorError;
            fontOpcion = fontPequenaNegrita;
          } else if (esOpcionCorrecta) {
            indicador = ' (Respuesta correcta)';
            brushOpcion = colorAcierto;
            fontOpcion = fontPequenaNegrita;
          }

          final textoCompletoOpcion = '$letra) $textoOp$indicador';
          final sizeOp = fontOpcion.measureString(
            textoCompletoOpcion,
            layoutArea: Size(anchoEval - 15, 200),
          );
          final double hOp = sizeOp.height > 14 ? (sizeOp.height + 2) : 14;

          if (yEval + hOp > altoEval - 20) {
            paginaEval = pdf.pages.add();
            anchoEval = paginaEval.getClientSize().width;
            altoEval = paginaEval.getClientSize().height;
            yEval = 14.0;
          }

          paginaEval.graphics.drawString(
            textoCompletoOpcion,
            fontOpcion,
            brush: brushOpcion,
            bounds: Rect.fromLTWH(10, yEval, anchoEval - 15, hOp),
          );
          yEval += hOp + 2;
        }
        yEval += 4;

        // Fila 4: Explicación pedagógica multilínea sin truncamiento
        if (explicacionLimpia.isNotEmpty) {
          if (yEval + alturaCajaExpl > altoEval - 20 && yEval > 40) {
            paginaEval = pdf.pages.add();
            anchoEval = paginaEval.getClientSize().width;
            altoEval = paginaEval.getClientSize().height;
            yEval = 14.0;
          }

          final double cajaHeight = (yEval + alturaCajaExpl <= altoEval - 10)
              ? alturaCajaExpl
              : (altoEval - yEval - 10);

          paginaEval.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 253, 231)),
            pen: PdfPen(PdfColor(255, 236, 179), width: 0.6),
            bounds: Rect.fromLTWH(0, yEval, anchoEval, cajaHeight),
          );

          final elemExplicacion = PdfTextElement(
            text: explicacionLimpia,
            font: fontDetalle,
            brush: colorTextoOscuro,
            format: PdfStringFormat(lineSpacing: 2),
          );

          final layoutExpl = elemExplicacion.draw(
            page: paginaEval,
            bounds: Rect.fromLTWH(8, yEval + 6, anchoEval - 16, altoEval - yEval - 10),
            format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
          );

          if (layoutExpl != null) {
            if (layoutExpl.page != paginaEval) {
              paginaEval = layoutExpl.page;
              anchoEval = paginaEval.getClientSize().width;
              altoEval = paginaEval.getClientSize().height;
            }
            yEval = layoutExpl.bounds.bottom + 12;
          } else {
            yEval += alturaCajaExpl + 8;
          }
        } else {
          yEval += 8;
        }

        // Separador sutil entre preguntas
        paginaEval.graphics.drawLine(
          PdfPen(PdfColor(238, 238, 238), width: 1),
          Offset(0, yEval),
          Offset(anchoEval, yEval),
        );
        yEval += 10;
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

  /// Formatea la clave técnica del nivel pedagógico a texto legible para educación primaria.
  static String _formatearNivel(String nivel) {
    final clean = nivel.toLowerCase().trim();
    if (clean == 'literal') {
      return 'Literal';
    } else if (clean == 'inferencial') {
      return 'Inferencial';
    } else if (clean == 'critico_reflexivo' ||
        clean == 'critico-reflexivo' ||
        clean == 'crítico_reflexivo' ||
        clean == 'crítico-reflexivo') {
      return 'Crítico-reflexivo';
    } else if (clean == 'sin_clasificar') {
      return 'Sin clasificar';
    }
    return 'General';
  }

  /// Sanitiza texto para fuentes estándar de PDF (Helvetica), conservando acentos
  /// en español (á, é, í, ó, ú, ñ, ¿, ¡) y reemplazando caracteres o emojis no compatibles.
  static String _sanitizarParaPdf(String texto) {
    if (texto.isEmpty) return '';

    // Reemplazar saltos de línea múltiples o caracteres de control
    var limpio = texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remover emojis y símbolos especiales que están fuera del mapa ISO-8859-1 de Helvetica
    limpio = limpio.replaceAll(
      RegExp(r'[\u{1F300}-\u{1FAFF}|\u{2600}-\u{27BF}|\u{2000}-\u{206F}]', unicode: true),
      '',
    );

    // Reemplazar viñetas o comillas tipográficas que puedan fallar en Helvetica estándar
    limpio = limpio
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-');

    return limpio.trim();
  }
}
