// integration_test/app_supabase_integration_test.dart
//
// ============================================================================
// CUENTOS MÁGICOS — SUITE DE PRUEBAS DE INTEGRACIÓN FLUTTER–SUPABASE
// Observación EP2 20: Evidencia de integración real con backend Supabase
//
// Entorno: Supabase Local (127.0.0.1:54321)
// Framework: integration_test (Oficial de Flutter SDK)
//
// Flujos verificados:
// 1. Autenticación real de estudiante con código de acceso y PIN numérico (6 dígitos)
// 2. Lectura y validación de perfil de usuario desde Supabase bajo RLS
// 3. Persistencia y recuperación de cuentos con escenas y decisiones narrativas
// 4. Consulta de cuestionarios con distribución pedagógica (2-2-1)
// 5. Aislamiento estricto de acceso (RLS / Multitenancy entre estudiantes)
// 6. Integración UI en vivo (LoginView -> StudentHomeView -> Logout)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/decision_narrativa.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_supabase.dart';
import 'package:tesis_investigacion/repositories/quiz_repository_supabase.dart';
import 'package:tesis_investigacion/services/auth_service.dart';
import 'package:tesis_investigacion/views/auth_gate.dart';
import 'package:tesis_investigacion/views/login_view.dart';
import 'package:tesis_investigacion/views/student_home_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Configuración estricta de Supabase local (127.0.0.1:54321)
  const supabaseLocalUrl = 'http://127.0.0.1:54321';
  const localAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
  const localServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

  late final SupabaseClient adminClient;
  late final SupabaseClient clientAnon;
  late final AuthService authService;
  late final CuentoRepositorySupabase cuentoRepo;
  late final QuizRepositorySupabase quizRepo;

  // Variables de fixture sintético controlado
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final suffix = (timestamp % 10000).toString().padLeft(4, '0');

  // Docente sintético
  final docEmail = 'doc.int.$suffix@cuentosmagicos.internal';
  final docPass = 'DocIntPass_$suffix!Aa';
  late String docUserId;

  final hexTail = timestamp.toRadixString(16).padLeft(12, '0');
  final hexTail12 = hexTail.length > 12 ? hexTail.substring(hexTail.length - 12) : hexTail.padLeft(12, '0');

  // Aula sintética (ID tipo UUID)
  final aulaId = '11111111-aaaa-4000-8000-$hexTail12';
  final codigoAula = 'A$suffix';

  // Estudiante A sintético
  final codigoAccesoA = '4A$suffix-001';
  final pinEstudianteA = ((100000 + (timestamp % 900000))).toString();
  final emailEstudianteA =
      '${codigoAccesoA.toLowerCase()}@estudiantes.cuentosmagicos.internal';
  late String studentAUserId;

  // Estudiante B sintético (para pruebas de aislamiento RLS)
  final codigoAccesoB = '4A$suffix-002';
  final pinEstudianteB = ((100001 + (timestamp % 900000))).toString();
  final emailEstudianteB =
      '${codigoAccesoB.toLowerCase()}@estudiantes.cuentosmagicos.internal';
  late String studentBUserId;

  // IDs de cuentos sintéticos
  final cuentoFixtureAId = 'cuento-fixture-a-$suffix';
  final cuentoFixtureBId = 'cuento-fixture-b-$suffix';
  final intentoFixtureId = '22222222-bbbb-4000-8000-$hexTail12';
  final nuevoCuentoGeneradoId = 'cuento-nuevo-$suffix';

  setUpAll(() async {
    // 1. Inicialización de clientes
    adminClient = SupabaseClient(supabaseLocalUrl, localServiceRoleKey);

    try {
      await Supabase.initialize(
        url: supabaseLocalUrl,
        publishableKey: localAnonKey,
      );
    } catch (_) {}

    clientAnon = Supabase.instance.client;

    authService = AuthService(client: clientAnon);
    cuentoRepo = CuentoRepositorySupabase(client: clientAnon);
    quizRepo = QuizRepositorySupabase(client: clientAnon);

    // 2. Crear docente sintético en Auth y Profiles
    final resDoc = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: docEmail,
        password: docPass,
        emailConfirm: true,
        userMetadata: {'nombre': 'Profesor Integración'},
      ),
    );
    docUserId = resDoc.user!.id;
    await adminClient.from('profiles').upsert({
      'id': docUserId,
      'nombre': 'Profesor Integración',
      'rol': 'docente',
    });

    // 3. Crear aula sintética
    await adminClient.from('aulas').insert({
      'id': aulaId,
      'nombre': 'Aula 4to Primaria Test',
      'codigo_aula': codigoAula,
      'docente_id': docUserId,
    });

    // 4. Crear estudiante A sintético
    final resEstA = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: emailEstudianteA,
        password: pinEstudianteA,
        emailConfirm: true,
        appMetadata: {
          'rol': 'estudiante',
          'codigo_acceso': codigoAccesoA,
        },
        userMetadata: {'nombre': 'Estudiante Integración A'},
      ),
    );
    studentAUserId = resEstA.user!.id;
    await adminClient.from('profiles').upsert({
      'id': studentAUserId,
      'nombre': 'Estudiante Integración A',
      'rol': 'estudiante',
      'codigo_acceso': codigoAccesoA,
    });
    await adminClient.from('aula_estudiantes').insert({
      'aula_id': aulaId,
      'estudiante_id': studentAUserId,
      'codigo_local': '001',
    });

    // 5. Crear estudiante B sintético (para aislamiento RLS)
    final resEstB = await adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: emailEstudianteB,
        password: pinEstudianteB,
        emailConfirm: true,
        appMetadata: {
          'rol': 'estudiante',
          'codigo_acceso': codigoAccesoB,
        },
        userMetadata: {'nombre': 'Estudiante Integración B'},
      ),
    );
    studentBUserId = resEstB.user!.id;
    await adminClient.from('profiles').upsert({
      'id': studentBUserId,
      'nombre': 'Estudiante Integración B',
      'rol': 'estudiante',
      'codigo_acceso': codigoAccesoB,
    });
    await adminClient.from('aula_estudiantes').insert({
      'aula_id': aulaId,
      'estudiante_id': studentBUserId,
      'codigo_local': '002',
    });

    // 6. Insertar cuento fixture para Estudiante A
    await adminClient.from('cuentos').insert({
      'id': cuentoFixtureAId,
      'titulo': 'El Zorro Sabio de los Andes',
      'personaje_principal': 'Zorro Fernando',
      'origen': 'pdf',
      'estudiante_id': studentAUserId,
      'aula_id': aulaId,
      'es_demo': false,
    });

    // 7. Insertar intento de quiz completado para Estudiante A (con respuestas 2-2-1)
    await adminClient.from('quiz_intentos').insert({
      'id': intentoFixtureId,
      'cuento_id': cuentoFixtureAId,
      'estudiante_id': studentAUserId,
      'aula_id': aulaId,
      'estado': 'completado',
      'puntaje': 5,
      'total_preguntas': 5,
      'porcentaje': 100,
      'completed_at': DateTime.now().toIso8601String(),
    });

    await adminClient.from('quiz_respuestas').insert([
      {
        'intento_id': intentoFixtureId,
        'numero_pregunta': 1,
        'pregunta': '¿Dónde vivía el zorro Fernando?',
        'opciones': ['En los Andes', 'En la selva', 'En la costa', 'En el desierto'],
        'indice_seleccionado': 0,
        'indice_correcto': 0,
        'es_correcta': true,
        'explicacion': 'El texto menciona explícitamente que vivía en los Andes.',
        'nivel_comprension': 'literal',
      },
      {
        'intento_id': intentoFixtureId,
        'numero_pregunta': 2,
        'pregunta': '¿Qué animal era el personaje principal?',
        'opciones': ['Un zorro', 'Un cóndor', 'Un puma', 'Una vicuña'],
        'indice_seleccionado': 0,
        'indice_correcto': 0,
        'es_correcta': true,
        'explicacion': 'El protagonista es un zorro llamado Fernando.',
        'nivel_comprension': 'literal',
      },
      {
        'intento_id': intentoFixtureId,
        'numero_pregunta': 3,
        'pregunta': '¿Por qué los demás animales buscaban su consejo?',
        'opciones': ['Por su sabiduría', 'Por su fuerza', 'Por su velocidad', 'Por su canto'],
        'indice_seleccionado': 0,
        'indice_correcto': 0,
        'es_correcta': true,
        'explicacion': 'Se deduce de sus acciones reflexivas ante los problemas.',
        'nivel_comprension': 'inferencial',
      },
      {
        'intento_id': intentoFixtureId,
        'numero_pregunta': 4,
        'pregunta': '¿Qué sentimiento motivó al zorro a ayudar?',
        'opciones': ['La empatía', 'El miedo', 'El enojo', 'La curiosidad'],
        'indice_seleccionado': 0,
        'indice_correcto': 0,
        'es_correcta': true,
        'explicacion': 'El zorro demostró preocupación genuina por sus vecinos.',
        'nivel_comprension': 'inferencial',
      },
      {
        'intento_id': intentoFixtureId,
        'numero_pregunta': 5,
        'pregunta': '¿Qué opinas sobre compartir conocimientos en comunidad?',
        'opciones': ['Fortalece la unión', 'No tiene importancia', 'Causa problemas', 'Es indiferente'],
        'indice_seleccionado': 0,
        'indice_correcto': 0,
        'es_correcta': true,
        'explicacion': 'Reflexión crítica sobre el valor formativo de la ayuda mutua.',
        'nivel_comprension': 'critico_reflexivo',
      },
    ]);

    // 8. Insertar cuento de Estudiante B (para validar aislamiento RLS)
    await adminClient.from('cuentos').insert({
      'id': cuentoFixtureBId,
      'titulo': 'El Misterio del Estudiante B',
      'personaje_principal': 'León',
      'origen': 'dibujo',
      'estudiante_id': studentBUserId,
      'aula_id': aulaId,
      'es_demo': false,
    });
  });

  tearDownAll(() async {
    // Limpieza exhaustiva y determinística con adminClient
    try {
      await adminClient.from('quiz_respuestas').delete().eq('intento_id', intentoFixtureId);
      await adminClient.from('quiz_intentos').delete().eq('id', intentoFixtureId);
      await adminClient.from('decisiones_narrativas').delete().eq('cuento_id', nuevoCuentoGeneradoId);
      await adminClient.from('escenas').delete().eq('cuento_id', nuevoCuentoGeneradoId);
      await adminClient.from('cuentos').delete().filter('id', 'in', [
        cuentoFixtureAId,
        cuentoFixtureBId,
        nuevoCuentoGeneradoId,
      ]);
      await adminClient.from('aula_estudiantes').delete().eq('aula_id', aulaId);
      await adminClient.from('aulas').delete().eq('id', aulaId);
      await adminClient.from('profiles').delete().filter('id', 'in', [
        studentAUserId,
        studentBUserId,
        docUserId,
      ]);
      await adminClient.auth.admin.deleteUser(studentAUserId);
      await adminClient.auth.admin.deleteUser(studentBUserId);
      await adminClient.auth.admin.deleteUser(docUserId);
    } catch (e) {
      debugPrint('[tearDownAll] Advertencia en limpieza: $e');
    }
  });

  // ==========================================================================
  // GRUPO 1: AUTENTICACIÓN Y PERFILES EN SUPABASE
  // ==========================================================================
  group('1. Integración de Autenticación y Perfil (Supabase Auth & Profiles)', () {
    testWidgets('1.1 Autenticación real de estudiante con código de acceso y PIN de 6 dígitos', (tester) async {
      final perfil = await authService.loginEstudiante(
        codigoAcceso: codigoAccesoA,
        pin: pinEstudianteA,
      );

      expect(perfil.id, equals(studentAUserId));
      expect(perfil.rol, equals(UserRole.estudiante));
      expect(perfil.nombre, equals('Estudiante Integración A'));
      expect(perfil.codigoAcceso, equals(codigoAccesoA));

      // Verificar que la sesión activa exista en el cliente Supabase
      expect(clientAnon.auth.currentUser, isNotNull);
      expect(clientAnon.auth.currentUser!.id, equals(studentAUserId));
      expect(clientAnon.auth.currentSession, isNotNull);
      expect(clientAnon.auth.currentSession!.accessToken, isNotEmpty);
    });

    testWidgets('1.2 Rechazo de credencial inválida (PIN incorrecto) sin modificar sesión', (tester) async {
      await authService.logout();

      expect(
        () async => await authService.loginEstudiante(
          codigoAcceso: codigoAccesoA,
          pin: '999999', // PIN inválido
        ),
        throwsA(isA<AuthException>()),
      );

      expect(clientAnon.auth.currentUser, isNull);
    });

    testWidgets('1.3 Lectura directa de perfil desde public.profiles bajo RLS', (tester) async {
      // Iniciar sesión con credencial correcta
      await authService.loginEstudiante(
        codigoAcceso: codigoAccesoA,
        pin: pinEstudianteA,
      );

      final perfil = await authService.obtenerPerfilActual();
      expect(perfil, isNotNull);
      expect(perfil!.id, equals(studentAUserId));
      expect(perfil.nombre, equals('Estudiante Integración A'));
      expect(perfil.rol, equals(UserRole.estudiante));
      expect(perfil.codigoAcceso, equals(codigoAccesoA));

      // Cierre de sesión limpio
      await authService.logout();
      expect(clientAnon.auth.currentUser, isNull);
    });
  });

  // ==========================================================================
  // GRUPO 2: PERSISTENCIA Y CONSULTA DE CUENTOS EN SUPABASE
  // ==========================================================================
  group('2. Integración de Repositorio de Cuentos (CuentoRepositorySupabase)', () {
    testWidgets('2.1 Guardado y recuperación completa de cuento con escenas y decisiones', (tester) async {
      // Autenticar al estudiante A
      await authService.loginEstudiante(
        codigoAcceso: codigoAccesoA,
        pin: pinEstudianteA,
      );

      final cuentoParaGuardar = Cuento(
        id: nuevoCuentoGeneradoId,
        titulo: 'Aventura en las Nubes',
        personajePrincipal: 'Cóndor Tomás',
        origen: CuentoOrigen.dibujo,
        descripcionPersonaje: 'Un cóndor con plumas brillantes',
        estudianteId: studentAUserId,
        aulaId: aulaId,
        esDemo: false,
        escenas: [
          Escena(
            numero: 1,
            contenido: 'El cóndor Tomás desplegó sus grandes alas sobre el valle sagrado.',
            opciones: ['Volar hacia las montañas', 'Descender al río'],
            esFinal: false,
          ),
          Escena(
            numero: 2,
            contenido: 'Voló hacia las altas cumbres nevadas y encontró un refugio seguro.',
            opciones: [],
            esFinal: true,
          ),
        ],
        decisiones: [
          DecisionNarrativa(
            numeroEscena: 1,
            opcionSeleccionada: 'Volar hacia las montañas',
          ),
        ],
      );

      // Guardar en Supabase (cuentos, escenas, decisiones_narrativas)
      await cuentoRepo.guardarCuento(cuentoParaGuardar);

      // Recuperar desde Supabase
      final cuentoRecuperado = await cuentoRepo.obtenerCuento(nuevoCuentoGeneradoId);

      expect(cuentoRecuperado, isNotNull);
      expect(cuentoRecuperado!.id, equals(nuevoCuentoGeneradoId));
      expect(cuentoRecuperado.titulo, equals('Aventura en las Nubes'));
      expect(cuentoRecuperado.personajePrincipal, equals('Cóndor Tomás'));
      expect(cuentoRecuperado.escenas.length, equals(2));
      expect(cuentoRecuperado.escenas[0].numero, equals(1));
      expect(cuentoRecuperado.escenas[0].opciones.length, equals(2));
      expect(cuentoRecuperado.escenas[1].esFinal, isTrue);
      expect(cuentoRecuperado.decisiones.length, equals(1));
      expect(cuentoRecuperado.decisiones[0].opcionSeleccionada, equals('Volar hacia las montañas'));
    });

    testWidgets('2.2 Listado de cuentos del estudiante autenticado', (tester) async {
      // Con sesión de Estudiante A activa
      final misCuentos = await cuentoRepo.listarCuentosPorEstudiante(studentAUserId);

      expect(misCuentos.isNotEmpty, isTrue);
      final ids = misCuentos.map((c) => c.id).toList();
      expect(ids.contains(cuentoFixtureAId), isTrue);
      expect(ids.contains(nuevoCuentoGeneradoId), isTrue);
    });
  });

  // ==========================================================================
  // GRUPO 3: HISTORIAL Y EVALUACIÓN DE QUIZ (QuizRepositorySupabase)
  // ==========================================================================
  group('3. Integración de Repositorio de Cuestionarios (QuizRepositorySupabase)', () {
    testWidgets('3.1 Consulta de resumen de quiz del estudiante con preguntas y respuestas pedagógicas', (tester) async {
      // Con sesión de Estudiante A activa
      final resumenes = await quizRepo.obtenerResumenesQuizPorEstudiante(studentAUserId);

      expect(resumenes.containsKey(cuentoFixtureAId), isTrue);
      final intento = resumenes[cuentoFixtureAId]!;

      expect(intento.intentoId, equals(intentoFixtureId));
      expect(intento.cuentoId, equals(cuentoFixtureAId));
      expect(intento.puntaje, equals(5));
      expect(intento.totalPreguntas, equals(5));
      expect(intento.porcentaje, equals(100));
      expect(intento.estaCompletado, isTrue);

      // Comprobación de las 5 respuestas y su taxonomía 2-2-1
      expect(intento.respuestas.length, equals(5));

      final literales = intento.respuestas.where((r) => r.nivelComprension == 'literal').length;
      final inferenciales = intento.respuestas.where((r) => r.nivelComprension == 'inferencial').length;
      final criticas = intento.respuestas.where((r) => r.nivelComprension == 'critico_reflexivo').length;

      expect(literales, equals(2), reason: 'Deben existir exactamente 2 preguntas de nivel literal');
      expect(inferenciales, equals(2), reason: 'Deben existir exactamente 2 preguntas de nivel inferencial');
      expect(criticas, equals(1), reason: 'Debe existir exactamente 1 pregunta de nivel crítico-reflexivo');
    });

    testWidgets('3.2 Consulta de intento por cuento específico', (tester) async {
      final intento = await quizRepo.obtenerResumenQuizPorCuento(cuentoFixtureAId);

      expect(intento, isNotNull);
      expect(intento!.intentoId, equals(intentoFixtureId));
      expect(intento.cuentoTitulo, equals('El Zorro Sabio de los Andes'));
      expect(intento.estudianteNombre, equals('Estudiante Integración A'));
    });
  });

  // ==========================================================================
  // GRUPO 4: AISLAMIENTO DE ACCESO Y SEGURIDAD RLS
  // ==========================================================================
  group('4. Validación de Aislamiento de Acceso (Políticas RLS en Supabase)', () {
    testWidgets('4.1 Estudiante A no puede listar ni ver cuentos privados de Estudiante B', (tester) async {
      // Con sesión de Estudiante A activa
      final cuentosDeB = await cuentoRepo.listarCuentosPorEstudiante(studentBUserId);

      // La política RLS impide que Estudiante A obtenga los cuentos no-demo de Estudiante B
      expect(cuentosDeB, isEmpty, reason: 'RLS debe devolver lista vacía al consultar datos de otro estudiante');
    });

    testWidgets('4.2 Estudiante A no puede acceder a resultados de quiz de Estudiante B', (tester) async {
      // Con sesión de Estudiante A activa
      final quizzesDeB = await quizRepo.obtenerResumenesQuizPorEstudiante(studentBUserId);

      // La política RLS en quiz_intentos impide leer intentos ajenos
      expect(quizzesDeB, isEmpty, reason: 'RLS debe bloquear el acceso a intentos de quiz de otros estudiantes');
    });

    testWidgets('4.3 Restricción de creación de cuentos por rol docente (Capa de Aplicación - StateError)', (tester) async {
      // Cerrar sesión de estudiante e iniciar sesión como docente
      await authService.logout();
      await authService.loginDocente(email: docEmail, password: docPass);

      final cuentoDocente = Cuento(
        id: 'cuento-doc-invalido-$suffix',
        titulo: 'Cuento Prohibido',
        personajePrincipal: 'Docente',
        origen: CuentoOrigen.dibujo,
        estudianteId: docUserId,
        aulaId: aulaId,
        esDemo: false,
      );

      // Validación defensiva en la capa de aplicación (CuentoRepositorySupabase)
      // Se comprueba que el repositorio bloquee el intento de guardado arrojando StateError
      expect(
        () async => await cuentoRepo.guardarCuento(cuentoDocente),
        throwsA(isA<StateError>()),
      );

      await authService.logout();
    });
  });

  // ==========================================================================
  // GRUPO 5: INTEGRACIÓN UI / FLUIDEZ DE WIDGETS CON SUPABASE EN VIVO
  // ==========================================================================
  group('5. Integración de Widgets y UI en Vivo (AuthGate & LoginView -> StudentHomeView)', () {
    testWidgets('5.1 Flujo visual de Login de Estudiante -> StudentHomeView -> Logout', (WidgetTester tester) async {
      // Asegurar estado de desautenticación
      await authService.logout();

      // Montar la jerarquía de widgets conectada al cliente real
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: authService,
            studentBuilder: (context, perfil) => StudentHomeView(
              perfil: perfil,
              cuentoRepository: cuentoRepo,
              quizRepository: quizRepo,
              onDibujar: () {},
              onUsarPdf: () {},
              onLogout: () async {
                await authService.logout();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar presencia de LoginView
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('🎒 Soy estudiante'), findsOneWidget);

      // 2. Ingresar código de acceso y PIN en los campos de texto
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), codigoAccesoA);
      await tester.enterText(textFields.at(1), pinEstudianteA);
      await tester.pump();

      // 3. Pulsar el botón de ingresar
      final botonIngresar = find.byType(ElevatedButton);
      expect(botonIngresar, findsOneWidget);
      await tester.tap(botonIngresar);

      // 4. Esperar la respuesta de Supabase y el renderizado reactivo de AuthGate
      await tester.pumpAndSettle();

      // 5. Verificar transición a StudentHomeView con los datos reales de Supabase
      expect(find.byType(StudentHomeView), findsOneWidget);
      expect(find.textContaining('¡Hola, Estudiante Integración A!'), findsOneWidget);
      expect(find.textContaining(codigoAccesoA), findsOneWidget);

      // 6. Probar cierre de sesión desde la UI
      final botonCerrarSesion = find.text('Cerrar sesión');
      expect(botonCerrarSesion, findsOneWidget);
      await tester.tap(botonCerrarSesion);
      await tester.pumpAndSettle();

      // 7. Verificar retorno a LoginView
      expect(find.byType(LoginView), findsOneWidget);
      expect(clientAnon.auth.currentUser, isNull);
    });
  });
}
