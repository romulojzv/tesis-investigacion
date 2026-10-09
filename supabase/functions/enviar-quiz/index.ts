import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from '@supabase/supabase-js';
import { validarEstudianteAutenticado } from '../_shared/auth.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const jsonHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json',
};

interface RespuestaEnviada {
  numero: number;
  indiceSeleccionado: number;
}

export function validarRespuestasEnviadas(respuestas: unknown): RespuestaEnviada[] | null {
  if (!Array.isArray(respuestas) || respuestas.length !== 5) {
    return null;
  }

  const vistas = new Set<number>();
  const resultado: RespuestaEnviada[] = [];

  for (const item of respuestas) {
    if (!item || typeof item !== 'object') return null;

    const numero = Number((item as Record<string, unknown>).numero);
    if (!Number.isInteger(numero) || numero < 1 || numero > 5) return null;

    if (vistas.has(numero)) return null; // Número duplicado
    vistas.add(numero);

    const indice = Number((item as Record<string, unknown>).indiceSeleccionado);
    if (!Number.isInteger(indice) || indice < 0 || indice > 3) return null;

    resultado.push({ numero, indiceSeleccionado: indice });
  }

  if (vistas.size !== 5) return null;

  return resultado.sort((a, b) => a.numero - b.numero);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Método no permitido. Solo se acepta POST.' }),
      { status: 405, headers: jsonHeaders },
    );
  }

  // 1. Validar autenticación de estudiante
  const authResult = await validarEstudianteAutenticado(req, corsHeaders);
  if (!authResult.ok) {
    return authResult.response!;
  }

  try {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: 'El cuerpo de la solicitud no es un JSON válido.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const intentoId = body.intentoId?.toString().trim() || body.intento_id?.toString().trim();
    if (!intentoId) {
      return new Response(
        JSON.stringify({ error: 'Falta el parámetro requerido: intentoId.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 2. Validar que vengan exactamente 5 respuestas válidas
    const respuestasValidadas = validarRespuestasEnviadas(body.respuestas);
    if (!respuestasValidadas) {
      return new Response(
        JSON.stringify({
          error: 'Debe responder exactamente las 5 preguntas del quiz con alternativas válidas (0 a 3).',
        }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 3. Preparar cliente de servicio para base de datos
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY no configuradas');
      return new Response(
        JSON.stringify({ error: 'Error de configuración interna del servidor.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 4. Cargar intento y validar propiedad por el estudiante
    const { data: intento, error: errIntento } = await serviceClient
      .from('quiz_intentos')
      .select('id, estudiante_id, estado, puntaje, total_preguntas, porcentaje')
      .eq('id', intentoId)
      .maybeSingle();

    if (errIntento || !intento || intento.estudiante_id !== authResult.userId) {
      return new Response(
        JSON.stringify({
          error: 'Acceso denegado. El intento no pertenece al estudiante o no existe.',
        }),
        { status: 403, headers: jsonHeaders },
      );
    }

    // 5. IDEMPOTENCIA: Si el intento ya está completado, no volver a calcular
    if (intento.estado === 'completado') {
      const { data: respuestasCompletadas, error: errC } = await serviceClient
        .from('quiz_respuestas')
        .select('numero_pregunta, pregunta, opciones, indice_seleccionado, indice_correcto, es_correcta, explicacion')
        .eq('intento_id', intento.id)
        .order('numero_pregunta', { ascending: true });

      if (!errC && respuestasCompletadas && respuestasCompletadas.length === 5) {
        return new Response(
          JSON.stringify({
            intentoId: intento.id,
            estado: 'completado',
            puntaje: intento.puntaje,
            total: intento.total_preguntas,
            porcentaje: intento.porcentaje,
            respuestas: respuestasCompletadas.map((r: {
              numero_pregunta: number;
              pregunta: string;
              opciones: string[];
              indice_seleccionado: number | null;
              indice_correcto: number;
              es_correcta: boolean | null;
              explicacion: string;
            }) => ({
              numero: r.numero_pregunta,
              pregunta: r.pregunta,
              opciones: r.opciones,
              indiceSeleccionado: r.indice_seleccionado,
              indiceCorrecto: r.indice_correcto,
              esCorrecta: r.es_correcta,
              explicacion: r.explicacion,
            })),
          }),
          { status: 200, headers: jsonHeaders },
        );
      }
    }

    // 6. Cargar preguntas guardadas desde el servidor para corregir
    const { data: preguntasGuardadas, error: errPreguntas } = await serviceClient
      .from('quiz_respuestas')
      .select('id, numero_pregunta, pregunta, opciones, indice_correcto, explicacion')
      .eq('intento_id', intento.id)
      .order('numero_pregunta', { ascending: true });

    if (errPreguntas || !preguntasGuardadas || preguntasGuardadas.length !== 5) {
      console.error('Error cargando preguntas del intento:', errPreguntas);
      return new Response(
        JSON.stringify({ error: 'No se encontraron las preguntas del intento registrado.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // 7. Corrección en el servidor (cero confianza en el cliente)
    let puntaje = 0;
    const resultadoPreguntas = [];

    for (let i = 0; i < 5; i++) {
      const preg = preguntasGuardadas[i];
      const resp = respuestasValidadas.find((r) => r.numero === preg.numero_pregunta);
      const indiceSeleccionado = resp ? resp.indiceSeleccionado : -1;
      const esCorrecta = indiceSeleccionado === preg.indice_correcto;

      if (esCorrecta) {
        puntaje++;
      }

      // Actualizar selección en DB
      const { error: errUpdResp } = await serviceClient
        .from('quiz_respuestas')
        .update({
          indice_seleccionado: indiceSeleccionado,
          es_correcta: esCorrecta,
        })
        .eq('id', preg.id);

      if (errUpdResp) {
        console.error('Error actualizando respuesta individual:', errUpdResp);
      }

      resultadoPreguntas.push({
        numero: preg.numero_pregunta,
        pregunta: preg.pregunta,
        opciones: preg.opciones,
        indiceSeleccionado,
        indiceCorrecto: preg.indice_correcto,
        esCorrecta,
        explicacion: preg.explicacion,
      });
    }

    const porcentaje = Math.round((puntaje / 5) * 100);
    const completedAt = new Date().toISOString();

    // 8. Actualizar intento a 'completado'
    const { error: errUpdIntento } = await serviceClient
      .from('quiz_intentos')
      .update({
        estado: 'completado',
        puntaje,
        porcentaje,
        completed_at: completedAt,
      })
      .eq('id', intento.id);

    if (errUpdIntento) {
      console.error('Error completando intento en quiz_intentos:', errUpdIntento);
      return new Response(
        JSON.stringify({ error: 'Error finalizando la calificación del quiz.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // 9. Retornar el resultado completo con revisión y explicaciones
    return new Response(
      JSON.stringify({
        intentoId: intento.id,
        estado: 'completado',
        puntaje,
        total: 5,
        porcentaje,
        respuestas: resultadoPreguntas,
      }),
      { status: 200, headers: jsonHeaders },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error('Error inesperado en enviar-quiz:', msg);
    return new Response(
      JSON.stringify({ error: 'Error interno en el servidor.' }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
