import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/generated_scene.dart';
import '../models/story_analysis.dart';
import 'ai_service.dart';

class SupabaseAiService implements AiService {
  final SupabaseClient client;

  SupabaseAiService({required this.client});

  // ======================================================
  // ANALIZAR HISTORIA ORIGINAL
  // ======================================================

  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async {
    final contenido = texto.trim();

    if (contenido.isEmpty) {
      throw ArgumentError('El texto no puede estar vacío.');
    }

    final response = await client.functions
        .invoke('analizar-historia', body: {'texto': contenido})
        .timeout(const Duration(seconds: 85));

    final json = _validarRespuesta(response.data);

    return StoryAnalysis.fromJson(json);
  }

  // ======================================================
  // GENERAR ESCENA INICIAL CON IA
  // ======================================================

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
    return generarEscena(
      titulo: titulo,
      personajePrincipal: personajePrincipal,
      personajeOriginal: personajeOriginal,
      esPersonajeNuevo: esPersonajeNuevo,
      descripcionPersonaje: descripcionPersonaje,
      textoFuente: textoFuente,
      resumenOriginal: resumenOriginal,
      escenarioOriginal: escenarioOriginal,
      conflictoPrincipal: conflictoPrincipal,
      finalOriginal: finalOriginal,
      contextoNarrativo:
          'Inicio de la aventura. Presentación del protagonista y su entorno.',
      decisionActual: 'Inicio de la historia',
      numeroEscena: 1,
      esUltimaEscena: false,
    );
  }

  // ======================================================
  // GENERAR SIGUIENTE ESCENA
  // ======================================================

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
    if (personajePrincipal.trim().isEmpty) {
      throw ArgumentError('El personaje principal es obligatorio.');
    }

    if (numeroEscena < 1) {
      throw ArgumentError('El número de escena debe ser positivo.');
    }

    if (numeroEscena > 1) {
      if (decisionActual.trim().isEmpty) {
        throw ArgumentError('La decisión seleccionada es obligatoria.');
      }

      if (contextoNarrativo.trim().isEmpty) {
        throw ArgumentError('No existe contexto narrativo.');
      }
    }

    final response = await client.functions
        .invoke(
          'generar-escena',
          body: {
            'titulo': titulo,
            'personajePrincipal': personajePrincipal,
            if (personajeOriginal != null &&
                personajeOriginal.trim().isNotEmpty)
              'personajeOriginal': personajeOriginal.trim(),
            'esPersonajeNuevo': esPersonajeNuevo,
            if (descripcionPersonaje != null &&
                descripcionPersonaje.trim().isNotEmpty)
              'descripcionPersonaje': descripcionPersonaje.trim(),
            'textoFuente': textoFuente,
            'resumenOriginal': resumenOriginal,
            'escenarioOriginal': escenarioOriginal,
            'conflictoPrincipal': conflictoPrincipal,
            'finalOriginal': finalOriginal,
            'contextoNarrativo': contextoNarrativo,
            'decisionActual': decisionActual,
            'numeroEscena': numeroEscena,
            'esUltimaEscena': esUltimaEscena,
          },
        )
        .timeout(const Duration(seconds: 85));

    final json = _validarRespuesta(response.data);

    return GeneratedScene.fromJson(json);
  }

  // ======================================================
  // VALIDAR RESPUESTAS
  // ======================================================

  Map<String, dynamic> _validarRespuesta(dynamic data) {
    if (data == null) {
      throw StateError('El servicio de IA no devolvió datos.');
    }

    if (data is! Map) {
      throw StateError('La respuesta de IA tiene un formato inválido.');
    }

    final json = Map<String, dynamic>.from(data);

    if (json['error'] != null) {
      throw StateError(json['error'].toString());
    }

    return json;
  }
}
