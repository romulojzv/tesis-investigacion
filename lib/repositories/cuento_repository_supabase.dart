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
          'descripcion_personaje',
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

      escenas: escenas,
      decisiones: decisiones,
    );
  }
}
