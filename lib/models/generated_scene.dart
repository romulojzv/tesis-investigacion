class GeneratedScene {
  final String contenido;
  final List<String> opciones;
  final bool esFinal;

  const GeneratedScene({
    required this.contenido,
    required this.opciones,
    required this.esFinal,
  });

  factory GeneratedScene.fromJson(Map<String, dynamic> json) {
    final contenido = json['contenido']?.toString().trim() ?? '';

    final esFinal = json['esFinal'] == true;

    final opcionesRaw = json['opciones'];

    if (contenido.isEmpty) {
      throw const FormatException('La escena generada no tiene contenido.');
    }

    if (opcionesRaw is! List) {
      throw const FormatException('Las opciones deben ser una lista.');
    }

    final opciones = opcionesRaw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (!esFinal) {
      if (opciones.length != 3 || opciones.toSet().length != 3) {
        throw const FormatException(
          'Una escena no final debe tener '
          'exactamente tres opciones diferentes.',
        );
      }
    } else if (opciones.isNotEmpty) {
      throw const FormatException('Una escena final no debe tener opciones.');
    }

    return GeneratedScene(
      contenido: contenido,
      opciones: opciones,
      esFinal: esFinal,
    );
  }
}
