import '../models/cuento.dart';
import '../models/decision_narrativa.dart';
import '../models/escena.dart';
import '../repositories/cuento_repository.dart';
import '../services/narrativa_service.dart';

class StoryController {
  final NarrativaService narrativaService;
  final CuentoRepository cuentoRepository;

  StoryController({
    required this.narrativaService,
    required this.cuentoRepository,
  });

  Future<Cuento> crearCuentoInicialDemo({
    required String id,
    required String nombrePersonaje,
  }) async {
    final nombre =
        nombrePersonaje.trim();

    if (nombre.isEmpty) {
      throw ArgumentError(
        'El nombre del personaje no puede estar vacío.',
      );
    }

    final cuento = Cuento(
      id: id,
      titulo:
          'La aventura de $nombre',
      personajePrincipal:
          nombre,
    );

    final escenaInicial =
        narrativaService.crearEscenaInicialDemo(
      nombrePersonaje: nombre,
    );

    cuento.agregarEscena(
      escenaInicial,
    );

    await cuentoRepository.guardarCuento(
      cuento,
    );

    return cuento;
  }

  Future<String> prepararContinuacion({
    required Cuento cuento,
    required String decision,
  }) async {
    if (decision.trim().isEmpty) {
      throw ArgumentError(
        'La decisión no puede estar vacía.',
      );
    }

    return narrativaService.construirContexto(
      escenas: cuento.escenas,
      decision: decision,
    );
  }

  Future<Escena> generarSiguienteEscena({
    required Cuento cuento,
    required Escena escenaActual,
    required String decision,
  }) async {
    final opcion =
        decision.trim();

    if (opcion.isEmpty) {
      throw ArgumentError(
        'La decisión no puede estar vacía.',
      );
    }

    if (cuento.escenas.isEmpty) {
      throw StateError(
        'El cuento todavía no tiene escenas.',
      );
    }

    final ultimaEscena =
        cuento.escenas.last;

    /*
     * Solamente la última escena generada
     * puede crear una continuación nueva.
     */
    if (ultimaEscena.numero !=
        escenaActual.numero) {
      throw StateError(
        'No se puede modificar una ruta '
        'desde una escena anterior.',
      );
    }

    if (escenaActual.esFinal) {
      throw StateError(
        'La historia ya ha finalizado.',
      );
    }

    /*
     * Evita enviar al controlador una
     * alternativa inventada o manipulada.
     */
    if (!escenaActual.opciones.contains(
      opcion,
    )) {
      throw ArgumentError(
        'La alternativa seleccionada '
        'no pertenece a la escena actual.',
      );
    }

    final decisionExistente =
        cuento.obtenerDecision(
      escenaActual.numero,
    );

    /*
     * Si ya existe una decisión y es distinta,
     * no permitimos cambiar la ruta.
     */
    if (decisionExistente != null &&
        decisionExistente.opcionSeleccionada !=
            opcion) {
      throw StateError(
        'Esta escena ya tiene una decisión.',
      );
    }

    /*
     * Si ya habíamos generado la siguiente escena,
     * la devolvemos en lugar de crear otra.
     *
     * Esto protege frente a dobles clics,
     * reintentos o respuestas duplicadas.
     */
    final escenaYaGenerada =
        cuento.obtenerEscena(
      escenaActual.numero + 1,
    );

    if (escenaYaGenerada != null) {
      return escenaYaGenerada;
    }

    /*
     * Registramos la decisión antes de llamar
     * al generador.
     *
     * Si la IA falla, podemos reintentar
     * exactamente la misma decisión.
     */
    if (decisionExistente == null) {
      cuento.registrarDecision(
        DecisionNarrativa(
          numeroEscena:
              escenaActual.numero,
          opcionSeleccionada:
              opcion,
        ),
      );

      await cuentoRepository.guardarCuento(
        cuento,
      );
    }

    final nuevaEscena =
        await narrativaService
            .generarSiguienteEscena(
      cuento: cuento,
      escenaActual: escenaActual,
      decision: opcion,
    );

    /*
     * Segunda protección frente a duplicados.
     */
    final existenteDespues =
        cuento.obtenerEscena(
      nuevaEscena.numero,
    );

    if (existenteDespues != null) {
      return existenteDespues;
    }

    cuento.agregarEscena(
      nuevaEscena,
    );

    await cuentoRepository.guardarCuento(
      cuento,
    );

    return nuevaEscena;
  }

  Future<void> agregarEscena({
    required Cuento cuento,
    required String contenido,
  }) async {
    if (contenido.trim().isEmpty) {
      throw ArgumentError(
        'El contenido de la escena '
        'no puede estar vacío.',
      );
    }

    final nuevaEscena = Escena(
      numero:
          cuento.escenas.length + 1,
      contenido: contenido,
    );

    cuento.agregarEscena(
      nuevaEscena,
    );

    await cuentoRepository.guardarCuento(
      cuento,
    );
  }
}