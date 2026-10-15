import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/story_controller.dart';
import 'models/cuento.dart';
import 'models/escena.dart';
import 'models/decision_narrativa.dart';
import 'models/generated_scene.dart';
import 'models/story_analysis.dart';
import 'repositories/cuento_repository_memoria.dart';
import 'services/ai_service.dart';
import 'services/document_service.dart';
import 'services/narracion_service.dart';
import 'services/narrativa_service.dart';
import 'views/story_view.dart';

class NoOpTts extends FlutterTts {
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;
  @override
  Future<dynamic> stop() async => 1;
}

class DummyAiService implements AiService {
  @override
  Future<StoryAnalysis> analizarHistoria(String texto) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://acxsyswrzdtstgqztojj.supabase.co',
  );
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  if (supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
    } catch (_) {}
  }

  final cuento = Cuento(
    id: 'cuento-staging-001',
    titulo: 'El Misterio del Valle Dorado',
    personajePrincipal: 'Nico',
    aulaId: 'aula-staging-4to',
    escenas: [
      Escena(
        numero: 1,
        contenido:
            'Nico exploraba las colinas doradas del valle cuando escuchó un rumor extraño cerca del cauce seco.',
        opciones: ['Seguir las huellas en la arena', 'Subir al mirador de piedra'],
        esFinal: false,
      ),
      Escena(
        numero: 2,
        contenido:
            'Nico dialogó amablemente con el gnomo guardián y juntos abrieron la compuerta para que el agua regara todos los campos. ¡El valle floreció y todos celebraron la amistad y el bien común!',
        opciones: const ['Fin de la aventura'],
        esFinal: true,
      ),
    ],
  );
  cuento.registrarDecision(
    DecisionNarrativa(
      numeroEscena: 1,
      opcionSeleccionada: 'Subir al mirador de piedra',
    ),
  );

  final narracionService = NarracionService(tts: NoOpTts());
  final storyController = StoryController(
    aiService: DummyAiService(),
    narrativaService: NarrativaService(),
    cuentoRepository: CuentoRepositoryMemoria(),
    documentService: DocumentService(),
  );

  runApp(
    MaterialApp(
      title: 'Cuentos Mágicos - Staging Windows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: StoryView(
          cuento: cuento,
          controller: storyController,
          narracionService: narracionService,
          autoNarrar: false,
          onSalir: () => exit(0),
        ),
      ),
    ),
  );
}
