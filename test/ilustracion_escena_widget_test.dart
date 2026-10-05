import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/widgets/ilustracion_escena_widget.dart';

void main() {
  group('IlustracionEscenaWidget', () {
    // 1x1 pixel PNG transparente válido
    final transparentPngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
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
      'muestra Image.memory cuando la URL es un Data URI base64 válido',
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
      },
    );

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
