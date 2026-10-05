import 'dart:typed_data';

enum EstadoImagenesPdf {
  sinImagenes,
  noVerificadas,
  potencialmenteUtiles,
  confirmadasPersonaje,
  descartadas,
}

class PdfStoryData {
  final String nombreArchivo;
  final String textoExtraido;
  final String? tituloDetectado;
  final String? tituloOriginal;
  final String? personajePrincipalDetectado;
  final String? descripcionPersonaje;
  final String? resumen;
  final String? escenario;
  final String? conflictoPrincipal;
  final String? finalOriginal;
  final List<Uint8List> imagenesExtraidas;
  final EstadoImagenesPdf estadoImagenes;
  final Uint8List? imagenSeleccionadaPersonaje;

  PdfStoryData({
    required this.nombreArchivo,
    required this.textoExtraido,
    this.tituloDetectado,
    this.tituloOriginal,
    this.personajePrincipalDetectado,
    this.descripcionPersonaje,
    this.resumen,
    this.escenario,
    this.conflictoPrincipal,
    this.finalOriginal,
    List<Uint8List>? imagenesExtraidas,
    EstadoImagenesPdf? estadoImagenes,
    this.imagenSeleccionadaPersonaje,
  }) : imagenesExtraidas = imagenesExtraidas ?? [],
       estadoImagenes =
           estadoImagenes ??
           ((imagenesExtraidas != null && imagenesExtraidas.isNotEmpty)
               ? EstadoImagenesPdf.noVerificadas
               : EstadoImagenesPdf.sinImagenes);

  bool get tieneTexto => textoExtraido.trim().isNotEmpty;

  bool get tienePersonajeDetectado =>
      personajePrincipalDetectado != null &&
      personajePrincipalDetectado!.trim().isNotEmpty;

  bool get tieneImagenes => imagenesExtraidas.isNotEmpty;

  bool get tieneImagenConfirmada =>
      estadoImagenes == EstadoImagenesPdf.confirmadasPersonaje &&
      imagenSeleccionadaPersonaje != null;

  PdfStoryData copyWith({
    String? tituloDetectado,
    String? tituloOriginal,
    String? personajePrincipalDetectado,
    String? descripcionPersonaje,
    String? resumen,
    String? escenario,
    String? conflictoPrincipal,
    String? finalOriginal,
    List<Uint8List>? imagenesExtraidas,
    EstadoImagenesPdf? estadoImagenes,
    Uint8List? imagenSeleccionadaPersonaje,
  }) {
    return PdfStoryData(
      nombreArchivo: nombreArchivo,
      textoExtraido: textoExtraido,
      tituloDetectado: tituloDetectado ?? this.tituloDetectado,
      tituloOriginal: tituloOriginal ?? this.tituloOriginal,
      personajePrincipalDetectado:
          personajePrincipalDetectado ?? this.personajePrincipalDetectado,
      descripcionPersonaje: descripcionPersonaje ?? this.descripcionPersonaje,
      resumen: resumen ?? this.resumen,
      escenario: escenario ?? this.escenario,
      conflictoPrincipal: conflictoPrincipal ?? this.conflictoPrincipal,
      finalOriginal: finalOriginal ?? this.finalOriginal,
      imagenesExtraidas: imagenesExtraidas ?? this.imagenesExtraidas,
      estadoImagenes: estadoImagenes ?? this.estadoImagenes,
      imagenSeleccionadaPersonaje:
          imagenSeleccionadaPersonaje ?? this.imagenSeleccionadaPersonaje,
    );
  }
}
