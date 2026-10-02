import '../models/escena.dart';

class NarrativaService {
  String construirContexto({
    required List<Escena> escenas,
    required String decision,
  }) {
    final escenasOrdenadas = [...escenas]
      ..sort((a, b) => a.numero.compareTo(b.numero));

    final buffer = StringBuffer();

    for (final escena in escenasOrdenadas) {
      buffer.writeln(
        'Escena ${escena.numero}: ${escena.contenido}',
      );
    }

    buffer.writeln(
      'Decisión del estudiante: $decision',
    );

    buffer.writeln(
      'Generar una continuación coherente, apropiada para estudiantes '
      'de educación primaria y relacionada con la decisión seleccionada.',
    );

    return buffer.toString();
  }
}