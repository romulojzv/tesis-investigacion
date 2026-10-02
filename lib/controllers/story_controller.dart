import '../models/cuento.dart';
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

  Future<String> prepararContinuacion({
    required Cuento cuento,
    required String decision,
  }) async {
    if (decision.trim().isEmpty) {
      throw ArgumentError('La decisión no puede estar vacía.');
    }

    return narrativaService.construirContexto(
      escenas: cuento.escenas,
      decision: decision,
    );
  }

  Future<void> agregarEscena({
    required Cuento cuento,
    required String contenido,
  }) async {
    if (contenido.trim().isEmpty) {
      throw ArgumentError('El contenido de la escena no puede estar vacío.');
    }

    final nuevaEscena = Escena(
      numero: cuento.escenas.length + 1,
      contenido: contenido,
    );

    cuento.agregarEscena(nuevaEscena);

    await cuentoRepository.guardarCuento(cuento);
  }
}