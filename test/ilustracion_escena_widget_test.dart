import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/widgets/ilustracion_escena_widget.dart';

class _MockHttpClient extends Fake implements HttpClient {
  final List<int> _imageBytes;
  _MockHttpClient(this._imageBytes);

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest(_imageBytes);
  }
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  final List<int> _imageBytes;
  _MockHttpClientRequest(this._imageBytes);

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse(_imageBytes);
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  final List<int> _imageBytes;
  _MockHttpClientResponse(this._imageBytes);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _imageBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_imageBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHostWidget extends StatefulWidget {
  final String imageUrl;

  const _TestHostWidget({required this.imageUrl});

  @override
  State<_TestHostWidget> createState() => _TestHostWidgetState();
}

class _TestHostWidgetState extends State<_TestHostWidget> {
  int rebuildCount = 0;

  void triggerRebuild() {
    setState(() {
      rebuildCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('Rebuilds: $rebuildCount'),
            Expanded(child: IlustracionEscenaWidget(imageUrl: widget.imageUrl)),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('IlustracionEscenaWidget', () {
    // 1x1 pixel PNG transparente válido
    final transparentPngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );

    // Segundo PNG válido diferente para pruebas de cambio de escena/URL
    final redDotPngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    test('esDataUri identifica correctamente prefijos data:image/', () {
      expect(
        IlustracionEscenaWidget.esDataUri('data:image/webp;base64,AAAA'),
        isTrue,
      );
      expect(
        IlustracionEscenaWidget.esDataUri('DATA:IMAGE/PNG;base64,AAAA'),
        isTrue,
      );
      expect(
        IlustracionEscenaWidget.esDataUri('https://ejemplo.com/foto.webp'),
        isFalse,
      );
      expect(
        IlustracionEscenaWidget.esDataUri('http://ejemplo.com/foto.png'),
        isFalse,
      );
    });

    test('decodificarDataUri extrae bytes válidos', () {
      final dataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
      final bytes = IlustracionEscenaWidget.decodificarDataUri(dataUri);

      expect(bytes, isNotNull);
      expect(bytes!.length, transparentPngBytes.length);
      expect(bytes, equals(transparentPngBytes));
    });

    test('decodificarDataUri retorna null ante base64 corrupto', () {
      final corruptUri = 'data:image/png;base64,%%%NO_BASE64%%%';
      final bytes = IlustracionEscenaWidget.decodificarDataUri(corruptUri);

      expect(bytes, isNull);
    });

    testWidgets(
      'muestra Image.memory cuando la URL es un Data URI base64 válido y usa gaplessPlayback',
      (tester) async {
        final dataUri =
            'data:image/png;base64,${base64Encode(transparentPngBytes)}';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: IlustracionEscenaWidget(imageUrl: dataUri)),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.image, isA<MemoryImage>());
        expect(imageWidget.gaplessPlayback, isTrue);
      },
    );

    testWidgets(
      'Data URI se decodifica una sola vez mientras imageUrl no cambie (mantiene misma referencia de bytes tras múltiples rebuilds)',
      (tester) async {
        final dataUri =
            'data:image/png;base64,${base64Encode(transparentPngBytes)}';

        await tester.pumpWidget(_TestHostWidget(imageUrl: dataUri));

        final hostState = tester.state<_TestHostWidgetState>(
          find.byType(_TestHostWidget),
        );

        final primeraImagen = tester.widget<Image>(find.byType(Image));
        final primerosBytes = (primeraImagen.image as MemoryImage).bytes;
        expect(primeraImagen.gaplessPlayback, isTrue);

        // Disparar 5 reconstrucciones del árbol
        for (var i = 0; i < 5; i++) {
          hostState.triggerRebuild();
          await tester.pump();
        }

        expect(find.text('Rebuilds: 5'), findsOneWidget);

        final imagenTrasRebuilds = tester.widget<Image>(find.byType(Image));
        final bytesTrasRebuilds =
            (imagenTrasRebuilds.image as MemoryImage).bytes;

        // La instancia de Uint8List decodificada DEBE ser idéntica por referencia en memoria
        expect(
          identical(primerosBytes, bytesTrasRebuilds),
          isTrue,
          reason:
              'No debe re-decodificar base64 en cada build si la URL no cambia',
        );
      },
    );

    testWidgets(
      'cambiar a otra escena/imageUrl sí actualiza la imagen y decodifica los nuevos bytes',
      (tester) async {
        final dataUri1 =
            'data:image/png;base64,${base64Encode(transparentPngBytes)}';
        final dataUri2 =
            'data:image/png;base64,${base64Encode(redDotPngBytes)}';

        await tester.pumpWidget(_TestHostWidget(imageUrl: dataUri1));

        final primeraImagen = tester.widget<Image>(find.byType(Image));
        final primerosBytes = (primeraImagen.image as MemoryImage).bytes;
        expect(primerosBytes, equals(transparentPngBytes));

        // Actualizar el host con la nueva URL de escena
        await tester.pumpWidget(_TestHostWidget(imageUrl: dataUri2));

        final segundaImagen = tester.widget<Image>(find.byType(Image));
        final segundosBytes = (segundaImagen.image as MemoryImage).bytes;

        expect(
          identical(primerosBytes, segundosBytes),
          isFalse,
          reason: 'Debe re-decodificar cuando la imageUrl cambia',
        );
        expect(segundosBytes, equals(redDotPngBytes));
      },
    );

    testWidgets('URL http/https sigue funcionando y usa gaplessPlayback', (
      tester,
    ) async {
      await HttpOverrides.runZoned(() async {
        const httpUrl = 'https://ejemplo.com/escena_1.png';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: IlustracionEscenaWidget(imageUrl: httpUrl)),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.image, isA<NetworkImage>());
        expect((imageWidget.image as NetworkImage).url, equals(httpUrl));
        expect(imageWidget.gaplessPlayback, isTrue);
      }, createHttpClient: (context) => _MockHttpClient(transparentPngBytes));
    });

    testWidgets(
      'dispara errorBuilder si el Data URI contiene base64 corrupto',
      (tester) async {
        bool errorCapturado = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IlustracionEscenaWidget(
                imageUrl: 'data:image/png;base64,!!invalido!!',
                errorBuilder: (context, error, stackTrace) {
                  errorCapturado = true;
                  return const Text('Error al renderizar');
                },
              ),
            ),
          ),
        );

        expect(errorCapturado, isTrue);
        expect(find.text('Error al renderizar'), findsOneWidget);
      },
    );

    testWidgets('dispara errorBuilder si el esquema de URL no es soportado', (
      tester,
    ) async {
      bool errorCapturado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IlustracionEscenaWidget(
              imageUrl: 'ftp://servidor/foto.png',
              errorBuilder: (context, error, stackTrace) {
                errorCapturado = true;
                return const Text('Esquema no soportado');
              },
            ),
          ),
        ),
      );

      expect(errorCapturado, isTrue);
      expect(find.text('Esquema no soportado'), findsOneWidget);
    });
  });
}
