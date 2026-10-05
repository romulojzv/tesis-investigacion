import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/cuento.dart';
import 'package:tesis_investigacion/models/escena.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';

void main() {
  group('Fase 0: Persistencia de personaje y round-trip de repositorio', () {
    late CuentoRepositoryMemoria repository;

    setUp(() {
      repository = CuentoRepositoryMemoria();
    });

    test('guarda y recupera fielmente personajePrincipal ("Pepe") y descripcionPersonaje por separado', () async {
      const idCuento = 'cuento-pepe-persistencia-001';
      const nombre = 'Pepe';
      const descripcion =
          'Lleva una mochila roja, tiene el cabello corto y es muy curioso.';

      final cuento = Cuento(
        id: idCuento,
        titulo: 'La aventura de Pepe',
        personajePrincipal: nombre,
        personajeOriginal: 'Ranj',
        esPersonajeNuevo: true,
        descripcionPersonaje: descripcion,
        escenas: [
          Escena(
            numero: 1,
            contenido: 'Pepe exploró el sendero con su mochila.',
            imageUrl: 'https://example.com/storage/escena_1.webp',
            opciones: const ['Seguir', 'Volver'],
          ),
        ],
      );

      // Guardar
      await repository.guardarCuento(cuento);

      // Recuperar
      final recuperado = await repository.obtenerCuento(idCuento);

      expect(recuperado, isNotNull);
      expect(recuperado!.id, idCuento);
      expect(recuperado.personajePrincipal, 'Pepe');
      expect(
        recuperado.personajePrincipal,
        isNot(contains('mochila roja')),
        reason: 'El nombre nunca debe mezclarse con la descripción',
      );
      expect(recuperado.descripcionPersonaje, descripcion);
      expect(recuperado.esPersonajeNuevo, isTrue);
      expect(
        recuperado.escenas.first.imageUrl,
        'https://example.com/storage/escena_1.webp',
      );
    });

    test('renameOriginal conserva la descripción original del cuento sin contaminación de newCharacter', () {
      final pdfData = PdfStoryData(
        nombreArchivo: 'historia.pdf',
        textoExtraido: 'Ranj caminaba...',
        personajePrincipalDetectado: 'Ranj',
        descripcionPersonaje: 'Un niño de 8 años con capa roja original.',
      );

      // Intento de personalizar en modo renameOriginal
      final personalizacion = CharacterCustomization(
        mode: CharacterMode.renameOriginal,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Pedro',
        descripcionPersonaje: 'mochila roja residual',
        personajeOriginal: 'Ranj',
      );

      // La personalización rechaza la descripción si el modo es renameOriginal
      expect(personalizacion.descripcionPersonaje, isNull);

      // Al crear el cuento, debe usarse la descripción original del PDF
      final cuento = Cuento(
        id: 'cuento-rename-persistencia',
        titulo: 'El viaje',
        personajePrincipal: personalizacion.nombrePersonaje,
        personajeOriginal: personalizacion.personajeOriginal,
        esPersonajeNuevo: false,
        descripcionPersonaje: pdfData.descripcionPersonaje,
      );

      expect(cuento.personajePrincipal, 'Pedro');
      expect(
        cuento.descripcionPersonaje,
        'Un niño de 8 años con capa roja original.',
      );
      expect(cuento.descripcionPersonaje, isNot(contains('mochila roja')));
      expect(cuento.fueRenombrado, isTrue);
    });

    test(
      'guarda y recupera múltiples escenas con sus respectivas URLs de imagen',
      () async {
        const idCuento = 'cuento-multi-escenas-img';

        final cuento = Cuento(
          id: idCuento,
          titulo: 'Cuento de 4 escenas',
          personajePrincipal: 'Pepe',
          escenas: [
            Escena(
              numero: 1,
              contenido: 'Escena 1',
              imageUrl: 'https://example.com/storage/escena_1.webp',
            ),
            Escena(
              numero: 2,
              contenido: 'Escena 2',
              imageUrl: 'https://example.com/storage/escena_2.webp',
            ),
            Escena(
              numero: 3,
              contenido: 'Escena 3',
              imageUrl: 'https://example.com/storage/escena_3.webp',
            ),
            Escena(
              numero: 4,
              contenido: 'Escena 4',
              imageUrl: 'https://example.com/storage/escena_4.webp',
              esFinal: true,
            ),
          ],
        );

        await repository.guardarCuento(cuento);
        final recuperado = await repository.obtenerCuento(idCuento);

        expect(recuperado, isNotNull);
        expect(recuperado!.escenas.length, 4);
        for (var i = 1; i <= 4; i++) {
          expect(
            recuperado.obtenerEscena(i)?.imageUrl,
            'https://example.com/storage/escena_$i.webp',
          );
        }
      },
    );
  });
}
