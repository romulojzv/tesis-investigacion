import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/services/auth_service.dart';
import 'package:tesis_investigacion/views/auth_gate.dart';
import 'package:tesis_investigacion/views/login_view.dart';
import 'package:tesis_investigacion/views/teacher_home_view.dart';

class FakeAuthService extends AuthService {
  User? fakeUser;
  Session? fakeSession;
  UserProfile? fakeProfile;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  bool logoutCalled = false;

  FakeAuthService({this.fakeUser, this.fakeSession, this.fakeProfile});

  @override
  User? get currentUser => fakeUser;

  @override
  Session? get currentSession => fakeSession;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile?> obtenerPerfilActual() async {
    return fakeProfile;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    fakeUser = null;
    fakeSession = null;
    fakeProfile = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('AuthGate Widget Tests', () {
    testWidgets('Sin sesión activa renderiza LoginView', (tester) async {
      final fakeAuth = FakeAuthService(fakeSession: null);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: fakeAuth,
            studentBuilder: (context, perfil) => const Text('STUDENT_VIEW'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('✨ Cuentos Mágicos ✨'), findsOneWidget);
      expect(find.text('🎒 Soy estudiante'), findsOneWidget);
      expect(find.text('👨‍🏫 Soy docente'), findsOneWidget);
      expect(find.text('STUDENT_VIEW'), findsNothing);
    });

    testWidgets(
      'LoginView normaliza código de acceso a MAYÚSCULAS en tiempo real mientras se escribe',
      (tester) async {
        final fakeAuth = FakeAuthService(fakeSession: null);

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              authService: fakeAuth,
              studentBuilder: (context, perfil) => const Text('STUDENT_VIEW'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final codigoInput = find.widgetWithText(TextField, '');
        // El primer TextField del formulario de estudiante es el código de acceso
        await tester.enterText(codigoInput.first, '4a26-001');
        await tester.pump();

        expect(find.text('4A26-001'), findsOneWidget);
      },
    );

    testWidgets('Con sesión estudiante renderiza flujo de estudiante', (
      tester,
    ) async {
      final fakeAuth = FakeAuthService(
        fakeSession: Session(
          accessToken: 'fake_jwt',
          tokenType: 'bearer',
          user: const User(
            id: 'est-123',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-06T00:00:00Z',
          ),
        ),
        fakeProfile: const UserProfile(
          id: 'est-123',
          nombre: 'María Estudiante',
          rol: UserRole.estudiante,
          codigoAcceso: '4A26-001',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: fakeAuth,
            studentBuilder: (context, perfil) {
              return Scaffold(
                body: Text('HOLA_${perfil.nombre}_ROL_${perfil.rol.valor}'),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('HOLA_María Estudiante_ROL_estudiante'), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);
      expect(find.byType(TeacherHomeView), findsNothing);
    });

    testWidgets('Con sesión docente renderiza TeacherHomeView', (tester) async {
      final fakeAuth = FakeAuthService(
        fakeSession: Session(
          accessToken: 'fake_jwt_docente',
          tokenType: 'bearer',
          user: const User(
            id: 'doc-999',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-06T00:00:00Z',
          ),
        ),
        fakeProfile: const UserProfile(
          id: 'doc-999',
          nombre: 'Profesor Carlos',
          rol: UserRole.docente,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: fakeAuth,
            studentBuilder: (context, perfil) => const Text('STUDENT_VIEW'),
          ),
        ),
      );

      // Primer pump para cargar perfil
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Panel Docente 🎓'), findsOneWidget);
      expect(find.text('Profesor Carlos'), findsOneWidget);
      expect(find.text('STUDENT_VIEW'), findsNothing);
    });

    testWidgets('Sesión activa sin perfil en profiles cierra sesión y avisa', (
      tester,
    ) async {
      final fakeAuth = FakeAuthService(
        fakeSession: Session(
          accessToken: 'fake_jwt_huerfano',
          tokenType: 'bearer',
          user: const User(
            id: 'huerfano-000',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-06T00:00:00Z',
          ),
        ),
        fakeProfile: null, // No existe en profiles
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: fakeAuth,
            studentBuilder: (context, perfil) => const Text('STUDENT_VIEW'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fakeAuth.logoutCalled, isTrue);
      expect(find.byType(LoginView), findsOneWidget);
      expect(
        find.text('La sesión no cuenta con un perfil educativo registrado.'),
        findsOneWidget,
      );
    });
  });
}
