// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import '../widgets/ilustracion_escena_widget.dart';
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

  final String? estudianteId;
  final String? aulaId;
  final bool esDemo;

  final Uint8List? referenciaVisualPng;

  final List<Escena> escenas;
  final List<DecisionNarrativa> decisiones;
  final bool? _esModoDibujo;

  Cuento({
    required this.id,
    required this.titulo,
    this.tituloOriginal,
    required String personajePrincipal,
    this.personajeOriginal,
    this.esPersonajeNuevo = false,
    this.origen = CuentoOrigen.dibujo,
    bool? esModoDibujo,
    this.textoFuente,
    this.resumenOriginal,
    this.escenarioOriginal,
    this.conflictoPrincipal,
    this.finalOriginal,
    this.descripcionPersonaje,
    this.estudianteId,
    this.aulaId,
    this.esDemo = false,
    Uint8List? referenciaVisualPng,
    List<Escena>? escenas,
    List<DecisionNarrativa>? decisiones,
  }) : _esModoDibujo = esModoDibujo,
       personajePrincipal = personajePrincipal.trim().replaceAll(
         RegExp(r'\s+'),
         ' ',
       ),
       referenciaVisualPng = referenciaVisualPng == null
           ? null
           : Uint8List.fromList(referenciaVisualPng),
       escenas = escenas ?? [],
       decisiones = decisiones ?? [];

  /// Indica si la representación visual del personaje se basa en un dibujo del estudiante.
  bool get esModoDibujo => _esModoDibujo ?? (origen == CuentoOrigen.dibujo);

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

  Uint8List? _referenciaGeneradaEscena1Bytes;
  final Map<int, Uint8List> _imagenesEscenasBytes = {};

  /// Retorna los bytes de la ilustración generada para la escena 1 si existe
  Uint8List? get referenciaGeneradaEscena1Bytes =>
      _referenciaGeneradaEscena1Bytes;

  /// Registra los bytes de la ilustración generada para la escena 1 en modo automático
  void registrarReferenciaEscena1(Uint8List bytes) {
    if (referenciaVisualPng == null && bytes.isNotEmpty) {
      _referenciaGeneradaEscena1Bytes = Uint8List.fromList(bytes);
    }
  }

  /// Retorna los bytes de la ilustración generada para una escena dada si están disponibles
  Uint8List? obtenerImagenBytesEscena(int numeroEscena) {
    if (_imagenesEscenasBytes.containsKey(numeroEscena)) {
      return _imagenesEscenasBytes[numeroEscena];
    }
    final escena = obtenerEscena(numeroEscena);
    if (escena != null &&
        escena.imageUrl != null &&
        IlustracionEscenaWidget.esDataUri(escena.imageUrl!)) {
      final bytes = IlustracionEscenaWidget.decodificarDataUri(
        escena.imageUrl!,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _imagenesEscenasBytes[numeroEscena] = bytes;
        return bytes;
      }
    }
    return null;
  }

  /// Registra los bytes de la ilustración generada para una escena (utilizada como anchor en escenas subsiguientes)
  void registrarImagenEscena(int numeroEscena, Uint8List bytes) {
    if (bytes.isNotEmpty) {
      _imagenesEscenasBytes[numeroEscena] = Uint8List.fromList(bytes);
    }
  }

  /// Retorna la referencia visual a utilizar para ilustrar la escena especificada.
  /// Prioridad estricta:
  /// 1. Dibujo del estudiante o imagen de PDF ([referenciaVisualPng]):
  ///    Tiene máxima prioridad y se usa para TODAS las escenas (1, 2, 3, 4...).
  /// 2. Modo diseño automático:
  ///    - Escena 1: retorna null (usa text-to-image).
  ///    - Escenas 2, 3, 4...: retorna los bytes de la ilustración de la escena 1
  ///      (manteniendo la misma referencia base estable y evitando drift acumulativo).
  Uint8List? obtenerReferenciaVisualParaEscena(int numeroEscena) {
    // 1. Dibujo original o imagen PDF siempre tiene prioridad absoluta
    if (referenciaVisualPng != null && referenciaVisualPng!.isNotEmpty) {
      return referenciaVisualPng;
    }

    // 2. Para escenas posteriores en modo automático, usar la imagen base de la escena 1
    if (numeroEscena > 1) {
      if (_referenciaGeneradaEscena1Bytes != null &&
          _referenciaGeneradaEscena1Bytes!.isNotEmpty) {
        return _referenciaGeneradaEscena1Bytes;
      }

      // Reutilizar la imagen ya generada de la escena 1 si existe
      final escena1 = obtenerEscena(1);
      if (escena1 != null &&
          escena1.imageUrl != null &&
          escena1.imageUrl!.trim().isNotEmpty) {
        final url = escena1.imageUrl!.trim();
        if (IlustracionEscenaWidget.esDataUri(url)) {
          final bytes = IlustracionEscenaWidget.decodificarDataUri(url);
          if (bytes != null && bytes.isNotEmpty) {
            _referenciaGeneradaEscena1Bytes = bytes;
            return bytes;
          }
        }
      }
    }

    return null;
  }

  /// Asocia o actualiza la imagen de una escena existente sin regenerar la escena.
  bool asociarImagenAEscena(int numeroEscena, String imageUrl) {
    final indice = escenas.indexWhere((e) => e.numero == numeroEscena);
    if (indice == -1) return false;
    escenas[indice] = escenas[indice].copyWith(imageUrl: imageUrl);
    return true;
  }
}
