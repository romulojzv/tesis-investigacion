import 'package:flutter/foundation.dart';

import '../models/character_customization.dart';
import '../models/cuento.dart';
import '../models/decision_narrativa.dart';
import '../models/escena.dart';
import '../models/generated_scene.dart';
import '../models/pdf_story_data.dart';
import '../repositories/cuento_repository.dart';
import '../services/ai_service.dart';
import '../services/contexto_narrativo_service.dart';
import '../services/document_service.dart';
import '../models/narrativa_config.dart';
import '../services/image_service.dart';
import '../services/narrativa_service.dart';
import '../utils/visual_description_helper.dart';
import '../widgets/ilustracion_escena_widget.dart';

class StoryController {
  final AiService aiService;
  final NarrativaService narrativaService;
  final CuentoRepository cuentoRepository;
  final DocumentService documentService;

  final ContextoNarrativoService contextoNarrativoService;
  final NarrativaConfig narrativaConfig;
  final ImageService? imageService;

  // Evita dos generaciones simultáneas
  // desde la misma escena.
  final Set<String> _generacionesEnCurso = {};

  // Bandera de guardia para evitar doble despacho concurrente
  bool _generandoSiguienteEscena = false;

  /// Indica si actualmente se está generando la siguiente escena
  bool get generandoSiguienteEscena => _generandoSiguienteEscena;

  // Evita doble solicitud o generaciones concurrentes de imágenes para la misma escena
  final Set<String> _generacionesImagenEnCurso = {};

  StoryController({
    required this.narrativaService,
    required this.cuentoRepository,
    required this.documentService,
    required this.aiService,
    this.imageService,
    this.contextoNarrativoService = const ContextoNarrativoService(),
    this.narrativaConfig = const NarrativaConfig(),
  });

  // =====================================================
  // CREAR CUENTO DESDE DIBUJO
  // =====================================================

  Future<Cuento> crearCuentoInicialDemo({
    required String id,
    required String nombrePersonaje,
    required Uint8List dibujoReferenciaPng,
    String? descripcionPersonaje,
  }) async {
    final nombre = nombrePersonaje.trim();

    if (nombre.isEmpty) {
      throw ArgumentError('El nombre del personaje no puede estar vacío.');
    }

    if (dibujoReferenciaPng.isEmpty) {
      throw ArgumentError('El dibujo de referencia no puede estar vacío.');
    }

    final descFinal =
        (descripcionPersonaje != null && descripcionPersonaje.trim().isNotEmpty)
        ? descripcionPersonaje.trim()
        : derivarDescripcionVisualBase(nombrePersonaje: nombre);

    final cuento = Cuento(
      id: id,
      titulo: 'La aventura de $nombre',
      personajePrincipal: nombre,
      origen: CuentoOrigen.dibujo,
      referenciaVisualPng: dibujoReferenciaPng,
      descripcionPersonaje: descFinal,
    );

    final escenaInicial = narrativaService.crearEscenaInicialDemo(
      nombrePersonaje: nombre,
      descripcionPersonaje: descFinal,
    );

    cuento.agregarEscena(escenaInicial);

    await cuentoRepository.guardarCuento(cuento);

    return cuento;
  }

  // =====================================================
  // PROCESAR PDF CON IA
  // =====================================================

  Future<PdfStoryData> procesarPdf({
    required String nombreArchivo,
    required Uint8List pdfBytes,
  }) async {
    final datosPdf = await documentService.procesarPdf(
      nombreArchivo: nombreArchivo,
      pdfBytes: pdfBytes,
    );

    if (!datosPdf.tieneTexto) {
      throw StateError('No se pudo extraer texto del PDF.');
    }

    final analisis = await aiService.analizarHistoria(datosPdf.textoExtraido);

    return datosPdf.copyWith(
      tituloDetectado: analisis.titulo,
      tituloOriginal: analisis.tituloOriginal,
      personajePrincipalDetectado: analisis.personajePrincipal,
      descripcionPersonaje: analisis.descripcionPersonaje,
      resumen: analisis.resumen,
      escenario: analisis.escenario,
      conflictoPrincipal: analisis.conflictoPrincipal,
      finalOriginal: analisis.finalOriginal,
    );
  }

  // =====================================================
  // CREAR CUENTO DESDE PDF PROCESADO
  // =====================================================

  Future<Cuento> crearCuentoDesdePdfProcesadoDemo({
    required String id,
    required PdfStoryData datosPdf,
    required CharacterCustomization personalizacion,
    Uint8List? dibujoReferenciaPng,
  }) async {
    final nombre = CharacterCustomization.sanitizarNombre(
      personalizacion.nombrePersonaje,
    );

    if (nombre.isEmpty) {
      throw ArgumentError('El nombre del personaje no puede estar vacío.');
    }

    if (!datosPdf.tieneTexto) {
      throw StateError('El PDF no contiene texto utilizable.');
    }

    if (personalizacion.visualMode == CharacterVisualMode.drawing &&
        (dibujoReferenciaPng == null || dibujoReferenciaPng.isEmpty)) {
      throw StateError(
        'Se seleccionó un personaje dibujado, '
        'pero no se recibió el dibujo.',
      );
    }

    final titulo = datosPdf.tituloDetectado?.trim();

    final esNuevo = personalizacion.mode == CharacterMode.newCharacter;
    final esRenombrado = personalizacion.mode == CharacterMode.renameOriginal;

    // Si es renombrado, conserva la descripción, personalidad y rasgos del protagonista original.
    // Si es un personaje nuevo, tiene su propia descripción cuando exista, sin heredar del original.
    final descripcionPersonaje = esNuevo
        ? (personalizacion.descripcionPersonaje?.trim().isNotEmpty == true
              ? personalizacion.descripcionPersonaje!.trim()
              : null)
        : datosPdf.descripcionPersonaje;

    final personajeOriginal = esRenombrado || esNuevo
        ? (personalizacion.personajeOriginal ??
              datosPdf.personajePrincipalDetectado)
        : datosPdf.personajePrincipalDetectado;

    final cuento = Cuento(
      id: id,
      titulo: titulo != null && titulo.isNotEmpty
          ? titulo
          : 'La aventura de $nombre',
      tituloOriginal: datosPdf.tituloOriginal,
      personajePrincipal: nombre,
      personajeOriginal: personajeOriginal,
      esPersonajeNuevo: esNuevo,
      origen: CuentoOrigen.pdf,
      esModoDibujo: personalizacion.visualMode == CharacterVisualMode.drawing,
      textoFuente: datosPdf.textoExtraido,
      resumenOriginal: datosPdf.resumen,
      escenarioOriginal: datosPdf.escenario,
      conflictoPrincipal: datosPdf.conflictoPrincipal,
      finalOriginal: datosPdf.finalOriginal,
      descripcionPersonaje: descripcionPersonaje,
      referenciaVisualPng:
          dibujoReferenciaPng ?? personalizacion.imagenReferencia,
    );

    debugPrint(
      '[DIAGNÓSTICO B] Al construir Cuento: '
      'cuento.id="${cuento.id}", '
      'personajePrincipal="${cuento.personajePrincipal}", '
      'descripcionPersonaje="${cuento.descripcionPersonaje ?? '(null)'}"',
    );

    Escena escenaInicial;
    try {
      final generatedScene = await aiService.generarEscenaInicial(
        titulo: cuento.titulo,
        personajePrincipal: nombre,
        personajeOriginal: cuento.personajeOriginal,
        esPersonajeNuevo: cuento.esPersonajeNuevo,
        textoFuente: datosPdf.textoExtraido,
        resumenOriginal: datosPdf.resumen ?? '',
        escenarioOriginal: datosPdf.escenario ?? '',
        conflictoPrincipal: datosPdf.conflictoPrincipal ?? '',
        finalOriginal: datosPdf.finalOriginal ?? '',
        descripcionPersonaje: cuento.descripcionPersonaje,
      );

      final contenidoSanitizado = cuento.requiereSustitucionNombreOriginal
          ? sanitizarNombrePersonaje(
              generatedScene.contenido,
              original: cuento.personajeOriginal!,
              actual: cuento.personajePrincipal,
            )
          : generatedScene.contenido;

      final opcionesSanitizadas = cuento.requiereSustitucionNombreOriginal
          ? generatedScene.opciones
                .map(
                  (op) => sanitizarNombrePersonaje(
                    op,
                    original: cuento.personajeOriginal!,
                    actual: cuento.personajePrincipal,
                  ),
                )
                .toList()
          : generatedScene.opciones;

      escenaInicial = Escena(
        numero: 1,
        contenido: contenidoSanitizado,
        opciones: opcionesSanitizadas,
        esFinal: generatedScene.esFinal,
      );
    } catch (_) {
      // Fallback seguro en español si falla la IA
      final fallback = narrativaService.crearEscenaInicialDesdePdfDemo(
        nombrePersonaje: nombre,
        datosPdf: datosPdf,
      );

      escenaInicial = cuento.requiereSustitucionNombreOriginal
          ? Escena(
              numero: fallback.numero,
              contenido: sanitizarNombrePersonaje(
                fallback.contenido,
                original: cuento.personajeOriginal!,
                actual: cuento.personajePrincipal,
              ),
              opciones: fallback.opciones
                  .map(
                    (op) => sanitizarNombrePersonaje(
                      op,
                      original: cuento.personajeOriginal!,
                      actual: cuento.personajePrincipal,
                    ),
                  )
                  .toList(),
              esFinal: fallback.esFinal,
            )
          : fallback;
    }

    cuento.agregarEscena(escenaInicial);

    await cuentoRepository.guardarCuento(cuento);

    return cuento;
  }

  // =====================================================
  // COMPATIBILIDAD CON MÉTODO ANTERIOR
  // =====================================================

  Future<Cuento> crearCuentoDesdePdfDemo({
    required String id,
    required String nombrePersonaje,
    required String nombreArchivo,
    required Uint8List pdfBytes,
  }) async {
    final datosPdf = await procesarPdf(
      nombreArchivo: nombreArchivo,
      pdfBytes: pdfBytes,
    );

    final personalizacion = CharacterCustomization(
      mode: CharacterMode.newCharacter,
      visualMode: CharacterVisualMode.automatic,
      nombrePersonaje: nombrePersonaje,
    );

    return crearCuentoDesdePdfProcesadoDemo(
      id: id,
      datosPdf: datosPdf,
      personalizacion: personalizacion,
    );
  }

  // =====================================================
  // PREPARAR CONTEXTO NARRATIVO
  // =====================================================

  Future<String> prepararContinuacion({
    required Cuento cuento,
    required String decision,
  }) async {
    final opcion = decision.trim();

    if (opcion.isEmpty) {
      throw ArgumentError('La decisión no puede estar vacía.');
    }

    final contexto = contextoNarrativoService.construirContexto(cuento);

    return '$contexto\n\n'
        'DECISIÓN ACTUAL DEL ESTUDIANTE:\n'
        '$opcion';
  }

  // =====================================================
  // GENERAR SIGUIENTE ESCENA CON GEMINI
  // =====================================================

  Future<Escena> generarSiguienteEscena({
    required Cuento cuento,
    required Escena escenaActual,
    required String decision,
  }) async {
    final opcion = decision.trim();

    if (opcion.isEmpty) {
      throw ArgumentError('La decisión no puede estar vacía.');
    }

    if (cuento.escenas.isEmpty) {
      throw StateError('El cuento todavía no tiene escenas.');
    }

    final escenasOrdenadas = [...cuento.escenas]
      ..sort((a, b) => a.numero.compareTo(b.numero));

    final ultimaEscena = escenasOrdenadas.last;

    if (ultimaEscena.numero != escenaActual.numero) {
      throw StateError(
        'No se puede modificar una ruta '
        'desde una escena anterior.',
      );
    }

    if (escenaActual.esFinal) {
      throw StateError('La historia ya ha finalizado.');
    }

    if (!escenaActual.opciones.contains(opcion)) {
      throw ArgumentError(
        'La alternativa seleccionada '
        'no pertenece a la escena actual.',
      );
    }

    final decisionExistente = cuento.obtenerDecision(escenaActual.numero);

    if (decisionExistente != null &&
        decisionExistente.opcionSeleccionada != opcion) {
      throw StateError('Esta escena ya tiene una decisión registrada.');
    }

    final numeroNuevaEscena = escenaActual.numero + 1;

    // Si la escena ya existe, no volvemos
    // a consumir una solicitud de Gemini.
    final escenaExistente = cuento.obtenerEscena(numeroNuevaEscena);

    if (escenaExistente != null) {
      // También reintenta persistir por si
      // falló un guardado anterior.
      await cuentoRepository.guardarCuento(cuento);

      return escenaExistente;
    }

    final claveGeneracion = '${cuento.id}:${escenaActual.numero}';

    if (_generandoSiguienteEscena ||
        !_generacionesEnCurso.add(claveGeneracion)) {
      throw StateError('Ya se está generando esta escena.');
    }

    _generandoSiguienteEscena = true;

    try {
      // -----------------------------------------------
      // 1. CONSTRUIR CONTEXTO ACUMULADO CON LÍMITES
      // -----------------------------------------------

      final contextoNarrativo = contextoNarrativoService.construirContexto(
        cuento,
        maxCaracteres: narrativaConfig.maxCaracteresContexto,
      );

      final textoFuente = cuento.textoFuente ?? '';
      final textoFuenteLimitado =
          textoFuente.length > narrativaConfig.maxCaracteresTextoFuente
          ? textoFuente.substring(0, narrativaConfig.maxCaracteresTextoFuente)
          : textoFuente;

      // -----------------------------------------------
      // 2. SOLICITAR ESCENA A GEMINI (CON REINTENTOS)
      // -----------------------------------------------

      final esUltimaEscena = numeroNuevaEscena >= narrativaConfig.maxEscenas;

      GeneratedScene? resultado;
      Object? ultimoError;

      for (
        var intento = 0;
        intento <= narrativaConfig.maxReintentos;
        intento++
      ) {
        try {
          final res = await aiService
              .generarEscena(
                titulo: cuento.titulo,
                personajePrincipal: cuento.personajePrincipal,
                personajeOriginal: cuento.personajeOriginal,
                esPersonajeNuevo: cuento.esPersonajeNuevo,
                descripcionPersonaje: cuento.descripcionPersonaje,
                textoFuente: textoFuenteLimitado,
                resumenOriginal: cuento.resumenOriginal ?? '',
                escenarioOriginal: cuento.escenarioOriginal ?? '',
                conflictoPrincipal: cuento.conflictoPrincipal ?? '',
                finalOriginal: cuento.finalOriginal ?? '',
                contextoNarrativo: contextoNarrativo,
                decisionActual: opcion,
                numeroEscena: numeroNuevaEscena,
                esUltimaEscena: esUltimaEscena,
              )
              .timeout(narrativaConfig.timeoutGeneracion);

          if (esUltimaEscena) {
            // El contenido final debe nacer como desenlace desde la generación.
            // Si la IA no finalizó o el texto sigue abierto, se rechaza y se reintenta.
            if (!res.esFinal ||
                res.opciones.isNotEmpty ||
                esFinalAbierto(res.contenido)) {
              throw StateError(
                'La IA generó una escena final abierta o sin desenlace conclusivo.',
              );
            }
          }

          resultado = res;
          break;
        } catch (e) {
          ultimoError = e;
          if (intento < narrativaConfig.maxReintentos) {
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }
      }

      if (resultado == null) {
        throw StateError(
          'No se pudo generar la siguiente escena tras reintentar: $ultimoError',
        );
      }

      // -----------------------------------------------
      // 3. CREAR MODELO DE ESCENA
      // -----------------------------------------------

      final contenidoSanitizado = cuento.requiereSustitucionNombreOriginal
          ? sanitizarNombrePersonaje(
              resultado.contenido,
              original: cuento.personajeOriginal!,
              actual: cuento.personajePrincipal,
            )
          : resultado.contenido;

      final opcionesSanitizadas = cuento.requiereSustitucionNombreOriginal
          ? resultado.opciones
                .map(
                  (op) => sanitizarNombrePersonaje(
                    op,
                    original: cuento.personajeOriginal!,
                    actual: cuento.personajePrincipal,
                  ),
                )
                .toList()
          : resultado.opciones;

      final esFinalForzado = esUltimaEscena;

      final List<String> opcionesDefinitivas;
      if (esFinalForzado) {
        opcionesDefinitivas = [];
      } else {
        if (opcionesSanitizadas.isNotEmpty) {
          opcionesDefinitivas = opcionesSanitizadas;
        } else {
          opcionesDefinitivas = [
            'Seguir explorando el camino',
            'Buscar una solución diferente con ingenio',
            'Pedir ayuda a un amigo cercano',
          ];
        }
      }

      final nuevaEscena = Escena(
        numero: numeroNuevaEscena,
        contenido: contenidoSanitizado,
        opciones: opcionesDefinitivas,
        esFinal: esFinalForzado,
      );

      // -----------------------------------------------
      // 4. REGISTRAR DECISIÓN
      // -----------------------------------------------

      // La registramos después de recibir la escena,
      // para no dejar una decisión nueva en memoria
      // cuando falla Gemini.

      if (decisionExistente == null) {
        cuento.registrarDecision(
          DecisionNarrativa(
            numeroEscena: escenaActual.numero,
            opcionSeleccionada: opcion,
          ),
        );
      }

      // -----------------------------------------------
      // 5. AÑADIR ESCENA AL CUENTO
      // -----------------------------------------------

      cuento.agregarEscena(nuevaEscena);

      // -----------------------------------------------
      // 6. GUARDAR EN SUPABASE
      // -----------------------------------------------

      await cuentoRepository.guardarCuento(cuento);

      return nuevaEscena;
    } finally {
      _generacionesEnCurso.remove(claveGeneracion);
      _generandoSiguienteEscena = false;
    }
  }

  // =====================================================
  // AGREGAR ESCENA MANUAL
  // =====================================================

  Future<void> agregarEscena({
    required Cuento cuento,
    required String contenido,
  }) async {
    if (contenido.trim().isEmpty) {
      throw ArgumentError('El contenido de la escena no puede estar vacío.');
    }

    final siguienteNumero = cuento.escenas.isEmpty
        ? 1
        : cuento.escenas
                  .map((escena) => escena.numero)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final nuevaEscena = Escena(numero: siguienteNumero, contenido: contenido);

    cuento.agregarEscena(nuevaEscena);

    await cuentoRepository.guardarCuento(cuento);
  }

  // =====================================================
  // SANITIZACIÓN DE NOMBRE DE PROTAGONISTA
  // =====================================================

  /// Sanitiza el texto de una escena generada reemplazando ocurrencias del nombre original
  /// por el nombre personalizado, usando límites de palabra para no alterar otras palabras.
  static String sanitizarNombrePersonaje(
    String texto, {
    required String original,
    required String actual,
  }) {
    final orig = original.trim();
    final act = actual.trim();
    if (orig.isEmpty ||
        act.isEmpty ||
        orig.toLowerCase() == act.toLowerCase()) {
      return texto;
    }

    final pattern = RegExp(
      r'(?<![\wáéíóúüñÁÉÍÓÚÜÑ])' +
          RegExp.escape(orig) +
          r'(?![\wáéíóúüñÁÉÍÓÚÜÑ])',
      caseSensitive: false,
    );
    return texto.replaceAll(pattern, act);
  }

  // =====================================================
  // DETECCIÓN DE FINAL ABIERTO
  // =====================================================

  /// Detecta si el texto de una supuesta escena final contiene señales
  /// evidentes de final abierto, inconcluso o que posterga la resolución.
  static bool esFinalAbierto(String texto) {
    if (texto.trim().isEmpty) return true;
    final min = texto.toLowerCase();
    const patrones = [
      'siguiente paso',
      'siguientes pasos',
      'decidió investigar',
      'decidieron investigar',
      'qué ocurrirá',
      'que ocurrira',
      'qué pasará',
      'que pasara',
      'qué hará',
      'que hara',
      'continuará',
      'continuara',
      'tendrá que descubrir',
      'tendra que descubrir',
      'tendrán que descubrir',
      'tendran que descubrir',
      'aún debía averiguar',
      'aun debia averiguar',
      'aún quedaba por descubrir',
      'aun quedaba por descubrir',
      'un nuevo misterio',
      'un misterio aún mayor',
      'una nueva aventura comenzaba',
      'la aventura apenas comenzaba',
    ];
    return patrones.any((p) => min.contains(p));
  }

  // =====================================================
  // GESTIÓN DE ILUSTRACIONES POR ESCENA
  // =====================================================

  /// Comprueba si actualmente se está generando la imagen para una escena dada.
  bool estaGenerandoImagen(String cuentoId, int numeroEscena) {
    return _generacionesImagenEnCurso.contains('$cuentoId:$numeroEscena');
  }

  /// Asegura que la escena cuente con una ilustración asociada.
  /// - Si la escena ya cuenta con [imageUrl], la devuelve inmediatamente (reutilización estricta).
  /// - Si ya hay una generación activa para esta escena, bloquea solicitudes duplicadas concurrentes.
  /// - Si la llamada falla o no hay [imageService], devuelve null sin bloquear el flujo del cuento.
  Future<String?> asegurarIlustracionEscena({
    required Cuento cuento,
    required int numeroEscena,
    bool forzarReintento = false,
  }) async {
    final escena = cuento.obtenerEscena(numeroEscena);
    if (escena == null) return null;

    // 1. Reutilización estricta: nunca regenerar si ya tiene URL salvo reintento manual forzado
    if (!forzarReintento &&
        escena.imageUrl != null &&
        escena.imageUrl!.trim().isNotEmpty) {
      return escena.imageUrl;
    }

    // 2. Si no hay servicio configurado, no hacer nada
    if (imageService == null) {
      return null;
    }

    final clave = '${cuento.id}:$numeroEscena';
    // 3. Prevenir doble clic o generaciones concurrentes para la misma escena
    if (!_generacionesImagenEnCurso.add(clave)) {
      return null;
    }

    try {
      Uint8List? referenciaBytes;
      Uint8List? referenciaAnteriorBytes;

      if (cuento.esModoDibujo) {
        // En escena 1: usar el dibujo del estudiante como referencia principal.
        referenciaBytes = cuento.referenciaVisualPng;
        // En escenas 2, 3, 4: usar dibujo original + anchor de la escena anterior
        if (numeroEscena > 1) {
          referenciaAnteriorBytes = cuento.obtenerImagenBytesEscena(
            numeroEscena - 1,
          );
        }
      } else {
        referenciaBytes = cuento.obtenerReferenciaVisualParaEscena(
          numeroEscena,
        );
        if (numeroEscena > 1) {
          referenciaAnteriorBytes = cuento.obtenerImagenBytesEscena(
            numeroEscena - 1,
          );
        }
      }

      // Si es modo dibujo y proviene de PDF (el estudiante dibujó la apariencia del personaje),
      // la descripción visual para la ilustración NO debe imponer los rasgos físicos del PDF (ej: niña).
      // Debe representar fielmente el diseño del dibujo del estudiante.
      final String? descripcionVisualParaImagen =
          cuento.esModoDibujo && cuento.origen == CuentoOrigen.pdf
          ? 'Representar a ${cuento.personajePrincipal} utilizando fielmente el diseño del personaje dibujado por el estudiante.'
          : cuento.descripcionPersonaje;

      final solicitud = SolicitudImagenEscena(
        cuentoId: cuento.id,
        numeroEscena: numeroEscena,
        contenidoEscena: escena.contenido,
        nombreProtagonista: cuento.personajePrincipal,
        descripcionPersonaje: descripcionVisualParaImagen,
        escenario: cuento.escenarioOriginal,
        referenciaVisualBytes: referenciaBytes,
        referenciaAnteriorBytes: referenciaAnteriorBytes,
        esModoDibujo: cuento.esModoDibujo,
      );

      final url = await imageService!
          .generarIlustracionEscena(solicitud)
          .timeout(const Duration(seconds: 40));

      if (url.trim().isNotEmpty) {
        final urlFinal = url.trim();
        cuento.asociarImagenAEscena(numeroEscena, urlFinal);

        // Guardar bytes generados para consistencia de anchors futuros
        if (IlustracionEscenaWidget.esDataUri(urlFinal)) {
          final bytesEscena = IlustracionEscenaWidget.decodificarDataUri(
            urlFinal,
          );
          if (bytesEscena != null && bytesEscena.isNotEmpty) {
            cuento.registrarImagenEscena(numeroEscena, bytesEscena);
            if (numeroEscena == 1 && cuento.referenciaVisualPng == null) {
              cuento.registrarReferenciaEscena1(bytesEscena);
            }
          }
        }

        // Guardar la URL en la base de datos (escenas.image_url)
        await cuentoRepository.guardarCuento(cuento);
        return urlFinal;
      }
      return null;
    } on ImageAuthException {
      // 401 y 403 son errores de autenticación/autorización:
      // NO deben enmascararse como fallo genérico de imagen ni reintentarse automáticamente.
      rethrow;
    } catch (_) {
      // Si la imagen falla por causas transitorias (red, 5xx), NO bloquear el cuento ni la narrativa
      return null;
    } finally {
      _generacionesImagenEnCurso.remove(clave);
    }
  }
}
