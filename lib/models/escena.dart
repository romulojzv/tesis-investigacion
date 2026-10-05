class Escena {
  final int numero;

  // Texto narrativo de la escena.
  final String contenido;

  // Imagen generada para esta escena.
  final String? imageUrl;

  // Alternativas que puede escoger el estudiante.
  final List<String> opciones;

  // Indica si esta es la última escena del cuento.
  final bool esFinal;

  Escena({
    required this.numero,
    required this.contenido,
    this.imageUrl,
    this.opciones = const [],
    this.esFinal = false,
  });

  Escena copyWith({
    int? numero,
    String? contenido,
    String? imageUrl,
    List<String>? opciones,
    bool? esFinal,
  }) {
    return Escena(
      numero: numero ?? this.numero,
      contenido: contenido ?? this.contenido,
      imageUrl: imageUrl ?? this.imageUrl,
      opciones: opciones ?? this.opciones,
      esFinal: esFinal ?? this.esFinal,
    );
  }
}
