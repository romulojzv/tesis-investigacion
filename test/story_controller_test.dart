import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/character_customization.dart';
import 'package:tesis_investigacion/models/generated_scene.dart';
import 'package:tesis_investigacion/controllers/story_controller.dart';
import 'package:tesis_investigacion/models/narrativa_config.dart';
import 'package:tesis_investigacion/models/pdf_story_data.dart';
import 'package:tesis_investigacion/models/story_analysis.dart';
import 'package:tesis_investigacion/repositories/cuento_repository_memoria.dart';
import 'package:tesis_investigacion/services/ai_service.dart';
import 'package:tesis_investigacion/services/document_service.dart';
import 'package:tesis_investigacion/services/narrativa_service.dart';

class FakeAiService implements AiService {
  String? ultimoPersonajeOriginalRecibido;
  String? ultimoPersonajePrincipalRecibido;
  bool? ultimoEsPersonajeNuevoRecibido;
  String? ultimaDescripcionPersonajeRecibida;

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    return StoryAnalysis(
      titulo: 'Cuento de prueba',
      personajePrincipal: 'Leo',
      descripcionPersonaje: 'Un personaje utilizado para las pruebas.',
      resumen: 'Este es un resumen generado para la prueba.',
      escenario: 'Un bosque mágico',
      conflictoPrincipal: 'El personaje debe encontrar el camino.',
      finalOriginal: 'El personaje logra regresar a casa.',
    );
  }

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
  }) async {
    ultimoPersonajeOriginalRecibido = personajeOriginal;
    ultimoPersonajePrincipalRecibido = personajePrincipal;
    ultimoEsPersonajeNuevoRecibido = esPersonajeNuevo;
    ultimaDescripcionPersonajeRecibida = descripcionPersonaje;

    // Si hubo un renombrado (ej. Ranj -> Pedro), simula que la IA a veces
    // filtra accidentalmente el nombre original "Ranj" para probar la sanitización.
    final contenido =
        personajeOriginal != null &&
            personajeOriginal.toLowerCase() != personajePrincipal.toLowerCase()
        ? '$personajePrincipal y $personajeOriginal inician la aventura en $escenarioOriginal.'
        : '$personajePrincipal comienza su aventura en $escenarioOriginal.';

    return GeneratedScene(
      contenido: contenido,
      opciones: const [
        'Seguir la ruta original hacia el río',
        'Tomar un atajo misterioso entre los árboles',
        'Preguntar a los sabios del bosque',
      ],
      esFinal: false,
    );
  }

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
  }) async {
    ultimoPersonajeOriginalRecibido = personajeOriginal;
    ultimoPersonajePrincipalRecibido = personajePrincipal;
    ultimoEsPersonajeNuevoRecibido = esPersonajeNuevo;
    ultimaDescripcionPersonajeRecibida = descripcionPersonaje;

    // Simula filtración accidental de Ranj si fue renombrado
    final contenido = esUltimaEscena
        ? '$personajePrincipal concluyó con éxito su travesía tras elegir "$decisionActual".'
        : (personajeOriginal != null &&
                  personajeOriginal.toLowerCase() !=
                      personajePrincipal.toLowerCase()
              ? '$personajePrincipal y $personajeOriginal decidieron "$decisionActual".'
              : '$personajePrincipal decidió "$decisionActual" y encontró una nueva aventura.');

    return GeneratedScene(
      contenido: contenido,
      opciones: esUltimaEscena
          ? const []
          : const [
              'Investigar las huellas del camino',
              'Conversar con el guardián del bosque',
              'Examinar el mapa encontrado',
            ],
      esFinal: esUltimaEscena,
    );
  }
}

class MockFlakyEndingAiService extends FakeAiService {
  int llamadasGenerarEscena4 = 0;
  final bool fallarSiempre;

  MockFlakyEndingAiService({this.fallarSiempre = false});

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
  }) async {
    if (numeroEscena == 4) {
      llamadasGenerarEscena4++;
      if (llamadasGenerarEscena4 == 1 || fallarSiempre) {
        // En el primer intento devuelve una escena con final abierto y opciones (inválido)
        return GeneratedScene(
          contenido:
              '$personajePrincipal se quedó pensando cuál sería el siguiente paso para descubrir el misterio.',
          opciones: const ['Seguir investigando'],
          esFinal: false,
        );
      }

      // En el reintento devuelve un desenlace real y conclusivo
      return GeneratedScene(
        contenido:
            '$personajePrincipal resolvió el problema del agua con ayuda de los vecinos y el tanque volvió a llenarse.',
        opciones: const [],
        esFinal: true,
      );
    }

    return super.generarEscena(
      titulo: titulo,
      personajePrincipal: personajePrincipal,
      personajeOriginal: personajeOriginal,
      textoFuente: textoFuente,
      resumenOriginal: resumenOriginal,
      escenarioOriginal: escenarioOriginal,
      conflictoPrincipal: conflictoPrincipal,
      finalOriginal: finalOriginal,
      contextoNarrativo: contextoNarrativo,
      decisionActual: decisionActual,
      numeroEscena: numeroEscena,
      esUltimaEscena: esUltimaEscena,
    );
  }
}

void main() {
  late StoryController controller;
  late CuentoRepositoryMemoria repository;

  late Uint8List dibujoPrueba;

  setUp(() {
    repository = CuentoRepositoryMemoria();

    dibujoPrueba = Uint8List.fromList([1, 2, 3, 4]);

    controller = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: FakeAiService(),
    );
  });

  test('crea un cuento inicial correctamente', () async {
    final cuento = await controller.crearCuentoInicialDemo(
      id: 'cuento-test-001',
      nombrePersonaje: 'Leo',
      dibujoReferenciaPng: dibujoPrueba,
    );

    expect(cuento.id, 'cuento-test-001');

    expect(cuento.personajePrincipal, 'Leo');

    expect(cuento.escenas, isNotEmpty);

    expect(cuento.escenas.first.numero, 1);

    expect(cuento.tieneReferenciaVisual, isTrue);
  });

  test('el cuento creado se guarda en el repositorio', () async {
    await controller.crearCuentoInicialDemo(
      id: 'cuento-test-002',
      nombrePersonaje: 'Ana',
      dibujoReferenciaPng: dibujoPrueba,
    );

    final cuentoGuardado = await repository.obtenerCuento('cuento-test-002');

    expect(cuentoGuardado, isNotNull);

    expect(cuentoGuardado!.personajePrincipal, 'Ana');

    expect(cuentoGuardado.tieneReferenciaVisual, isTrue);
  });

  test('FakeAiService devuelve análisis estructurado', () async {
    final ai = FakeAiService();

    final analisis = await ai.analizarHistoria(
      'Había una vez un niño llamado Leo.',
    );

    expect(analisis.titulo, 'Cuento de prueba');

    expect(analisis.personajePrincipal, 'Leo');

    expect(analisis.escenario, 'Un bosque mágico');
  });

  test('crearCuentoDesdePdfProcesadoDemo genera primera escena con IA y opciones contextuales', () async {
    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento.pdf',
      textoExtraido: 'Había una vez un detective en busca de agua.',
      tituloDetectado: 'El misterio del agua',
      tituloOriginal: 'The Case of the Missing Water',
      personajePrincipalDetectado: 'Ranj',
      escenario: 'Una aldea soleada',
      conflictoPrincipal: 'Los pozos de agua se han secado',
    );

    final personalizacion = CharacterCustomization(
      mode: CharacterMode.keepOriginal,
      visualMode: CharacterVisualMode.automatic,
      nombrePersonaje: 'Ranj',
    );

    final cuento = await controller.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-pdf-001',
      datosPdf: pdfData,
      personalizacion: personalizacion,
    );

    expect(cuento.titulo, 'El misterio del agua');
    expect(cuento.tituloOriginal, 'The Case of the Missing Water');
    expect(cuento.escenas.length, 1);
    expect(cuento.escenas.first.numero, 1);
    expect(cuento.escenas.first.contenido, contains('Ranj'));
    expect(cuento.escenas.first.opciones.length, 3);
    expect(cuento.escenas.first.esFinal, isFalse);
  });

  test('generarSiguienteEscena respeta límite de maxEscenas finalizando la historia', () async {
    final controllerConLimite = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: FakeAiService(),
      narrativaConfig: const NarrativaConfig(maxEscenas: 2),
    );

    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento.pdf',
      textoExtraido: 'Historia de prueba',
      tituloDetectado: 'Aventura corta',
    );

    final cuento = await controllerConLimite.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-limite-001',
      datosPdf: pdfData,
      personalizacion: CharacterCustomization(
        mode: CharacterMode.keepOriginal,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Leo',
      ),
    );

    expect(cuento.escenas.length, 1);
    final primeraEscena = cuento.escenas.first;

    final segundaEscena = await controllerConLimite.generarSiguienteEscena(
      cuento: cuento,
      escenaActual: primeraEscena,
      decision: primeraEscena.opciones.first,
    );

    expect(segundaEscena.numero, 2);
    expect(segundaEscena.esFinal, isTrue);
    expect(segundaEscena.opciones, isEmpty);
    expect(cuento.decisiones.length, 1);
  });

  test('Ranj -> Pedro mantiene Pedro durante toda la aventura y sanitiza filtraciones', () async {
    final ai = FakeAiService();
    final ctrl = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: ai,
      narrativaConfig: const NarrativaConfig(maxEscenas: 4),
    );

    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento_ranj.pdf',
      textoExtraido: 'Ranj vivía en un pueblo donde el agua era escasa.',
      tituloDetectado: 'El caso del agua perdida',
      tituloOriginal: 'The Case of the Missing Water',
      personajePrincipalDetectado: 'Ranj',
      escenario: 'Una aldea soleada',
      conflictoPrincipal: 'Falta agua en los pozos',
    );

    final personalizacion = CharacterCustomization(
      mode: CharacterMode.renameOriginal,
      visualMode: CharacterVisualMode.automatic,
      nombrePersonaje: 'Pedro',
      personajeOriginal: 'Ranj',
    );

    final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-pedro-001',
      datosPdf: pdfData,
      personalizacion: personalizacion,
    );

    // Verificar modelo Cuento
    expect(cuento.personajePrincipal, 'Pedro');
    expect(cuento.personajeOriginal, 'Ranj');
    expect(cuento.fueRenombrado, isTrue);

    // Escena 1: Sanitizado, nunca debe contener "Ranj"
    expect(cuento.escenas.first.contenido, contains('Pedro'));
    expect(cuento.escenas.first.contenido, isNot(contains('Ranj')));

    // Generar escena 2
    final escena2 = await ctrl.generarSiguienteEscena(
      cuento: cuento,
      escenaActual: cuento.escenas.first,
      decision: cuento.escenas.first.opciones.first,
    );
    expect(escena2.numero, 2);
    expect(escena2.contenido, contains('Pedro'));
    expect(escena2.contenido, isNot(contains('Ranj')));

    // Generar escena 3
    final escena3 = await ctrl.generarSiguienteEscena(
      cuento: cuento,
      escenaActual: escena2,
      decision: escena2.opciones.first,
    );
    expect(escena3.numero, 3);
    expect(escena3.contenido, contains('Pedro'));
    expect(escena3.contenido, isNot(contains('Ranj')));

    // Generar escena 4 (desenlace definitivo con maxEscenas = 4)
    final escena4 = await ctrl.generarSiguienteEscena(
      cuento: cuento,
      escenaActual: escena3,
      decision: escena3.opciones.first,
    );
    expect(escena4.numero, 4);
    expect(escena4.esFinal, isTrue);
    expect(escena4.opciones, isEmpty);
    expect(escena4.contenido, contains('Pedro'));
    expect(escena4.contenido, isNot(contains('Ranj')));
  });

  test('mantener Ranj sigue funcionando normalmente sin sustitución', () async {
    final ai = FakeAiService();
    final ctrl = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: ai,
    );

    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento_ranj.pdf',
      textoExtraido: 'Ranj vivía en un pueblo donde el agua era escasa.',
      tituloDetectado: 'El caso del agua perdida',
      personajePrincipalDetectado: 'Ranj',
      escenario: 'Una aldea',
      conflictoPrincipal: 'Falta agua',
    );

    final personalizacion = CharacterCustomization(
      mode: CharacterMode.keepOriginal,
      visualMode: CharacterVisualMode.automatic,
      nombrePersonaje: 'Ranj',
      personajeOriginal: 'Ranj',
    );

    final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-ranj-001',
      datosPdf: pdfData,
      personalizacion: personalizacion,
    );

    expect(cuento.personajePrincipal, 'Ranj');
    expect(cuento.fueRenombrado, isFalse);
    expect(cuento.escenas.first.contenido, contains('Ranj'));
  });

  test('personaje nuevo sigue funcionando correctamente', () async {
    final ai = FakeAiService();
    final ctrl = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: ai,
    );

    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento_ranj.pdf',
      textoExtraido: 'Texto original de la historia.',
      tituloDetectado: 'El gran viaje',
      personajePrincipalDetectado: 'Ranj',
      escenario: 'La montaña',
    );

    final personalizacion = CharacterCustomization(
      mode: CharacterMode.newCharacter,
      visualMode: CharacterVisualMode.automatic,
      nombrePersonaje: 'Valeria',
    );

    final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-valeria-001',
      datosPdf: pdfData,
      personalizacion: personalizacion,
    );

    expect(cuento.personajePrincipal, 'Valeria');
    expect(cuento.fueRenombrado, isFalse);
    expect(cuento.escenas.first.contenido, contains('Valeria'));
  });

  test(
    'maxEscenas = 4 garantiza que la escena 4 siempre finaliza sin opciones',
    () async {
      final ai = FakeAiService();
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: ai,
        narrativaConfig: const NarrativaConfig(maxEscenas: 4),
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Texto de prueba',
        tituloDetectado: 'Cuento de 4 escenas',
      );

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-max4-001',
        datosPdf: pdfData,
        personalizacion: CharacterCustomization(
          mode: CharacterMode.newCharacter,
          visualMode: CharacterVisualMode.automatic,
          nombrePersonaje: 'Lucas',
        ),
      );

      // Escena 1
      expect(cuento.escenas.length, 1);
      expect(cuento.escenas[0].esFinal, isFalse);

      // Escena 2
      final escena2 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: cuento.escenas.last.opciones.first,
      );
      expect(escena2.numero, 2);
      expect(escena2.esFinal, isFalse);

      // Escena 3
      final escena3 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: escena2,
        decision: escena2.opciones.first,
      );
      expect(escena3.numero, 3);
      expect(escena3.esFinal, isFalse);

      // Escena 4
      final escena4 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: escena3,
        decision: escena3.opciones.first,
      );
      expect(escena4.numero, 4);
      expect(escena4.esFinal, isTrue);
      expect(escena4.opciones, isEmpty);

      // Intentar generar después del desenlace arroja StateError
      expect(
        () => ctrl.generarSiguienteEscena(
          cuento: cuento,
          escenaActual: escena4,
          decision: 'Cualquiera',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('asociarImagenAEscena asocia y preserva la imagen al navegar por las escenas', () async {
    final ai = FakeAiService();
    final ctrl = StoryController(
      narrativaService: NarrativaService(),
      cuentoRepository: repository,
      documentService: DocumentService(),
      aiService: ai,
    );

    final pdfData = PdfStoryData(
      nombreArchivo: 'cuento.pdf',
      textoExtraido: 'Texto de prueba',
      tituloDetectado: 'Aventura con imagen',
    );

    final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
      id: 'cuento-img-001',
      datosPdf: pdfData,
      personalizacion: CharacterCustomization(
        mode: CharacterMode.newCharacter,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Maya',
      ),
    );

    // Inicialmente no tiene imagen
    expect(cuento.escenas.first.imageUrl, isNull);

    // Asociar imagen a escena 1
    final asociada = cuento.asociarImagenAEscena(
      1,
      'https://storage.supabase.co/escena1.webp',
    );
    expect(asociada, isTrue);
    expect(
      cuento.obtenerEscena(1)!.imageUrl,
      'https://storage.supabase.co/escena1.webp',
    );

    // Avanzar a escena 2
    final escena2 = await ctrl.generarSiguienteEscena(
      cuento: cuento,
      escenaActual: cuento.escenas.first,
      decision: cuento.escenas.first.opciones.first,
    );
    expect(escena2.numero, 2);

    // Volver a consultar la escena 1: la imagen se conserva intacta
    expect(
      cuento.obtenerEscena(1)!.imageUrl,
      'https://storage.supabase.co/escena1.webp',
    );
  });

  group('Cierre narrativo real y validación de escena 4', () {
    test(
      'esFinalAbierto detecta correctamente expresiones de final inconcluso',
      () {
        expect(
          StoryController.esFinalAbierto(
            'Pedro se quedó pensando cuál sería el siguiente paso para descubrir la verdad.',
          ),
          isTrue,
        );
        expect(
          StoryController.esFinalAbierto(
            'El joven héroe decidió investigar a dónde conducía la extraña cueva.',
          ),
          isTrue,
        );
        expect(
          StoryController.esFinalAbierto(
            'Nadie sabía qué ocurrirá en el futuro.',
          ),
          isTrue,
        );
        expect(
          StoryController.esFinalAbierto(
            'Esta aventura continuará muy pronto.',
          ),
          isTrue,
        );
        expect(
          StoryController.esFinalAbierto(
            'Pedro tendrá que descubrir el secreto.',
          ),
          isTrue,
        );
        expect(
          StoryController.esFinalAbierto(
            'Aún debía averiguar quién cerró la llave.',
          ),
          isTrue,
        );

        // Cierres conclusivos válidos no deben ser detectados como abiertos
        expect(
          StoryController.esFinalAbierto(
            'Pedro siguió la tubería y descubrió que una válvula rota desviaba el agua. Con ayuda de los vecinos lograron repararla y el tanque volvió a llenarse. Pedro comprendió que observar con atención y trabajar en equipo resolvió el misterio.',
          ),
          isFalse,
        );
      },
    );

    test('cuando la primera generación de escena 4 es abierta, StoryController reintenta y obtiene un desenlace conclusivo', () async {
      final flakyAi = MockFlakyEndingAiService(fallarSiempre: false);
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: flakyAi,
        narrativaConfig: const NarrativaConfig(maxEscenas: 4, maxReintentos: 2),
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Texto de prueba',
        tituloDetectado: 'Aventura de prueba',
      );

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-retry-001',
        datosPdf: pdfData,
        personalizacion: CharacterCustomization(
          mode: CharacterMode.newCharacter,
          visualMode: CharacterVisualMode.automatic,
          nombrePersonaje: 'Pedro',
        ),
      );

      // Generar Escena 2
      final escena2 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: cuento.escenas.last.opciones.first,
      );

      // Generar Escena 3
      final escena3 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: escena2,
        decision: escena2.opciones.first,
      );

      // Generar Escena 4: el primer intento de la IA devolverá un final abierto,
      // por lo que StoryController debe rechazarlo y reintentar.
      final escena4 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: escena3,
        decision: escena3.opciones.first,
      );

      expect(flakyAi.llamadasGenerarEscena4, 2);
      expect(escena4.numero, 4);
      expect(escena4.esFinal, isTrue);
      expect(escena4.opciones, isEmpty);
      expect(
        escena4.contenido,
        contains('resolvió el problema del agua con ayuda de los vecinos'),
      );
    });

    test('si la IA falla en generar un desenlace cerrado en todos los intentos, StoryController lanza error y no fuerza un final falso', () async {
      final alwaysOpenAi = MockFlakyEndingAiService(fallarSiempre: true);
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: alwaysOpenAi,
        narrativaConfig: const NarrativaConfig(maxEscenas: 4, maxReintentos: 1),
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Texto de prueba',
        tituloDetectado: 'Aventura de prueba',
      );

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-fail-001',
        datosPdf: pdfData,
        personalizacion: CharacterCustomization(
          mode: CharacterMode.newCharacter,
          visualMode: CharacterVisualMode.automatic,
          nombrePersonaje: 'Pedro',
        ),
      );

      final escena2 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.last,
        decision: cuento.escenas.last.opciones.first,
      );

      final escena3 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: escena2,
        decision: escena2.opciones.first,
      );

      // Al no obtener desenlace válido, no se crea escena 4 con final falso
      expect(
        () => ctrl.generarSiguienteEscena(
          cuento: cuento,
          escenaActual: escena3,
          decision: escena3.opciones.first,
        ),
        throwsA(isA<StateError>()),
      );

      expect(cuento.escenas.length, 3);
      expect(cuento.obtenerEscena(4), isNull);
    });

    test('maxEscenas se mantiene estrictamente en 4', () {
      const config = NarrativaConfig();
      expect(config.maxEscenas, 4);
    });

    test('NarrativaConfig incluye parámetros de sincronización TTS palabrasPorMinutoBase, velocidadTtsBase e intervaloVisualMinimoMs', () {
      const config = NarrativaConfig();
      expect(config.palabrasPorMinutoBase, 140);
      expect(config.velocidadTtsBase, 0.5);
      expect(config.intervaloVisualMinimoMs, 30);

      final custom = config.copyWith(
        palabrasPorMinutoBase: 150,
        velocidadTtsBase: 0.6,
        intervaloVisualMinimoMs: 32,
        factorAjusteRevelado: 0.88,
      );
      expect(custom.palabrasPorMinutoBase, 150);
      expect(custom.velocidadTtsBase, 0.6);
      expect(custom.intervaloVisualMinimoMs, 32);
      expect(custom.factorAjusteRevelado, 0.88);
    });

    test('NarrativaConfig define factorAjusteRevelado por defecto en 0.90', () {
      const config = NarrativaConfig();
      expect(config.factorAjusteRevelado, 0.90);
    });

    test('renameOriginal conserva la identidad original y no marca esPersonajeNuevo', () async {
      final fakeAi = FakeAiService();
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: fakeAi,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Texto sobre Ranj el niño curioso en el bosque.',
        tituloDetectado: 'El gran viaje de Ranj',
        tituloOriginal: 'Ranj\'s Big Trip',
        personajePrincipalDetectado: 'Ranj',
        descripcionPersonaje:
            'Un niño curioso de 8 años con capa roja y gran agilidad.',
        resumen: 'Ranj explora el bosque en busca de un manantial.',
        escenario: 'Bosque de los pinos',
        conflictoPrincipal: 'El tanque de agua está vacío.',
        finalOriginal: 'Ranj llena el tanque con los vecinos.',
      );

      // El usuario elige CAMBIAR ÚNICAMENTE SU NOMBRE (Ranj -> Pedro)
      final personalizacion = CharacterCustomization(
        mode: CharacterMode.renameOriginal,
        visualMode: CharacterVisualMode.pdfImages,
        nombrePersonaje: 'Pedro',
        personajeOriginal: 'Ranj',
      );

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-rename-001',
        datosPdf: pdfData,
        personalizacion: personalizacion,
      );

      // Semántica de renameOriginal:
      expect(cuento.personajePrincipal, 'Pedro');
      expect(cuento.personajeOriginal, 'Ranj');
      expect(cuento.esPersonajeNuevo, isFalse);
      expect(cuento.fueRenombrado, isTrue);
      expect(cuento.requiereSustitucionNombreOriginal, isTrue);

      // Conserva la descripción y apariencia del personaje original
      expect(cuento.descripcionPersonaje, pdfData.descripcionPersonaje);

      // Parámetros enviados a la IA en la escena inicial
      expect(fakeAi.ultimoPersonajePrincipalRecibido, 'Pedro');
      expect(fakeAi.ultimoPersonajeOriginalRecibido, 'Ranj');
      expect(fakeAi.ultimoEsPersonajeNuevoRecibido, isFalse);
      expect(
        fakeAi.ultimaDescripcionPersonajeRecibida,
        pdfData.descripcionPersonaje,
      );

      // Generar escena siguiente también conserva identidad
      final escena2 = await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: cuento.escenas.first.opciones.first,
      );

      expect(escena2.contenido, isNotEmpty);
      expect(fakeAi.ultimoPersonajePrincipalRecibido, 'Pedro');
      expect(fakeAi.ultimoPersonajeOriginalRecibido, 'Ranj');
      expect(fakeAi.ultimoEsPersonajeNuevoRecibido, isFalse);
      expect(
        fakeAi.ultimaDescripcionPersonajeRecibida,
        pdfData.descripcionPersonaje,
      );
    });

    test('newCharacter se mantiene conceptualmente diferente con descripción propia', () async {
      final fakeAi = FakeAiService();
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: fakeAi,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Texto sobre Ranj el niño curioso en el bosque.',
        tituloDetectado: 'El gran viaje de Ranj',
        personajePrincipalDetectado: 'Ranj',
        descripcionPersonaje: 'Un niño de 8 años con capa roja.',
      );

      const descripcionPropia =
          'Una astronauta inventora con traje espacial brillante y gafas mágicas.';

      // El usuario elige CREAR MI PROPIO PROTAGONISTA
      final personalizacion = CharacterCustomization(
        mode: CharacterMode.newCharacter,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Valeria',
        personajeOriginal: 'Ranj',
        descripcionPersonaje: descripcionPropia,
      );

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-new-001',
        datosPdf: pdfData,
        personalizacion: personalizacion,
      );

      // Semántica de newCharacter:
      expect(cuento.personajePrincipal, 'Valeria');
      expect(cuento.personajeOriginal, 'Ranj');
      expect(cuento.esPersonajeNuevo, isTrue);
      expect(
        cuento.fueRenombrado,
        isFalse,
      ); // No es simplemente un renombrado, es nuevo
      expect(
        cuento.requiereSustitucionNombreOriginal,
        isTrue,
      ); // Reemplaza menciones residuales de Ranj

      // NO hereda la apariencia/personalidad del personaje original
      expect(cuento.descripcionPersonaje, descripcionPropia);
      expect(
        cuento.descripcionPersonaje,
        isNot(equals(pdfData.descripcionPersonaje)),
      );

      // Parámetros enviados a la IA
      expect(fakeAi.ultimoPersonajePrincipalRecibido, 'Valeria');
      expect(fakeAi.ultimoEsPersonajeNuevoRecibido, isTrue);
      expect(fakeAi.ultimaDescripcionPersonajeRecibida, descripcionPropia);

      // En siguiente escena se conserva esPersonajeNuevo
      await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: cuento.escenas.first.opciones.first,
      );

      expect(fakeAi.ultimoEsPersonajeNuevoRecibido, isTrue);
      expect(fakeAi.ultimaDescripcionPersonajeRecibida, descripcionPropia);
    });

    test('nombre "Pepe" y descripción "Lleva una mochila roja" permanecen estrictamente separados sin concatenar', () async {
      final fakeAi = FakeAiService();
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: fakeAi,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Ranj exploraba el bosque...',
        tituloDetectado: 'La aventura',
        personajePrincipalDetectado: 'Ranj',
      );

      final personalizacion = CharacterCustomization(
        mode: CharacterMode.newCharacter,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: '   Pepe    ',
        descripcionPersonaje: '  Lleva una mochila roja.  ',
        personajeOriginal: 'Ranj',
      );

      // Verificación en modelo CharacterCustomization
      expect(personalizacion.nombrePersonaje, 'Pepe');
      expect(personalizacion.nombrePersonaje, isNot(contains('mochila roja')));
      expect(personalizacion.descripcionPersonaje, 'Lleva una mochila roja.');

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pepe-001',
        datosPdf: pdfData,
        personalizacion: personalizacion,
      );

      // Verificación en Cuento:
      expect(cuento.personajePrincipal, 'Pepe');
      expect(cuento.personajePrincipal, isNot(contains('mochila')));
      expect(cuento.personajePrincipal, isNot(equals('Pepe mochila roja')));
      expect(cuento.descripcionPersonaje, 'Lleva una mochila roja.');

      // Verificación en payload enviado al AiService:
      expect(fakeAi.ultimoPersonajePrincipalRecibido, 'Pepe');
      expect(
        fakeAi.ultimoPersonajePrincipalRecibido,
        isNot(contains('mochila')),
      );
      expect(
        fakeAi.ultimaDescripcionPersonajeRecibida,
        'Lleva una mochila roja.',
      );

      // Generar escena siguiente también mantiene estricta separación:
      await ctrl.generarSiguienteEscena(
        cuento: cuento,
        escenaActual: cuento.escenas.first,
        decision: cuento.escenas.first.opciones.first,
      );

      expect(fakeAi.ultimoPersonajePrincipalRecibido, 'Pepe');
      expect(
        fakeAi.ultimaDescripcionPersonajeRecibida,
        'Lleva una mochila roja.',
      );
    });

    test('cambiar a renameOriginal no hereda ni reutiliza la descripción de un personaje nuevo', () async {
      final fakeAi = FakeAiService();
      final ctrl = StoryController(
        narrativaService: NarrativaService(),
        cuentoRepository: repository,
        documentService: DocumentService(),
        aiService: fakeAi,
      );

      final pdfData = PdfStoryData(
        nombreArchivo: 'cuento.pdf',
        textoExtraido: 'Ranj exploraba el bosque...',
        tituloDetectado: 'El gran viaje de Ranj',
        personajePrincipalDetectado: 'Ranj',
        descripcionPersonaje: 'Un niño curioso de 8 años con capa roja.',
      );

      // Si por alguna razón se intentara pasar descripcionPersonaje en modo renameOriginal
      final personalizacion = CharacterCustomization(
        mode: CharacterMode.renameOriginal,
        visualMode: CharacterVisualMode.automatic,
        nombrePersonaje: 'Pedro',
        descripcionPersonaje: 'mochila roja',
        personajeOriginal: 'Ranj',
      );

      // CharacterCustomization rechaza descripción en modo renameOriginal
      expect(personalizacion.descripcionPersonaje, isNull);

      final cuento = await ctrl.crearCuentoDesdePdfProcesadoDemo(
        id: 'cuento-pedro-001',
        datosPdf: pdfData,
        personalizacion: personalizacion,
      );

      // Conserva la descripción original del cuento
      expect(cuento.descripcionPersonaje, pdfData.descripcionPersonaje);
      expect(cuento.descripcionPersonaje, isNot(contains('mochila roja')));
      expect(
        fakeAi.ultimaDescripcionPersonajeRecibida,
        pdfData.descripcionPersonaje,
      );
    });
  });
}
