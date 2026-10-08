import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/main.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/auth_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';
import 'package:tesis_investigacion/views/document_view.dart';
import 'package:tesis_investigacion/views/draw_view.dart';
import 'package:tesis_investigacion/views/login_view.dart';
import 'package:tesis_investigacion/views/story_view.dart';
import 'package:tesis_investigacion/views/student_home_view.dart';

class FakeStartupAuthService extends AuthService {
  User? fakeUser;
  Session? fakeSession;
  UserProfile? fakeProfile;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  bool logoutCalled = false;
  bool localSignOutCalled = false;

  FakeStartupAuthService({this.fakeUser, this.fakeSession, this.fakeProfile});

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

  @override
  Future<void> limpiarSesionLocalAlInicio() async {
    localSignOutCalled = true;
    fakeUser = null;
    fakeSession = null;
    fakeProfile = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<UserProfile> loginEstudiante({
    required String codigoAcceso,
    required String pin,
  }) async {
    final perfil = UserProfile(
      id: 'est-001',
      nombre: 'Estudiante C',
      rol: UserRole.estudiante,
      codigoAcceso: codigoAcceso.trim().toUpperCase(),
    );
    fakeUser = const User(
      id: 'est-001',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-08T00:00:00Z',
    );
    fakeSession = Session(
      accessToken: 'fake_jwt_estudiante',
      tokenType: 'bearer',
      user: fakeUser!,
    );
    fakeProfile = perfil;
    _controller.add(AuthState(AuthChangeEvent.signedIn, fakeSession));
    return perfil;
  }

  void dispose() {
    _controller.close();
  }
}

class CountingImageService implements ImageService {
  int llamadas = 0;
  final int errorStatus;

  CountingImageService({required this.errorStatus});

  @override
  Future<String> generarIlustracionEscena(
    SolicitudImagenEscena solicitud,
  ) async {
    llamadas++;
    throw ImageAuthException(
      statusCode: errorStatus,
      message: errorStatus == 401
          ? 'Sesión no válida o expirada. Por favor inicie sesión nuevamente.'
          : 'Acceso denegado. Función reservada para estudiantes.',
    );
  }
}

class DummyAiService implements AiService {
  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async => StoryAnalysis(
    titulo: 'Cuento Test',
    personajePrincipal: 'Lucas',
    descripcionPersonaje: '',
    resumen: '',
    escenario: '',
    conflictoPrincipal: '',
    finalOriginal: '',
  );

  @override
  Future<GeneratedScene> generarEscenaInicial({
    required String titulo,
    required String personajePrincipal,
    String? personajeOriginal,
    bool esPersonajeNuevo = false,
    required String textoFuente,
    required String resumenOriginal,
    required String escenarioOriginal,
    required String conflictoPrincipal,
    required String finalOriginal,
    String? descripcionPersonaje,
  }) async => GeneratedScene(
    contenido: 'Inicio de la aventura',
    opciones: const ['Opción 1'],
    esFinal: false,
  );

  @override
  Future<GeneratedScene> generarEscena({
    required String titulo,
    required String personajePrincipal,
    String? personajeOriginal,
    bool esPersonajeNuevo = false,
    String? descripcionPersonaje,
    required String textoFuente,
    required String resumenOriginal,
    required String escenarioOriginal,
    required String conflictoPrincipal,
    required String finalOriginal,
    required String contextoNarrativo,
    required String decisionActual,
    required int numeroEscena,
    bool esUltimaEscena = false,
  }) async => GeneratedScene(
    contenido: 'Escena $numeroEscena',
    opciones: esUltimaEscena ? const [] : const ['Opción 1'],
    esFinal: esUltimaEscena,
  );
}

void main() {
  group('F. Tests de Regresión Auth (AUTH-START-01 a AUTH-START-07)', () {
    testWidgets(
      'AUTH-START-01: Existe sesión restaurada al iniciar + FORCE_LOGIN_ON_START=true '
      '-> se ejecuta signOut local -> LoginView aparece -> StudentHomeView NO aparece',
      (tester) async {
        // Simulamos sesión persistida del último estudiante antes de abrir la app
        final fakeAuth = FakeStartupAuthService(
          fakeSession: Session(
            accessToken: 'persisted_jwt_estudiante_c',
            tokenType: 'bearer',
            user: const User(
              id: 'est-001',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-08T00:00:00Z',
            ),
          ),
          fakeProfile: const UserProfile(
            id: 'est-001',
            nombre: 'Estudiante C',
            rol: UserRole.estudiante,
            codigoAcceso: '4A26-003',
          ),
        );

        // Al arrancar con FORCE_LOGIN_ON_START=true se invoca la limpieza inicial
        await fakeAuth.limpiarSesionLocalAlInicio();
        expect(fakeAuth.localSignOutCalled, isTrue);
        expect(fakeAuth.currentSession, isNull);

        // Se construye la aplicación
        await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
        await tester.pumpAndSettle();

        // LoginView DEBE aparecer obligatoriamente; StudentHomeView NO debe aparecer
        expect(find.byType(LoginView), findsOneWidget);
        expect(find.byType(StudentHomeView), findsNothing);
        expect(find.text('🎒 Soy estudiante'), findsOneWidget);
        expect(find.textContaining('4A26-003'), findsNothing);
      },
    );

    testWidgets(
      'AUTH-START-02: Después del signOut inicial: currentSession == null '
      '-> ningún profile anterior puede abrir StudentHomeView',
      (tester) async {
        // Aunque exista un profile viejo cacheado o residual en memoria, si currentSession es null:
        final fakeAuth = FakeStartupAuthService(
          fakeSession: null,
          fakeProfile: const UserProfile(
            id: 'est-001',
            nombre: 'Estudiante C',
            rol: UserRole.estudiante,
            codigoAcceso: '4A26-003',
          ),
        );

        expect(fakeAuth.currentSession, isNull);

        await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
        await tester.pumpAndSettle();

        // La interfaz NUNCA debe abrir StudentHomeView con el profile viejo
        expect(find.byType(StudentHomeView), findsNothing);
        expect(find.byType(LoginView), findsOneWidget);
        expect(find.textContaining('¡Hola, Estudiante C!'), findsNothing);
      },
    );

    testWidgets('AUTH-START-03: Login válido después del arranque -> signedIn '
        '-> carga profile nuevo -> StudentHomeView aparece', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeStartupAuthService(
        fakeSession: null,
        fakeProfile: null,
      );

      await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);

      // Ingresar credenciales del estudiante
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '4A26-003');
      await tester.enterText(textFields.at(1), '123456');
      await tester.pump();

      final botonIngresar = find.widgetWithText(
        ElevatedButton,
        '🚀 ¡Entrar a mi aventura!',
      );
      await tester.tap(botonIngresar);
      await tester.pumpAndSettle();

      // Debe transicionar correctamente a StudentHomeView con la nueva sesión activa
      expect(find.byType(StudentHomeView), findsOneWidget);
      expect(find.textContaining('Estudiante C'), findsOneWidget);
      expect(find.textContaining('4A26-003'), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);
      expect(fakeAuth.currentSession, isNotNull);
    });

    testWidgets(
      'AUTH-START-04: Cerrar y volver a iniciar aplicación -> vuelve a LoginView',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeAuth = FakeStartupAuthService(
          fakeSession: null,
          fakeProfile: null,
        );

        // 1. Primera ejecución: Login inicial
        await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), '4A26-003');
        await tester.enterText(textFields.at(1), '123456');
        await tester.pump();

        final botonIngresar = find.widgetWithText(
          ElevatedButton,
          '🚀 ¡Entrar a mi aventura!',
        );
        await tester.tap(botonIngresar);
        await tester.pumpAndSettle();

        expect(find.byType(StudentHomeView), findsOneWidget);

        // 2. Cerrar la app y simular nuevo inicio con FORCE_LOGIN_ON_START=true
        await fakeAuth.limpiarSesionLocalAlInicio();
        expect(fakeAuth.currentSession, isNull);

        // 3. Reabrir aplicación
        await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
        await tester.pumpAndSettle();

        // Debe volver a LoginView sin saltar a StudentHomeView
        expect(find.byType(LoginView), findsOneWidget);
        expect(find.byType(StudentHomeView), findsNothing);
      },
    );

    testWidgets(
      'AUTH-START-05: Navegación interna durante sesión activa -> NO cierra sesión',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeAuth = FakeStartupAuthService(
          fakeSession: null,
          fakeProfile: null,
        );

        await tester.pumpWidget(CuentosMagicosApp(authService: fakeAuth));
        await tester.pumpAndSettle();

        // Login inicial
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), '4A26-003');
        await tester.enterText(textFields.at(1), '123456');
        await tester.pump();

        final botonIngresar = find.widgetWithText(
          ElevatedButton,
          '🚀 ¡Entrar a mi aventura!',
        );
        await tester.tap(botonIngresar);
        await tester.pumpAndSettle();

        expect(find.byType(StudentHomeView), findsOneWidget);

        // Navegar a Dibujar
        final botonDibujo = find.text('Dibujar');
        await tester.tap(botonDibujo);
        await tester.pumpAndSettle();

        expect(find.byType(DrawView), findsOneWidget);
        expect(fakeAuth.currentSession, isNotNull);
        expect(fakeAuth.logoutCalled, isFalse);

        // Volver atrás desde Dibujar
        final botonVolverDibujo = find.byIcon(Icons.arrow_back_rounded);
        if (botonVolverDibujo.evaluate().isNotEmpty) {
          await tester.tap(botonVolverDibujo.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(StudentHomeView), findsOneWidget);
        expect(fakeAuth.currentSession, isNotNull);

        // Navegar a Usar un PDF
        final botonPdf = find.text('Usar un PDF');
        await tester.tap(botonPdf);
        await tester.pumpAndSettle();

        expect(find.byType(DocumentView), findsOneWidget);
        expect(fakeAuth.currentSession, isNotNull);
        expect(fakeAuth.logoutCalled, isFalse);

        // Volver atrás desde PDF
        final botonVolverPdf = find.byIcon(Icons.arrow_back_rounded);
        if (botonVolverPdf.evaluate().isNotEmpty) {
          await tester.tap(botonVolverPdf.first);
          await tester.pumpAndSettle();
        }

        expect(find.byType(StudentHomeView), findsOneWidget);
        expect(fakeAuth.currentSession, isNotNull);
      },
    );

    test('AUTH-START-06: 401 de generar-imagen '
        '-> propagar ImageAuthException y no ejecutar retries automáticos adicionales', () async {
      final mockImage = CountingImageService(errorStatus: 401);
      final repo = CuentoRepositoryMemoria();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: DummyAiService(),
        imageService: mockImage,
      );

      final cuento = Cuento(
        id: 'c-401',
        titulo: 'Cuento de prueba',
        personajePrincipal: 'Lucas',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Lucas camina por el bosque.',
            opciones: const ['Seguir'],
          ),
        ],
      );

      expect(
        () => controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: 1,
        ),
        throwsA(
          isA<ImageAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Debe haber intentado exactamente 1 vez (CERO reintentos automáticos ante 401)
      expect(mockImage.llamadas, equals(1));
    });

    test('AUTH-START-07: 403 de generar-imagen '
        '-> propagar ImageAuthException y no ejecutar retries automáticos adicionales', () async {
      final mockImage = CountingImageService(errorStatus: 403);
      final repo = CuentoRepositoryMemoria();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: DummyAiService(),
        imageService: mockImage,
      );

      final cuento = Cuento(
        id: 'c-403',
        titulo: 'Cuento de prueba',
        personajePrincipal: 'Lucas',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Lucas observa una cueva.',
            opciones: const ['Entrar'],
          ),
        ],
      );

      expect(
        () => controller.asegurarIlustracionEscena(
          cuento: cuento,
          numeroEscena: 1,
        ),
        throwsA(
          isA<ImageAuthException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );

      // Debe haber intentado exactamente 1 vez (CERO reintentos automáticos ante 403)
      expect(mockImage.llamadas, equals(1));
    });

    testWidgets('AUTH-START-06 (Widget): Error 401 en StoryView no muestra botón Reintentar de imagen '
        'y ofrece Iniciar sesión para recuperar la sesión', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockImage = CountingImageService(errorStatus: 401);
      final repo = CuentoRepositoryMemoria();
      final controller = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repo,
        documentService: DocumentService(),
        aiService: DummyAiService(),
        imageService: mockImage,
      );

      final cuento = Cuento(
        id: 'cuento-test-401',
        titulo: 'Cuento 401',
        personajePrincipal: 'Lucas',
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Lucas mira a su alrededor.',
            opciones: const ['Avanzar'],
          ),
        ],
      );

      bool salirInvocado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StoryView(
            cuento: cuento,
            controller: controller,
            autoNarrar: false,
            onSalir: () {
              salirInvocado = true;
            },
          ),
        ),
      );

      // Esperar a que la solicitud asíncrona de imagen falle con 401
      await tester.pumpAndSettle();

      // Exactamente 1 llamada al servicio de imagen (sin retries)
      expect(mockImage.llamadas, equals(1));

      // NO debe existir botón Reintentar para generación de imagen
      expect(find.widgetWithText(FilledButton, 'Reintentar'), findsNothing);

      // Debe avisar de sesión no válida o expirada
      expect(find.text('Sesión no válida o expirada.'), findsOneWidget);

      // Debe ofrecer Iniciar sesión
      final botonIniciar = find.widgetWithText(FilledButton, 'Iniciar sesión');
      expect(botonIniciar, findsOneWidget);

      await tester.tap(botonIniciar);
      await tester.pumpAndSettle();
      expect(salirInvocado, isTrue);
    });
  });
}
