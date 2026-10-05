import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';

void main() {
  group('NarrativaService', () {
    late NarrativaService service;

    setUp(() {
      service = NarrativaService();
    });

    test('construye contexto ordenando escenas y agregando la decisión', () {
      final escenas = [
        Escena(numero: 2, contenido: 'Segunda escena'),
        Escena(numero: 1, contenido: 'Primera escena'),
      ];

      final contexto = service.construirContexto(
        escenas: escenas,
        decision: 'Entrar al bosque',
      );

      final posicionPrimera = contexto.indexOf('Primera escena');

      final posicionSegunda = contexto.indexOf('Segunda escena');

      expect(posicionPrimera, lessThan(posicionSegunda));

      expect(contexto, contains('Decisión del estudiante: Entrar al bosque'));
    });

    test('crea escena inicial para modo dibujo', () {
      final escena = service.crearEscenaInicialDemo(nombrePersonaje: 'Lucas');

      expect(escena.numero, 1);

      expect(escena.contenido, contains('Lucas'));

      expect(escena.opciones, isNotEmpty);

      expect(escena.esFinal, isFalse);
    });

    test('construye contexto completo incluyendo decisiones anteriores', () {
      final cuento = Cuento(
        id: 'cuento-1',
        titulo: 'Prueba',
        personajePrincipal: 'Ana',
      );

      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Ana llegó al bosque.',
          opciones: const ['Seguir el camino'],
        ),
      );

      final contexto = service.construirContextoCompleto(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: 'Seguir el camino',
      );

      expect(contexto, contains('Personaje principal: Ana'));

      expect(contexto, contains('Ana llegó al bosque.'));

      expect(contexto, contains('Nueva decisión: Seguir el camino'));
    });
  });
}
