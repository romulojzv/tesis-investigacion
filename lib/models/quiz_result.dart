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
    final opcionesRaw = json['opciones'] as List<dynamic>? ?? [];
    return QuizQuestionResult(
      numero: json['numero'] as int? ?? 1,
      pregunta: json['pregunta'] as String? ?? '',
      opciones: opcionesRaw.map((e) => e.toString()).toList(),
      indiceSeleccionado: json['indiceSeleccionado'] as int? ?? -1,
      indiceCorrecto: json['indiceCorrecto'] as int? ?? 0,
      esCorrecta: json['esCorrecta'] as bool? ?? false,
      explicacion: json['explicacion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'pregunta': pregunta,
      'opciones': opciones,
      'indiceSeleccionado': indiceSeleccionado,
      'indiceCorrecto': indiceCorrecto,
      'esCorrecta': esCorrecta,
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
    final respuestasRaw = json['respuestas'] as List<dynamic>? ?? [];
    return QuizResult(
      intentoId: json['intentoId'] as String? ?? '',
      puntaje: json['puntaje'] as int? ?? 0,
      total: json['total'] as int? ?? 5,
      porcentaje: json['porcentaje'] as num? ?? 0,
      respuestas: respuestasRaw
          .map((e) => QuizQuestionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
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
