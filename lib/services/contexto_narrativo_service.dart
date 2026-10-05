import '../models/cuento.dart';

class ContextoNarrativoService {
  const ContextoNarrativoService();

  /// Construye el historial de escenas y decisiones
  /// que Gemini necesita para continuar el cuento.
  ///
  /// La decisionActual se envía por separado
  /// a la Edge Function generar-escena.
  String construirContexto(Cuento cuento, {int? maxCaracteres}) {
    if (cuento.escenas.isEmpty) {
      throw StateError(
        'No se puede generar una continuación '
        'sin una escena inicial.',
      );
    }

    final buffer = StringBuffer();

    buffer.writeln('HISTORIAL NARRATIVO');
    buffer.writeln();

    final escenasOrdenadas = [...cuento.escenas]
      ..sort((a, b) => a.numero.compareTo(b.numero));

    final decisionesPorEscena = {
      for (final decision in cuento.decisiones)
        decision.numeroEscena: decision.opcionSeleccionada,
    };

    // Si no hay límite o el historial es breve, incluimos todo ordenado.
    for (final escena in escenasOrdenadas) {
      buffer.writeln('ESCENA ${escena.numero}:');
      buffer.writeln(_limpiarTexto(escena.contenido));

      final decisionSeleccionada = decisionesPorEscena[escena.numero];
      if (decisionSeleccionada != null &&
          decisionSeleccionada.trim().isNotEmpty) {
        buffer.writeln(
          'DECISIÓN TOMADA: ${_limpiarTexto(decisionSeleccionada)}',
        );
      }
      buffer.writeln();
    }

    final resultado = buffer.toString().trim();

    if (maxCaracteres == null || resultado.length <= maxCaracteres) {
      return resultado;
    }

    // Poda inteligente: Siempre conservar Escena 1, las decisiones tomadas y las escenas más recientes.
    final bufferPoda = StringBuffer();
    bufferPoda.writeln('HISTORIAL NARRATIVO (RESUMIDO)');
    bufferPoda.writeln();

    final primeraEscena = escenasOrdenadas.first;
    bufferPoda.writeln('ESCENA 1 (INICIO):');
    bufferPoda.writeln(_limpiarTexto(primeraEscena.contenido));

    final primeraDecision = decisionesPorEscena[primeraEscena.numero];
    if (primeraDecision != null && primeraDecision.trim().isNotEmpty) {
      bufferPoda.writeln('DECISIÓN TOMADA: ${_limpiarTexto(primeraDecision)}');
    }
    bufferPoda.writeln();

    // Decisiones intermedias acumuladas
    if (cuento.decisiones.length > 1) {
      bufferPoda.writeln('DECISIONES CLAVE DEL RECORRIDO:');
      for (final d in cuento.decisiones) {
        bufferPoda.writeln(
          '- En escena ${d.numeroEscena}: "${_limpiarTexto(d.opcionSeleccionada)}"',
        );
      }
      bufferPoda.writeln();
    }

    // Añadir las escenas más recientes
    final escenasRecientes = escenasOrdenadas.skip(1).toList();
    final limiteRecientes = escenasRecientes.length > 2
        ? escenasRecientes.sublist(escenasRecientes.length - 2)
        : escenasRecientes;

    for (final escena in limiteRecientes) {
      bufferPoda.writeln('ESCENA ${escena.numero}:');
      bufferPoda.writeln(_limpiarTexto(escena.contenido));

      final dec = decisionesPorEscena[escena.numero];
      if (dec != null && dec.trim().isNotEmpty) {
        bufferPoda.writeln('DECISIÓN TOMADA: ${_limpiarTexto(dec)}');
      }
      bufferPoda.writeln();
    }

    return bufferPoda.toString().trim();
  }

  String _limpiarTexto(String texto) {
    return texto
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .trim();
  }
}
