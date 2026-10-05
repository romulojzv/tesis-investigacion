class StoryAnalysis {
  final String titulo;
  final String? tituloOriginal;
  final String personajePrincipal;
  final String descripcionPersonaje;
  final String resumen;
  final String escenario;
  final String conflictoPrincipal;
  final String finalOriginal;

  StoryAnalysis({
    required this.titulo,
    this.tituloOriginal,
    required this.personajePrincipal,
    required this.descripcionPersonaje,
    required this.resumen,
    required this.escenario,
    required this.conflictoPrincipal,
    required this.finalOriginal,
  });

  factory StoryAnalysis.fromJson(Map<String, dynamic> json) {
    final orig =
        json['tituloOriginal']?.toString().trim() ??
        json['titulo_original']?.toString().trim();
    return StoryAnalysis(
      titulo: json['titulo']?.toString().trim() ?? '',
      tituloOriginal: (orig != null && orig.isNotEmpty) ? orig : null,
      personajePrincipal: json['personajePrincipal']?.toString().trim() ?? '',
      descripcionPersonaje:
          json['descripcionPersonaje']?.toString().trim() ?? '',
      resumen: json['resumen']?.toString().trim() ?? '',
      escenario: json['escenario']?.toString().trim() ?? '',
      conflictoPrincipal: json['conflictoPrincipal']?.toString().trim() ?? '',
      finalOriginal: json['finalOriginal']?.toString().trim() ?? '',
    );
  }
}
