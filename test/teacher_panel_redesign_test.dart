// test/teacher_panel_redesign_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tesis_investigacion/models/quiz_attempt_summary.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';
import 'package:tesis_investigacion/models/user_profile.dart';
import 'package:tesis_investigacion/repositories/quiz_repository_supabase.dart';
import 'package:tesis_investigacion/utils/date_formatter.dart';
import 'package:tesis_investigacion/views/components/quiz_result_detail_dialog.dart';
import 'package:tesis_investigacion/views/components/teacher_class_summary.dart';
import 'package:tesis_investigacion/views/teacher_home_view.dart';

class MockQuizRepositoryTest implements QuizRepository {
  final List<QuizAttemptSummary> resultados;

  MockQuizRepositoryTest({required this.resultados});

  @override
  Future<List<QuizAttemptSummary>> obtenerResultadosPorDocente() async =>
      resultados;

  @override
  Future<Map<String, QuizAttemptSummary>> obtenerResumenesQuizPorEstudiante(
    String estudianteId,
  ) async => {};

  @override
  Future<QuizAttemptSummary?> obtenerResumenQuizPorCuento(
    String cuentoId,
  ) async => null;
}

void main() {
  final perfilDocente = UserProfile(
    id: 'docente-1',
    nombre: 'Profesor Carlos',
    rol: UserRole.docente,
  );

  final aulaA = {
    'id': 'aula-a',
    'nombre': '4to Grado A',
    'codigo_aula': '4A',
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
  };

  final aulaB = {
    'id': 'aula-b',
    'nombre': '4to Grado B',
    'codigo_aula': '4B',
    'created_at': DateTime(2026, 1, 2).toIso8601String(),
  };

  final estudianteA1 = {
    'estudiante_id': 'est-a1',
    'nombre': 'Estudiante A1',
    'codigo_acceso': '4A01',
    'codigo_local': '001',
  };

  final estudianteA2 = {
    'estudiante_id': 'est-a2',
    'nombre': 'Estudiante A2',
    'codigo_acceso': '4A02',
    'codigo_local': '002',
  };

  final estudianteA3 = {
    'estudiante_id': 'est-a3',
    'nombre': 'Estudiante A3',
    'codigo_acceso': '4A03',
    'codigo_local': '003',
  };

  final estudianteA4 = {
    'estudiante_id': 'est-a4',
    'nombre': 'Estudiante A4',
    'codigo_acceso': '4A04',
    'codigo_local': '004',
  };

  final estudianteB1 = {
    'estudiante_id': 'est-b1',
    'nombre': 'Estudiante B1',
    'codigo_acceso': '4B01',
    'codigo_local': '001',
  };

  group('SELECTOR DE AULA (TEACHER-CLASS-01 .. 04)', () {
    testWidgets(
      'TEACHER-CLASS-01: docente con 1 aula la selecciona automáticamente',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = MockQuizRepositoryTest(resultados: []);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('4to Grado A (4A)'), findsOneWidget);
        expect(find.text('Estudiante A1'), findsOneWidget);
      },
    );

    testWidgets(
      'TEACHER-CLASS-02: docente con 2 aulas puede cambiar entre ellas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = MockQuizRepositoryTest(resultados: []);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA, aulaB],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1],
                'aula-b': [estudianteB1],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Inicialmente aula A seleccionada
        expect(find.text('4to Grado A (4A)'), findsOneWidget);
        expect(find.text('Estudiante A1'), findsOneWidget);
        expect(find.text('Estudiante B1'), findsNothing);

        // Abrir dropdown y seleccionar aula B
        await tester.tap(find.text('4to Grado A (4A)'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4to Grado B (4B)').last);
        await tester.pumpAndSettle();

        expect(find.text('Estudiante B1'), findsOneWidget);
        expect(find.text('Estudiante A1'), findsNothing);
      },
    );

    testWidgets(
      'TEACHER-CLASS-03: cambiar aula cambia estudiantes y resultados',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final quizA1 = QuizAttemptSummary(
          intentoId: 'i-a1',
          cuentoId: 'c-1',
          cuentoTitulo: 'Cuento A1',
          estudianteId: 'est-a1',
          estudianteNombre: 'Estudiante A1',
          codigoAcceso: '4A01',
          aulaId: 'aula-a',
          estado: 'completado',
          puntaje: 5,
          totalPreguntas: 5,
          porcentaje: 100,
          createdAt: DateTime.now(),
        );

        final quizB1 = QuizAttemptSummary(
          intentoId: 'i-b1',
          cuentoId: 'c-2',
          cuentoTitulo: 'Cuento B1',
          estudianteId: 'est-b1',
          estudianteNombre: 'Estudiante B1',
          codigoAcceso: '4B01',
          aulaId: 'aula-b',
          estado: 'completado',
          puntaje: 3,
          totalPreguntas: 5,
          porcentaje: 60,
          createdAt: DateTime.now(),
        );

        final repo = MockQuizRepositoryTest(resultados: [quizA1, quizB1]);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA, aulaB],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1],
                'aula-b': [estudianteB1],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Aula A: 1 resultado
        expect(find.text('1 resultado(s)'), findsOneWidget);
        expect(find.text('Estudiante A1'), findsOneWidget);

        // Cambiar a Aula B
        await tester.tap(find.text('4to Grado A (4A)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4to Grado B (4B)').last);
        await tester.pumpAndSettle();

        expect(find.text('Estudiante B1'), findsOneWidget);
        expect(find.text('Estudiante A1'), findsNothing);
        expect(find.text('1 resultado(s)'), findsOneWidget);
      },
    );

    testWidgets('TEACHER-CLASS-04: no mezcla alumnos de aulas distintas', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = MockQuizRepositoryTest(resultados: []);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherHomeView(
            perfil: perfilDocente,
            onLogout: () {},
            quizRepository: repo,
            aulasIniciales: [aulaA, aulaB],
            estudiantesInicialesPorAula: {
              'aula-a': [estudianteA1, estudianteA2],
              'aula-b': [estudianteB1],
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // En Aula A solo están A1 y A2
      expect(find.text('Estudiante A1'), findsOneWidget);
      expect(find.text('Estudiante A2'), findsOneWidget);
      expect(find.text('Estudiante B1'), findsNothing);

      // En Aula B solo está B1
      await tester.tap(find.text('4to Grado A (4A)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4to Grado B (4B)').last);
      await tester.pumpAndSettle();

      expect(find.text('Estudiante B1'), findsOneWidget);
      expect(find.text('Estudiante A1'), findsNothing);
      expect(find.text('Estudiante A2'), findsNothing);
    });
  });

  group('MÉTRICAS DEL RESUMEN DEL AULA (TEACHER-METRIC-01 .. 06)', () {
    test('TEACHER-METRIC-01: total matriculados correcto', () {
      final matriculados = [
        estudianteA1,
        estudianteA2,
        estudianteA3,
        estudianteA4,
      ];
      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: matriculados,
        intentosDelAula: [],
      );
      expect(metrics.totalMatriculados, equals(4));
    });

    test('TEACHER-METRIC-02: participante se cuenta una sola vez aunque tenga múltiples quizzes', () {
      final matriculados = [estudianteA1, estudianteA2];

      // estudianteA1 tiene 3 quizzes completados, estudianteA2 tiene 0
      final intentos = [
        QuizAttemptSummary(
          intentoId: 'q1',
          cuentoId: 'c1',
          cuentoTitulo: 'C1',
          estudianteId: 'est-a1',
          estudianteNombre: 'A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
        QuizAttemptSummary(
          intentoId: 'q2',
          cuentoId: 'c2',
          cuentoTitulo: 'C2',
          estudianteId: 'est-a1',
          estudianteNombre: 'A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
        QuizAttemptSummary(
          intentoId: 'q3',
          cuentoId: 'c3',
          cuentoTitulo: 'C3',
          estudianteId: 'est-a1',
          estudianteNombre: 'A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
      ];

      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: matriculados,
        intentosDelAula: intentos,
      );

      expect(metrics.totalMatriculados, equals(2));
      // Debe contar como 1 participante, NO como 3
      expect(metrics.participantesUnicos, equals(1));
    });

    test('TEACHER-METRIC-03: sin participación = matriculados - participantes únicos', () {
      final matriculados = [
        estudianteA1,
        estudianteA2,
        estudianteA3,
        estudianteA4,
      ];

      final intentos = [
        QuizAttemptSummary(
          intentoId: 'q1',
          cuentoId: 'c1',
          cuentoTitulo: 'C1',
          estudianteId: 'est-a1',
          estudianteNombre: 'A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
      ];

      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: matriculados,
        intentosDelAula: intentos,
      );

      expect(metrics.totalMatriculados, equals(4));
      expect(metrics.participantesUnicos, equals(1));
      expect(metrics.sinParticipacion, equals(3));
    });

    test('TEACHER-METRIC-04: porcentaje de participación correcto (ej. 3 de 4 = 75 %)', () {
      final matriculados = [
        estudianteA1,
        estudianteA2,
        estudianteA3,
        estudianteA4,
      ];

      final intentos = [
        QuizAttemptSummary(
          intentoId: 'q1',
          cuentoId: 'c1',
          cuentoTitulo: 'C1',
          estudianteId: 'est-a1',
          estudianteNombre: 'A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
        QuizAttemptSummary(
          intentoId: 'q2',
          cuentoId: 'c2',
          cuentoTitulo: 'C2',
          estudianteId: 'est-a2',
          estudianteNombre: 'A2',
          codigoAcceso: '4A02',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
        QuizAttemptSummary(
          intentoId: 'q3',
          cuentoId: 'c3',
          cuentoTitulo: 'C3',
          estudianteId: 'est-a3',
          estudianteNombre: 'A3',
          codigoAcceso: '4A03',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
      ];

      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: matriculados,
        intentosDelAula: intentos,
      );

      expect(metrics.totalMatriculados, equals(4));
      expect(metrics.participantesUnicos, equals(3));
      expect(metrics.sinParticipacion, equals(1));
      expect(metrics.porcentajeParticipacion, equals(75.0));
    });

    test('TEACHER-METRIC-05: 0 alumnos produce 0 % y no error por división entre cero', () {
      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: [],
        intentosDelAula: [],
      );

      expect(metrics.totalMatriculados, equals(0));
      expect(metrics.participantesUnicos, equals(0));
      expect(metrics.sinParticipacion, equals(0));
      expect(metrics.porcentajeParticipacion, equals(0.0));
      expect(metrics.totalQuizzesCompletados, equals(0));
    });

    test('TEACHER-METRIC-06: total quizzes completados cuenta intentos, no estudiantes (ej. 8 quizzes de 3 alumnos)', () {
      final matriculados = [
        estudianteA1,
        estudianteA2,
        estudianteA3,
        estudianteA4,
      ];

      // 4 quizzes para est-a1, 3 para est-a2, 1 para est-a3 -> Total 8 quizzes
      final intentos = [
        ...List.generate(
          4,
          (i) => QuizAttemptSummary(
            intentoId: 'qa1-$i',
            cuentoId: 'c-$i',
            cuentoTitulo: 'Cuento $i',
            estudianteId: 'est-a1',
            estudianteNombre: 'A1',
            codigoAcceso: '4A01',
            estado: 'completado',
            createdAt: DateTime.now(),
          ),
        ),
        ...List.generate(
          3,
          (i) => QuizAttemptSummary(
            intentoId: 'qa2-$i',
            cuentoId: 'c2-$i',
            cuentoTitulo: 'Cuento 2-$i',
            estudianteId: 'est-a2',
            estudianteNombre: 'A2',
            codigoAcceso: '4A02',
            estado: 'completado',
            createdAt: DateTime.now(),
          ),
        ),
        QuizAttemptSummary(
          intentoId: 'qa3-0',
          cuentoId: 'c3-0',
          cuentoTitulo: 'Cuento 3',
          estudianteId: 'est-a3',
          estudianteNombre: 'A3',
          codigoAcceso: '4A03',
          estado: 'completado',
          createdAt: DateTime.now(),
        ),
      ];

      final metrics = AulaMetrics.calcular(
        estudiantesMatriculados: matriculados,
        intentosDelAula: intentos,
      );

      expect(metrics.totalMatriculados, equals(4));
      expect(metrics.participantesUnicos, equals(3));
      expect(metrics.sinParticipacion, equals(1));
      expect(metrics.porcentajeParticipacion, equals(75.0));
      // Aquí SÍ debe contar todos los 8 intentos
      expect(metrics.totalQuizzesCompletados, equals(8));
    });
  });

  group('TABLA Y RESULTADOS POR ESTUDIANTE (TEACHER-STUDENT-01 .. 04)', () {
    testWidgets(
      'TEACHER-STUDENT-01: lista muestra cada estudiante una sola vez',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = MockQuizRepositoryTest(resultados: []);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1, estudianteA2],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Estudiante A1'), findsOneWidget);
        expect(find.text('Estudiante A2'), findsOneWidget);
      },
    );

    testWidgets(
      'TEACHER-STUDENT-02: contador de quizzes por estudiante correcto',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final intentos = [
          QuizAttemptSummary(
            intentoId: 'q1',
            cuentoId: 'c1',
            cuentoTitulo: 'Cuento 1',
            estudianteId: 'est-a1',
            estudianteNombre: 'Estudiante A1',
            codigoAcceso: '4A01',
            estado: 'completado',
            createdAt: DateTime.now(),
          ),
          QuizAttemptSummary(
            intentoId: 'q2',
            cuentoId: 'c2',
            cuentoTitulo: 'Cuento 2',
            estudianteId: 'est-a1',
            estudianteNombre: 'Estudiante A1',
            codigoAcceso: '4A01',
            estado: 'completado',
            createdAt: DateTime.now(),
          ),
        ];

        final repo = MockQuizRepositoryTest(resultados: intentos);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1, estudianteA2],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Estudiante A1 tiene 2 quizzes, Estudiante A2 tiene 0
        expect(find.text('2'), findsWidgets);
        expect(find.text('0'), findsWidgets);
      },
    );

    testWidgets(
      'TEACHER-STUDENT-03: seleccionar estudiante muestra únicamente sus resultados',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final quizA1 = QuizAttemptSummary(
          intentoId: 'q1',
          cuentoId: 'c1',
          cuentoTitulo: 'El misterio de A1',
          estudianteId: 'est-a1',
          estudianteNombre: 'Estudiante A1',
          codigoAcceso: '4A01',
          estado: 'completado',
          puntaje: 4,
          totalPreguntas: 5,
          porcentaje: 80,
          createdAt: DateTime.now(),
        );

        final quizA2 = QuizAttemptSummary(
          intentoId: 'q2',
          cuentoId: 'c2',
          cuentoTitulo: 'El misterio de A2',
          estudianteId: 'est-a2',
          estudianteNombre: 'Estudiante A2',
          codigoAcceso: '4A02',
          estado: 'completado',
          puntaje: 2,
          totalPreguntas: 5,
          porcentaje: 40,
          createdAt: DateTime.now(),
        );

        final repo = MockQuizRepositoryTest(resultados: [quizA1, quizA2]);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1, estudianteA2],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Seleccionar Estudiante A1
        await tester.tap(find.text('Estudiante A1'));
        await tester.pumpAndSettle();

        expect(find.text('Resultados de Estudiante A1'), findsOneWidget);
        expect(find.text('El misterio de A1'), findsOneWidget);
        // NO debe listar el cuento de Estudiante A2
        expect(find.text('El misterio de A2'), findsNothing);

        // Botón volver
        await tester.tap(find.text('Volver a estudiantes'));
        await tester.pumpAndSettle();

        expect(find.text('Estudiantes del aula (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'TEACHER-STUDENT-04: estudiante sin resultados muestra estado vacío',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = MockQuizRepositoryTest(resultados: []);

        await tester.pumpWidget(
          MaterialApp(
            home: TeacherHomeView(
              perfil: perfilDocente,
              onLogout: () {},
              quizRepository: repo,
              aulasIniciales: [aulaA],
              estudiantesInicialesPorAula: {
                'aula-a': [estudianteA1],
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Seleccionar Estudiante A1
        await tester.tap(find.text('Estudiante A1'));
        await tester.pumpAndSettle();

        expect(find.text('Resultados de Estudiante A1'), findsOneWidget);
        expect(
          find.text('Aún no tiene resultados de comprensión.'),
          findsOneWidget,
        );
      },
    );
  });

  group('ORDEN Y NÚMEROS DE PREGUNTA EN DETALLE (QUIZ-NUMBER-01 .. 03)', () {
    testWidgets(
      'QUIZ-NUMBER-01: detalle muestra exactamente preguntas 1, 2, 3, 4, 5',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final intento = QuizAttemptSummary(
          intentoId: 'i-full',
          cuentoId: 'c-full',
          cuentoTitulo: 'Cuento de Prueba',
          estudianteId: 'est-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: '4A01',
          estado: 'completado',
          puntaje: 3,
          totalPreguntas: 5,
          porcentaje: 60,
          createdAt: DateTime.now(),
          respuestas: List.generate(
            5,
            (i) => QuizQuestionResult(
              numero: i + 1,
              pregunta: '¿Pregunta ${i + 1}?',
              opciones: ['A', 'B', 'C', 'D'],
              indiceSeleccionado: 0,
              indiceCorrecto: 0,
              esCorrecta: true,
              explicacion: 'Explicación ${i + 1}',
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => QuizResultDetailDialog.mostrar(ctx, intento),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        // Debe mostrar exactamente Pregunta 1, Pregunta 2, Pregunta 3, Pregunta 4, Pregunta 5
        expect(find.text('Pregunta 1'), findsOneWidget);
        expect(find.text('Pregunta 2'), findsOneWidget);
        expect(find.text('Pregunta 3'), findsOneWidget);
        expect(find.text('Pregunta 4'), findsOneWidget);
        expect(find.text('Pregunta 5'), findsOneWidget);
      },
    );

    testWidgets(
      'QUIZ-NUMBER-02: respuestas desordenadas se ordenan por numero_pregunta',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Enviamos preguntas en orden 4, 2, 5, 1, 3
        final ordenDesordenado = [4, 2, 5, 1, 3];
        final intento = QuizAttemptSummary(
          intentoId: 'i-desord',
          cuentoId: 'c-desord',
          cuentoTitulo: 'Cuento Desordenado',
          estudianteId: 'est-1',
          estudianteNombre: 'Mateo',
          codigoAcceso: '4A01',
          estado: 'completado',
          createdAt: DateTime.now(),
          respuestas: ordenDesordenado
              .map(
                (n) => QuizQuestionResult(
                  numero: n,
                  pregunta: 'Texto pregunta $n',
                  opciones: ['1', '2', '3', '4'],
                  indiceSeleccionado: 0,
                  indiceCorrecto: 0,
                  esCorrecta: true,
                  explicacion: 'Exp $n',
                ),
              )
              .toList(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => QuizResultDetailDialog.mostrar(ctx, intento),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.text('Pregunta 1'), findsOneWidget);
        expect(find.text('Pregunta 2'), findsOneWidget);
        expect(find.text('Pregunta 3'), findsOneWidget);
        expect(find.text('Pregunta 4'), findsOneWidget);
        expect(find.text('Pregunta 5'), findsOneWidget);
      },
    );

    test('QUIZ-NUMBER-03: comprobar persistencia/parsing correcto de numero_pregunta desde PostgreSQL snake_case', () {
      // Simula el JSON devuelto directamente por Supabase PostgREST
      final jsonPostgres = {
        'numero_pregunta': 4,
        'pregunta': '¿Cuál fue el conflicto?',
        'opciones': ['A', 'B', 'C', 'D'],
        'indice_seleccionado': 2,
        'indice_correcto': 2,
        'es_correcta': true,
        'explicacion': 'El conflicto ocurrió en el río.',
      };

      final parsed = QuizQuestionResult.fromJson(jsonPostgres);

      expect(parsed.numero, equals(4));
      expect(parsed.pregunta, equals('¿Cuál fue el conflicto?'));
      expect(parsed.indiceSeleccionado, equals(2));
      expect(parsed.indiceCorrecto, equals(2));
      expect(parsed.esCorrecta, isTrue);
      expect(parsed.explicacion, equals('El conflicto ocurrió en el río.'));
    });
  });

  group('FECHA LOCAL DOCENTE (TIME-TEACHER-01)', () {
    test('TIME-TEACHER-01: fecha sigue usando hora local con toLocal()', () {
      // Una fecha en UTC
      final fechaUtc = DateTime.utc(2026, 10, 8, 20, 30);
      final formateada = DateFormatter.formatearFechaHoraLocal(fechaUtc);

      // Verificamos que coincida con la hora local de la máquina
      final local = fechaUtc.toLocal();
      final horaEsperada = local.hour.toString().padLeft(2, '0');
      final minutoEsperado = local.minute.toString().padLeft(2, '0');

      expect(formateada.contains('$horaEsperada:$minutoEsperado'), isTrue);
    });
  });
}
