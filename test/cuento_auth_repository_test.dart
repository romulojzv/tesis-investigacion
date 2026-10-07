import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';

void main() {
  group('Cuento y Repositorio con Autenticación', () {
    test('Cuento nuevo soporta estudianteId, aulaId y esDemo', () {
      final cuento = Cuento(
        id: 'c-test-01',
        titulo: 'El viaje estelar',
        personajePrincipal: 'Mateo',
        estudianteId: 'est-uuid-111',
        aulaId: 'aula-uuid-222',
        esDemo: false,
      );

      expect(cuento.id, equals('c-test-01'));
      expect(cuento.estudianteId, equals('est-uuid-111'));
      expect(cuento.aulaId, equals('aula-uuid-222'));
      expect(cuento.esDemo, isFalse);
    });

    test('Cuento por defecto mantiene compatibilidad histórica (esDemo=false, ids null)', () {
      final cuento = Cuento(
        id: 'c-demo-legacy',
        titulo: 'Cuento Antiguo',
        personajePrincipal: 'Pepe',
      );

      expect(cuento.estudianteId, isNull);
      expect(cuento.aulaId, isNull);
      expect(cuento.esDemo, isFalse);
    });

    test('listarCuentosPorEstudiante solo retorna cuentos del alumno y excluye demos', () async {
      final repo = CuentoRepositoryMemoria();

      // Cuento alumno A
      final cuentoA1 = Cuento(
        id: 'c-a-1',
        titulo: 'Aventura de A 1',
        personajePrincipal: 'Robot',
        estudianteId: 'alumno-A',
        esDemo: false,
      );

      // Cuento alumno A (demo antiguo)
      final cuentoADemo = Cuento(
        id: 'c-a-demo',
        titulo: 'Demo de A',
        personajePrincipal: 'Gatito',
        estudianteId: 'alumno-A',
        esDemo: true, // No debe aparecer
      );

      // Cuento alumno B
      final cuentoB1 = Cuento(
        id: 'c-b-1',
        titulo: 'Aventura de B',
        personajePrincipal: 'Dragón',
        estudianteId: 'alumno-B',
        esDemo: false,
      );

      // Cuento sin autor (demo histórico global)
      final cuentoGlobalDemo = Cuento(
        id: 'c-global-demo',
        titulo: 'Demo Antiguo Global',
        personajePrincipal: 'Caballero',
        estudianteId: null,
        esDemo: true,
      );

      await repo.guardarCuento(cuentoA1);
      await repo.guardarCuento(cuentoADemo);
      await repo.guardarCuento(cuentoB1);
      await repo.guardarCuento(cuentoGlobalDemo);

      // Consulta de Alumno A
      final misAventurasA = await repo.listarCuentosPorEstudiante('alumno-A');
      expect(misAventurasA.length, equals(1));
      expect(misAventurasA.first.id, equals('c-a-1'));
      expect(misAventurasA.first.titulo, equals('Aventura de A 1'));

      // Consulta de Alumno B
      final misAventurasB = await repo.listarCuentosPorEstudiante('alumno-B');
      expect(misAventurasB.length, equals(1));
      expect(misAventurasB.first.id, equals('c-b-1'));
      expect(misAventurasB.first.titulo, equals('Aventura de B'));

      // Consulta de Alumno C (sin cuentos)
      final misAventurasC = await repo.listarCuentosPorEstudiante('alumno-C');
      expect(misAventurasC, isEmpty);
    });
  });
}
