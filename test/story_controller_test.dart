import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';

void main() {
  group('StoryController', () {
    test('agrega una escena y guarda el cuento', () async {
      final repository = CuentoRepositoryMemoria();

      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
      );

      final cuento = Cuento(
        id: 'cuento-001',
        titulo: 'La aventura del bosque',
        personajePrincipal: 'Lucas',
      );

      await controller.agregarEscena(
        cuento: cuento,
        contenido: 'Lucas ingresó al bosque mágico.',
      );

      expect(cuento.escenas.length, 1);
      expect(cuento.escenas.first.numero, 1);

      final cuentoGuardado =
          await repository.obtenerCuento('cuento-001');

      expect(cuentoGuardado, isNotNull);
      expect(cuentoGuardado!.escenas.length, 1);
    });

    test('construye el contexto con una decisión narrativa', () async {
      final repository = CuentoRepositoryMemoria();

      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
      );

      final cuento = Cuento(
        id: 'cuento-002',
        titulo: 'La puerta misteriosa',
        personajePrincipal: 'Ana',
      );

      await controller.agregarEscena(
        cuento: cuento,
        contenido: 'Ana encontró una puerta en medio del bosque.',
      );

      final contexto = await controller.prepararContinuacion(
        cuento: cuento,
        decision: 'Abrir la puerta',
      );

      expect(
        contexto,
        contains('Decisión del estudiante: Abrir la puerta'),
      );

      expect(
        contexto,
        contains('Ana encontró una puerta'),
      );
    });
  });
}