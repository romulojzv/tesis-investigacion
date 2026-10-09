// lib/models/quiz_question.dart

/// Representa una pregunta del quiz entregada al estudiante antes de finalizar.
/// No incluye correctIndex ni explicación para garantizar seguridad en cliente.
class QuizQuestion {
  final int numero;
  final String pregunta;
  final List<String> opciones;

  const QuizQuestion({
    required this.numero,
    required this.pregunta,
    required this.opciones,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opcionesRaw = json['opciones'] as List<dynamic>? ?? [];
    return QuizQuestion(
      numero: json['numero'] as int? ?? 1,
      pregunta: json['pregunta'] as String? ?? '',
      opciones: opcionesRaw.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'numero': numero, 'pregunta': pregunta, 'opciones': opciones};
  }
}

/// Representa la respuesta seleccionada por el estudiante para una pregunta.
class QuizAnswerSubmission {
  final int numero;
  final int indiceSeleccionado;

  const QuizAnswerSubmission({
    required this.numero,
    required this.indiceSeleccionado,
  });

  factory QuizAnswerSubmission.fromJson(Map<String, dynamic> json) {
    return QuizAnswerSubmission(
      numero: json['numero'] as int? ?? 1,
      indiceSeleccionado: json['indiceSeleccionado'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'numero': numero, 'indiceSeleccionado': indiceSeleccionado};
  }
}
