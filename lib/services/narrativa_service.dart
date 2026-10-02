import '../models/cuento.dart';
import '../models/escena.dart';

class NarrativaService {
  String construirContexto({
    required List<Escena> escenas,
    required String decision,
  }) {
    final escenasOrdenadas = [...escenas]
      ..sort(
        (a, b) => a.numero.compareTo(b.numero),
      );

    final buffer = StringBuffer();

    for (final escena in escenasOrdenadas) {
      buffer.writeln(
        'Escena ${escena.numero}: '
        '${escena.contenido}',
      );
    }

    buffer.writeln(
      'Decisión del estudiante: $decision',
    );

    buffer.writeln(
      'Generar una continuación coherente, '
      'apropiada para estudiantes de educación '
      'primaria y relacionada con la decisión '
      'seleccionada.',
    );

    return buffer.toString();
  }

  String construirContextoCompleto({
    required Cuento cuento,
    required Escena escenaActual,
    required String decision,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      'Personaje principal: '
      '${cuento.personajePrincipal}',
    );

    buffer.writeln();

    buffer.writeln('Historia hasta el momento:');

    for (final escena in cuento.escenas) {
      buffer.writeln(
        'Escena ${escena.numero}: '
        '${escena.contenido}',
      );
    }

    if (cuento.decisiones.isNotEmpty) {
      buffer.writeln();

      buffer.writeln(
        'Decisiones tomadas por el estudiante:',
      );

      for (final decision in cuento.decisiones) {
        buffer.writeln(
          'Escena ${decision.numeroEscena}: '
          '${decision.opcionSeleccionada}',
        );
      }
    }

    buffer.writeln();

    buffer.writeln(
      'Escena actual: '
      '${escenaActual.contenido}',
    );

    buffer.writeln(
      'Nueva decisión: $decision',
    );

    buffer.writeln();

    buffer.writeln(
      'La continuación debe mantener coherencia '
      'con las escenas y decisiones anteriores.',
    );

    return buffer.toString();
  }

  Escena crearEscenaInicialDemo({
    required String nombrePersonaje,
  }) {
    return Escena(
      numero: 1,
      contenido:
          '$nombrePersonaje abrió los ojos y descubrió '
          'un lugar lleno de luces brillantes, sonidos '
          'misteriosos y caminos que parecían esconder '
          'una gran aventura.',
      opciones: [
        'Seguir las luces misteriosas',
        'Buscar de dónde viene el sonido',
        'Observar el lugar antes de avanzar',
      ],
    );
  }

  Future<Escena> generarSiguienteEscena({
    required Cuento cuento,
    required Escena escenaActual,
    required String decision,
  }) async {
    /*
     * Este contexto será el que posteriormente
     * se enviará a Gemini.
     */
    construirContextoCompleto(
      cuento: cuento,
      escenaActual: escenaActual,
      decision: decision,
    );

    /*
     * Simulación temporal del tiempo de respuesta
     * de la IA.
     */
    await Future.delayed(
      const Duration(
        milliseconds: 1200,
      ),
    );

    final siguienteNumero =
        escenaActual.numero + 1;

    /*
     * Solo para probar el flujo.
     *
     * Cuando conectemos Gemini,
     * la IA determinará cuándo termina
     * la historia según nuestras reglas.
     */
    final esFinal =
        siguienteNumero >= 4;

    final contenido =
        _generarContenidoDemo(
      nombrePersonaje:
          cuento.personajePrincipal,
      decision: decision,
      numeroEscena:
          siguienteNumero,
    );

    final opciones = esFinal
        ? <String>[]
        : _generarOpcionesContextualesDemo(
            nombrePersonaje:
                cuento.personajePrincipal,
            decisionAnterior:
                decision,
            contenido:
                contenido,
          );

    return Escena(
      numero: siguienteNumero,
      contenido: contenido,
      opciones: opciones,
      esFinal: esFinal,
    );
  }

  String _generarContenidoDemo({
    required String nombrePersonaje,
    required String decision,
    required int numeroEscena,
  }) {
    return '$nombrePersonaje decidió "$decision". '
        'Mientras avanzaba, descubrió que aquella '
        'elección lo llevaba hacia una nueva parte '
        'de la aventura. Algo inesperado apareció '
        'frente a él y tuvo que pensar cuidadosamente '
        'qué hacer a continuación.';
  }

  List<String> _generarOpcionesContextualesDemo({
    required String nombrePersonaje,
    required String decisionAnterior,
    required String contenido,
  }) {
    final decision =
        decisionAnterior.toLowerCase();

    /*
     * Estas reglas existen únicamente para
     * simular alternativas variables mientras
     * todavía no conectamos Gemini.
     */

    if (decision.contains('luz') ||
        decision.contains('luces')) {
      return [
        'Acercarse con cuidado a la luz',
        'Descubrir qué produce el resplandor',
        'Buscar pistas alrededor de las luces',
      ];
    }

    if (decision.contains('sonido') ||
        decision.contains('melod')) {
      return [
        'Seguir escuchando atentamente',
        'Buscar quién produce el sonido',
        'Acercarse lentamente al lugar',
      ];
    }

    if (decision.contains('bosque') ||
        decision.contains('árbol')) {
      return [
        'Explorar un sendero entre los árboles',
        'Buscar huellas en el suelo',
        'Observar lo que hay detrás de los árboles',
      ];
    }

    if (decision.contains('hablar')) {
      return [
        'Hacer una nueva pregunta',
        'Escuchar atentamente la respuesta',
        'Preguntar si necesita ayuda',
      ];
    }

    if (decision.contains('investigar') ||
        decision.contains('explorar')) {
      return [
        'Revisar una pista encontrada',
        'Explorar una zona diferente',
        'Seguir las señales del camino',
      ];
    }

    return [
      'Observar con atención lo que apareció',
      'Buscar una pista antes de continuar',
      'Avanzar con cuidado hacia lo desconocido',
    ];
  }
}