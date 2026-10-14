import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from '@supabase/supabase-js';
import { validarEstudianteAutenticado } from '../_shared/auth.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
};

const respond = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return respond(405, { error: 'Método no permitido. Solo se acepta POST.' });
  }

  // 1. Validar autenticación de estudiante vía JWT
  const auth = await validarEstudianteAutenticado(req, corsHeaders);
  if (!auth.ok) {
    return auth.response!;
  }

  try {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return respond(400, { error: 'Cuerpo de solicitud JSON inválido.' });
    }

    const intentoId = typeof body.intentoId === 'string'
      ? body.intentoId.trim()
      : (typeof body.intento_id === 'string' ? body.intento_id.trim() : '');
    const numero = Number(body.numero);
    const indice = Number(body.indiceSeleccionado ?? body.indice_seleccionado);

    if (
      !/^[a-fA-F0-9-]{36}$/.test(intentoId) ||
      !Number.isInteger(numero) ||
      numero < 1 ||
      numero > 5 ||
      !Number.isInteger(indice) ||
      indice < 0 ||
      indice > 3
    ) {
      return respond(400, { error: 'Datos de respuesta inválidos o fuera de rango.' });
    }

    const url = Deno.env.get('SUPABASE_URL');
    const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) {
      console.error('Variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY no configuradas');
      return respond(500, { error: 'Servicio no configurado adecuadamente.' });
    }

    const service = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 2. Invocar la función RPC transaccional que valida autorización, inmutabilidad y califica
    const { data, error } = await service.rpc('responder_pregunta_segura', {
      p_intento_id: intentoId,
      p_numero: numero,
      p_indice: indice,
      p_estudiante_id: auth.userId,
    });

    if (error) {
      console.error('Error en responder_pregunta_segura:', error.code, error.message);
      if (error.code === '42501') {
        return respond(403, { error: 'Intento no autorizado para este estudiante.' });
      }
      return respond(409, {
        error: error.message || 'No se pudo registrar la respuesta o ya fue confirmada.',
      });
    }

    return respond(200, data as Record<string, unknown>);
  } catch (err) {
    console.error('Error inesperado en responder-pregunta:', err);
    return respond(500, { error: 'Error interno en el servidor.' });
  }
});
