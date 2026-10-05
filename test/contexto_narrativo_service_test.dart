import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/services/contexto_narrativo_service.dart';

void main() {
  group('ContextoNarrativoService', () {
    const service = ContextoNarrativoService();

    test('construye contexto completo cuando está bajo el límite', () {
      final cuento = Cuento(
        id: 'c1',
        titulo: 'El misterio del agua',
        personajePrincipal: 'Ranj',
      );

      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Ranj descubre que no hay agua en el pozo.',
          opciones: ['Buscar en el río'],
        ),
      );

      cuento.registrarDecision(
        DecisionNarrativa(
          numeroEscena: 1,
          opcionSeleccionada: 'Buscar en el río',
        ),
      );

      final contexto = service.construirContexto(cuento, maxCaracteres: 2000);

      expect(contexto, contains('HISTORIAL NARRATIVO'));
      expect(contexto, contains('ESCENA 1:'));
      expect(contexto, contains('Ranj descubre que no hay agua'));
      expect(contexto, contains('DECISIÓN TOMADA: Buscar en el río'));
    });

    test('aplica poda inteligente reteniendo escena 1 y decisiones cuando supera maxCaracteres', () {
      final cuento = Cuento(
        id: 'c2',
        titulo: 'Aventura larga',
        personajePrincipal: 'Leo',
      );

      cuento.agregarEscena(
        Escena(
          numero: 1,
          contenido: 'Leo comienza su viaje en la colina lejana.',
        ),
      );
      cuento.registrarDecision(
        DecisionNarrativa(numeroEscena: 1, opcionSeleccionada: 'Ir al norte'),
      );

      for (var i = 2; i <= 6; i++) {
        cuento.agregarEscena(
          Escena(
            numero: i,
            contenido:
                'Escena número $i con mucho texto narrativo para sobrepasar el límite asignado para la prueba de límites.',
          ),
        );
        cuento.registrarDecision(
          DecisionNarrativa(
            numeroEscena: i,
            opcionSeleccionada: 'Decisión tomada en escena $i',
          ),
        );
      }

      final contextoPodado = service.construirContexto(
        cuento,
        maxCaracteres: 250,
      );

      expect(contextoPodado, contains('ESCENA 1 (INICIO):'));
      expect(contextoPodado, contains('Leo comienza su viaje'));
      expect(contextoPodado, contains('DECISIÓN TOMADA: Ir al norte'));
      expect(contextoPodado, contains('DECISIONES CLAVE DEL RECORRIDO:'));
      expect(contextoPodado, contains('ESCENA 6:'));
    });
  });
}
