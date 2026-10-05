import '../models/cuento.dart';
import '../models/escena.dart';
import '../models/pdf_story_data.dart';

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
        'Escena ${escena.numero}: '
        '${escena.contenido}',
      );
    }

    buffer.writeln('Decisión del estudiante: $decision');

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

      buffer.writeln('Decisiones tomadas por el estudiante:');

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

    buffer.writeln('Nueva decisión: $decision');

    buffer.writeln();

    buffer.writeln(
      'La continuación debe mantener coherencia '
      'con las escenas y decisiones anteriores.',
    );

    return buffer.toString();
  }

  // =========================================================
  // ESCENA INICIAL DESDE DIBUJO
  // =========================================================

  Escena crearEscenaInicialDemo({required String nombrePersonaje}) {
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

  // =========================================================
  // ESCENA INICIAL DESDE PDF REAL
  // =========================================================

  Escena crearEscenaInicialDesdePdfDemo({
    required String nombrePersonaje,
    required PdfStoryData datosPdf,
  }) {
    final titulo = datosPdf.tituloDetectado ?? datosPdf.nombreArchivo;
    final tieneAnalisis =
        datosPdf.resumen != null && datosPdf.resumen!.trim().isNotEmpty;

    if (tieneAnalisis) {
      final escenario =
          (datosPdf.escenario != null && datosPdf.escenario!.trim().isNotEmpty)
          ? datosPdf.escenario!.trim()
          : 'un lugar lleno de sorpresas';
      final conflicto =
          (datosPdf.conflictoPrincipal != null &&
              datosPdf.conflictoPrincipal!.trim().isNotEmpty)
          ? datosPdf.conflictoPrincipal!.trim()
          : 'un gran enigma por resolver';

      final contenido =
          '$nombrePersonaje comienza su aventura en "$titulo".\n\n'
          'La historia se sitúa en $escenario. Todo parece tranquilo hasta que se presenta '
          'una situación importante: $conflicto. $nombrePersonaje sabe que debe actuar con '
          'valentía e ingenio para descubrir qué está sucediendo.';

      return Escena(
        numero: 1,
        contenido: contenido,
        opciones: [
          'Avanzar por la ruta principal para investigar el problema',
          'Explorar un camino alternativo en busca de pistas',
          'Observar los alrededores y consultar con los presentes',
        ],
      );
    }

    final fragmentoLimpio = _obtenerFragmentoInicialLimpio(
      datosPdf.textoExtraido,
      limite: 450,
    );

    return Escena(
      numero: 1,
      contenido:
          '$nombrePersonaje comienza su aventura dentro de la historia "$titulo".\n\n'
          '$fragmentoLimpio',
      opciones: [
        'Avanzar por el camino principal',
        'Explorar una ruta diferente',
        'Investigar con cuidado antes de decidir',
      ],
    );
  }

  String _obtenerFragmentoInicialLimpio(String texto, {required int limite}) {
    // Filtrar metadatos editoriales comunes, páginas, ISBNs, etc.
    var limpio = texto
        .replaceAll(RegExp(r'page\s+\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'p[aá]gina\s+\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'isbn[\s:\d-]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'cc-by[\s\d.-]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'pratham\s+books', caseSensitive: false), '')
        .replaceAll(RegExp(r'storyweaver', caseSensitive: false), '')
        .trim();

    if (limpio.length <= limite) {
      return limpio;
    }

    final fragmento = limpio.substring(0, limite);
    final ultimoPunto = fragmento.lastIndexOf('.');

    if (ultimoPunto > 100) {
      return fragmento.substring(0, ultimoPunto + 1);
    }

    final ultimoEspacio = fragmento.lastIndexOf(' ');
    if (ultimoEspacio <= 0) {
      return '$fragmento...';
    }

    return '${fragmento.substring(0, ultimoEspacio)}...';
  }

  // =========================================================
  // GENERACIÓN DE CONTINUACIONES
  // =========================================================

  Future<Escena> generarSiguienteEscena({
    required Cuento cuento,
    required Escena escenaActual,
    required String decision,
  }) async {
    construirContextoCompleto(
      cuento: cuento,
      escenaActual: escenaActual,
      decision: decision,
    );

    await Future.delayed(const Duration(milliseconds: 1200));

    final siguienteNumero = escenaActual.numero + 1;

    final esFinal = siguienteNumero >= 4;

    final contenido = _generarContenidoDemo(
      nombrePersonaje: cuento.personajePrincipal,
      decision: decision,
      numeroEscena: siguienteNumero,
    );

    final opciones = esFinal
        ? <String>[]
        : _generarOpcionesContextualesDemo(decisionAnterior: decision);

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
    required String decisionAnterior,
  }) {
    final decision = decisionAnterior.toLowerCase();

    if (decision.contains('original')) {
      return [
        'Continuar con lo que sucede en la historia',
        'Seguir al personaje principal',
        'Descubrir qué ocurre después',
      ];
    }

    if (decision.contains('diferente') || decision.contains('ruta')) {
      return [
        'Tomar un camino que no aparece en el cuento',
        'Buscar una solución diferente',
        'Cambiar una decisión importante',
      ];
    }

    if (decision.contains('observar')) {
      return [
        'Buscar pistas en la escena',
        'Observar a los personajes',
        'Investigar antes de continuar',
      ];
    }

    return [
      'Seguir avanzando con cuidado',
      'Buscar una pista',
      'Explorar otra posibilidad',
    ];
  }
}
