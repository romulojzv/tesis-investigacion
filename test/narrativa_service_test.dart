import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';

void main() {
  group('NarrativaService', () {
    test('construye el contexto respetando el orden de las escenas', () {
      final service = NarrativaService();

      final escenas = [
        Escena(
          numero: 2,
          contenido: 'El personaje encuentra una puerta misteriosa.',
        ),
        Escena(
          numero: 1,
          contenido: 'El personaje inicia su aventura en el bosque.',
        ),
      ];

      const decision = 'Abrir la puerta misteriosa';

      final resultado = service.construirContexto(
        escenas: escenas,
        decision: decision,
      );

      expect(
        resultado.indexOf('Escena 1'),
        lessThan(resultado.indexOf('Escena 2')),
      );

      expect(
        resultado,
        contains('Decisión del estudiante: Abrir la puerta misteriosa'),
      );
    });
  });
}