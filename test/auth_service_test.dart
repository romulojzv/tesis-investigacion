import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/services/auth_service.dart';

void main() {
  group('AuthService y UserProfile Tests', () {
    test('normalización de código de acceso de estudiante', () {
      expect(
        AuthService.normalizarCodigoAcceso(' 4a26-001 '),
        equals('4A26-001'),
      );
      expect(
        AuthService.normalizarCodigoAcceso('5b26-042\n'),
        equals('5B26-042'),
      );
    });

    test('construcción determinista de correo sintético interno', () {
      final email1 = AuthService.construirEmailSintetico('4A26-001');
      expect(email1, equals('4a26-001@estudiantes.cuentosmagicos.internal'));

      final email2 = AuthService.construirEmailSintetico('  3c26-015  ');
      expect(email2, equals('3c26-015@estudiantes.cuentosmagicos.internal'));
    });

    test('parsing estricto de roles en UserRole', () {
      expect(UserRole.fromString('docente'), equals(UserRole.docente));
      expect(UserRole.fromString('DOCENTE'), equals(UserRole.docente));
      expect(UserRole.fromString('estudiante'), equals(UserRole.estudiante));
      expect(UserRole.fromString('Estudiante '), equals(UserRole.estudiante));

      expect(
        () => UserRole.fromString('administrador'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => UserRole.fromString('hacker'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('UserProfile fromMap y toMap convierten correctamente', () {
      final mapDocente = {
        'id': 'usr-doc-123',
        'nombre': 'Prof. Carlos',
        'rol': 'docente',
        'codigo_acceso': null,
        'created_at': '2026-10-06T00:00:00.000Z',
      };

      final profileDocente = UserProfile.fromMap(mapDocente);
      expect(profileDocente.id, equals('usr-doc-123'));
      expect(profileDocente.nombre, equals('Prof. Carlos'));
      expect(profileDocente.rol, equals(UserRole.docente));
      expect(profileDocente.codigoAcceso, isNull);

      final mapEstudiante = {
        'id': 'usr-est-456',
        'nombre': 'Pedro',
        'rol': 'estudiante',
        'codigo_acceso': '4A26-001',
        'created_at': '2026-10-06T00:00:00.000Z',
      };

      final profileEstudiante = UserProfile.fromMap(mapEstudiante);
      expect(profileEstudiante.id, equals('usr-est-456'));
      expect(profileEstudiante.nombre, equals('Pedro'));
      expect(profileEstudiante.rol, equals(UserRole.estudiante));
      expect(profileEstudiante.codigoAcceso, equals('4A26-001'));
      expect(profileEstudiante.toMap()['rol'], equals('estudiante'));
    });
  });
}
