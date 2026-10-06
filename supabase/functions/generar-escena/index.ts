import '@supabase/functions-js/edge-runtime.d.ts';

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

function esTextoEnEspanol(texto: string): boolean {
  if (!texto || texto.trim().length === 0) return false;
  const textoMin = texto.toLowerCase();

  // Comprobar palabras funcionales en inglés frecuentes
  const palabrasIngles = [
    ' the ',
    ' and ',
    ' with ',
    ' they ',
    ' this ',
    ' that ',
    ' from ',
    ' were ',
    ' have ',
    ' could ',
    ' would ',
  ];
  let coincidenciasIngles = 0;
  for (const palabra of palabrasIngles) {
    if (textoMin.includes(palabra)) {
      coincidenciasIngles++;
    }
  }

  // Si contiene 3 o más palabras funcionales claras en inglés, no está en español
  if (coincidenciasIngles >= 3) {
    return false;
  }

  return true;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
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

    const titulo = body.titulo?.toString().trim() ?? '';
    const personajePrincipal = body.personajePrincipal?.toString().trim() ?? '';
    const personajeOriginal = body.personajeOriginal?.toString().trim() ?? '';
    const fueRenombrado =
      personajeOriginal.length > 0 &&
      personajeOriginal.toLowerCase() !== personajePrincipal.toLowerCase();

    const textoFuente = body.textoFuente?.toString().trim() ?? '';
    const resumenOriginal = body.resumenOriginal?.toString().trim() ?? '';
    const escenarioOriginal = body.escenarioOriginal?.toString().trim() ?? '';
    const conflictoPrincipal = body.conflictoPrincipal?.toString().trim() ?? '';
    const finalOriginal = body.finalOriginal?.toString().trim() ?? '';
    const contextoNarrativo = body.contextoNarrativo?.toString().trim() ?? '';
    const decisionActual = body.decisionActual?.toString().trim() ?? '';
    const numeroEscena = Number(body.numeroEscena ?? 0);
    const esUltimaEscena = body.esUltimaEscena === true;

    if (!personajePrincipal || numeroEscena <= 0) {
      return new Response(
        JSON.stringify({
          error:
            'Faltan datos obligatorios para generar la escena (personajePrincipal o numeroEscena válido).',
        }),
        {
          status: 400,
          headers: jsonHeaders,
        },
      );
    }

    if (numeroEscena > 1 && (!contextoNarrativo || !decisionActual)) {
      return new Response(
        JSON.stringify({
          error:
            'Para escenas posteriores a la primera, contextoNarrativo y decisionActual son obligatorios.',
        }),
        {
          status: 400,
          headers: jsonHeaders,
        },
      );
    }

    const esPersonajeNuevo = body.esPersonajeNuevo === true;
    const descripcionPersonaje =
      body.descripcionPersonaje?.toString().trim() ?? '';

    // LOG TEMPORAL DE DIAGNÓSTICO E
    console.log('[DIAGNÓSTICO E] generar-escena recibido:', {
      personajePrincipal,
      numeroEscena,
      esPersonajeNuevo,
      descripcionPersonaje: descripcionPersonaje || '(vacío)',
    });

    const textoFuenteLimitado =
      textoFuente.length > 8000 ? textoFuente.substring(0, 8000) : textoFuente;

    const seccionFichaBase = descripcionPersonaje
      ? `
RASGOS BASE DEL PROTAGONISTA (CANÓNICOS Y PERMANENTES):
"${descripcionPersonaje}"
- Estos rasgos base son la fuente canónica y permanente del protagonista durante toda la aventura.
- En la narración puedes redactarlos con fluidez y naturalidad respetando fielmente estos rasgos (por ejemplo, si su ficha indica vestimenta o accesorios específicos, mantén esos colores y características exactas; NO inventes otros colores ni rasgos contradictorios).
- Solo pueden modificarse temporalmente si la propia acción de la escena lo exige (ejemplos: ponerse una capucha por lluvia, quitarse la mochila para cruzar un río nadando, ensuciarse la ropa en el camino). Dichas modificaciones temporales jamás redefinen su apariencia base ni sustituyen sus rasgos permanentes.
`
      : '';

    const reglaNombreExacto = `
REGLAS ESTRICTAS DE NOMBRE Y TRATAMIENTO:
1. Usa estrictamente "${personajePrincipal}" como el nombre propio del protagonista.
2. NO uses diminutivos no solicitados (por ejemplo, si el nombre es "${personajePrincipal}", no lo conviertas arbitrariamente en un diminutivo), salvo que el estudiante lo haya escrito con diminutivo originalmente.
3. PROHIBIDO combinar la descripción con el nombre. NO llames al personaje "${personajePrincipal} ${descripcionPersonaje || ''}".
4. NO conviertas objetos, ropa o características físicas en parte de su nombre compuesto.
`;

    const instruccionProtagonista = esPersonajeNuevo
      ? `
ATENCIÓN CRÍTICA - PROTAGONISTA NUEVO:
El estudiante ha creado un protagonista NUEVO para vivir esta aventura.

DATOS DEL PROTAGONISTA NUEVO:
- Nombre: "${personajePrincipal}"
${descripcionPersonaje ? `- Descripción física y vestimenta: "${descripcionPersonaje}"` : '- Descripción: (Sin descripción física adicional)'}

${seccionFichaBase}
${reglaNombreExacto}
5. "${personajePrincipal}" reemplaza narrativamente al protagonista del documento original ("${personajeOriginal || 'protagonista original'}"). NO debes asumir automáticamente que conserva su apariencia o personalidad original.
6. Bajo ninguna circunstancia uses el nombre original "${personajeOriginal}".
`
      : fueRenombrado
      ? `
ATENCIÓN CRÍTICA - PROTAGONISTA ORIGINAL RENOMBRADO:
El personaje es exactamente el protagonista original de la historia ("${personajeOriginal}"), pero el estudiante ha decidido cambiar únicamente su nombre a "${personajePrincipal}".
- "${personajePrincipal}" CONSERVA fielmente toda la personalidad, apariencia, descripción original, papel narrativo, habilidades y relaciones con los demás personajes de "${personajeOriginal}".
${descripcionPersonaje ? `- Descripción y rasgos del protagonista: "${descripcionPersonaje}"` : ''}
${reglaNombreExacto}
- Debes utilizar exclusivamente "${personajePrincipal}". Bajo ninguna circunstancia uses el nombre antiguo "${personajeOriginal}".
`
      : `
DATOS DEL PROTAGONISTA:
- Nombre: "${personajePrincipal}"
${seccionFichaBase}
${reglaNombreExacto}
`;

    let prompt = '';

    if (numeroEscena === 1) {
      prompt = `
Eres un narrador de cuentos interactivos infantiles para estudiantes de educación primaria.
Tu objetivo es crear la ESCENA INICIAL (Escena 1) de una aventura interactiva, adaptando el relato al español.
${instruccionProtagonista}
DATOS DEL CUENTO:
- Título: ${titulo || 'Aventura mágica'}
- Protagonista: ${personajePrincipal}
- Resumen del cuento original: ${resumenOriginal || 'No disponible'}
- Escenario original: ${escenarioOriginal || 'No disponible'}
- Conflicto principal: ${conflictoPrincipal || 'No disponible'}
- Desenlace original previsto: ${finalOriginal || 'No disponible'}
- Texto fuente de referencia:
${textoFuenteLimitado || 'No disponible'}

INSTRUCCIONES PARA LA ESCENA INICIAL:
1. Idioma: REDACTA OBLIGATORIAMENTE TODO EN ESPAÑOL, con lenguaje amigable, educativo y atractivo para niños de primaria. Si el texto fuente está en inglés, adáptalo completamente al español.
2. Contenido de la escena:
   - Presenta al protagonista (${personajePrincipal}) en su entorno o punto de partida.
   - Establece claramente el escenario (${escenarioOriginal}).
   - Introduce de forma emocionante el conflicto o problema central (${conflictoPrincipal}).
   - NO copies fragmentos en bruto del PDF ni incluyas metadatos editoriales, números de página ni agradecimientos.
   - Longitud: entre 90 y 160 palabras.
3. Decisiones narrativas:
   - "esFinal": false.
   - "opciones": Exactamente tres (3) opciones narrativas concretas, atractivas y distintas para que el niño decida qué hacer:
     * Opción 1 (Ruta original): Acción concreta que avanza según los hechos originales del cuento fuente.
     * Opción 2 (Ruta alternativa): Acción concreta que explora un camino diferente o una solución alternativa ingeniosa.
     * Opción 3 (Ruta de investigación): Acción concreta de observación, diálogo o exploración detallada del entorno.
   - NO uses opciones genéricas como "Seguir la historia" o "Ver qué pasa". Describe acciones específicas del personaje.

Devuelve estrictamente un JSON con las propiedades: contenido, opciones, esFinal.
`;
    } else if (esUltimaEscena) {
      prompt = `
Eres un narrador de cuentos infantiles para estudiantes de educación primaria.
Tu objetivo es escribir el DESENLACE DEFINITIVO (Escena final ${numeroEscena}) que cierre por completo esta aventura.
${instruccionProtagonista}

DATOS DEL CUENTO:
- Título: ${titulo || 'Aventura mágica'}
- Protagonista: ${personajePrincipal}
- Resumen del cuento original: ${resumenOriginal || 'No disponible'}
- Escenario original: ${escenarioOriginal || 'No disponible'}
- Conflicto principal QUE DEBE QUEDAR RESUELTO AQUÍ: ${conflictoPrincipal || 'No disponible'}
- Desenlace original de referencia: ${finalOriginal || 'No disponible'}

HISTORIAL DE LA HISTORIA (CONTEXTO ACUMULADO):
${contextoNarrativo}

ÚLTIMA DECISIÓN TOMADA POR EL ESTUDIANTE:
"${decisionActual}"

INSTRUCCIONES CRÍTICAS PARA EL DESENLACE FINAL (NO ES UNA ESCENA INTERMEDIA):
1. Resolución completa del conflicto:
   - Muestra la consecuencia directa y exitosa de la decisión: "${decisionActual}".
   - Resuelve de forma clara y concluyente el conflicto central ("${conflictoPrincipal}") y el misterio planteado.
   - Muestra el desenlace definitivo: cómo queda el lugar y cómo se soluciona el problema.
2. Cierre del protagonista:
   - Da un cierre reflexivo y satisfactorio a ${personajePrincipal} (por ejemplo: alegría comunitaria, aprendizaje o reconocimiento).
3. PROHIBICIONES ESTRICTAS (BAJO NINGUNA CIRCUNSTANCIA):
   - PROHIBIDO dejar preguntas abiertas o incógnitas pendientes (NO uses "¿qué pasará ahora?", "¿qué hará?", "¿a dónde conducirá?").
   - PROHIBIDO dejar investigaciones o viajes pendientes (NO uses "decidió investigar a dónde llevaba", "el siguiente paso", "tendrá que descubrir", "aún debía averiguar").
   - PROHIBIDO introducir nuevos misterios, villanos, amenazas o caminos.
   - PROHIBIDO sugerir continuaciones (NO uses "continuará", "una nueva aventura comenzaba").
   - La historia TERMINA DEFINITIVAMENTE en esta escena.
4. Extensión: Entre 100 y 160 palabras en español fluido para primaria.
5. Formato JSON obligatorio:
   - "esFinal": true
   - "opciones": [] (lista vacía obligatoria, NO agregues ninguna opción)

Devuelve estrictamente un JSON con las propiedades: contenido, opciones, esFinal.
`;
    } else {
      prompt = `
Eres un narrador de cuentos interactivos infantiles para estudiantes de educación primaria.
Tu objetivo es continuar la historia de forma coherente según las decisiones tomadas por el estudiante.
${instruccionProtagonista}
DATOS DEL CUENTO:
- Título: ${titulo || 'Aventura mágica'}
- Protagonista: ${personajePrincipal}
- Resumen del cuento original: ${resumenOriginal || 'No disponible'}
- Escenario original: ${escenarioOriginal || 'No disponible'}
- Conflicto principal: ${conflictoPrincipal || 'No disponible'}
- Desenlace original de referencia: ${finalOriginal || 'No disponible'}

HISTORIAL DE LA HISTORIA (CONTEXTO ACUMULADO):
${contextoNarrativo}

DECISIÓN ACTUAL DEL ESTUDIANTE:
"${decisionActual}"

NÚMERO DE ESTA ESCENA: ${numeroEscena}

REGLAS NARRATIVAS:
1. Idioma: REDACTA OBLIGATORIAMENTE EN ESPAÑOL. Todo el contenido y las opciones deben estar en español claro para primaria.
2. Consecuencia directa: La escena debe comenzar mostrando de forma visible qué ocurre a causa de la decisión tomada: "${decisionActual}".
3. Coherencia: Mantén la personalidad de ${personajePrincipal}, el escenario y la lógica de los acontecimientos previos.
4. Extensión: Entre 90 y 160 palabras.
5. Continuación:
   - "esFinal": false.
   - "opciones": Exactamente tres (3) decisiones narrativas diferentes, específicas y creativas:
     1) Ruta original: avanza hacia los acontecimientos del relato original.
     2) Ruta alternativa: permite consecuencias diferentes e intrigantes.
     3) Acción concreta de observación, ingenio o diálogo.
   - Cada opción debe ser una acción concreta (no genérica) y no estar vacía.

Devuelve estrictamente un JSON con las propiedades: contenido, opciones, esFinal.
`;
    }

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
            contenido: {
              type: 'STRING',
              description: 'Texto narrativo de la escena redactado en español',
            },
            opciones: {
              type: 'ARRAY',
              description:
                'Exactamente 3 opciones diferentes si esFinal es false, o lista vacía si esFinal es true',
              items: {
                type: 'STRING',
              },
            },
            esFinal: {
              type: 'BOOLEAN',
              description: 'Indica si la escena es el desenlace de la historia',
            },
          },
          required: ['contenido', 'opciones', 'esFinal'],
        },
      },
    });

    let respuestaExitosa: Response | null = null;
    let modeloUsado = '';
    const errores: string[] = [];

    for (const modelo of modelos) {
      console.log(`Intentando generar escena ${numeroEscena} con modelo: ${modelo}`);
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
        console.warn(`Modelo ${modelo} devolvió estado ${errorStatus}`);
        errores.push(`${modelo}: ${errorStatus} ${errorText.substring(0, 150)}`);
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') {
          console.warn(`Modelo ${modelo} timeout después de ${TIMEOUT_MS / 1000}s`);
          errores.push(`${modelo}: timeout`);
        } else {
          const msg =
            error instanceof Error ? error.message : 'Error desconocido';
          console.warn(`Modelo ${modelo} falló con error: ${msg}`);
          errores.push(`${modelo}: ${msg}`);
        }
      }
    }

    if (!respuestaExitosa) {
      console.error('Todos los modelos de Gemini fallaron:', errores);
      return new Response(
        JSON.stringify({
          error:
            'El servicio de IA no pudo generar la escena en este momento. Inténtalo nuevamente.',
        }),
        {
          status: 503,
          headers: jsonHeaders,
        },
      );
    }

    console.log(
      `Escena ${numeroEscena} generada exitosamente con modelo: ${modeloUsado}`,
    );

    const geminiData = await respuestaExitosa.json();
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      console.error(
        'Gemini devolvió una respuesta vacía o sin candidatos válidos.',
      );
      return new Response(
        JSON.stringify({
          error: 'La IA no devolvió contenido narrativo válido.',
        }),
        {
          status: 502,
          headers: jsonHeaders,
        },
      );
    }

    let parsedJson: Record<string, unknown>;
    try {
      parsedJson = JSON.parse(rawText);
    } catch {
      console.error('Error al parsear el JSON devuelto por Gemini.');
      return new Response(
        JSON.stringify({
          error: 'La IA devolvió un formato no interpretable.',
        }),
        {
          status: 502,
          headers: jsonHeaders,
        },
      );
    }

    function sanitizarNombre(texto: string, original: string, actual: string): string {
      if (!original || !actual || original.toLowerCase() === actual.toLowerCase()) {
        return texto;
      }
      const regex = new RegExp(
        `(?<![\\wáéíóúüñÁÉÍÓÚÜÑ])${original.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}(?![\\wáéíóúüñÁÉÍÓÚÜÑ])`,
        'gi',
      );
      return texto.replace(regex, actual);
    }

    function esFinalAbierto(texto: string): boolean {
      const patron = /(siguiente\s+paso|decidi[oó]\s+investigar|qu[eé]\s+ocurrir[aá]|continuar[aá]|tendr[aá]\s+que\s+descubrir|a[uú]n\s+deb[ií]a\s+averiguar|el\s+misterio\s+apenas\s+comenzaba|qu[eé]\s+har[aá]\s+ahora|hacia\s+d[oó]nde\s+llevaba|por\s+descubrir)/i;
      return patron.test(texto);
    }

    let contenido = parsedJson.contenido?.toString().trim() ?? '';
    if (fueRenombrado) {
      contenido = sanitizarNombre(contenido, personajeOriginal, personajePrincipal);
    }

    if (!contenido) {
      console.error('La escena generada no tiene contenido.');
      return new Response(
        JSON.stringify({
          error: 'La escena generada no tiene contenido.',
        }),
        {
          status: 502,
          headers: jsonHeaders,
        },
      );
    }

    // Si es la última escena pero quedó abierta o con opciones, solicitar reescritura de desenlace a Gemini
    if (
      esUltimaEscena &&
      (parsedJson.esFinal !== true ||
        (Array.isArray(parsedJson.opciones) && parsedJson.opciones.length > 0) ||
        esFinalAbierto(contenido))
    ) {
      console.warn(
        'La escena final generada quedó abierta o con opciones. Solicitando reescritura de desenlace definitivo a Gemini...',
      );

      const promptReescritura = `
Eres un narrador de cuentos infantiles para primaria. La siguiente escena final quedó INCONCLUSA, con opciones o con final abierto:
"${contenido}"

REESCRIBE OBLIGATORIAMENTE esta escena final como un DESENLACE DEFINITIVO Y CONCLUYENTE:
1. Resuelve el conflicto principal por completo y explica cómo concluye todo satisfactoriamente para ${personajePrincipal}.
2. PROHIBIDO dejar misterios abiertos, preguntas, investigaciones pendientes o frases como "siguiente paso", "decidió investigar", "a dónde llevaba" o "continuará".
3. Formato JSON obligatorio:
{
  "contenido": "texto del desenlace definitivo",
  "opciones": [],
  "esFinal": true
}
`;

      const requestBodyReescritura = JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [{ text: promptReescritura }],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          maxOutputTokens: 2000,
          responseSchema: {
            type: 'OBJECT',
            properties: {
              contenido: { type: 'STRING' },
              opciones: { type: 'ARRAY', items: { type: 'STRING' } },
              esFinal: { type: 'BOOLEAN' },
            },
            required: ['contenido', 'opciones', 'esFinal'],
          },
        },
      });

      for (const modelo of modelos) {
        try {
          const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`;
          const respReescritura = await llamarGemini(url, geminiApiKey, requestBodyReescritura);
          if (respReescritura.ok) {
            const dataRe = await respReescritura.json();
            const textRe = dataRe?.candidates?.[0]?.content?.parts?.[0]?.text;
            if (textRe) {
              const jsonRe = JSON.parse(textRe);
              let contRe = jsonRe.contenido?.toString().trim() ?? '';
              if (fueRenombrado) {
                contRe = sanitizarNombre(contRe, personajeOriginal, personajePrincipal);
              }
              if (
                contRe &&
                jsonRe.esFinal === true &&
                (!jsonRe.opciones || (Array.isArray(jsonRe.opciones) && jsonRe.opciones.length === 0)) &&
                !esFinalAbierto(contRe)
              ) {
                parsedJson = jsonRe;
                contenido = contRe;
                console.log('Reescritura de desenlace exitosa con modelo:', modelo);
                break;
              }
            }
          }
        } catch (e) {
          console.warn('Error en reescritura de escena final con modelo', modelo, e);
        }
      }
    }

    // Validación estricta para la última escena
    if (esUltimaEscena) {
      const tieneOpciones = Array.isArray(parsedJson.opciones) && parsedJson.opciones.length > 0;
      if (parsedJson.esFinal !== true || tieneOpciones || esFinalAbierto(contenido)) {
        console.error('La escena final continúa abierta o sin desenlace conclusivo tras validación.');
        return new Response(
          JSON.stringify({
            error: 'La IA no devolvió un desenlace conclusivo para la última escena.',
          }),
          {
            status: 502,
            headers: jsonHeaders,
          },
        );
      }
    }

    const esFinal = parsedJson.esFinal === true;

    // Verificación razonable de idioma español
    if (!esTextoEnEspanol(contenido)) {
      console.warn('Advertencia: El texto parece no estar en español.');
      // No descartamos texto válido por nombres propios, pero advertimos en el servidor.
    }

    let opcionesFinales: string[] = [];

    if (esFinal) {
      opcionesFinales = [];
    } else {
      const opcionesRaw = Array.isArray(parsedJson.opciones)
        ? parsedJson.opciones
        : [];

      const opcionesLimpias = opcionesRaw
        .map((op) => {
          const texto = (op ?? '').toString().trim();
          return fueRenombrado
            ? sanitizarNombre(texto, personajeOriginal, personajePrincipal)
            : texto;
        })
        .filter((op) => op.length > 0);

      // Exigir exactamente tres opciones no vacías y distintas
      const opcionesUnicas = [...new Set(opcionesLimpias)];

      if (opcionesUnicas.length < 3) {
        console.error(
          `Opciones insuficientes o repetidas: ${JSON.stringify(opcionesLimpias)}`,
        );
        return new Response(
          JSON.stringify({
            error:
              'La escena generada no contiene exactamente tres decisiones diferentes.',
          }),
          {
            status: 502,
            headers: jsonHeaders,
          },
        );
      }

      opcionesFinales = opcionesUnicas.slice(0, 3);
    }

    const resultado = {
      contenido,
      opciones: opcionesFinales,
      esFinal,
    };

    return new Response(JSON.stringify(resultado), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (error) {
    const errorMsg =
      error instanceof Error ? error.message : 'Error inesperado del servidor.';
    console.error('Excepción no controlada en generar-escena:', errorMsg);

    return new Response(
      JSON.stringify({
        error: errorMsg,
      }),
      {
        status: 500,
        headers: jsonHeaders,
      },
    );
  }
});
