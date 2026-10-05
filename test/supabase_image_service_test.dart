import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tesis_investigacion/services/image_service.dart';
import 'package:tesis_investigacion/services/supabase_image_service.dart';

class FakeFunctionsClient extends Fake implements FunctionsClient {
  dynamic responseData;
  Map<String, dynamic>? lastBody;
  String? lastFunction;

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
    if (body is Map<String, dynamic>) {
      lastBody = body;
    }
    return FunctionResponse(data: responseData, status: 200);
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeFunctionsClient _mockFunctions = FakeFunctionsClient();

  @override
  FunctionsClient get functions => _mockFunctions;
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
        expect(
          mockFunctions.lastBody?['referenciaVisualBase64'],
          base64Encode(bytesReferencia),
        );
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
  });
}
