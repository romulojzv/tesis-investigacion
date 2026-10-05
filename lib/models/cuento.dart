import 'dart:typed_data';

import 'decision_narrativa.dart';
import 'escena.dart';

enum CuentoOrigen { dibujo, pdf }

class Cuento {
  final String id;
  final String titulo;
  final String? tituloOriginal;
  final String personajePrincipal;
  final String? personajeOriginal;
  final bool esPersonajeNuevo;
  final CuentoOrigen origen;

  final String? textoFuente;
  final String? resumenOriginal;
  final String? escenarioOriginal;
  final String? conflictoPrincipal;
  final String? finalOriginal;
  final String? descripcionPersonaje;

  final Uint8List? referenciaVisualPng;

  final List<Escena> escenas;
  final List<DecisionNarrativa> decisiones;

  Cuento({
    required this.id,
    required this.titulo,
    this.tituloOriginal,
    required String personajePrincipal,
    this.personajeOriginal,
    this.esPersonajeNuevo = false,
    this.origen = CuentoOrigen.dibujo,
    this.textoFuente,
    this.resumenOriginal,
    this.escenarioOriginal,
    this.conflictoPrincipal,
    this.finalOriginal,
    this.descripcionPersonaje,
    Uint8List? referenciaVisualPng,
    List<Escena>? escenas,
    List<DecisionNarrativa>? decisiones,
  }) : personajePrincipal = personajePrincipal.trim().replaceAll(
         RegExp(r'\s+'),
         ' ',
       ),
       referenciaVisualPng = referenciaVisualPng == null
           ? null
           : Uint8List.fromList(referenciaVisualPng),
       escenas = escenas ?? [],
       decisiones = decisiones ?? [];

  /// Indica si el personaje actual es el original renombrado (conserva personalidad y rol original)
  bool get fueRenombrado =>
      !esPersonajeNuevo &&
      personajeOriginal != null &&
      personajeOriginal!.trim().isNotEmpty &&
      personajeOriginal!.trim().toLowerCase() !=
          personajePrincipal.trim().toLowerCase();

  /// Indica si se debe sanitizar cualquier mención residual del nombre original en el texto
  bool get requiereSustitucionNombreOriginal =>
      personajeOriginal != null &&
      personajeOriginal!.trim().isNotEmpty &&
      personajeOriginal!.trim().toLowerCase() !=
          personajePrincipal.trim().toLowerCase();

  bool get tieneReferenciaVisual {
    return referenciaVisualPng != null && referenciaVisualPng!.isNotEmpty;
  }

  bool get tieneContextoOriginal {
    return textoFuente != null && textoFuente!.trim().isNotEmpty;
  }

  String get origenDatabase {
    switch (origen) {
      case CuentoOrigen.dibujo:
        return 'dibujo';

      case CuentoOrigen.pdf:
        return 'pdf';
    }
  }

  void agregarEscena(Escena escena) {
    final existe = escenas.any((item) => item.numero == escena.numero);

    if (existe) {
      return;
    }

    escenas.add(escena);

    escenas.sort((a, b) => a.numero.compareTo(b.numero));
  }

  Escena? obtenerEscena(int numero) {
    for (final escena in escenas) {
      if (escena.numero == numero) {
        return escena;
      }
    }

    return null;
  }

  DecisionNarrativa? obtenerDecision(int numeroEscena) {
    for (final decision in decisiones) {
      if (decision.numeroEscena == numeroEscena) {
        return decision;
      }
    }

    return null;
  }

  bool registrarDecision(DecisionNarrativa decision) {
    final existente = obtenerDecision(decision.numeroEscena);

    if (existente != null) {
      if (existente.opcionSeleccionada != decision.opcionSeleccionada) {
        throw StateError(
          'La escena ${decision.numeroEscena} '
          'ya tiene una decisión registrada.',
        );
      }

      return false;
    }

    decisiones.add(decision);

    decisiones.sort((a, b) => a.numeroEscena.compareTo(b.numeroEscena));

    return true;
  }

  /// Asocia o actualiza la imagen de una escena existente sin regenerar la escena.
  bool asociarImagenAEscena(int numeroEscena, String imageUrl) {
    final indice = escenas.indexWhere((e) => e.numero == numeroEscena);
    if (indice == -1) return false;
    escenas[indice] = escenas[indice].copyWith(imageUrl: imageUrl);
    return true;
  }
}
