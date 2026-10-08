import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/supabase_image_service.dart';

class FakeSession extends Fake implements Session {
  @override
  final String accessToken;

  @override
  final bool isExpired;

  FakeSession({
    this.accessToken = 'fake_valid_jwt_token',
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
  group('SolicitudImagenEscena - Construcción de Prompts', () {
    test('construirPrompt incluye reglas, estilo, protagonista y acción', () {
      final solicitud = SolicitudImagenEscena(
        cuentoId: 'cuento-123',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        descripcionPersonaje: 'Lleva una mochila roja y cabello corto',
        contenidoEscena:
            'Pepe descubre una tubería escondida detrás de unas rocas',
        escenario: 'Una colina verde y soleada',
      );

      final prompt = solicitud.construirPrompt();

      expect(prompt, contains('Pepe'));
      expect(prompt, contains('Lleva una mochila roja'));
      expect(prompt, contains('tubería escondida'));
      expect(prompt, contains('colina verde'));
      expect(prompt, contains('NO incluir palabras, letras'));
      expect(
        prompt,
        isNot(contains('Transformación suave de dibujo infantil')),
      );
    });

    test('modo dibujo incluye reglas explícitas de refinamiento suave y preservación de identidad', () {
      final solicitud = SolicitudImagenEscena(
        cuentoId: 'cuento-dibujo-01',
        numeroEscena: 1,
        nombreProtagonista: 'Pollito Pepe',
        descripcionPersonaje: 'Pollito amarillo con cabeza roja',
        contenidoEscena: 'Pollito Pepe salta sobre una rama',
        esModoDibujo: true,
      );

      final prompt = solicitud.construirPrompt();

      // Reglas de preservación de identidad
      expect(prompt, contains('Transformación suave de dibujo infantil'));
      expect(prompt, contains('conserva fielmente la identidad'));
      expect(prompt, contains('silueta'));
      expect(prompt, contains('colores dominantes'));
      expect(prompt, contains('especie'));
      expect(prompt, contains('detalles distintivos'));
      expect(prompt, contains('creación del niño'));

      // Modificaciones permitidas
      expect(prompt, contains('limpiar líneas'));
      expect(prompt, contains('completar pequeños huecos'));
      expect(prompt, contains('suavizar trazos'));
      expect(prompt, contains('mejorar ligeramente proporciones'));

      // Reglas negativas estrictas
      expect(prompt, contains('NO rediseñar completamente el personaje'));
      expect(prompt, contains('NO cambiar de especie o tipo de criatura'));
      expect(prompt, contains('NO hacerlo humanoide si no lo era'));
      expect(
        prompt,
        contains('NO agregar ropa o accesorios importantes inexistentes'),
      );
      expect(prompt, contains('NO sustituir sus colores principales'));
      expect(prompt, contains('NO eliminar detalles distintivos'));
      expect(
        prompt,
        contains(
          'NO convertir todos los dibujos en un personaje infantil genérico',
        ),
      );
      expect(
        prompt,
        contains(
          'NO perfeccionar tanto el dibujo que deje de parecer creación del niño',
        ),
      );
    });

    test('modo no dibujo (PDF/automático) NO incluye reglas de refinamiento de dibujo infantil', () {
      final solicitudPdf = SolicitudImagenEscena(
        cuentoId: 'cuento-pdf-01',
        numeroEscena: 1,
        nombreProtagonista: 'El Conejo Sabio',
        descripcionPersonaje: 'Conejo con anteojos',
        contenidoEscena: 'El conejo lee un libro antiguo',
        esModoDibujo: false,
      );

      final prompt = solicitudPdf.construirPrompt();

      expect(
        prompt,
        isNot(contains('Transformación suave de dibujo infantil')),
      );
      expect(prompt, isNot(contains('creación del niño')));
      expect(
        prompt,
        isNot(contains('NO rediseñar completamente el personaje')),
      );
      expect(prompt, isNot(contains('NO hacerlo humanoide')));
      expect(prompt, contains('Protagonista: El Conejo Sabio'));
      expect(prompt, contains('Reglas de consistencia:'));
    });
  });

  group('SupabaseImageService', () {
    late FakeSupabaseClient fakeClient;
    late SupabaseImageService service;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      service = SupabaseImageService(client: fakeClient);
    });

    test(
      'envía los parámetros esperados a generar-imagen y retorna la imageUrl',
      () async {
        (fakeClient.functions as FakeFunctionsClient).responseData = {
          'success': true,
          'imageUrl':
              'https://storage.supabase.co/cuentos/c123/escenas/escena_1.webp',
          'imagePath': 'c123/escenas/escena_1.webp',
        };

        final bytesReferencia = Uint8List.fromList([1, 2, 3, 4, 5]);
        final solicitud = SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 1,
          nombreProtagonista: 'Pepe',
          descripcionPersonaje: 'Mochila roja',
          contenidoEscena: 'Pepe camina alegremente.',
          escenario: 'Bosque',
          referenciaVisualBytes: bytesReferencia,
        );

        final url = await service.generarIlustracionEscena(solicitud);

        expect(
          url,
          'https://storage.supabase.co/cuentos/c123/escenas/escena_1.webp',
        );

        final mockFunctions = fakeClient.functions as FakeFunctionsClient;
        expect(mockFunctions.lastFunction, 'generar-imagen');
        expect(mockFunctions.lastBody?['cuentoId'], 'c123');
        expect(mockFunctions.lastBody?['numeroEscena'], 1);
        expect(mockFunctions.lastBody?['personajePrincipal'], 'Pepe');
        expect(mockFunctions.lastBody?['descripcionPersonaje'], 'Mochila roja');
        expect(
          mockFunctions.lastBody?['contenidoEscena'],
          'Pepe camina alegremente.',
        );
        expect(mockFunctions.lastBody?['escenario'], 'Bosque');
        expect(mockFunctions.lastBody?['esModoDibujo'], isFalse);
        expect(
          mockFunctions.lastBody?['referenciaVisualBase64'],
          base64Encode(bytesReferencia),
        );
      },
    );

    test(
      'envía esModoDibujo true cuando la solicitud es de origen dibujo',
      () async {
        (fakeClient.functions as FakeFunctionsClient).responseData = {
          'success': true,
          'imageUrl':
              'https://storage.supabase.co/cuentos/c123/escenas/escena_1.webp',
          'imagePath': 'c123/escenas/escena_1.webp',
        };

        final solicitud = const SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 1,
          nombreProtagonista: 'Pollito Pepe',
          contenidoEscena: 'Pollito camina.',
          esModoDibujo: true,
        );

        await service.generarIlustracionEscena(solicitud);

        final mockFunctions = fakeClient.functions as FakeFunctionsClient;
        expect(mockFunctions.lastBody?['esModoDibujo'], isTrue);
      },
    );

    test(
      'lanza StateError si la respuesta contiene un error del backend',
      () async {
        (fakeClient.functions as FakeFunctionsClient).responseData = {
          'error': 'Fallo al invocar el proveedor Pollinations',
          'detalle': 'Timeout de red',
        };

        final solicitud = const SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 2,
          nombreProtagonista: 'Pepe',
          contenidoEscena: 'Pepe corre.',
        );

        expect(
          () => service.generarIlustracionEscena(solicitud),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Fallo al invocar el proveedor Pollinations'),
            ),
          ),
        );
      },
    );

    test('respuesta con Data URI es aceptada y retornada correctamente', () async {
      const dataUriEsperada =
          'data:image/webp;base64,UklGRkAAAABXRUJQVlA4IDQAAADwAQCdASoBAAEAAQAcJaACdLoB+AA/vlAAA=';
      (fakeClient.functions as FakeFunctionsClient).responseData = {
        'success': true,
        'imageUrl': dataUriEsperada,
        'flujo': 'text_to_image',
        'modeloUsado': 'black-forest-labs/flux.1-schnell',
      };

      const solicitud = SolicitudImagenEscena(
        cuentoId: 'c-data-uri',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        contenidoEscena: 'Pepe camina.',
      );

      final url = await service.generarIlustracionEscena(solicitud);
      expect(url, dataUriEsperada);
    });

    test(
      'propaga error con detalle cuando Pollinations devuelve JSON de error',
      () async {
        (fakeClient.functions as FakeFunctionsClient).responseData = {
          'error': 'Pollinations devolvió status 401',
          'detalle': 'Unauthorized: Invalid API key',
        };

        const solicitud = SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 1,
          nombreProtagonista: 'Pepe',
          contenidoEscena: 'Pepe corre.',
        );

        expect(
          () => service.generarIlustracionEscena(solicitud),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Pollinations devolvió status 401'),
                contains('Unauthorized: Invalid API key'),
              ),
            ),
          ),
        );
      },
    );

    test('sin referencia visual NO incluye referenciaVisualBase64 en la solicitud', () async {
      (fakeClient.functions as FakeFunctionsClient).responseData = {
        'success': true,
        'imageUrl':
            'https://storage.supabase.co/cuentos/c-text/escenas/escena_1.webp',
        'flujo': 'text_to_image',
        'modeloUsado': 'black-forest-labs/flux.1-schnell',
      };

      const solicitudSinRef = SolicitudImagenEscena(
        cuentoId: 'c-text',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        descripcionPersonaje: 'Lleva una mochila roja',
        contenidoEscena: 'Pepe descubre una tubería.',
        referenciaVisualBytes: null,
      );

      final url = await service.generarIlustracionEscena(solicitudSinRef);
      expect(url, isNotEmpty);

      final mockFunctions = fakeClient.functions as FakeFunctionsClient;
      expect(
        mockFunctions.lastBody!.containsKey('referenciaVisualBase64'),
        isFalse,
      );
      expect(mockFunctions.lastBody?['personajePrincipal'], 'Pepe');
      expect(
        mockFunctions.lastBody?['descripcionPersonaje'],
        'Lleva una mochila roja',
      );
    });

    test('con referencia visual SÍ incluye referenciaVisualBase64 en la solicitud', () async {
      (fakeClient.functions as FakeFunctionsClient).responseData = {
        'success': true,
        'imageUrl':
            'https://storage.supabase.co/cuentos/c-edits/escenas/escena_1.webp',
        'flujo': 'edicion_con_referencia',
        'modeloUsado': 'black-forest-labs/flux.2-klein-4b',
      };

      final bytes = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]); // Magic bytes PNG
      final solicitudConRef = SolicitudImagenEscena(
        cuentoId: 'c-edits',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        descripcionPersonaje: 'Lleva una mochila roja',
        contenidoEscena: 'Pepe descubre una tubería.',
        referenciaVisualBytes: bytes,
      );

      final url = await service.generarIlustracionEscena(solicitudConRef);
      expect(url, isNotEmpty);

      final mockFunctions = fakeClient.functions as FakeFunctionsClient;
      expect(
        mockFunctions.lastBody!.containsKey('referenciaVisualBase64'),
        isTrue,
      );
      expect(
        mockFunctions.lastBody?['referenciaVisualBase64'],
        base64Encode(bytes),
      );
      expect(mockFunctions.lastBody?['personajePrincipal'], 'Pepe');
    });

    test('en modo dibujo para escenas 2+, referenciaVisualBase64 contiene el dibujo original como fuente de identidad y no campos inventados', () async {
      (fakeClient.functions as FakeFunctionsClient).responseData = {
        'success': true,
        'imageUrl': 'https://storage.supabase.co/cuentos/c-dibujo-esc2/escenas/escena_2.webp',
        'flujo': 'edicion_con_referencia',
        'modeloUsado': 'black-forest-labs/flux.2-klein-4b',
      };

      final dibujoOriginalBytes = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        1,
        2,
        3,
      ]);
      final escena1Bytes = Uint8List.fromList([82, 73, 70, 70, 9, 8, 7]);

      final solicitudEscena2 = SolicitudImagenEscena(
        cuentoId: 'c-dibujo-esc2',
        numeroEscena: 2,
        nombreProtagonista: 'Pollito Pepe',
        descripcionPersonaje: 'Pollito amarillo con cresta roja',
        contenidoEscena:
            'Pollito Pepe cruza el río nadando en una hoja gigante.',
        escenario: 'Río del bosque',
        referenciaVisualBytes: dibujoOriginalBytes,
        referenciaAnteriorBytes: escena1Bytes,
        esModoDibujo: true,
      );

      final url = await service.generarIlustracionEscena(solicitudEscena2);
      expect(url, isNotEmpty);

      final mockFunctions = fakeClient.functions as FakeFunctionsClient;
      final body = mockFunctions.lastBody!;

      // 1. Debe incluir esModoDibujo = true
      expect(body['esModoDibujo'], isTrue);

      // 2. Debe incluir el dibujo original como referencia principal
      expect(body['referenciaVisualBase64'], base64Encode(dibujoOriginalBytes));

      // 3. NO debe enviar campos inexistentes en el contrato como image_anchor
      expect(body.containsKey('image_anchor'), isFalse);
    });

    test('falla con StateError si no hay sesión de usuario activa', () async {
      fakeClient._mockAuth.mockSession = null;
      const solicitud = SolicitudImagenEscena(
        cuentoId: 'c123',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        contenidoEscena: 'Pepe camina.',
      );

      expect(
        () => service.generarIlustracionEscena(solicitud),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No hay una sesión activa'),
          ),
        ),
      );
    });

    test('falla con StateError si la sesión de usuario expiró', () async {
      fakeClient._mockAuth.mockSession = FakeSession(isExpired: true);
      const solicitud = SolicitudImagenEscena(
        cuentoId: 'c123',
        numeroEscena: 1,
        nombreProtagonista: 'Pepe',
        contenidoEscena: 'Pepe camina.',
      );

      expect(
        () => service.generarIlustracionEscena(solicitud),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('La sesión ha expirado'),
          ),
        ),
      );
    });

    test(
      'falla con mensaje descriptivo si Edge Function retorna 401',
      () async {
        final mockFunctions = fakeClient.functions as FakeFunctionsClient;
        mockFunctions.exceptionToThrow = const FunctionException(
          status: 401,
          details: {'error': 'No autorizado'},
        );

        const solicitud = SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 1,
          nombreProtagonista: 'Pepe',
          contenidoEscena: 'Pepe camina.',
        );

        expect(
          () => service.generarIlustracionEscena(solicitud),
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
      'falla con mensaje descriptivo si Edge Function retorna 403',
      () async {
        final mockFunctions = fakeClient.functions as FakeFunctionsClient;
        mockFunctions.exceptionToThrow = const FunctionException(
          status: 403,
          details: {'error': 'Prohibido'},
        );

        const solicitud = SolicitudImagenEscena(
          cuentoId: 'c123',
          numeroEscena: 1,
          nombreProtagonista: 'Pepe',
          contenidoEscena: 'Pepe camina.',
        );

        expect(
          () => service.generarIlustracionEscena(solicitud),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('exclusivamente para estudiantes'),
            ),
          ),
        );
      },
    );
  });
}
