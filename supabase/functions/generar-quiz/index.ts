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

const modelos = [
  'gemini-3.5-flash-lite',
  'gemini-3.6-flash',
  'gemini-3.8-flash',
];

const TIMEOUT_MS = 25000;

export interface PreguntaGeminiRaw {
  numero: number;
  pregunta: string;
  opciones: string[];
  indiceCorrecto: number;
  explicacion: string;
}

export function validarEstructuraPreguntas(preguntas: unknown): PreguntaGeminiRaw[] | null {
  if (!Array.isArray(preguntas) || preguntas.length !== 5) {
    return null;
  }

  const resultado: PreguntaGeminiRaw[] = [];

  for (let i = 0; i < 5; i++) {
    const item = preguntas[i];
    if (!item || typeof item !== 'object') return null;

    const pregunta = typeof item.pregunta === 'string' ? item.pregunta.trim() : '';
    if (pregunta.length < 5) return null;

    if (!Array.isArray(item.opciones) || item.opciones.length !== 4) return null;

    const opcionesLimpia = item.opciones.map((op: unknown) =>
      typeof op === 'string' ? op.trim() : '',
    );

    // Todas deben ser no vacías
    if (opcionesLimpia.some((op: string) => op.length === 0)) return null;

    // Todas deben ser distintas entre sí
    const unicas = new Set(opcionesLimpia.map((op: string) => op.toLowerCase()));
    if (unicas.size !== 4) return null;

    const indiceCorrecto = Number(item.indiceCorrecto);
    if (!Number.isInteger(indiceCorrecto) || indiceCorrecto < 0 || indiceCorrecto > 3) {
      return null;
    }

    const explicacion = typeof item.explicacion === 'string' ? item.explicacion.trim() : '';
    if (explicacion.length < 5) return null;

    resultado.push({
      numero: i + 1,
      pregunta,
      opciones: opcionesLimpia,
      indiceCorrecto,
      explicacion,
    });
  }

  return resultado;
}

async function llamarGemini(
  url: string,
  apiKey: string,
  requestBody: string,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    return await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: requestBody,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

export async function solicitarPreguntasAGemini(params: {
  titulo: string;
  personajePrincipal: string;
  caminoRecorrido: string;
  geminiApiKey: string;
}): Promise<PreguntaGeminiRaw[]> {
  const prompt = `
Eres un especialista en evaluación pedagógica y comprensión lectora para educación primaria (aproximadamente 4.º grado de primaria, niños de 9 a 10 años).
Tu tarea es generar EXACTAMENTE CINCO (5) preguntas de opción múltiple para evaluar la comprensión del cuento que el estudiante acaba de completar.

REGLAS PEDAGÓGICAS ESTRICTAS:
1. Basado EXCLUSIVAMENTE en el cuento: Las preguntas deben basarse única y exclusivamente en los acontecimientos, personajes, decisiones y desenlace del camino recorrido por el estudiante. NO inventes sucesos ajenos ni preguntes por hechos que no ocurrieron.
2. Nivel primaria: Vocabulario claro, oraciones comprensibles, sin ambigüedades, sin preguntas tramposas y sin dobles negaciones.
3. Variedad de tipos de pregunta (distribución deseada):
   - Preguntas 1 y 2: Comprensión literal (detalles explícitos, lugares, objetos o personajes encontrados).
   - Pregunta 3: Secuencia temporal o causa/efecto (qué ocurrió después de cierto hecho, o por qué sucedió algo).
   - Pregunta 4: Inferencia sencilla (cómo se sentía un personaje, intenciones evidentes o lección de la aventura).
   - Pregunta 5: Decisión, acción o desenlace (relacionada con las decisiones tomadas por el protagonista o cómo se resolvió el conflicto final).
4. Opciones de respuesta:
   - Exactamente cuatro (4) alternativas por pregunta.
   - Exactamente UNA alternativa correcta objetiva.
   - Tres distractores plausibles en el contexto del cuento, pero inequívocamente incorrectos.
   - Las cuatro opciones deben ser distintas entre sí y tener longitud similar.
5. Índice correcto: Un entero exacto entre 0 y 3 que indique la posición de la alternativa correcta en la lista de opciones.
6. Explicación: Una breve explicación (1 o 2 oraciones) orientada al niño, fundamentando por qué esa opción es la correcta según la historia.
7. Seguridad infantil: Contenido 100% apto para niños de primaria. Absolutamente prohibido contenido violento o inapropiado.

INFORMACIÓN DEL CUENTO Y CAMINO RECORRIDO POR EL ESTUDIANTE:
- Título: "${params.titulo}"
- Protagonista: "${params.personajePrincipal}"

HISTORIA RECORRIDA:
${params.caminoRecorrido}

Devuelve estrictamente un JSON con la estructura solicitada.
`;

  const requestBody = JSON.stringify({
    contents: [
      {
        role: 'user',
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      responseMimeType: 'application/json',
      maxOutputTokens: 2500,
      responseSchema: {
        type: 'OBJECT',
        properties: {
          preguntas: {
            type: 'ARRAY',
            description: 'Lista de exactamente 5 preguntas de comprensión lectora',
            items: {
              type: 'OBJECT',
              properties: {
                numero: { type: 'INTEGER', description: 'Número del 1 al 5' },
                pregunta: { type: 'STRING', description: 'Texto de la pregunta' },
                opciones: {
                  type: 'ARRAY',
                  description: 'Exactamente 4 alternativas distintas',
                  items: { type: 'STRING' },
                },
                indiceCorrecto: { type: 'INTEGER', description: 'Índice de la opción correcta (0 a 3)' },
                explicacion: { type: 'STRING', description: 'Explicación de la respuesta correcta' },
              },
              required: ['numero', 'pregunta', 'opciones', 'indiceCorrecto', 'explicacion'],
            },
          },
        },
        required: ['preguntas'],
      },
    },
  });

  let ultimoError = '';

  for (let intento = 1; intento <= 2; intento++) {
    for (const modelo of modelos) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`;

      try {
        const response = await llamarGemini(url, params.geminiApiKey, requestBody);
        if (!response.ok) {
          const errText = await response.text();
          ultimoError = `Modelo ${modelo} devolvió ${response.status}: ${errText.substring(0, 100)}`;
          continue;
        }

        const data = await response.json();
        const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!rawText) {
          ultimoError = `Modelo ${modelo} devolvió respuesta sin texto`;
          continue;
        }

        const parsed = JSON.parse(rawText);
        const validado = validarEstructuraPreguntas(parsed.preguntas);
        if (validado) {
          return validado;
        }

        ultimoError = 'Estructura de preguntas inválida devuelta por Gemini';
      } catch (err) {
        ultimoError = err instanceof Error ? err.message : String(err);
      }
    }
  }

  throw new Error(`Fallo generando quiz con Gemini tras reintentos: ${ultimoError}`);
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

    const cuentoId = body.cuentoId?.toString().trim() || body.cuento_id?.toString().trim();
    if (!cuentoId) {
      return new Response(
        JSON.stringify({ error: 'Falta el parámetro requerido: cuentoId.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 2. Validar pertenencia del cuento mediante RLS del estudiante
    const { data: cuento, error: errCuento } = await authResult.userClient!
      .from('cuentos')
      .select('id, titulo, personaje_principal, conflicto_principal, final_original, estudiante_id, aula_id')
      .eq('id', cuentoId)
      .maybeSingle();

    if (errCuento || !cuento || cuento.estudiante_id !== authResult.userId) {
      return new Response(
        JSON.stringify({
          error: 'Acceso denegado. El cuento especificado no pertenece al estudiante o no existe.',
        }),
        { status: 403, headers: jsonHeaders },
      );
    }

    // 3. Obtener escenas y verificar que la aventura esté completada
    const { data: escenas, error: errEscenas } = await authResult.userClient!
      .from('escenas')
      .select('numero, contenido, es_final')
      .eq('cuento_id', cuentoId)
      .order('numero', { ascending: true });

    if (errEscenas || !escenas || escenas.length === 0) {
      return new Response(
        JSON.stringify({ error: 'El cuento no tiene escenas registradas.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const escenaFinal = escenas.find((e: { es_final: boolean }) => e.es_final === true);
    if (!escenaFinal && escenas.length < 4) {
      return new Response(
        JSON.stringify({
          error: 'El cuento aún no ha finalizado. El quiz solo puede generarse cuando la aventura está terminada.',
        }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 4. Preparar cliente de servicio para operaciones de base de datos
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

    // 5. IDEMPOTENCIA: Verificar si ya existe un intento para este cuento/estudiante
    const { data: intentoExistente } = await serviceClient
      .from('quiz_intentos')
      .select('id, estado, puntaje, total_preguntas, porcentaje')
      .eq('cuento_id', cuentoId)
      .eq('estudiante_id', authResult.userId)
      .maybeSingle();

    if (intentoExistente) {
      if (intentoExistente.estado === 'en_progreso') {
        const { data: respuestasGuardadas, error: errResp } = await serviceClient
          .from('quiz_respuestas')
          .select('numero_pregunta, pregunta, opciones')
          .eq('intento_id', intentoExistente.id)
          .order('numero_pregunta', { ascending: true });

        if (!errResp && respuestasGuardadas && respuestasGuardadas.length === 5) {
          return new Response(
            JSON.stringify({
              intentoId: intentoExistente.id,
              estado: 'en_progreso',
              preguntas: respuestasGuardadas.map((r: { numero_pregunta: number; pregunta: string; opciones: string[] }) => ({
                numero: r.numero_pregunta,
                pregunta: r.pregunta,
                opciones: r.opciones,
              })),
            }),
            { status: 200, headers: jsonHeaders },
          );
        }
      } else if (intentoExistente.estado === 'completado') {
        const { data: respuestasGuardadas } = await serviceClient
          .from('quiz_respuestas')
          .select('numero_pregunta, pregunta, opciones, indice_seleccionado, indice_correcto, es_correcta, explicacion')
          .eq('intento_id', intentoExistente.id)
          .order('numero_pregunta', { ascending: true });

        return new Response(
          JSON.stringify({
            intentoId: intentoExistente.id,
            estado: 'completado',
            puntaje: intentoExistente.puntaje,
            total: intentoExistente.total_preguntas,
            porcentaje: intentoExistente.porcentaje,
            respuestas: (respuestasGuardadas || []).map((r: {
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

    // 6. Obtener decisiones narrativas reales tomadas por el estudiante
    const { data: decisiones } = await authResult.userClient!
      .from('decisiones_narrativas')
      .select('numero_escena, opcion_seleccionada')
      .eq('cuento_id', cuentoId)
      .order('numero_escena', { ascending: true });

    // 7. Construir resumen cronológico del camino recorrido
    let caminoRecorrido = '';
    for (const esc of escenas) {
      caminoRecorrido += `\n[ESCENA ${esc.numero}]\n${esc.contenido}\n`;
      const dec = (decisiones || []).find((d: { numero_escena: number }) => d.numero_escena === esc.numero);
      if (dec) {
        caminoRecorrido += `DECISIÓN TOMADA POR EL ESTUDIANTE: "${dec.opcion_seleccionada}"\n`;
      }
    }

    const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiApiKey) {
      console.error('GEMINI_API_KEY no está configurada');
      return new Response(
        JSON.stringify({ error: 'El servicio de IA no está configurado adecuadamente.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // 8. Llamar a Gemini para generar exactamente las 5 preguntas
    let preguntasGeneradas: PreguntaGeminiRaw[];
    try {
      preguntasGeneradas = await solicitarPreguntasAGemini({
        titulo: cuento.titulo,
        personajePrincipal: cuento.personaje_principal,
        caminoRecorrido,
        geminiApiKey,
      });
    } catch (genErr) {
      console.error('Error generando preguntas con Gemini:', genErr);
      return new Response(
        JSON.stringify({
          error: 'No pudimos preparar las preguntas en este momento. Inténtalo nuevamente.',
        }),
        { status: 503, headers: jsonHeaders },
      );
    }

    // 9. Persistir el intento en quiz_intentos y las 5 preguntas en quiz_respuestas
    const { data: nuevoIntento, error: errInsertIntento } = await serviceClient
      .from('quiz_intentos')
      .insert({
        cuento_id: cuentoId,
        estudiante_id: authResult.userId,
        aula_id: cuento.aula_id,
        estado: 'en_progreso',
        total_preguntas: 5,
      })
      .select('id')
      .single();

    if (errInsertIntento || !nuevoIntento) {
      console.error('Error insertando intento en quiz_intentos:', errInsertIntento);
      return new Response(
        JSON.stringify({ error: 'Error registrando el quiz en el sistema.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    const filasRespuestas = preguntasGeneradas.map((p) => ({
      intento_id: nuevoIntento.id,
      numero_pregunta: p.numero,
      pregunta: p.pregunta,
      opciones: p.opciones,
      indice_correcto: p.indiceCorrecto,
      explicacion: p.explicacion,
    }));

    const { error: errInsertRespuestas } = await serviceClient
      .from('quiz_respuestas')
      .insert(filasRespuestas);

    if (errInsertRespuestas) {
      console.error('Error insertando preguntas en quiz_respuestas:', errInsertRespuestas);
      // Limpiar intento parcial para evitar estado huérfano
      await serviceClient.from('quiz_intentos').delete().eq('id', nuevoIntento.id);
      return new Response(
        JSON.stringify({ error: 'Error registrando las preguntas del quiz.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // 10. Retornar a Flutter ÚNICAMENTE las preguntas sanitizadas (SIN indiceCorrecto ni explicacion)
    const preguntasSanitizadas = preguntasGeneradas.map((p) => ({
      numero: p.numero,
      pregunta: p.pregunta,
      opciones: p.opciones,
    }));

    return new Response(
      JSON.stringify({
        intentoId: nuevoIntento.id,
        estado: 'en_progreso',
        preguntas: preguntasSanitizadas,
      }),
      { status: 200, headers: jsonHeaders },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error('Error inesperado en generar-quiz:', msg);
    return new Response(
      JSON.stringify({ error: 'Error interno en el servidor.' }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
