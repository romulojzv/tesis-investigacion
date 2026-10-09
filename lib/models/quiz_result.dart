// lib/models/quiz_result.dart

/// Representa el resultado individual de una pregunta calificada por el servidor.
class QuizQuestionResult {
  final int numero;
  final String pregunta;
  final List<String> opciones;
  final int indiceSeleccionado;
  final int indiceCorrecto;
  final bool esCorrecta;
  final String explicacion;

  const QuizQuestionResult({
    required this.numero,
    required this.pregunta,
    required this.opciones,
    required this.indiceSeleccionado,
    required this.indiceCorrecto,
    required this.esCorrecta,
    required this.explicacion,
  });

  String get opcionSeleccionadaTexto {
    if (indiceSeleccionado >= 0 && indiceSeleccionado < opciones.length) {
      return opciones[indiceSeleccionado];
    }
    return '(Sin respuesta)';
  }

  String get opcionCorrectaTexto {
    if (indiceCorrecto >= 0 && indiceCorrecto < opciones.length) {
      return opciones[indiceCorrecto];
    }
    return '';
  }

  factory QuizQuestionResult.fromJson(Map<String, dynamic> json) {
    final opcionesRaw =
        (json['opciones'] ?? json['options']) as List<dynamic>? ?? [];

    final numVal =
        json['numero_pregunta'] ?? json['numero'] ?? json['numeroPregunta'];
    final indSel = json['indice_seleccionado'] ?? json['indiceSeleccionado'];
    final indCorr = json['indice_correcto'] ?? json['indiceCorrecto'];
    final esCorr = json['es_correcta'] ?? json['esCorrecta'];

    final int numParsed;
    if (numVal is int) {
      numParsed = numVal;
    } else if (numVal is num) {
      numParsed = numVal.toInt();
    } else {
      numParsed = int.tryParse(numVal?.toString() ?? '') ?? 1;
    }

    final int indSelParsed;
    if (indSel is int) {
      indSelParsed = indSel;
    } else if (indSel is num) {
      indSelParsed = indSel.toInt();
    } else {
      indSelParsed = int.tryParse(indSel?.toString() ?? '') ?? -1;
    }

    final int indCorrParsed;
    if (indCorr is int) {
      indCorrParsed = indCorr;
    } else if (indCorr is num) {
      indCorrParsed = indCorr.toInt();
    } else {
      indCorrParsed = int.tryParse(indCorr?.toString() ?? '') ?? 0;
    }

    final bool esCorrParsed;
    if (esCorr is bool) {
      esCorrParsed = esCorr;
    } else if (esCorr != null) {
      esCorrParsed = esCorr.toString().toLowerCase() == 'true';
    } else {
      esCorrParsed = indSelParsed >= 0 && indSelParsed == indCorrParsed;
    }

    return QuizQuestionResult(
      numero: numParsed,
      pregunta: (json['pregunta'] ?? json['question']) as String? ?? '',
      opciones: opcionesRaw.map((e) => e.toString()).toList(),
      indiceSeleccionado: indSelParsed,
      indiceCorrecto: indCorrParsed,
      esCorrecta: esCorrParsed,
      explicacion:
          (json['explicacion'] ?? json['explanation']) as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'numero_pregunta': numero,
      'pregunta': pregunta,
      'opciones': opciones,
      'indiceSeleccionado': indiceSeleccionado,
      'indice_seleccionado': indiceSeleccionado,
      'indiceCorrecto': indiceCorrecto,
      'indice_correcto': indiceCorrecto,
      'esCorrecta': esCorrecta,
      'es_correcta': esCorrecta,
      'explicacion': explicacion,
    };
  }
}

/// Representa el resultado global calificado y devuelto por el servidor tras enviar-quiz.
class QuizResult {
  final String intentoId;
  final int puntaje;
  final int total;
  final num porcentaje;
  final List<QuizQuestionResult> respuestas;

  const QuizResult({
    required this.intentoId,
    required this.puntaje,
    required this.total,
    required this.porcentaje,
    required this.respuestas,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final respuestasRaw =
        (json['respuestas'] ?? json['quiz_respuestas']) as List<dynamic>? ?? [];
    final listado =
        respuestasRaw
            .map((e) => QuizQuestionResult.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));

    return QuizResult(
      intentoId:
          (json['intentoId'] ?? json['intento_id'] ?? json['id']) as String? ??
          '',
      puntaje: (json['puntaje'] as num?)?.toInt() ?? 0,
      total: (json['total'] ?? json['total_preguntas'] as num?)?.toInt() ?? 5,
      porcentaje: (json['porcentaje'] as num?) ?? 0,
      respuestas: listado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intentoId': intentoId,
      'puntaje': puntaje,
      'total': total,
      'porcentaje': porcentaje,
      'respuestas': respuestas.map((r) => r.toJson()).toList(),
    };
  }
}
