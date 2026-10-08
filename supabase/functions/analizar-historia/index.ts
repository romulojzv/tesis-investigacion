import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { validarEstudianteAutenticado } from '../_shared/auth.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

Deno.serve(async (req) => {
  // 1. Pre-vuelo CORS (sin requerir autenticación)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 2. Restricción de método HTTP
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Método no permitido. Solo se acepta POST.' }),
      { status: 405, headers: jsonHeaders },
    );
  }

  // 3. SEGURIDAD: Validar que el usuario tenga sesión válida y rol 'estudiante'
  const authResult = await validarEstudianteAutenticado(req, corsHeaders);
  if (!authResult.ok) {
    return authResult.response!;
  }

  try {
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

    if (!geminiApiKey) {
      console.error('GEMINI_API_KEY no está configurada.');
      return new Response(
        JSON.stringify({
          error: 'El servicio de IA no está configurado adecuadamente.',
        }),
        {
          status: 500,
          headers: jsonHeaders,
        },
      );
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({
          error: 'El cuerpo de la solicitud no es un JSON válido.',
        }),
        {
          status: 400,
          headers: jsonHeaders,
        },
      );
    }

    const texto = body.texto?.toString().trim();

    if (!texto) {
      return new Response(
        JSON.stringify({
          error: 'No se recibió texto para analizar.',
        }),
        {
          status: 400,
          headers: jsonHeaders,
        },
      );
    }

    const prompt = `
Analiza el siguiente cuento infantil.
Extrae únicamente información respaldada por el texto proporcionado.

REGLA FUNDAMENTAL DE IDIOMA:
Todos los campos descriptivos (titulo, resumen, escenario, conflictoPrincipal, finalOriginal, descripcionPersonaje) DEBEN redactarse en ESPAÑOL fluido, natural y adaptado para estudiantes de educación primaria, incluso si el cuento original está en inglés u otro idioma.

Debes identificar:
- titulo: Título adaptado o traducido al español para niños de educación primaria (por ejemplo, si en inglés se titula "The Case of the Missing Water", el título en español debe ser "El misterio del agua desaparecida").
- tituloOriginal: Título original exacto en el idioma en que está escrito el documento fuente (por ejemplo: "The Case of the Missing Water").
- personajePrincipal: Nombre del personaje principal o protagonista.
- descripcionPersonaje: Breve descripción en español de la personalidad, rol o rasgos del protagonista.
- resumen: Resumen en español de los acontecimientos esenciales del cuento (entre 60 y 120 palabras).
- escenario: Escenario principal donde transcurre la historia, descrito en español.
- conflictoPrincipal: El conflicto, problema o misterio central del cuento, explicado en español.
- finalOriginal: El desenlace o final de la historia original, explicado en español.

No inventes información que no esté en el cuento.
Si algún dato no puede determinarse claramente, devuelve una cadena vacía en ese campo.

CUENTO:
${texto}
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
        maxOutputTokens: 2000,
        responseSchema: {
          type: 'OBJECT',
          properties: {
            titulo: {
              type: 'STRING',
              description: 'Título adaptado al español para niños de primaria',
            },
            tituloOriginal: {
              type: 'STRING',
              description: 'Título original en el idioma del documento fuente',
            },
            personajePrincipal: {
              type: 'STRING',
              description: 'Nombre del personaje principal',
            },
            descripcionPersonaje: {
              type: 'STRING',
              description: 'Descripción breve del personaje en español',
            },
            resumen: {
              type: 'STRING',
              description: 'Resumen del cuento en español',
            },
            escenario: {
              type: 'STRING',
              description: 'Escenario principal en español',
            },
            conflictoPrincipal: {
              type: 'STRING',
              description: 'Conflicto principal en español',
            },
            finalOriginal: {
              type: 'STRING',
              description: 'Final original en español',
            },
          },
          required: [
            'titulo',
            'personajePrincipal',
            'descripcionPersonaje',
            'resumen',
            'escenario',
            'conflictoPrincipal',
            'finalOriginal',
          ],
        },
      },
    });

    let respuestaExitosa: Response | null = null;
    let modeloUsado = '';
    const errores: string[] = [];

    for (const modelo of modelos) {
      console.log(`Probando modelo: ${modelo}`);
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`;

      try {
        const response = await llamarGemini(url, geminiApiKey, requestBody);

        if (response.ok) {
          respuestaExitosa = response;
          modeloUsado = modelo;
          break;
        }

        const errorStatus = response.status;
        const errorText = await response.text();
        console.warn(`Modelo ${modelo} respondió ${errorStatus}.`);
        errores.push(`${modelo}: ${errorStatus} ${errorText.substring(0, 150)}`);
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') {
          console.warn(`Modelo ${modelo} superó ${TIMEOUT_MS / 1000}s de timeout.`);
          errores.push(`${modelo}: timeout`);
        } else {
          const msg = error instanceof Error ? error.message : 'Error desconocido';
          console.warn(`Error usando ${modelo}: ${msg}`);
          errores.push(`${modelo}: ${msg}`);
        }
      }
    }

    if (!respuestaExitosa) {
      console.error('Todos los modelos fallaron:', errores);
      return new Response(
        JSON.stringify({
          error:
            'El servicio de IA está temporalmente ocupado. Inténtalo nuevamente.',
        }),
        {
          status: 503,
          headers: jsonHeaders,
        },
      );
    }

    console.log(`Modelo utilizado: ${modeloUsado}`);

    const geminiData = await respuestaExitosa.json();
    const textResult =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!textResult) {
      console.error('Gemini no devolvió texto de análisis.');
      return new Response(
        JSON.stringify({
          error: 'Gemini no devolvió un análisis válido.',
        }),
        {
          status: 502,
          headers: jsonHeaders,
        },
      );
    }

    let analysis: Record<string, unknown>;
    try {
      analysis = JSON.parse(textResult);
    } catch {
      console.error('Gemini devolvió un JSON inválido.');
      return new Response(
        JSON.stringify({
          error: 'Gemini devolvió un JSON inválido.',
        }),
        {
          status: 502,
          headers: jsonHeaders,
        },
      );
    }

    console.log('Análisis completado correctamente en español.');

    return new Response(JSON.stringify(analysis), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : 'Error desconocido.';
    console.error('Error no controlado en analizar-historia:', msg);

    return new Response(
      JSON.stringify({
        error: msg,
      }),
      {
        status: 500,
        headers: jsonHeaders,
      },
    );
  }
});