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
  // =========================================================
  // ESCENA INICIAL DESDE DIBUJO / CONTEXTO VARIABLE
  // =========================================================

  Escena crearEscenaInicialDemo({
    required String nombrePersonaje,
    String? descripcionPersonaje,
    String? contextoInicial,
  }) {
    final nombre = nombrePersonaje.trim();
    final textoBusqueda =
        '${nombre.toLowerCase()} ${(descripcionPersonaje ?? '').toLowerCase()} ${(contextoInicial ?? '').toLowerCase()}';

    // Determinar índice determinista basado en caracteres para variar el inicio
    final seed = nombre.codeUnits.fold<int>(0, (prev, elem) => prev + elem);

    // 1. Ave / Granja / Pollito
    if (_contieneAlguna(textoBusqueda, const [
      'pollito',
      'pollo',
      'ave',
      'pájaro',
      'pajaro',
      'gallina',
      'gallo',
      'pato',
      'cisne',
      'loro',
      'canario',
      'plumas',
      'pico',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre estaba dando saltitos curiosos por la granja cuando vio unas semillas brillantes que formaban un sendero dorado hacia el huerto secreto.',
          opciones: const [
            'Seguir el sendero de semillas brillantes',
            'Aletear con fuerza hacia la cerca del huerto',
            'Preguntar a los otros animales si conocen el sendero',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre picoteaba una hoja llena de rocío en el jardín y de pronto encontró una pequeña puerta de madera entre las raíces de un gran árbol.',
          opciones: const [
            'Tocar suavemente la puertecita con el pico',
            'Mirar por la rendija a ver qué brilla dentro',
            'Cantar una melodía alegre para ver si alguien responde',
          ],
        );
      }
    }

    // 2. Caballero / Castillo / Pirata / Aventura medieval
    if (_contieneAlguna(textoBusqueda, const [
      'caballero',
      'armadura',
      'espada',
      'escudo',
      'castillo',
      'pirata',
      'sable',
      'tesoro',
      'guerrero',
      'aldea',
      'torneo',
      'reino',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre llegó con paso decidido frente al puente de piedra de un antiguo castillo, donde un estandarte de colores ondeaba con el viento anunciando una misión especial.',
          opciones: const [
            'Avanzar por el puente levadizo para hablar con el guardia',
            'Examinar el escudo grabado en la torre de entrada',
            'Buscar un camino bordeando el foso del castillo',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre desdobló con cuidado un mapa antiguo encontrado en un baúl, cuyas marcas señalaban la entrada a la legendaria colina del dragón sabio.',
          opciones: const [
            'Seguir la flecha dibujada hacia la colina',
            'Buscar pistas alrededor para confirmar el rumbo',
            'Subir a una roca alta para observar el horizonte',
          ],
        );
      }
    }

    // 3. Robot / Tecnología / Androide
    if (_contieneAlguna(textoBusqueda, const [
      'robot',
      'androide',
      'máquina',
      'maquina',
      'engranaje',
      'tuerca',
      'taller',
      'laboratorio',
      'circuito',
      'antena',
      'nave',
      'tecnología',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre encendió sus luces de exploración en el taller de inventos al detectar una suave señal de música que provenía de una caja metálica entre los estantes.',
          opciones: const [
            'Acercarse con cuidado para abrir la caja metálica',
            'Conectar su sensor para analizar la señal musical',
            'Pedirle al pequeño dron ayudante que inspeccione primero',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre caminaba por las calles luminosas de la ciudad futura cuando una chispa azul amistosa bajó zumbando y se posó sobre su antena.',
          opciones: const [
            'Seguir la chispa azul mientras vuela hacia un callejón misterioso',
            'Guardar la energía de la chispa en su batería de repuesto',
            'Consultar en el panel de información qué significa esa luz',
          ],
        );
      }
    }

    // 4. Vehículo / Coche / Transporte
    if (_contieneAlguna(textoBusqueda, const [
      'coche',
      'auto',
      'carro',
      'vehículo',
      'vehiculo',
      'tren',
      'cohete',
      'avión',
      'avion',
      'camión',
      'camion',
      'ruedas',
      'motor',
      'pista',
      'carretera',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre hizo sonar su bocina alegre mientras recorría la pista soleada y llegó a una curva donde aparecían tres caminos con carteles misteriosos.',
          opciones: const [
            'Tomar la pista rápida que sube por la colina',
            'Acelerar por el camino decorado con flores de colores',
            'Frenar un momento para leer bien los carteles',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre puso en marcha sus motores tras una revisión completa, listo para rodar por un valle lleno de sorpresas y rutas por descubrir.',
          opciones: const [
            'Cruzar el gran puente que lleva al valle desconocido',
            'Explorar la ruta junto al río cristalino',
            'Hacer sonar los motores para avisar a sus amigos que el viaje comienza',
          ],
        );
      }
    }

    // 5. Dragón / Criatura fantástica / Monstruo amigable
    if (_contieneAlguna(textoBusqueda, const [
      'dragón',
      'dragon',
      'monstruo',
      'dinosaurio',
      'duende',
      'hada',
      'mágico',
      'magico',
      'fantasía',
      'fantasia',
      'alas',
      'fuego',
      'cueva',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre asomó su cabeza desde una acogedora cueva de musgo y vio flotando en el aire una estela de chispas de colores que parecía invitarlo a jugar.',
          opciones: const [
            'Seguir la estela de chispas hacia el claro del bosque',
            'Extender sus alas con curiosidad para tocar una chispa',
            'Saludar con un rugido amistoso a ver quién responde',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre descubrió entre los árboles gigantes un arroyo que brillaba con agua violeta y hacía sonar campanitas cada vez que una hoja caía.',
          opciones: const [
            'Beber un sorbito del agua violeta',
            'Seguir la corriente del arroyo hacia la cascada cantarina',
            'Lanzar una hoja suave para ver hacia dónde flota',
          ],
        );
      }
    }

    // 6. Criatura marina / Acuática
    if (_contieneAlguna(textoBusqueda, const [
      'pez',
      'pescado',
      'sirena',
      'pulpo',
      'ballena',
      'delfín',
      'delfin',
      'tiburón',
      'tiburon',
      'mar',
      'océano',
      'oceano',
      'arrecife',
      'agua',
      'coral',
    ])) {
      return Escena(
        numero: 1,
        contenido:
            '$nombre nadaba alegremente entre corales de colores cuando una gran concha marina se abrió despacio dejando ver una perla luminosa.',
        opciones: const [
          'Nadar cerca de la concha para mirar la perla',
          'Llamar a un grupo de peces amigos para compartir el hallazgo',
          'Explorar la cueva submarina que se abre detrás del coral',
        ],
      );
    }

    // 7. Mamífero / Mascota / Animal amigable
    if (_contieneAlguna(textoBusqueda, const [
      'perro',
      'perrito',
      'gato',
      'gatito',
      'oso',
      'osito',
      'conejo',
      'conejito',
      'león',
      'leon',
      'tigre',
      'zorro',
      'lobo',
      'ardilla',
      'mono',
    ])) {
      if (seed % 2 == 0) {
        return Escena(
          numero: 1,
          contenido:
              '$nombre corría alegremente por una pradera verde cuando vio una mariposa con alas transparentes que dejaba un caminito de polvo brillante al volar.',
          opciones: const [
            'Seguir a la mariposa dando saltos entre las flores',
            'Sentarse a observar hacia qué árbol se dirige',
            'Buscar en su mochila algo para compartir en el camino',
          ],
        );
      } else {
        return Escena(
          numero: 1,
          contenido:
              '$nombre exploraba un sendero tranquilo bordeado de pinos cuando escuchó el suave tintineo de una campanita escondida entre unos arbustos de moras.',
          opciones: const [
            'Asomarse con cuidado entre los arbustos para ver la campanita',
            'Caminar despacio alrededor del pino más cercano',
            'Llamar con voz amigable para ver si alguien necesita ayuda',
          ],
        );
      }
    }

    // 8. General / Personaje infantil / Explorador (4 variantes según seed)
    final variante = seed % 4;
    switch (variante) {
      case 0:
        return Escena(
          numero: 1,
          contenido:
              '$nombre subió a lo alto de una colina verde con su mochila al hombro y descubrió a lo lejos una torre rodeada de árboles con hojas doradas.',
          opciones: const [
            'Bajar con paso firme hacia el bosque de hojas doradas',
            'Sacar su mapa para ubicar la torre misteriosa',
            'Buscar un mirador seguro para observar con más detalle',
          ],
        );
      case 1:
        return Escena(
          numero: 1,
          contenido:
              '$nombre caminaba por la plaza de una aldea tranquila cuando una paloma mensajera dejó caer una cinta brillante con un sobre misterioso a sus pies.',
          opciones: const [
            'Abrir con cuidado el sobre para leer el mensaje',
            'Mirar hacia el campanario para ver de dónde vino la paloma',
            'Preguntar a los vecinos si saben a quién pertenece la cinta',
          ],
        );
      case 2:
        return Escena(
          numero: 1,
          contenido:
              '$nombre exploraba una sala llena de estanterías de madera y al tocar un lomo dorado, un libro ilustrado se abrió solo iluminando la mesa.',
          opciones: const [
            'Leer la primera página del libro ilustrado',
            'Pasar con cuidado la página para ver los mapas dibujados',
            'Tocar el relieve dorado de la portada para ver qué ocurre',
          ],
        );
      default:
        return Escena(
          numero: 1,
          contenido:
              '$nombre llegó a la orilla de un río cristalino donde un puente colgante de madera invitaba a cruzar hacia un valle lleno de misterios por resolver.',
          opciones: const [
            'Cruzar con calma el puente agarrándose bien de las cuerdas',
            'Lanzar una piedrita al río para comprobar la corriente',
            'Explorar la orilla en busca de una balsa o un camino alternativo',
          ],
        );
    }
  }

  static bool _contieneAlguna(String texto, List<String> palabras) {
    for (final p in palabras) {
      if (texto.contains(p)) return true;
    }
    return false;
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
