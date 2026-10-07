import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/views/draw_view.dart';

void main() {
  group('DrawView Lifecycle and TextEditingController Regression Tests', () {
    testWidgets(
      'Diálogo de nombre crea, usa y destruye TextEditingController sin lanzar used after being disposed',
      (tester) async {
        String? nombreFinal;
        Uint8List? dibujoFinal;

        await tester.pumpWidget(
          MaterialApp(
            home: DrawView(
              onVolver: () {},
              onContinuar: (nombre, dibujo) {
                nombreFinal = nombre;
                dibujoFinal = dibujo;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Dibujar un trazo en el lienzo para que _canvasImage no sea null
        final gesture = await tester.startGesture(const Offset(350, 250));
        await gesture.moveBy(const Offset(60, 60));
        await gesture.up();
        await tester.pumpAndSettle();

        // 2. Pulsar botón para abrir diálogo de nombre
        final btnCrearMiCuento = find.text('Crear mi cuento');
        expect(btnCrearMiCuento, findsOneWidget);
        await tester.tap(btnCrearMiCuento);
        await tester.pumpAndSettle();

        // 3. Verificar que el diálogo está visible
        expect(find.text('✨ Dale vida a tu personaje'), findsOneWidget);
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // 4. Ingresar nombre del personaje
        await tester.enterText(textFieldFinder, 'Valeria La Dragona');
        await tester.pump();

        // 5. Pulsar "Crear cuento" dentro del diálogo
        final btnConfirmar = find.widgetWithText(FilledButton, 'Crear cuento');
        expect(btnConfirmar, findsOneWidget);
        await tester.tap(btnConfirmar);

        // 6. Permitir que la animación de cierre del diálogo se ejecute completamente
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Esperar la resolución del Future asíncrono del motor (toByteData)
        await tester.runAsync(() async {
          for (int i = 0; i < 20; i++) {
            if (nombreFinal != null) break;
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pump();

        // 7. Confirmar que se invocó el callback sin errores de lifecycle
        expect(nombreFinal, equals('Valeria La Dragona'));
        expect(dibujoFinal, isNotNull);
        expect(dibujoFinal!.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'Cancelar el diálogo de nombre y volver a abrirlo no corrompe el ciclo de vida del controller',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DrawView(onVolver: () {}, onContinuar: (nombre, dibujo) {}),
          ),
        );

        await tester.pumpAndSettle();

        // Dibujar un trazo
        final gesture = await tester.startGesture(const Offset(350, 250));
        await gesture.moveBy(const Offset(40, 40));
        await gesture.up();
        await tester.pumpAndSettle();

        // Abrir diálogo y cancelar
        await tester.tap(find.text('Crear mi cuento'));
        await tester.pumpAndSettle();

        expect(find.text('Cancelar'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        // Volver a abrir el diálogo
        await tester.tap(find.text('Crear mi cuento'));
        await tester.pumpAndSettle();

        expect(find.text('✨ Dale vida a tu personaje'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Cancelar nuevamente
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.text('✨ Dale vida a tu personaje'), findsNothing);
      },
    );

    testWidgets(
      'Navegación fuera de DrawView mientras se dibuja o confirma no genera fugas de controllers',
      (tester) async {
        bool enDrawView = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: enDrawView
                    ? DrawView(
                        onVolver: () {
                          setState(() => enDrawView = false);
                        },
                        onContinuar: (nombre, dibujo) {
                          setState(() => enDrawView = false);
                        },
                      )
                    : const Scaffold(body: Text('PANTALLA_SIGUIENTE')),
              );
            },
          ),
        );

        await tester.pumpAndSettle();

        // Dibujar
        final gesture = await tester.startGesture(const Offset(350, 250));
        await gesture.moveBy(const Offset(50, 50));
        await gesture.up();
        await tester.pumpAndSettle();

        // Abrir diálogo
        await tester.tap(find.text('Crear mi cuento'));
        await tester.pumpAndSettle();

        // Confirmar y cambiar de pantalla
        await tester.enterText(find.byType(TextField), 'Simón');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuento'));

        await tester.pump();
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          for (int i = 0; i < 20; i++) {
            if (!enDrawView) break;
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();

        expect(find.text('PANTALLA_SIGUIENTE'), findsOneWidget);
        expect(find.byType(DrawView), findsNothing);
      },
    );
  });
}
