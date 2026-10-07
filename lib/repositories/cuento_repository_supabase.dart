import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cuento.dart';
import '../models/decision_narrativa.dart';
import '../models/escena.dart';
import 'cuento_repository.dart';

class CuentoRepositorySupabase implements CuentoRepository {
  final SupabaseClient client;

  CuentoRepositorySupabase({required this.client});

  String _textoSeguro(String texto) {
    return texto
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .trim();
  }

  String? _textoSeguroOpcional(String? texto) {
    if (texto == null) {
      return null;
    }

    final limpio = _textoSeguro(texto);

    if (limpio.isEmpty) {
      return null;
    }

    return limpio;
  }

  @override
  Future<void> guardarCuento(Cuento cuento) async {
    debugPrint(
      '[DIAGNÓSTICO C] Antes de guardar Supabase: '
      'cuento.id="${cuento.id}", '
      'descripcion_personaje="${cuento.descripcionPersonaje ?? '(null)'}"',
    );

    String? estudianteId = cuento.estudianteId;
    String? aulaId = cuento.aulaId;
    bool esDemo = cuento.esDemo;

    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      // 1. Validar rol del usuario actual en profiles
      final profileData = await client
          .from('profiles')
          .select('rol')
          .eq('id', currentUser.id)
          .maybeSingle();

      final rol = profileData?['rol']?.toString().toLowerCase();

      if (rol == 'docente') {
        throw StateError(
          'Los docentes no tienen permiso para crear o guardar cuentos.',
        );
      }

      if (rol == 'estudiante') {
        estudianteId ??= currentUser.id;

        // Si aulaId aún no está asignado, consultar las matrículas del estudiante
        if (aulaId == null) {
          final matriculas = await client
              .from('aula_estudiantes')
              .select('aula_id')
              .eq('estudiante_id', currentUser.id);

          if (matriculas.length == 1) {
            aulaId = matriculas.first['aula_id']?.toString();
          } else {
            // Si tiene 0 o más de un aula, queda null por diseño del piloto
            aulaId = null;
          }
        }
      }
    } else {
      // Sin sesión activa (modo demo / compatibilidad histórica)
      if (estudianteId == null) {
        esDemo = true;
      }
    }

    await client.from('cuentos').upsert({
      'id': _textoSeguro(cuento.id),
      'titulo': _textoSeguro(cuento.titulo),
      'personaje_principal': _textoSeguro(cuento.personajePrincipal),
      'origen': cuento.origenDatabase,

      'texto_fuente': _textoSeguroOpcional(cuento.textoFuente),

      'resumen_original': _textoSeguroOpcional(cuento.resumenOriginal),

      'escenario_original': _textoSeguroOpcional(cuento.escenarioOriginal),

      'conflicto_principal': _textoSeguroOpcional(cuento.conflictoPrincipal),

      'final_original': _textoSeguroOpcional(cuento.finalOriginal),

      'descripcion_personaje': _textoSeguroOpcional(
        cuento.descripcionPersonaje,
      ),

      'estudiante_id': estudianteId,
      'aula_id': aulaId,
      'es_demo': esDemo,
    }, onConflict: 'id');

    if (cuento.escenas.isNotEmpty) {
      final escenasData = cuento.escenas.map((escena) {
        return {
          'cuento_id': _textoSeguro(cuento.id),
          'numero': escena.numero,
          'contenido': _textoSeguro(escena.contenido),
          'image_url': _textoSeguroOpcional(escena.imageUrl),
          'opciones': escena.opciones.map(_textoSeguro).toList(),
          'es_final': escena.esFinal,
        };
      }).toList();

      await client
          .from('escenas')
          .upsert(escenasData, onConflict: 'cuento_id,numero');
    }

    if (cuento.decisiones.isNotEmpty) {
      final decisionesData = cuento.decisiones.map((decision) {
        return {
          'cuento_id': _textoSeguro(cuento.id),
          'numero_escena': decision.numeroEscena,
          'opcion_seleccionada': _textoSeguro(decision.opcionSeleccionada),
        };
      }).toList();

      await client
          .from('decisiones_narrativas')
          .upsert(decisionesData, onConflict: 'cuento_id,numero_escena');
    }
  }

  @override
  Future<Cuento?> obtenerCuento(String id) async {
    final cuentoData = await client
        .from('cuentos')
        .select(
          'id, '
          'titulo, '
          'personaje_principal, '
          'origen, '
          'texto_fuente, '
          'resumen_original, '
          'escenario_original, '
          'conflicto_principal, '
          'final_original, '
          'descripcion_personaje, '
          'estudiante_id, '
          'aula_id, '
          'es_demo',
        )
        .eq('id', id)
        .maybeSingle();

    if (cuentoData == null) {
      return null;
    }

    final escenasData = await client
        .from('escenas')
        .select(
          'numero, '
          'contenido, '
          'image_url, '
          'opciones, '
          'es_final',
        )
        .eq('cuento_id', id)
        .order('numero', ascending: true);

    final decisionesData = await client
        .from('decisiones_narrativas')
        .select(
          'numero_escena, '
          'opcion_seleccionada',
        )
        .eq('cuento_id', id)
        .order('numero_escena', ascending: true);

    final escenas = escenasData.map<Escena>((data) {
      final opcionesRaw = data['opciones'];

      final opciones = opcionesRaw is List
          ? opcionesRaw.map((opcion) => opcion.toString()).toList()
          : <String>[];

      return Escena(
        numero: data['numero'] as int,
        contenido: data['contenido'].toString(),
        imageUrl: data['image_url']?.toString(),
        opciones: opciones,
        esFinal: data['es_final'] as bool? ?? false,
      );
    }).toList();

    final decisiones = decisionesData.map<DecisionNarrativa>((data) {
      return DecisionNarrativa(
        numeroEscena: data['numero_escena'] as int,
        opcionSeleccionada: data['opcion_seleccionada'].toString(),
      );
    }).toList();

    final origenTexto = cuentoData['origen']?.toString().trim().toLowerCase();

    final origen = origenTexto == 'pdf'
        ? CuentoOrigen.pdf
        : CuentoOrigen.dibujo;

    return Cuento(
      id: cuentoData['id'].toString(),
      titulo: cuentoData['titulo'].toString(),
      personajePrincipal: cuentoData['personaje_principal'].toString(),
      origen: origen,

      textoFuente: cuentoData['texto_fuente']?.toString(),

      resumenOriginal: cuentoData['resumen_original']?.toString(),

      escenarioOriginal: cuentoData['escenario_original']?.toString(),

      conflictoPrincipal: cuentoData['conflicto_principal']?.toString(),

      finalOriginal: cuentoData['final_original']?.toString(),

      descripcionPersonaje: cuentoData['descripcion_personaje']?.toString(),

      estudianteId: cuentoData['estudiante_id']?.toString(),
      aulaId: cuentoData['aula_id']?.toString(),
      esDemo: cuentoData['es_demo'] as bool? ?? false,

      escenas: escenas,
      decisiones: decisiones,
    );
  }

  @override
  Future<List<Cuento>> listarCuentosPorEstudiante(String estudianteId) async {
    final cuentosData = await client
        .from('cuentos')
        .select(
          'id, '
          'titulo, '
          'personaje_principal, '
          'origen, '
          'texto_fuente, '
          'resumen_original, '
          'escenario_original, '
          'conflicto_principal, '
          'final_original, '
          'descripcion_personaje, '
          'estudiante_id, '
          'aula_id, '
          'es_demo',
        )
        .eq('estudiante_id', estudianteId)
        .eq('es_demo', false)
        .order('created_at', ascending: false);

    return cuentosData.map<Cuento>((data) {
      final origenTexto = data['origen']?.toString().trim().toLowerCase();
      final origen = origenTexto == 'pdf'
          ? CuentoOrigen.pdf
          : CuentoOrigen.dibujo;

      return Cuento(
        id: data['id'].toString(),
        titulo: data['titulo'].toString(),
        personajePrincipal: data['personaje_principal'].toString(),
        origen: origen,
        textoFuente: data['texto_fuente']?.toString(),
        resumenOriginal: data['resumen_original']?.toString(),
        escenarioOriginal: data['escenario_original']?.toString(),
        conflictoPrincipal: data['conflicto_principal']?.toString(),
        finalOriginal: data['final_original']?.toString(),
        descripcionPersonaje: data['descripcion_personaje']?.toString(),
        estudianteId: data['estudiante_id']?.toString(),
        aulaId: data['aula_id']?.toString(),
        esDemo: data['es_demo'] as bool? ?? false,
      );
    }).toList();
  }
}
