import 'dart:typed_data';

enum CharacterMode { keepOriginal, renameOriginal, newCharacter }

enum CharacterVisualMode { pdfImages, automatic, drawing }

class CharacterCustomization {
  final CharacterMode mode;
  final CharacterVisualMode visualMode;
  final String nombrePersonaje;
  final String? personajeOriginal;
  final String? descripcionPersonaje;
  final Uint8List? imagenReferencia;
  final String? estadoDisenoAutomatico;

  CharacterCustomization({
    required this.mode,
    required this.visualMode,
    required String nombrePersonaje,
    this.personajeOriginal,
    String? descripcionPersonaje,
    this.imagenReferencia,
    this.estadoDisenoAutomatico,
  }) : nombrePersonaje = sanitizarNombre(nombrePersonaje),
       descripcionPersonaje =
           (mode == CharacterMode.newCharacter &&
               descripcionPersonaje != null &&
               descripcionPersonaje.trim().isNotEmpty)
           ? descripcionPersonaje.trim().replaceAll(RegExp(r'\s+'), ' ')
           : null;

  /// Sanitiza el nombre eliminando espacios redundantes y espacios al inicio/final
  static String sanitizarNombre(String nombre) {
    return nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool get esPersonajeNuevo => mode == CharacterMode.newCharacter;
  bool get esRenombrado => mode == CharacterMode.renameOriginal;
}
