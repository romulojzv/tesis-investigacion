import 'dart:async';

// ignore: unnecessary_import
import 'package:characters/characters.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum EstadoNarracion { detenido, reproduciendo, pausado, error }

class VozInfo {
  final String nombre;
  final String locale;
  final String etiqueta;

  const VozInfo({
    required this.nombre,
    required this.locale,
    required this.etiqueta,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VozInfo &&
          runtimeType == other.runtimeType &&
          nombre == other.nombre &&
          locale == other.locale;

  @override
  int get hashCode => nombre.hashCode ^ locale.hashCode;
}

/// Representa un fragmento breve de texto para acompañamiento visual sincronizado.
/// Conserva con precisión quirúrgica los índices en el texto original.
class NarracionSegmento {
  final String texto;
  final int indiceInicio;
  final int indiceFin;

  const NarracionSegmento({
    required this.texto,
    required this.indiceInicio,
    required this.indiceFin,
  });

  int get longitud => texto.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NarracionSegmento &&
          runtimeType == other.runtimeType &&
          texto == other.texto &&
          indiceInicio == other.indiceInicio &&
          indiceFin == other.indiceFin;

  @override
  int get hashCode =>
      texto.hashCode ^ indiceInicio.hashCode ^ indiceFin.hashCode;

  @override
  String toString() => 'NarracionSegmento("$texto", $indiceInicio, $indiceFin)';
}

class _TokenPalabra {
  final String texto;
  final int inicio;
  final int fin;
  final bool sigueSaltoLinea;

  const _TokenPalabra({
    required this.texto,
    required this.inicio,
    required this.fin,
    required this.sigueSaltoLinea,
  });

  static final RegExp _regexFinOracion = RegExp(r'''[.!?]+[\)\]»”"'\s]*$''');
  static final RegExp _regexPuntuacionIntermedia = RegExp(
    r'''[,;:]+[\)\]»”"'\s]*$''',
  );

  /// Si termina con puntuación fuerte de fin de oración (. ! ?)
  bool get esFinOracion => _regexFinOracion.hasMatch(texto);

  /// Si termina con puntuación intermedia (, ; :)
  bool get esPuntuacionIntermedia => _regexPuntuacionIntermedia.hasMatch(texto);
}

class _ResultadoCorte {
  final int score;
  final List<int> cortes;

  const _ResultadoCorte({required this.score, required this.cortes});
}

class NarracionService {
  final FlutterTts _tts;

  EstadoNarracion _estado = EstadoNarracion.detenido;
  List<VozInfo> _vocesDisponibles = [];
  VozInfo? _vozSeleccionada;
  double _velocidad = 0.5; // Velocidad amigable para primaria (0.0 a 1.0)
  int _indiceSegmentoActual = -1;
  List<NarracionSegmento> _segmentosActuales = [];

  Completer<void>? _fraseCompleter;
  bool _detencionSolicitada = false;

  void Function(int indiceSegmento)? onSegmentoCambio;
  void Function(int indiceFrase)? onFraseCambio;
  void Function(EstadoNarracion estado)? onEstadoCambio;

  NarracionService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _configurarHandlers();
  }

  EstadoNarracion get estado => _estado;
  List<VozInfo> get vocesDisponibles => List.unmodifiable(_vocesDisponibles);
  VozInfo? get vozSeleccionada => _vozSeleccionada;
  double get velocidad => _velocidad;
  int get indiceSegmentoActual => _indiceSegmentoActual;
  int get indiceFraseActual => _indiceSegmentoActual;
  List<NarracionSegmento> get segmentosActuales =>
      List.unmodifiable(_segmentosActuales);
  List<String> get frasesActuales =>
      _segmentosActuales.map((s) => s.texto).toList();
  bool get estaReproduciendo => _estado == EstadoNarracion.reproduciendo;

  void _configurarHandlers() {
    _tts.setCompletionHandler(() {
      if (_fraseCompleter != null && !_fraseCompleter!.isCompleted) {
        _fraseCompleter!.complete();
      }
    });

    _tts.setCancelHandler(() {
      if (_fraseCompleter != null && !_fraseCompleter!.isCompleted) {
        _fraseCompleter!.complete();
      }
    });

    _tts.setErrorHandler((dynamic msg) {
      debugPrint('Error en sintetizador de voz: $msg');
      if (_fraseCompleter != null && !_fraseCompleter!.isCompleted) {
        _fraseCompleter!.complete();
      }
      _actualizarEstado(EstadoNarracion.error);
    });
  }

  void _actualizarEstado(EstadoNarracion nuevoEstado) {
    _estado = nuevoEstado;
    onEstadoCambio?.call(_estado);
  }

  /// Inicializa la síntesis de voz y detecta voces en español de Windows
  Future<void> inicializar() async {
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(_velocidad);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      final dynamic voicesRaw = await _tts.getVoices;
      final listaVoces = <VozInfo>[];

      if (voicesRaw is List) {
        for (final v in voicesRaw) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = (v['locale'] ?? v['lang'] ?? '').toString();

            // Filtrar voces en español disponibles en el sistema
            final esEspanol =
                locale.toLowerCase().startsWith('es') ||
                name.toLowerCase().contains('spanish') ||
                name.toLowerCase().contains('español') ||
                name.toLowerCase().contains('helena') ||
                name.toLowerCase().contains('sabina') ||
                name.toLowerCase().contains('raul') ||
                name.toLowerCase().contains('pablo') ||
                name.toLowerCase().contains('laura');

            if (esEspanol && name.isNotEmpty) {
              String etiqueta = name;
              if (name.contains('Helena') ||
                  name.contains('Sabina') ||
                  name.contains('Laura')) {
                etiqueta = '$name (Femenina)';
              } else if (name.contains('Raul') || name.contains('Pablo')) {
                etiqueta = '$name (Masculina)';
              }

              listaVoces.add(
                VozInfo(
                  nombre: name,
                  locale: locale.isNotEmpty ? locale : 'es-ES',
                  etiqueta: etiqueta,
                ),
              );
            }
          }
        }
      }

      _vocesDisponibles = listaVoces;

      if (_vocesDisponibles.isNotEmpty) {
        _vozSeleccionada = _vocesDisponibles.first;
        await _tts.setVoice({
          'name': _vozSeleccionada!.nombre,
          'locale': _vozSeleccionada!.locale,
        });
      }
    } catch (e) {
      debugPrint('Aviso: Síntesis de voz no disponible o error al iniciar: $e');
    }
  }

  /// Conectores y preposiciones que señalan inicios de frases naturales en español
  static const Set<String> _conectoresInicio = {
    'hacia',
    'para',
    'por',
    'con',
    'sin',
    'sobre',
    'hasta',
    'desde',
    'entre',
    'que',
    'cuando',
    'donde',
    'como',
    'porque',
    'pero',
    'sino',
    'aunque',
    'mientras',
    'si',
    'y',
    'e',
    'o',
    'u',
  };

  /// Palabras proclíticas que no deben quedar sueltas al final de un segmento
  static const Set<String> _palabrasProcliticasFinal = {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'al',
    'del',
    'de',
    'en',
    'a',
    'hacia',
    'para',
    'con',
    'por',
    'sin',
    'sobre',
    'hasta',
    'desde',
    'entre',
    'y',
    'e',
    'o',
    'u',
    'que',
  };

  static bool _esCapitalizada(String palabra) {
    final limpia = palabra.replaceAll(
      RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true),
      '',
    );
    if (limpia.isEmpty) return false;
    final primerChar = limpia[0];
    return primerChar == primerChar.toUpperCase() &&
        primerChar != primerChar.toLowerCase();
  }

  List<_TokenPalabra> _extraerTokens(String texto) {
    final matches = RegExp(r'\S+').allMatches(texto);
    final tokens = <_TokenPalabra>[];
    var ultimoFin = 0;

    for (final m in matches) {
      final intermedio = texto.substring(ultimoFin, m.start);
      final sigueSalto = intermedio.contains('\n') || intermedio.contains('\r');
      tokens.add(
        _TokenPalabra(
          texto: m.group(0)!,
          inicio: m.start,
          fin: m.end,
          sigueSaltoLinea: sigueSalto,
        ),
      );
      ultimoFin = m.end;
    }

    return tokens;
  }

  List<List<_TokenPalabra>> _agruparEnOraciones(List<_TokenPalabra> tokens) {
    final oraciones = <List<_TokenPalabra>>[];
    var oracionActual = <_TokenPalabra>[];

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (oracionActual.isNotEmpty && token.sigueSaltoLinea) {
        oraciones.add(oracionActual);
        oracionActual = <_TokenPalabra>[];
      }

      oracionActual.add(token);

      if (token.esFinOracion) {
        oraciones.add(oracionActual);
        oracionActual = <_TokenPalabra>[];
      }
    }

    if (oracionActual.isNotEmpty) {
      oraciones.add(oracionActual);
    }

    return oraciones;
  }

  int _puntuarFragmento(List<_TokenPalabra> tokens, int start, int end) {
    final n = tokens.length;
    final length = end - start + 1;
    var score = 0;

    // Preferencia de longitud (objetivo entre 2 y 5 palabras, preferiblemente 3 o 4)
    if (length == 3) {
      score += 35;
    } else if (length == 4) {
      score += 30;
    } else if (length == 2) {
      score += 20;
    } else if (length == 5) {
      score += 15;
    }

    final tokenFinal = tokens[end];
    final textoFinalLimpio = tokenFinal.texto.toLowerCase().replaceAll(
      RegExp(r'[^\wáéíóúüñ]'),
      '',
    );

    // Puntuación al final del fragmento (respetando signos de puntuación)
    if (tokenFinal.esPuntuacionIntermedia) {
      score += 60;
    }

    // Penalización por palabra proclítica al final (artículo o preposición suelta)
    if (end < n - 1 && _palabrasProcliticasFinal.contains(textoFinalLimpio)) {
      score -= 120;
    }

    // Siguiente token
    if (end < n - 1) {
      final tokenSiguiente = tokens[end + 1];
      final textoSiguienteLimpio = tokenSiguiente.texto
          .toLowerCase()
          .replaceAll(RegExp(r'[^\wáéíóúüñ]'), '');

      // Conector o preposición al inicio del siguiente fragmento
      if (_conectoresInicio.contains(textoSiguienteLimpio)) {
        score += 45;
      }

      // Evitar cortar nombres propios o expresiones de forma extraña (dos palabras en mayúscula seguidas)
      if (_esCapitalizada(tokenFinal.texto) &&
          _esCapitalizada(tokenSiguiente.texto)) {
        score -= 500;
      }
    }

    return score;
  }

  List<int> _calcularCortesOptimos(List<_TokenPalabra> tokens) {
    final n = tokens.length;
    final memo = <int, _ResultadoCorte>{};

    _ResultadoCorte resolver(int start) {
      if (start >= n) {
        return const _ResultadoCorte(score: 0, cortes: []);
      }
      if (memo.containsKey(start)) {
        return memo[start]!;
      }

      final restante = n - start;
      if (restante <= 5 && restante >= 2) {
        // Si el fragmento restante ya tiene entre 2 y 5 palabras, solo se subdivide si contiene
        // signos de puntuación intermedia que justifiquen el corte.
        final tienePuntuacionIntermedia = tokens
            .sublist(start, n - 1)
            .any((t) => t.esPuntuacionIntermedia);

        if (!tienePuntuacionIntermedia) {
          final res = _ResultadoCorte(
            score: _puntuarFragmento(tokens, start, n - 1),
            cortes: [n - 1],
          );
          memo[start] = res;
          return res;
        }

        var mejorResultado = _ResultadoCorte(
          score: _puntuarFragmento(tokens, start, n - 1),
          cortes: [n - 1],
        );

        for (var k = 2; k <= restante - 2; k++) {
          final end = start + k - 1;
          if (!tokens[end].esPuntuacionIntermedia) continue;
          final scoreActual = _puntuarFragmento(tokens, start, end);
          final resSiguiente = resolver(end + 1);
          final scoreTotal = scoreActual + resSiguiente.score;
          if (scoreTotal > mejorResultado.score) {
            mejorResultado = _ResultadoCorte(
              score: scoreTotal,
              cortes: [end, ...resSiguiente.cortes],
            );
          }
        }

        memo[start] = mejorResultado;
        return mejorResultado;
      }

      // Si restante > 5: debemos tomar k entre 2 y 5 tal que el restante no sea 1
      _ResultadoCorte? mejor;

      for (var k = 2; k <= 5; k++) {
        if (start + k > n) continue;
        final restoDespues = n - (start + k);
        if (restoDespues == 1) continue; // Evitar dejar 1 palabra huérfana

        final end = start + k - 1;
        final scoreActual = _puntuarFragmento(tokens, start, end);
        final resSiguiente = resolver(end + 1);
        final scoreTotal = scoreActual + resSiguiente.score;

        if (mejor == null || scoreTotal > mejor.score) {
          mejor = _ResultadoCorte(
            score: scoreTotal,
            cortes: [end, ...resSiguiente.cortes],
          );
        }
      }

      // Fallback de seguridad si no hubo opción estricta
      if (mejor == null) {
        final k = (restante / 2).clamp(2, 5).toInt();
        final end = (start + k - 1).clamp(start, n - 1);
        final resSiguiente = resolver(end + 1);
        mejor = _ResultadoCorte(
          score: _puntuarFragmento(tokens, start, end) + resSiguiente.score,
          cortes: [end, ...resSiguiente.cortes],
        );
      }

      memo[start] = mejor;
      return mejor;
    }

    return resolver(0).cortes;
  }

  List<NarracionSegmento> _segmentarOracion(
    String textoCompleto,
    List<_TokenPalabra> tokens,
  ) {
    if (tokens.isEmpty) return const [];
    final n = tokens.length;

    if (n <= 5) {
      return [
        NarracionSegmento(
          texto: textoCompleto.substring(tokens.first.inicio, tokens.last.fin),
          indiceInicio: tokens.first.inicio,
          indiceFin: tokens.last.fin,
        ),
      ];
    }

    final cortes = _calcularCortesOptimos(tokens);
    final segmentos = <NarracionSegmento>[];
    var inicioIdx = 0;

    for (final finIdx in cortes) {
      final tokInicio = tokens[inicioIdx];
      final tokFin = tokens[finIdx];
      segmentos.add(
        NarracionSegmento(
          texto: textoCompleto.substring(tokInicio.inicio, tokFin.fin),
          indiceInicio: tokInicio.inicio,
          indiceFin: tokFin.fin,
        ),
      );
      inicioIdx = finIdx + 1;
    }

    return segmentos;
  }

  /// Subdivide el texto en fragmentos breves (2-5 palabras por segmento)
  /// respetando signos de puntuación, nombres propios y límites sintácticos.
  List<NarracionSegmento> segmentarTexto(String texto) {
    if (texto.trim().isEmpty) return const [];

    final tokens = _extraerTokens(texto);
    if (tokens.isEmpty) return const [];

    final oraciones = _agruparEnOraciones(tokens);
    final todosLosSegmentos = <NarracionSegmento>[];

    for (final oracion in oraciones) {
      todosLosSegmentos.addAll(_segmentarOracion(texto, oracion));
    }

    return todosLosSegmentos;
  }

  /// Reconstruye el texto original exactamente a partir de los segmentos y los espacios
  /// intermedios, garantizando conservación del 100% de caracteres y puntuación.
  static String reconstruirTexto({
    required String original,
    required List<NarracionSegmento> segmentos,
  }) {
    if (segmentos.isEmpty) return original;
    final buffer = StringBuffer();
    var currentOffset = 0;

    for (final seg in segmentos) {
      if (seg.indiceInicio > currentOffset) {
        buffer.write(original.substring(currentOffset, seg.indiceInicio));
      }
      buffer.write(seg.texto);
      currentOffset = seg.indiceFin;
    }

    if (currentOffset < original.length) {
      buffer.write(original.substring(currentOffset));
    }

    return buffer.toString();
  }

  /// Construye los TextSpans para renderizado manteniendo el 100% del texto original,
  /// incluyendo saltos de línea y espaciado, resaltando únicamente el segmento activo.
  List<InlineSpan> construirTextSpans({
    required String texto,
    required List<NarracionSegmento> segmentos,
    required int indiceActivo,
    required TextStyle estiloNormal,
    required TextStyle estiloResaltado,
  }) {
    if (texto.isEmpty) return const [];
    if (segmentos.isEmpty) {
      return [TextSpan(text: texto, style: estiloNormal)];
    }

    final spans = <InlineSpan>[];
    var currentOffset = 0;

    for (var i = 0; i < segmentos.length; i++) {
      final seg = segmentos[i];

      // Texto no resaltado previo al segmento (espacios, saltos de línea)
      if (seg.indiceInicio > currentOffset) {
        final espaciado = texto.substring(currentOffset, seg.indiceInicio);
        spans.add(TextSpan(text: espaciado, style: estiloNormal));
      }

      final esActivo = i == indiceActivo;
      spans.add(
        TextSpan(
          text: seg.texto,
          style: esActivo ? estiloResaltado : estiloNormal,
        ),
      );

      currentOffset = seg.indiceFin;
    }

    // Texto restante después del último segmento
    if (currentOffset < texto.length) {
      final resto = texto.substring(currentOffset);
      spans.add(TextSpan(text: resto, style: estiloNormal));
    }

    return spans;
  }

  /// Divide el texto de una escena en oraciones completas (mantenido por compatibilidad).
  List<String> segmentarEnFrases(String texto) {
    if (texto.trim().isEmpty) return [];

    final parrafos = texto.split(RegExp(r'\n+'));
    final frases = <String>[];

    for (final parrafo in parrafos) {
      final pLimpio = parrafo.trim();
      if (pLimpio.isEmpty) continue;

      // Dividir por signos de puntuación (. ! ? :) manteniendo coherencia
      final matches = RegExp(r'[^.!?:]+[.!?:]*')
          .allMatches(pLimpio)
          .map((m) => m.group(0)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      if (matches.isNotEmpty) {
        frases.addAll(matches);
      } else {
        frases.add(pLimpio);
      }
    }

    return frases;
  }

  /// Inicia la lectura acompañada segmento por segmento con resaltado visual sincronizado
  Future<void> narrarEscena({
    required String contenido,
    int segmentoInicial = 0,
    int fraseInicial = 0,
  }) async {
    await detener();

    final segmentos = segmentarTexto(contenido);
    if (segmentos.isEmpty) return;

    _segmentosActuales = segmentos;
    _detencionSolicitada = false;
    _actualizarEstado(EstadoNarracion.reproduciendo);

    final inicio = segmentoInicial > 0 ? segmentoInicial : fraseInicial;
    for (var i = inicio; i < _segmentosActuales.length; i++) {
      if (_detencionSolicitada) break;

      _indiceSegmentoActual = i;
      onSegmentoCambio?.call(_indiceSegmentoActual);
      onFraseCambio?.call(_indiceSegmentoActual);

      final segmento = _segmentosActuales[i];
      _fraseCompleter = Completer<void>();

      try {
        await _tts.speak(segmento.texto);
        await _fraseCompleter!.future;
      } catch (e) {
        debugPrint('Error al narrar segmento $i: $e');
        break;
      }

      // Pequeña pausa natural entre segmentos para lectura infantil
      if (!_detencionSolicitada && i < _segmentosActuales.length - 1) {
        await Future.delayed(const Duration(milliseconds: 180));
      }
    }

    if (!_detencionSolicitada) {
      _indiceSegmentoActual = -1;
      onSegmentoCambio?.call(_indiceSegmentoActual);
      onFraseCambio?.call(_indiceSegmentoActual);
      _actualizarEstado(EstadoNarracion.detenido);
    }
  }

  /// Detiene la narración inmediatamente
  Future<void> detener() async {
    _detencionSolicitada = true;
    if (_fraseCompleter != null && !_fraseCompleter!.isCompleted) {
      _fraseCompleter!.complete();
    }
    try {
      await _tts.stop();
    } catch (_) {}

    _indiceSegmentoActual = -1;
    onSegmentoCambio?.call(_indiceSegmentoActual);
    onFraseCambio?.call(_indiceSegmentoActual);
    _actualizarEstado(EstadoNarracion.detenido);
  }

  /// Narra el texto completo de forma continua y natural, enviando el texto
  /// completo al sintetizador TTS sin fragmentar en pausas artificiales.
  Future<void> narrarTextoCompleto(String texto) async {
    await detener();

    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty) return;

    _detencionSolicitada = false;
    _actualizarEstado(EstadoNarracion.reproduciendo);

    _fraseCompleter = Completer<void>();

    try {
      await _tts.speak(textoLimpio);
      await _fraseCompleter!.future;
    } catch (e) {
      debugPrint('Error en narrarTextoCompleto: $e');
      _actualizarEstado(EstadoNarracion.error);
      return;
    }

    if (!_detencionSolicitada) {
      _actualizarEstado(EstadoNarracion.detenido);
    }
  }

  /// Cambia la velocidad de reproducción (0.2 a 1.0)
  Future<void> cambiarVelocidad(double nuevaVelocidad) async {
    _velocidad = nuevaVelocidad.clamp(0.2, 1.0);
    try {
      await _tts.setSpeechRate(_velocidad);
    } catch (_) {}
  }

  /// Cambia la voz seleccionada
  Future<void> cambiarVoz(VozInfo voz) async {
    _vozSeleccionada = voz;
    try {
      await _tts.setVoice({'name': voz.nombre, 'locale': voz.locale});
    } catch (_) {}
  }

  /// Libera recursos y detiene la narración
  void dispose() {
    detener();
  }
}

/// Controlador de revelado progresivo letra por letra (grapheme clusters).
/// Revela el texto carácter a carácter acumulativamente sin romper unidades Unicode
/// (tildes, eñes, emojis, saltos de línea ni caracteres combinados).
/// Sincroniza dinámicamente el ritmo visual con la velocidad del TTS para acompañar la narración.
class ControladorReveladoTexto {
  static const int palabrasPorMinutoBasePorDefecto = 140;
  static const double velocidadTtsBasePorDefecto = 0.5;
  static const int intervaloVisualMinimoMsPorDefecto = 30;
  static const double factorAjusteReveladoPorDefecto = 0.90;

  final String textoCompleto;
  final int totalCaracteres;
  final int totalPalabras;

  final int palabrasPorMinutoBase;
  final double velocidadTtsBase;
  final int intervaloVisualMinimoMs;
  final double factorAjusteRevelado;

  int _caracteresMostrados = 0;
  String _textoVisible = '';
  Timer? _timer;
  double _velocidadTts;
  int _msPorTick = 30;
  int _caracteresPorTick = 1;
  bool _estaAnimando = false;

  void Function(String textoVisible)? _onTick;
  VoidCallback? _onCompleto;

  ControladorReveladoTexto({
    required this.textoCompleto,
    double velocidad = 0.5,
    this.palabrasPorMinutoBase = palabrasPorMinutoBasePorDefecto,
    this.velocidadTtsBase = velocidadTtsBasePorDefecto,
    this.intervaloVisualMinimoMs = intervaloVisualMinimoMsPorDefecto,
    this.factorAjusteRevelado = factorAjusteReveladoPorDefecto,
    bool mostrarCompletoInmediatamente = false,
  }) : _velocidadTts = velocidad.clamp(0.2, 1.0),
       totalCaracteres = textoCompleto.characters.length,
       totalPalabras = _contarPalabras(textoCompleto) {
    if (mostrarCompletoInmediatamente || totalCaracteres == 0) {
      _caracteresMostrados = totalCaracteres;
      _textoVisible = textoCompleto;
    } else {
      _caracteresMostrados = 1;
      _textoVisible = textoCompleto.characters.take(1).toString();
    }
    _recalcularParametros();
  }

  static int _contarPalabras(String texto) {
    if (texto.trim().isEmpty) return 0;
    return RegExp(r'\S+').allMatches(texto).length;
  }

  /// Calcula los parámetros de refresco UI y caracteres por tick en función
  /// de la cantidad de caracteres, palabras y velocidad de lectura del TTS.
  /// Sincroniza la duración estimada de la narración con el ritmo de aparición visual,
  /// aplicando [factorAjusteRevelado] (por defecto 0.90, ~10% más rápido) para evitar
  /// que la voz se adelante al texto.
  static ({int msPorTick, int caracteresPorTick}) calcularParametrosVisuales({
    required int totalCaracteres,
    int? caracteresRestantes,
    int? totalPalabras,
    required double velocidadTts,
    int palabrasPorMinutoBase = palabrasPorMinutoBasePorDefecto,
    double velocidadTtsBase = velocidadTtsBasePorDefecto,
    int intervaloVisualMinimoMs = intervaloVisualMinimoMsPorDefecto,
    double factorAjusteRevelado = factorAjusteReveladoPorDefecto,
  }) {
    final restantes = caracteresRestantes ?? totalCaracteres;
    if (restantes <= 0 || totalCaracteres <= 0) {
      return (msPorTick: intervaloVisualMinimoMs, caracteresPorTick: 1);
    }

    final palabrasTotales = (totalPalabras != null && totalPalabras > 0)
        ? totalPalabras
        : (totalCaracteres / 5.5).ceil();

    final fraccionRestante = (restantes / totalCaracteres).clamp(0.01, 1.0);
    final palabrasRestantes = (palabrasTotales * fraccionRestante).clamp(
      1.0,
      palabrasTotales.toDouble(),
    );

    final vel = velocidadTts.clamp(0.2, 1.0);

    // Estimación del tiempo del habla para lo que resta narrar (en milisegundos)
    final segundosEstimados =
        (palabrasRestantes / palabrasPorMinutoBase) *
        60.0 *
        (velocidadTtsBase / vel);
    final duracionVisual = (segundosEstimados * 1000) * factorAjusteRevelado;
    final msTotal = duracionVisual.round().clamp(300, 300000);

    final msPorCaracter = msTotal / restantes;

    final minTick = intervaloVisualMinimoMs.clamp(25, 45);

    if (msPorCaracter >= minTick) {
      // 1 carácter por tick con intervalo suave
      final intervalo = msPorCaracter.round().clamp(minTick, 250);
      return (msPorTick: intervalo, caracteresPorTick: 1);
    } else if (msPorCaracter >= (minTick / 2.0)) {
      // Avanzar 2 caracteres por tick manteniendo tick >= minTick
      final intervalo = (msPorCaracter * 2).round().clamp(minTick, minTick * 2);
      return (msPorTick: intervalo, caracteresPorTick: 2);
    } else {
      // Texto extenso o TTS muy rápido: 3 caracteres por tick
      final intervalo = (msPorCaracter * 3).round().clamp(
        minTick,
        (minTick * 2.2).round(),
      );
      return (msPorTick: intervalo, caracteresPorTick: 3);
    }
  }

  void _recalcularParametros() {
    final restantes = (totalCaracteres - _caracteresMostrados).clamp(
      0,
      totalCaracteres,
    );
    final params = calcularParametrosVisuales(
      totalCaracteres: totalCaracteres,
      caracteresRestantes: restantes > 0 ? restantes : totalCaracteres,
      totalPalabras: totalPalabras,
      velocidadTts: _velocidadTts,
      palabrasPorMinutoBase: palabrasPorMinutoBase,
      velocidadTtsBase: velocidadTtsBase,
      intervaloVisualMinimoMs: intervaloVisualMinimoMs,
      factorAjusteRevelado: factorAjusteRevelado,
    );
    _msPorTick = params.msPorTick;
    _caracteresPorTick = params.caracteresPorTick;
  }

  /// Mantiene compatibilidad con cortes para tests y observadores.
  List<int> get cortes => List.generate(totalCaracteres, (i) => i + 1);

  static List<int> calcularCortes(String texto) =>
      List.generate(texto.characters.length, (i) => i + 1);

  String get textoVisible => _textoVisible;
  int get pasoActual => _caracteresMostrados;
  int get totalPasos => totalCaracteres;
  int get caracteresMostrados => _caracteresMostrados;
  int get msPorTick => _msPorTick;
  int get caracteresPorTick => _caracteresPorTick;
  bool get estaAnimando => _estaAnimando;
  bool get estaCompleto =>
      totalCaracteres == 0 ||
      _caracteresMostrados >= totalCaracteres ||
      _textoVisible == textoCompleto;

  /// Inicia el temporizador de revelado progresivo letra a letra.
  void iniciar({
    void Function(String textoVisible)? onTick,
    VoidCallback? onCompleto,
  }) {
    detener(mostrarTextoCompleto: false);

    if (totalCaracteres == 0 || _caracteresMostrados >= totalCaracteres) {
      _textoVisible = textoCompleto;
      onTick?.call(_textoVisible);
      onCompleto?.call();
      return;
    }

    _estaAnimando = true;
    _onTick = onTick;
    _onCompleto = onCompleto;
    onTick?.call(_textoVisible);

    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _recalcularParametros();
    _timer = Timer.periodic(Duration(milliseconds: _msPorTick), (_) {
      avanzarPaso(cantidad: _caracteresPorTick);
      _onTick?.call(_textoVisible);
      if (estaCompleto) {
        detener(mostrarTextoCompleto: true);
      }
    });
  }

  /// Avanza caracteres de forma acumulativa y monótona usando grapheme clusters.
  /// Lo mostrado anteriormente SIEMPRE permanece intacto como prefijo.
  void avanzarPaso({int? cantidad}) {
    if (_caracteresMostrados < totalCaracteres) {
      final incremento = cantidad ?? _caracteresPorTick;
      _caracteresMostrados = (_caracteresMostrados + incremento).clamp(
        0,
        totalCaracteres,
      );

      if (_caracteresMostrados >= totalCaracteres) {
        _textoVisible = textoCompleto;
        _estaAnimando = false;
        _timer?.cancel();
        _timer = null;
      } else {
        _textoVisible = textoCompleto.characters
            .take(_caracteresMostrados)
            .toString();
      }
    } else {
      _textoVisible = textoCompleto;
      _estaAnimando = false;
      _timer?.cancel();
      _timer = null;
    }
  }

  double get velocidadTts => _velocidadTts;

  /// Cadencia calculada en caracteres visibles por segundo.
  double get caracteresPorSegundo => (_caracteresPorTick * 1000.0) / _msPorTick;

  /// Actualiza dinámicamente la velocidad según los cambios en el slider del TTS.
  /// Recalcula el ritmo visual restante para acompañar la nueva velocidad,
  /// conservando intacto todo el progreso ya mostrado (sin reiniciar ni perder texto).
  void actualizarVelocidad(double nuevaVelocidad) {
    _velocidadTts = nuevaVelocidad.clamp(0.2, 1.0);
    _recalcularParametros();
    if (_estaAnimando) {
      _iniciarTimer();
    }
  }

  /// Muestra inmediatamente el 100% del texto y detiene la animación.
  void mostrarTodo() {
    detener(mostrarTextoCompleto: true);
  }

  /// Detiene el temporizador. Si [mostrarTextoCompleto] es true, muestra todo el texto.
  void detener({bool mostrarTextoCompleto = true}) {
    _timer?.cancel();
    _timer = null;
    _estaAnimando = false;
    if (mostrarTextoCompleto) {
      _caracteresMostrados = totalCaracteres;
      _textoVisible = textoCompleto;
      _onTick?.call(_textoVisible);
      _onCompleto?.call();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _estaAnimando = false;
  }
}
