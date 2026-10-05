import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tesis_investigacion/services/narracion_service.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  void Function()? _completionHandler;
  final List<String> textosHablados = [];

  @override
  void setCompletionHandler(dynamic handler) {
    _completionHandler = handler as void Function()?;
  }

  @override
  void setCancelHandler(dynamic handler) {}

  @override
  void setErrorHandler(dynamic handler) {}

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    textosHablados.add(text);
    Future.microtask(() {
      _completionHandler?.call();
    });
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NarracionService', () {
    late NarracionService service;

    setUp(() {
      service = NarracionService();
    });

    test('segmentarEnFrases divide texto por oraciones completas y signos de puntuación', () {
      const texto =
          'Ranj llegó al pozo. Estaba completamente seco! ¿Dónde estará el agua? Pronto descubrió un sendero misterioso.';

      final frases = service.segmentarEnFrases(texto);

      expect(frases.length, 4);
      expect(frases[0], 'Ranj llegó al pozo.');
      expect(frases[1], 'Estaba completamente seco!');
      expect(frases[2], '¿Dónde estará el agua?');
      expect(frases[3], 'Pronto descubrió un sendero misterioso.');
    });

    test('segmentarEnFrases maneja saltos de línea y texto infantil de varias líneas', () {
      const texto =
          'Había una vez un pequeño detective.\n\nTodos los días salía a explorar el campo: buscaba huellas y pistas.';

      final frases = service.segmentarEnFrases(texto);

      expect(frases.length, greaterThanOrEqualTo(2));
      expect(frases.first, contains('pequeño detective'));
    });

    test(
      'segmentarEnFrases retorna lista vacía si el texto está en blanco',
      () {
        expect(service.segmentarEnFrases('   '), isEmpty);
        expect(service.segmentarEnFrases(''), isEmpty);
      },
    );

    test('estado inicial de narración es detenido', () {
      expect(service.estado, EstadoNarracion.detenido);
      expect(service.estaReproduciendo, isFalse);
      expect(service.indiceFraseActual, -1);
      expect(service.indiceSegmentoActual, -1);
    });

    // -------------------------------------------------------------
    // PRUEBAS ESPECÍFICAS DE MEJORA DE NARRACIÓN (REQUISITOS 1 A 7)
    // -------------------------------------------------------------

    test('1. segmentación de una oración corta', () {
      const texto = 'Ranj corrió rápidamente.';
      final segmentos = service.segmentarTexto(texto);

      expect(segmentos.length, 1);
      expect(segmentos.first.texto, 'Ranj corrió rápidamente.');
      expect(segmentos.first.indiceInicio, 0);
      expect(segmentos.first.indiceFin, texto.length);
    });

    test('2. segmentación de una oración larga', () {
      const texto =
          'Ranj corrió rápidamente hacia la colina para buscar una pista.';
      final segmentos = service.segmentarTexto(texto);

      expect(segmentos.length, 3);
      expect(segmentos[0].texto, 'Ranj corrió rápidamente');
      expect(segmentos[1].texto, 'hacia la colina');
      expect(segmentos[2].texto, 'para buscar una pista.');

      for (final seg in segmentos) {
        final numPalabras = seg.texto.trim().split(RegExp(r'\s+')).length;
        expect(numPalabras, inInclusiveRange(2, 5));
      }
    });

    test('3. signos , . ! ? : ;', () {
      const texto =
          '¡Mira, Ranj! ¿Qué es eso? Es una pista: una llave dorada; brilla mucho.';
      final segmentos = service.segmentarTexto(texto);

      expect(segmentos.length, greaterThanOrEqualTo(4));
      for (final seg in segmentos) {
        final numPalabras = seg.texto.trim().split(RegExp(r'\s+')).length;
        expect(numPalabras, inInclusiveRange(1, 5));
      }

      final textoConcatenado = segmentos.map((s) => s.texto).join(' ');
      expect(textoConcatenado, contains('¡Mira,'));
      expect(textoConcatenado, contains('Ranj!'));
      expect(textoConcatenado, contains('¿Qué es eso?'));
      expect(textoConcatenado, contains(':'));
      expect(textoConcatenado, contains(';'));
    });

    test('4. conservación exacta del texto al reconstruir segmentos', () {
      const texto =
          'Había una vez un pequeño detective.\n\nTodos los días salía a explorar el campo: buscaba huellas y pistas misteriosas entre las flores.';
      final segmentos = service.segmentarTexto(texto);

      // Cada segmento coincide exactamente con su porción en el texto original
      for (final seg in segmentos) {
        expect(texto.substring(seg.indiceInicio, seg.indiceFin), seg.texto);
      }

      // Reconstrucción estática de texto
      final reconstruido = NarracionService.reconstruirTexto(
        original: texto,
        segmentos: segmentos,
      );
      expect(reconstruido, texto);

      // Reconstrucción mediante InlineSpan para renderizado visual
      final spans = service.construirTextSpans(
        texto: texto,
        segmentos: segmentos,
        indiceActivo: 1,
        estiloNormal: const TextStyle(fontSize: 20),
        estiloResaltado: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
      final textoDeSpans = spans.map((s) => (s as TextSpan).text).join();
      expect(textoDeSpans, texto);
    });

    test('5. texto con nombres propios', () {
      const texto =
          'Ayer por la tarde, Don Quijote y Sancho Panza salieron a recorrer el bosque.';
      final segmentos = service.segmentarTexto(texto);

      for (final seg in segmentos) {
        if (seg.texto.contains('Don')) {
          expect(seg.texto, contains('Quijote'));
        }
        if (seg.texto.contains('Sancho')) {
          expect(seg.texto, contains('Panza'));
        }
      }
    });

    test('6. textos vacíos', () {
      expect(service.segmentarTexto(''), isEmpty);
      expect(service.segmentarTexto('   '), isEmpty);
      expect(service.segmentarTexto('\n\n\t  \r\n'), isEmpty);
    });

    test('7. cambio de segmento activo', () async {
      final fakeTts = FakeFlutterTts();
      final serviceConFake = NarracionService(tts: fakeTts);
      const texto =
          'Ranj corrió rápidamente hacia la colina para buscar una pista.';

      final indicesRegistrados = <int>[];
      serviceConFake.onSegmentoCambio = (indice) {
        indicesRegistrados.add(indice);
      };

      expect(serviceConFake.indiceSegmentoActual, -1);

      // Narrar y esperar ciclo completo
      await serviceConFake.narrarEscena(contenido: texto);

      // Se registraron los segmentos en orden ascendente y al final volvió a -1
      expect(indicesRegistrados, contains(0));
      expect(indicesRegistrados, contains(1));
      expect(indicesRegistrados, contains(2));
      expect(indicesRegistrados.last, -1);
      expect(serviceConFake.indiceSegmentoActual, -1);
      expect(serviceConFake.estado, EstadoNarracion.detenido);
    });

    // -------------------------------------------------------------
    // PRUEBAS DE NARRACIÓN CONTINUA Y REVELADO PROGRESIVO DE TEXTO
    // -------------------------------------------------------------

    test('narrarTextoCompleto envía el texto completo al TTS sin micro-fragmentación', () async {
      final fakeTts = FakeFlutterTts();
      final serviceConFake = NarracionService(tts: fakeTts);
      const textoLargo =
          'Pedro observó el tanque de agua completamente vacío y decidió llamar a sus amigos para investigar el misterio del pozo.';

      await serviceConFake.narrarTextoCompleto(textoLargo);

      expect(fakeTts.textosHablados.length, 1);
      expect(fakeTts.textosHablados.first, textoLargo);
      expect(serviceConFake.estado, EstadoNarracion.detenido);
    });

    test('revelado acumulativo conserva exactamente el texto original', () {
      const texto =
          'Pedro observó el tanque vacío y decidió emprender una expedición por la colina.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      while (!ctrl.estaCompleto) {
        ctrl.avanzarPaso();
      }

      expect(ctrl.textoVisible, texto);
      expect(ctrl.estaCompleto, isTrue);
    });

    test(
      'las letras mostradas nunca desaparecen durante avance acumulativo',
      () {
        const texto =
            'Pedro observó el tanque vacío y decidió actuar con gran valentía.';
        final ctrl = ControladorReveladoTexto(textoCompleto: texto);

        var anterior = ctrl.textoVisible;
        expect(anterior, isNotEmpty);

        while (!ctrl.estaCompleto) {
          ctrl.avanzarPaso();
          final actual = ctrl.textoVisible;

          // Cada paso conserva exactamente todo lo mostrado anteriormente como prefijo
          expect(
            actual.startsWith(anterior),
            isTrue,
            reason:
                'El texto anterior "$anterior" debe ser prefijo de "$actual"',
          );
          expect(actual.length, greaterThanOrEqualTo(anterior.length));
          anterior = actual;
        }

        expect(ctrl.textoVisible, texto);
      },
    );

    test('revelado acumulativo respeta caracteres Unicode con tildes (áéíóú) y eñes (ñ)', () {
      const texto = 'El niño soñó con un pájaro en el jardín de la abuela.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      expect(ctrl.totalCaracteres, texto.characters.length);

      while (!ctrl.estaCompleto) {
        ctrl.avanzarPaso(cantidad: 1);
        // Asegurarse de que el texto visible sea siempre un prefijo válido en caracteres
        final count = ctrl.caracteresMostrados;
        expect(ctrl.textoVisible, texto.characters.take(count).toString());
      }

      expect(ctrl.textoVisible, texto);
      expect(ctrl.textoVisible, contains('niño'));
      expect(ctrl.textoVisible, contains('soñó'));
      expect(ctrl.textoVisible, contains('pájaro'));
      expect(ctrl.textoVisible, contains('jardín'));
    });

    test('revelado acumulativo maneja emojis sin romper grapheme clusters', () {
      const texto = 'Pedro encontró agua fresca 💧 y una estrella mágica 🌟.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      expect(ctrl.totalCaracteres, texto.characters.length);

      // Avanzamos paso a paso comprobando que los emojis no se fragmenten en bytes UTF-16 inválidos
      while (!ctrl.estaCompleto) {
        ctrl.avanzarPaso(cantidad: 1);
        final visible = ctrl.textoVisible;
        expect(visible.characters.length, ctrl.caracteresMostrados);
      }

      expect(ctrl.textoVisible, texto);
      expect(ctrl.textoVisible, contains('💧'));
      expect(ctrl.textoVisible, contains('🌟'));
    });

    test(
      'revelado acumulativo preserva saltos de línea y signos de puntuación',
      () {
        const texto = 'Capítulo 1:\nEl inicio del viaje.\n\n¿Estás listo? ¡Sí!';
        final ctrl = ControladorReveladoTexto(textoCompleto: texto);

        while (!ctrl.estaCompleto) {
          ctrl.avanzarPaso();
        }

        expect(ctrl.textoVisible, texto);
        expect(ctrl.textoVisible, contains('\n'));
        expect(ctrl.textoVisible, contains('¿Estás listo?'));
      },
    );

    test(
      'mostrarCompletoInmediatamente muestra la escena completa sin animación',
      () {
        const texto = 'Esta escena ya fue leída anteriormente.';
        final ctrl = ControladorReveladoTexto(
          textoCompleto: texto,
          mostrarCompletoInmediatamente: true,
        );

        expect(ctrl.estaCompleto, isTrue);
        expect(ctrl.textoVisible, texto);
        expect(ctrl.estaAnimando, isFalse);
      },
    );

    test(
      'finalizar la animación con mostrarTodo muestra todo inmediatamente',
      () {
        const texto = 'Una aventura fantástica en el bosque encantado.';
        final ctrl = ControladorReveladoTexto(textoCompleto: texto);

        expect(ctrl.estaCompleto, isFalse);
        expect(ctrl.textoVisible, isNot(equals(texto)));

        ctrl.mostrarTodo();

        expect(ctrl.estaCompleto, isTrue);
        expect(ctrl.textoVisible, texto);
        expect(ctrl.estaAnimando, isFalse);
      },
    );

    test('detener muestra todo o permite mostrarlo inmediatamente', () {
      const texto = 'El misterio de la cueva escondida y el tesoro perdido.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      ctrl.iniciar();
      expect(ctrl.estaAnimando, isTrue);

      // Detener solicitando mostrar todo
      ctrl.detener(mostrarTextoCompleto: true);

      expect(ctrl.estaAnimando, isFalse);
      expect(ctrl.estaCompleto, isTrue);
      expect(ctrl.textoVisible, texto);
    });

    test('TTS 0.25 produce revelado visual más lento que TTS 0.50', () {
      const texto =
          'Había una vez en un valle encantado una pequeña ardilla que buscaba bellotas doradas para el invierno.';
      final ctrlLento = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.25,
      );
      final ctrlMedio = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
      );

      // A velocidad lenta (0.25), la cadencia de caracteres por segundo debe ser menor
      // y el intervalo de refresco msPorTick debe ser mayor
      expect(
        ctrlLento.caracteresPorSegundo,
        lessThan(ctrlMedio.caracteresPorSegundo),
      );
      expect(ctrlLento.msPorTick, greaterThanOrEqualTo(ctrlMedio.msPorTick));
    });

    test('TTS 0.85 produce revelado visual más rápido que TTS 0.50', () {
      const texto =
          'Había una vez en un valle encantado una pequeña ardilla que buscaba bellotas doradas para el invierno.';
      final ctrlMedio = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
      );
      final ctrlRapido = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.85,
      );

      // A velocidad rápida (0.85), la cadencia de caracteres por segundo debe ser mayor
      expect(
        ctrlRapido.caracteresPorSegundo,
        greaterThan(ctrlMedio.caracteresPorSegundo),
      );
    });

    test('cambiar velocidad durante animación conserva progreso sin reiniciar ni retroceder', () {
      const texto =
          'Pedro caminó cuidadosamente por el sendero hacia la colina más alta.';
      final ctrl = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
      );

      // Avanzar varios pasos
      for (var i = 0; i < 15; i++) {
        ctrl.avanzarPaso();
      }

      final caracteresMostradosPrevios = ctrl.caracteresMostrados;
      final textoMostradoPrevio = ctrl.textoVisible;
      expect(caracteresMostradosPrevios, greaterThan(1));

      // El usuario cambia el slider a velocidad rápida 0.85 en curso
      ctrl.actualizarVelocidad(0.85);

      // El progreso se conserva intacto
      expect(ctrl.caracteresMostrados, caracteresMostradosPrevios);
      expect(ctrl.textoVisible, textoMostradoPrevio);
      expect(ctrl.velocidadTts, 0.85);

      // Siguiente avance acumula sobre lo que ya estaba mostrado sin retroceder
      ctrl.avanzarPaso();
      expect(ctrl.caracteresMostrados, greaterThan(caracteresMostradosPrevios));
      expect(ctrl.textoVisible.startsWith(textoMostradoPrevio), isTrue);
    });

    test('revelado sigue siendo estrictamente acumulativo y monótono', () {
      const texto =
          'Había una vez en una montaña lejana un manantial cristalino.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      String anterior = '';
      while (!ctrl.estaCompleto) {
        ctrl.avanzarPaso();
        final actual = ctrl.textoVisible;
        expect(actual.startsWith(anterior), isTrue);
        expect(actual.length, greaterThanOrEqualTo(anterior.length));
        anterior = actual;
      }
      expect(ctrl.textoVisible, texto);
    });

    test('cuando TTS termina antes que la animación, se muestra inmediatamente el texto completo', () {
      const texto = 'Un cuento maravilloso donde el final llega rápido.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);

      // Inicia la animación y solo avanza un paso inicial
      ctrl.avanzarPaso();
      expect(ctrl.estaCompleto, isFalse);
      expect(ctrl.textoVisible.length, lessThan(texto.length));

      // Simula la finalización del TTS (que invoca mostrarTodo())
      ctrl.mostrarTodo();

      expect(ctrl.estaCompleto, isTrue);
      expect(ctrl.textoVisible, texto);
      expect(ctrl.estaAnimando, isFalse);
    });

    test(
      'cuando la animación termina antes que TTS, el texto permanece completo',
      () {
        const texto = 'Texto corto que termina de revelarse pronto.';
        final ctrl = ControladorReveladoTexto(textoCompleto: texto);

        // Completa todos los pasos de la animación
        while (!ctrl.estaCompleto) {
          ctrl.avanzarPaso();
        }

        expect(ctrl.estaCompleto, isTrue);
        expect(ctrl.textoVisible, texto);

        // Aunque continúe el tiempo o se invoque avanzarPaso(), el texto permanece completo
        ctrl.avanzarPaso();
        expect(ctrl.textoVisible, texto);
        expect(ctrl.estaCompleto, isTrue);
      },
    );

    test('detener la narración muestra todo el texto inmediatamente', () {
      const texto = 'Pedro decidió detener la narración a mitad del camino.';
      final ctrl = ControladorReveladoTexto(textoCompleto: texto);
      ctrl.iniciar();

      expect(ctrl.estaAnimando, isTrue);
      expect(ctrl.estaCompleto, isFalse);

      ctrl.detener(mostrarTextoCompleto: true);

      expect(ctrl.estaAnimando, isFalse);
      expect(ctrl.estaCompleto, isTrue);
      expect(ctrl.textoVisible, texto);
    });

    test('factorAjusteRevelado = 0.90 acelera la cadencia visual aproximadamente un 10% respecto a 1.00', () {
      const texto =
          'Había una vez en un valle encantado una pequeña ardilla que buscaba bellotas doradas para el invierno.';

      final paramsBase = ControladorReveladoTexto.calcularParametrosVisuales(
        totalCaracteres: texto.characters.length,
        totalPalabras: 16,
        velocidadTts: 0.50,
        factorAjusteRevelado: 1.00,
      );

      final paramsAjustado =
          ControladorReveladoTexto.calcularParametrosVisuales(
            totalCaracteres: texto.characters.length,
            totalPalabras: 16,
            velocidadTts: 0.50,
            factorAjusteRevelado: 0.90,
          );

      final cadenciaBase =
          (paramsBase.caracteresPorTick * 1000.0) / paramsBase.msPorTick;
      final cadenciaAjustada =
          (paramsAjustado.caracteresPorTick * 1000.0) /
          paramsAjustado.msPorTick;

      expect(cadenciaAjustada, greaterThan(cadenciaBase));

      final ctrl100 = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
        factorAjusteRevelado: 1.00,
      );
      final ctrl090 = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
        factorAjusteRevelado: 0.90,
      );

      expect(
        ctrl090.caracteresPorSegundo,
        greaterThan(ctrl100.caracteresPorSegundo),
      );
    });

    test('revelado visual escala congruentemente en los tres ritmos TTS: 0.25 (lento), 0.50 (normal) y 0.85 (rápido)', () {
      const texto =
          'En un pueblo muy lejano, las campanas sonaban anunciando la llegada de los viajeros.';

      final ctrlLento = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.25,
        factorAjusteRevelado: 0.90,
      );
      final ctrlNormal = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.50,
        factorAjusteRevelado: 0.90,
      );
      final ctrlRapido = ControladorReveladoTexto(
        textoCompleto: texto,
        velocidad: 0.85,
        factorAjusteRevelado: 0.90,
      );

      expect(
        ctrlLento.caracteresPorSegundo,
        lessThan(ctrlNormal.caracteresPorSegundo),
      );
      expect(
        ctrlNormal.caracteresPorSegundo,
        lessThan(ctrlRapido.caracteresPorSegundo),
      );
    });
  });
}
