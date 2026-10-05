class NarrativaConfig {
  /// Número máximo de escenas por aventura antes de exigir un desenlace definitivo.
  final int maxEscenas;

  /// Longitud máxima en caracteres del contexto acumulado enviado a Gemini.
  final int maxCaracteresContexto;

  /// Longitud máxima en caracteres del texto fuente original del PDF.
  final int maxCaracteresTextoFuente;

  /// Tiempo máximo de espera por cada solicitud a la IA.
  final Duration timeoutGeneracion;

  /// Número máximo de reintentos en caso de error transitorio.
  final int maxReintentos;

  /// Cantidad máxima de tokens a generar por escena.
  final int maxTokensGeneracion;

  /// Tasa base de lectura infantil en palabras por minuto para la velocidad de referencia (por defecto 140).
  final int palabrasPorMinutoBase;

  /// Velocidad estándar de referencia del TTS (por defecto 0.5).
  final double velocidadTtsBase;

  /// Intervalo mínimo del temporizador visual en milisegundos para mantener fluidez sin sobrecargar la UI (por defecto 30).
  final int intervaloVisualMinimoMs;

  /// Factor multiplicador sobre la duración estimada del TTS para adelantar visualmente el texto (~10% más rápido, por defecto 0.90).
  final double factorAjusteRevelado;

  const NarrativaConfig({
    this.maxEscenas = 4,
    this.maxCaracteresContexto = 5500,
    this.maxCaracteresTextoFuente = 8000,
    this.timeoutGeneracion = const Duration(seconds: 45),
    this.maxReintentos = 2,
    this.maxTokensGeneracion = 1800,
    this.palabrasPorMinutoBase = 140,
    this.velocidadTtsBase = 0.5,
    this.intervaloVisualMinimoMs = 30,
    this.factorAjusteRevelado = 0.90,
  });

  NarrativaConfig copyWith({
    int? maxEscenas,
    int? maxCaracteresContexto,
    int? maxCaracteresTextoFuente,
    Duration? timeoutGeneracion,
    int? maxReintentos,
    int? maxTokensGeneracion,
    int? palabrasPorMinutoBase,
    double? velocidadTtsBase,
    int? intervaloVisualMinimoMs,
    double? factorAjusteRevelado,
  }) {
    return NarrativaConfig(
      maxEscenas: maxEscenas ?? this.maxEscenas,
      maxCaracteresContexto:
          maxCaracteresContexto ?? this.maxCaracteresContexto,
      maxCaracteresTextoFuente:
          maxCaracteresTextoFuente ?? this.maxCaracteresTextoFuente,
      timeoutGeneracion: timeoutGeneracion ?? this.timeoutGeneracion,
      maxReintentos: maxReintentos ?? this.maxReintentos,
      maxTokensGeneracion: maxTokensGeneracion ?? this.maxTokensGeneracion,
      palabrasPorMinutoBase:
          palabrasPorMinutoBase ?? this.palabrasPorMinutoBase,
      velocidadTtsBase: velocidadTtsBase ?? this.velocidadTtsBase,
      intervaloVisualMinimoMs:
          intervaloVisualMinimoMs ?? this.intervaloVisualMinimoMs,
      factorAjusteRevelado: factorAjusteRevelado ?? this.factorAjusteRevelado,
    );
  }
}
