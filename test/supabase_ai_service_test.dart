import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tesis_investigacion/services/supabase_ai_service.dart';

class FakeSession extends Fake implements Session {
  @override
  final String accessToken;

  @override
  final bool isExpired;

  FakeSession({
    this.accessToken = 'jwt_estudiante_valido',
    this.isExpired = false,
  });
}

class FakeFunctionsClient extends Fake implements FunctionsClient {
  dynamic responseData;
  Map<String, dynamic>? lastBody;
  Map<String, String>? lastHeaders;
  String? lastFunction;
  FunctionException? exceptionToThrow;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    HttpMethod method = HttpMethod.post,
    Map<String, dynamic>? queryParameters,
    dynamic abortSignal,
    dynamic files,
    dynamic responseType,
    dynamic region,
  }) async {
    lastFunction = functionName;
    lastHeaders = headers;
    if (body is Map<String, dynamic>) {
      lastBody = body;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return FunctionResponse(data: responseData, status: 200);
  }
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  Session? mockSession;

  FakeGoTrueClient({Session? session}) : mockSession = session ?? FakeSession();

  @override
  Session? get currentSession => mockSession;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeFunctionsClient _mockFunctions = FakeFunctionsClient();
  final FakeGoTrueClient _mockAuth = FakeGoTrueClient();

  @override
  FunctionsClient get functions => _mockFunctions;

  @override
  GoTrueClient get auth => _mockAuth;
}

void main() {
  group('SupabaseAiService - Seguridad y Sesión JWT', () {
    late FakeSupabaseClient fakeClient;
    late SupabaseAiService service;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      service = SupabaseAiService(client: fakeClient);
    });

    test(
      'analizarHistoria envía encabezado Authorization con Bearer token',
      () async {
        fakeClient._mockFunctions.responseData = {
          'titulo': 'El Conejito Valiente',
          'tituloOriginal': 'The Brave Bunny',
          'personajePrincipal': 'Conejito',
          'descripcionPersonaje': 'Un conejo con orejas largas',
          'resumen': 'Una aventura en el prado.',
          'escenario': 'El prado verde',
          'conflictoPrincipal': 'Encontrar zanahorias',
          'finalOriginal': 'Todos comieron felices',
        };

        final res = await service.analizarHistoria(
          'Había una vez un conejo en el prado.',
        );

        expect(res.titulo, 'El Conejito Valiente');
        expect(fakeClient._mockFunctions.lastFunction, 'analizar-historia');
        expect(
          fakeClient._mockFunctions.lastHeaders?['Authorization'],
          'Bearer jwt_estudiante_valido',
        );
      },
    );

    test(
      'analizarHistoria rechaza ejecución si no hay sesión activa',
      () async {
        fakeClient._mockAuth.mockSession = null;

        expect(
          () => service.analizarHistoria('Texto de prueba'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No hay una sesión activa'),
            ),
          ),
        );
      },
    );

    test(
      'analizarHistoria rechaza ejecución si la sesión está expirada',
      () async {
        fakeClient._mockAuth.mockSession = FakeSession(isExpired: true);

        expect(
          () => service.analizarHistoria('Texto de prueba'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('La sesión ha expirado'),
            ),
          ),
        );
      },
    );

    test(
      'analizarHistoria transforma HTTP 401 en StateError controlado',
      () async {
        fakeClient._mockFunctions.exceptionToThrow = const FunctionException(
          status: 401,
          details: {'error': 'No autorizado'},
        );

        expect(
          () => service.analizarHistoria('Texto de prueba'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Sesión no autorizada o expirada'),
            ),
          ),
        );
      },
    );

    test(
      'analizarHistoria transforma HTTP 403 en StateError de rol denegado',
      () async {
        fakeClient._mockFunctions.exceptionToThrow = const FunctionException(
          status: 403,
          details: {'error': 'Acceso denegado'},
        );

        expect(
          () => service.analizarHistoria('Texto de prueba'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Acceso denegado. Función de IA disponible únicamente para estudiantes',
              ),
            ),
          ),
        );
      },
    );

    test(
      'generarEscena envía encabezado Authorization con Bearer token',
      () async {
        fakeClient._mockFunctions.responseData = {
          'contenido': 'El conejito comenzó a caminar.',
          'opciones': ['Ir a la colina', 'Buscar un río', 'Descansar'],
          'esFinal': false,
        };

        final escena = await service.generarEscena(
          titulo: 'Aventura',
          personajePrincipal: 'Conejito',
          textoFuente: 'Había una vez...',
          resumenOriginal: 'Un conejito.',
          escenarioOriginal: 'Prado',
          conflictoPrincipal: 'Hambre',
          finalOriginal: 'Comió',
          contextoNarrativo: 'Inicio',
          decisionActual: 'Caminar',
          numeroEscena: 2,
        );

        expect(escena.contenido, 'El conejito comenzó a caminar.');
        expect(fakeClient._mockFunctions.lastFunction, 'generar-escena');
        expect(
          fakeClient._mockFunctions.lastHeaders?['Authorization'],
          'Bearer jwt_estudiante_valido',
        );
      },
    );

    test('generarEscena rechaza ejecución si no hay sesión activa', () async {
      fakeClient._mockAuth.mockSession = null;

      expect(
        () => service.generarEscena(
          titulo: 'Aventura',
          personajePrincipal: 'Conejito',
          textoFuente: 'Texto',
          resumenOriginal: 'Resumen',
          escenarioOriginal: 'Escenario',
          conflictoPrincipal: 'Conflicto',
          finalOriginal: 'Final',
          contextoNarrativo: 'Contexto',
          decisionActual: 'Decisión',
          numeroEscena: 2,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No hay una sesión activa'),
          ),
        ),
      );
    });

    test(
      'generarEscena transforma HTTP 401 en StateError controlado',
      () async {
        fakeClient._mockFunctions.exceptionToThrow = const FunctionException(
          status: 401,
          details: {'error': 'No autorizado'},
        );

        expect(
          () => service.generarEscena(
            titulo: 'Aventura',
            personajePrincipal: 'Conejito',
            textoFuente: 'Texto',
            resumenOriginal: 'Resumen',
            escenarioOriginal: 'Escenario',
            conflictoPrincipal: 'Conflicto',
            finalOriginal: 'Final',
            contextoNarrativo: 'Contexto',
            decisionActual: 'Decisión',
            numeroEscena: 2,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Sesión no autorizada o expirada'),
            ),
          ),
        );
      },
    );

    test(
      'generarEscena transforma HTTP 403 en StateError de rol denegado',
      () async {
        fakeClient._mockFunctions.exceptionToThrow = const FunctionException(
          status: 403,
          details: {'error': 'Acceso denegado'},
        );

        expect(
          () => service.generarEscena(
            titulo: 'Aventura',
            personajePrincipal: 'Conejito',
            textoFuente: 'Texto',
            resumenOriginal: 'Resumen',
            escenarioOriginal: 'Escenario',
            conflictoPrincipal: 'Conflicto',
            finalOriginal: 'Final',
            contextoNarrativo: 'Contexto',
            decisionActual: 'Decisión',
            numeroEscena: 2,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Acceso denegado. Función de IA disponible únicamente para estudiantes',
              ),
            ),
          ),
        );
      },
    );
  });
}
