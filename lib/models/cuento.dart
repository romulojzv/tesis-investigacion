import 'decision_narrativa.dart';
import 'escena.dart';

class Cuento {
  final String id;
  final String titulo;
  final String personajePrincipal;

  final List<Escena> escenas;
  final List<DecisionNarrativa> decisiones;

  Cuento({
    required this.id,
    required this.titulo,
    required this.personajePrincipal,
    List<Escena>? escenas,
    List<DecisionNarrativa>? decisiones,
  })  : escenas = escenas ?? [],
        decisiones = decisiones ?? [];

  void agregarEscena(Escena escena) {
    final existe = escenas.any(
      (item) => item.numero == escena.numero,
    );

    if (existe) {
      return;
    }

    escenas.add(escena);

    escenas.sort(
      (a, b) => a.numero.compareTo(b.numero),
    );
  }

  Escena? obtenerEscena(int numero) {
    for (final escena in escenas) {
      if (escena.numero == numero) {
        return escena;
      }
    }

    return null;
  }

  DecisionNarrativa? obtenerDecision(
    int numeroEscena,
  ) {
    for (final decision in decisiones) {
      if (decision.numeroEscena == numeroEscena) {
        return decision;
      }
    }

    return null;
  }

  bool registrarDecision(
    DecisionNarrativa decision,
  ) {
    final existente = obtenerDecision(
      decision.numeroEscena,
    );

    if (existente != null) {
      if (existente.opcionSeleccionada !=
          decision.opcionSeleccionada) {
        throw StateError(
          'La escena ${decision.numeroEscena} '
          'ya tiene una decisión registrada.',
        );
      }

      return false;
    }

    decisiones.add(decision);

    decisiones.sort(
      (a, b) =>
          a.numeroEscena.compareTo(b.numeroEscena),
    );

    return true;
  }
}