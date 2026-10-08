import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from '@supabase/supabase-js';
import { validarEstudianteAutenticado } from '../_shared/auth.ts';
import { construirFormDataEdicionPollinations } from './pollinations_client.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const jsonHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json',
};

// ============================================================================
// MODELOS DISPONIBLES EN POLLINATIONS AI (Catálogo Actual)
// ============================================================================

// Flujo A: SIN referencia visual (Text-to-Image económico y veloz)
// Modalidad: ["text"] -> ["image"]. Costo: 0.002 pollen (~$0.002)
const MODELO_TEXT_TO_IMAGE = 'black-forest-labs/flux.1-schnell';

// Flujo B: CON referencia visual (Edición y consistencia de personaje)
// Modalidad: ["text", "image"] -> ["image"]. Soporta hasta 10 referencias. Costo: 0.005 pollen (~$0.005)
const MODELO_CON_REFERENCIA = 'black-forest-labs/flux.2-klein-4b';

const POLLINATIONS_BASE_URL = 'https://gen.pollinations.ai';
const TIMEOUT_MS = 35000;
const TAMANO_MAX_BYTES = 15 * 1024 * 1024; // 15 MB
const TAMANO_MIN_BYTES = 1024; // 1 KB
const TAMANO_MAX_REFERENCIA_BYTES = 10 * 1024 * 1024; // 10 MB

interface SolicitudGeneracionImagen {
  cuentoId: string;
  numeroEscena: number;
  personajePrincipal: string;
  descripcionPersonaje?: string;
  contenidoEscena: string;
  escenario?: string;
  referenciaVisualBase64?: string;
  referenciaAnchorBase64?: string;
  referenciaVisualUrl?: string;
  modelo?: string;
  seed?: number;
  esModoDibujo?: boolean;
}

/**
 * Detecta el tipo MIME y extensión a partir de los bytes mágicos de la imagen
 */
function detectarMimeType(bytes: Uint8Array): { mime: string; ext: string } {
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    return { mime: 'image/png', ext: 'png' };
  }
  // JPEG: FF D8 FF
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return { mime: 'image/jpeg', ext: 'jpg' };
  }
  // WebP: RIFF ... WEBP
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return { mime: 'image/webp', ext: 'webp' };
  }
  return { mime: 'image/png', ext: 'png' };
}

/**
 * Convierte una cadena base64 a Uint8Array
 */
function base64ToUint8Array(base64: string): Uint8Array {
  const cleanBase64 = base64.replace(/^data:image\/[a-z]+;base64,/, '');
  const binaryString = atob(cleanBase64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

/**
 * Convierte un Uint8Array a cadena Base64
 */
function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = '';
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/**
 * Construye el prompt visual estructurado para el modelo de difusión,
 * separando rigurosamente nombre, descripción física del protagonista y acción de la escena.
 */
function construirPromptVisual(params: {
  personajePrincipal: string;
  descripcionPersonaje?: string;
  contenidoEscena: string;
  escenario?: string;
  numeroEscena: number;
  tieneReferenciaVisual: boolean;
  esModoDibujo?: boolean;
}): string {
  const partes: string[] = [];

  // 1. Estilo artístico infantil de libro de cuentos
  partes.push(
    "Children's storybook illustration, warm and vibrant storybook art style, clean colorful digital watercolor, soft whimsical lighting, joyful atmosphere, high quality picture book for primary school children",
  );

  // 2. [SECCIÓN 1] IDENTIDAD DEL PROTAGONISTA — PRESERVAR IDENTIDAD
  const desc = params.descripcionPersonaje?.trim();
  if (desc && desc.length > 0) {
    partes.push(
      `CHARACTER IDENTITY (PRESERVE EXACT IDENTITY): Protagonist name: "${params.personajePrincipal}". CANONICAL BASE TRAITS: ${desc}. ` +
      `STRICT CHARACTER CONTINUITY: Keep the exact same protagonist across all scenes with the same base visual nature, entity type, body silhouette, structural features, and core color palette. ` +
      `Do not transform or convert the protagonist into a different type of creature, object, or character.`,
    );
  } else {
    partes.push(
      `CHARACTER IDENTITY (PRESERVE EXACT IDENTITY): Protagonist: "${params.personajePrincipal}". Strict character continuity across all scenes: same visual nature, same form, same key traits`,
    );
  }

  // 3. [SECCIÓN 2] ESCENA ACTUAL — REPRESENTAR OBLIGATORIAMENTE ESTA ACCIÓN Y LUGAR
  partes.push(
    `CURRENT SCENE NARRATIVE (SCENE ${params.numeroEscena} — MUST DEPICT THIS EXACT ACTION AND SETTING): ` +
    `The illustration MUST vividly portray the specific events, actions, location, and key objects of this scene: "${params.contenidoEscena.trim()}". ` +
    (params.escenario && params.escenario.trim().length > 0 ? `Setting environment: ${params.escenario.trim()}. ` : '') +
    `Visually depict every distinct narrative element mentioned in the scene text (places, objects, gestures, atmosphere).`,
  );

  // 4. [SECCIÓN 3] COMPOSICIÓN Y ENCUADRE DINÁMICO — CAMBIAR SEGÚN LA HISTORIA
  partes.push(
    `COMPOSITION AND STAGING (MUST CHANGE WHEN STORY CHANGES): Create a genuinely new illustration with fresh composition, dynamic camera angle, and scene-appropriate background for Scene ${params.numeroEscena}. ` +
    `Adapt the protagonist's pose, interaction, and orientation to match this specific action. ` +
    `Expressly AVOID: same pose, same camera framing, same background, same composition across scenes.`,
  );

  // 5. [SECCIÓN 4] USO DE REFERENCIA — IDENTIDAD DEL PERSONAJE
  if (params.tieneReferenciaVisual) {
    if (params.esModoDibujo) {
      partes.push(
        `ORIGINAL DRAWING REFERENCE (CHARACTER IDENTITY REFERENCE ONLY): The reference image is the child's ORIGINAL DRAWING of the protagonist. ` +
        `Strictly preserve the protagonist's identity, species, facial/body silhouette, and core colors from this drawing. ` +
        `Create a rich, complete storybook scene with new environment, dynamic pose, and fresh composition for Scene ${params.numeroEscena} matching the current scene text. ` +
        `Do not copy a static pose or keep empty white paper background.`,
      );
    } else {
      partes.push(
        `PREVIOUS IMAGE REFERENCE (CHARACTER IDENTITY REFERENCE ONLY): The previous image is a CHARACTER IDENTITY reference only. ` +
        `Do not copy its pose, camera angle, background, scenery, or composition. ` +
        `Create a genuinely new illustration that depicts the CURRENT scene text. ` +
        `If the previous image conflicts with the current narrative, follow the current narrative while preserving only the protagonist's identity.`,
      );
    }
  }

  // 7. SEGURIDAD INFANTIL Y CONTENIDO APROPIADO PARA PRIMARIA
  partes.push(
    'CHILD-SAFE CONTENT RULES: Safe and age-appropriate for primary school children (ages 6-12). ' +
    'ALLOWED WHEN PRESENT IN THE SOURCE DRAWING OR NARRATIVELY RELEVANT: child-appropriate fantasy, adventure, and action in a non-graphic storybook style. ' +
    'Do not introduce weapons, armor, combat elements, or other major props if they are not present in the original drawing or required by the story context. ' +
    'Existing benign fantasy weapons must not be automatically converted into toys. ' +
    'STRICTLY FORBIDDEN: sexual or sexualized content, explicit nudity, graphic violence, blood or gore, torture, explicitly depicted drugs, explicit hate symbols, extreme horror or terrifying imagery, and clearly adult content. ' +
    'If an element is truly inappropriate, neutralize only that specific inappropriate part while preserving the original benign adventure concept',
  );

  // 8. Reglas estrictas de calidad y presentación artística
  partes.push(
    'Artistic presentation: Clear focal composition, age-appropriate for young children, beautiful book illustration. Absolutely NO text, NO written words, NO letters, NO speech bubbles, NO subtitles, NO watermarks, NO blurry background',
  );

  return partes.join('. ');
}

/**
 * FLUJO A: Generación normal Text-to-Image (SIN referencia visual)
 * Endpoint: GET https://gen.pollinations.ai/image/{prompt}
 * Modelo: black-forest-labs/flux.1-schnell
 */
async function solicitarTextToImagePollinations(
  prompt: string,
  modelo: string,
  seed: number,
  apiKey: string,
): Promise<{ buffer: Uint8Array; contentType: string; statusHttp: number }> {
  const url = new URL(`${POLLINATIONS_BASE_URL}/image/${encodeURIComponent(prompt)}`);
  url.searchParams.set('model', modelo);
  url.searchParams.set('width', '1024');
  url.searchParams.set('height', '768');
  url.searchParams.set('seed', seed.toString());
  url.searchParams.set('nologo', 'true');

  const headers: Record<string, string> = {
    'Authorization': `Bearer ${apiKey}`,
    'Accept': 'image/*',
  };

  let ultimoError: Error | null = null;

  for (let intento = 1; intento <= 2; intento++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

    try {
      const res = await fetch(url.toString(), {
        method: 'GET',
        headers,
        signal: controller.signal,
      });

      if (!res.ok) {
        const errorText = await res.text().catch(() => '');
        console.error(
          `[generar-imagen] [Text-to-Image] Pollinations respondió con error HTTP ${res.status}: ${errorText.slice(0, 400)}`,
        );
        throw new Error(
          `Pollinations respondió HTTP ${res.status}: ${errorText.slice(0, 300)}`,
        );
      }

      const contentType = res.headers.get('content-type') || '';
      if (!contentType.startsWith('image/')) {
        const errorText = await res.text().catch(() => '');
        console.error(
          `[generar-imagen] [Text-to-Image] Content-Type no-imagen: ${contentType}, cuerpo: ${errorText.slice(0, 400)}`,
        );
        throw new Error(
          `Pollinations devolvió un Content-Type no imagen (${contentType}): ${errorText.slice(0, 200)}`,
        );
      }

      const arrayBuffer = await res.arrayBuffer();
      const buffer = new Uint8Array(arrayBuffer);

      if (buffer.byteLength < TAMANO_MIN_BYTES) {
        throw new Error(`La imagen recibida es demasiado pequeña (${buffer.byteLength} bytes)`);
      }
      if (buffer.byteLength > TAMANO_MAX_BYTES) {
        throw new Error(`La imagen recibida supera el límite de 15MB (${buffer.byteLength} bytes)`);
      }

      return { buffer, contentType, statusHttp: res.status };
    } catch (err: unknown) {
      ultimoError = err instanceof Error ? err : new Error(String(err));
      console.warn(`[generar-imagen] [Text-to-Image] Reintento tras fallo: ${ultimoError.message}`);
      if (intento < 2) {
        await new Promise((r) => setTimeout(r, 1500));
      }
    } finally {
      clearTimeout(timer);
    }
  }

  throw ultimoError || new Error('No se pudo generar la imagen tras reintentos');
}

/**
 * FLUJO B: Edición / Generación con Referencia Visual (Image-to-Image)
 * Endpoint: POST https://gen.pollinations.ai/v1/images/edits
 * Formato: multipart/form-data
 * Modelo: black-forest-labs/flux.2-klein-4b
 */
async function solicitarEdicionConReferenciaPollinations(params: {
  prompt: string;
  modelo: string;
  referenciaBytes: Uint8Array;
  mimeType: string;
  ext: string;
  apiKey: string;
  seed: number;
}): Promise<{ buffer: Uint8Array; contentType: string; statusHttp: number }> {
  const url = `${POLLINATIONS_BASE_URL}/v1/images/edits`;

  const formData = construirFormDataEdicionPollinations({
    prompt: params.prompt,
    modelo: params.modelo,
    referenciaBytes: params.referenciaBytes,
    mimeType: params.mimeType,
    ext: params.ext,
    seed: params.seed,
  });

  const headers: Record<string, string> = {
    'Authorization': `Bearer ${params.apiKey}`,
  };

  let ultimoError: Error | null = null;

  for (let intento = 1; intento <= 2; intento++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers,
        body: formData,
        signal: controller.signal,
      });

      if (!res.ok) {
        const errorText = await res.text().catch(() => '');
        console.error(
          `[generar-imagen] [Edits-Multipart] Pollinations respondió con error HTTP ${res.status}: ${errorText.slice(0, 400)}`,
        );
        throw new Error(
          `Pollinations edits respondió HTTP ${res.status}: ${errorText.slice(0, 300)}`,
        );
      }

      const resContentType = res.headers.get('content-type') || '';

      // Si responde con JSON (OpenAI-compatible /v1/images/edits)
      if (resContentType.includes('application/json')) {
        const json = await res.json();
        const item = json.data?.[0];
        if (item?.b64_json) {
          const imgBuffer = base64ToUint8Array(item.b64_json);
          return { buffer: imgBuffer, contentType: 'image/webp', statusHttp: res.status };
        }
        if (item?.url) {
          const imgRes = await fetch(item.url);
          const arrayBuffer = await imgRes.arrayBuffer();
          return {
            buffer: new Uint8Array(arrayBuffer),
            contentType: imgRes.headers.get('content-type') || 'image/webp',
            statusHttp: res.status,
          };
        }
        throw new Error('Respuesta JSON de Pollinations edits no contiene datos de imagen.');
      }

      // Si responde directamente con el flujo de imagen binario
      const arrayBuffer = await res.arrayBuffer();
      const buffer = new Uint8Array(arrayBuffer);

      if (buffer.byteLength < TAMANO_MIN_BYTES) {
        throw new Error(`La imagen recibida es demasiado pequeña (${buffer.byteLength} bytes)`);
      }
      if (buffer.byteLength > TAMANO_MAX_BYTES) {
        throw new Error(`La imagen recibida supera el límite de 15MB (${buffer.byteLength} bytes)`);
      }

      return {
        buffer,
        contentType: resContentType.startsWith('image/') ? resContentType : 'image/webp',
        statusHttp: res.status,
      };
    } catch (err: unknown) {
      ultimoError = err instanceof Error ? err : new Error(String(err));
      console.warn(`[generar-imagen] [Edits-Multipart] Reintento tras fallo: ${ultimoError.message}`);
      if (intento < 2) {
        await new Promise((r) => setTimeout(r, 1500));
      }
    } finally {
      clearTimeout(timer);
    }
  }

  throw ultimoError || new Error('No se pudo editar la imagen con referencia tras reintentos');
}

// ============================================================================
// SERVIDOR EDGE FUNCTION
// ============================================================================

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

  let bodyCuentoId = 'desconocido';
  let bodyNumeroEscena = -1;

  try {
    const pollinationsApiKey = Deno.env.get('POLLINATIONS_API_KEY');
    if (!pollinationsApiKey || pollinationsApiKey.trim().length === 0) {
      console.error('[generar-imagen] POLLINATIONS_API_KEY no configurada');
      return new Response(
        JSON.stringify({
          error: 'POLLINATIONS_API_KEY no configurada',
        }),
        { status: 500, headers: jsonHeaders },
      );
    }

    let body: SolicitudGeneracionImagen;
    try {
      body = (await req.json()) as SolicitudGeneracionImagen;
    } catch {
      return new Response(
        JSON.stringify({ error: 'Cuerpo de solicitud inválido o JSON mal formado.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const {
      cuentoId,
      numeroEscena,
      personajePrincipal,
      descripcionPersonaje,
      contenidoEscena,
      escenario,
      referenciaVisualBase64,
      referenciaAnchorBase64,
      modelo,
      esModoDibujo,
    } = body;

    bodyCuentoId = cuentoId || 'desconocido';
    bodyNumeroEscena = numeroEscena || -1;

    if (!cuentoId || !numeroEscena || !personajePrincipal || !contenidoEscena) {
      return new Response(
        JSON.stringify({
          error: 'Faltan parámetros requeridos: cuentoId, numeroEscena, personajePrincipal, contenidoEscena.',
        }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 4. Si el cuento existe en la base de datos, validar propiedad mediante RLS
    if (cuentoId) {
      const { data: cuento } = await authResult.userClient!
        .from('cuentos')
        .select('id, estudiante_id')
        .eq('id', cuentoId)
        .maybeSingle();

      if (cuento && cuento.estudiante_id && cuento.estudiante_id !== authResult.userId) {
        return new Response(
          JSON.stringify({
            error: 'Acceso denegado. El cuento especificado pertenece a otro estudiante.',
          }),
          { status: 403, headers: jsonHeaders },
        );
      }
    }

    // Decodificar y validar bytes de referencia visual original
    let referenciaBytes: Uint8Array | null = null;
    let mimeReferencia = { mime: 'image/png', ext: 'png' };

    if (referenciaVisualBase64 && referenciaVisualBase64.trim().length > 50) {
      try {
        const bytes = base64ToUint8Array(referenciaVisualBase64);
        if (bytes.byteLength >= 100 && bytes.byteLength <= TAMANO_MAX_REFERENCIA_BYTES) {
          referenciaBytes = bytes;
          mimeReferencia = detectarMimeType(bytes);
        } else {
          console.warn(
            `[generar-imagen] Referencia visual descartada por tamaño fuera de rango: ${bytes.byteLength} bytes`,
          );
        }
      } catch (decErr) {
        console.warn('[generar-imagen] Error decodificando referenciaVisualBase64:', decErr);
      }
    }

    // Decodificar y validar anchor de escena previa si fue proporcionado
    let anchorBytes: Uint8Array | null = null;
    let mimeAnchor = { mime: 'image/webp', ext: 'webp' };

    if (referenciaAnchorBase64 && referenciaAnchorBase64.trim().length > 50) {
      try {
        const bytes = base64ToUint8Array(referenciaAnchorBase64);
        if (bytes.byteLength >= 100 && bytes.byteLength <= TAMANO_MAX_REFERENCIA_BYTES) {
          anchorBytes = bytes;
          mimeAnchor = detectarMimeType(bytes);
        }
      } catch (decErr) {
        console.warn('[generar-imagen] Error decodificando referenciaAnchorBase64:', decErr);
      }
    }

    const tieneReferenciaVisual = referenciaBytes !== null || anchorBytes !== null;

    // SELECCIÓN DE MODELO Y ENDPOINT SEGÚN FLUJO:
    // - Flujo A (Sin referencia): flux.1-schnell vía GET /image/{prompt}
    // - Flujo B (Con referencia): flux.2-klein-4b vía POST /v1/images/edits multipart
    const modeloFinal = modelo ||
      (tieneReferenciaVisual ? MODELO_CON_REFERENCIA : MODELO_TEXT_TO_IMAGE);

    const endpointElegido = tieneReferenciaVisual
      ? 'POST /v1/images/edits'
      : 'GET /image/{prompt}';

    const seed = body.seed ?? Math.floor(Math.random() * 1000000);

    const promptVisual = construirPromptVisual({
      personajePrincipal,
      descripcionPersonaje,
      contenidoEscena,
      escenario,
      numeroEscena,
      tieneReferenciaVisual,
      esModoDibujo: esModoDibujo === true,
    });

    // LOG SEGURO DE INICIO (Sin credenciales ni base64 completo)
    console.log('[generar-imagen] Solicitud recibida:', {
      cuentoId,
      numeroEscena,
      modelo: modeloFinal,
      tieneReferenciaVisual,
      tieneAnchor: anchorBytes !== null,
      endpoint: endpointElegido,
    });

    let resultadoImagen: { buffer: Uint8Array; contentType: string; statusHttp: number };

    if (tieneReferenciaVisual) {
      // FLUJO B: Multipart POST /v1/images/edits
      // En modo dibujo, la referencia enviada como 'image' es SIEMPRE el dibujo original
      // del estudiante (referenciaBytes). Esto asegura la preservación fiel de la identidad
      // sin reutilizar imágenes renderizadas previas que congelarían fondo o pose.
      const refFinal = (referenciaBytes || anchorBytes)!;
      const mimeFinal = referenciaBytes ? mimeReferencia : mimeAnchor;

      resultadoImagen = await solicitarEdicionConReferenciaPollinations({
        prompt: promptVisual,
        modelo: modeloFinal,
        referenciaBytes: refFinal,
        mimeType: mimeFinal.mime,
        ext: mimeFinal.ext,
        apiKey: pollinationsApiKey,
        seed,
      });
    } else {
      // FLUJO A: GET /image/{prompt}
      resultadoImagen = await solicitarTextToImagePollinations(
        promptVisual,
        modeloFinal,
        seed,
        pollinationsApiKey,
      );
    }

    const { buffer, contentType, statusHttp } = resultadoImagen;

    // Preparar ruta en Supabase Storage
    const storagePath = `${cuentoId}/escenas/escena_${numeroEscena}.webp`;
    let urlPublicaFinal = '';
    let storageGuardado = false;

    // Intentar persistencia en Supabase Storage si el bucket 'cuentos' está disponible
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (supabaseUrl && supabaseServiceKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        const { error: uploadError } = await supabase.storage
          .from('cuentos')
          .upload(storagePath, buffer, {
            contentType,
            upsert: true,
          });

        if (!uploadError) {
          const { data: publicUrlData } = supabase.storage
            .from('cuentos')
            .getPublicUrl(storagePath);

          if (publicUrlData?.publicUrl) {
            urlPublicaFinal = publicUrlData.publicUrl;
            storageGuardado = true;
          }
        }
      } catch (storageErr) {
        // Storage no configurado aún (normal en esta fase preliminar)
      }
    }

    // Para la prueba sin Storage activado, devolvemos temporalmente
    // la Data URI en base64 para que Flutter la muestre con Image.memory.
    if (!urlPublicaFinal) {
      const base64Data = uint8ArrayToBase64(buffer);
      urlPublicaFinal = `data:${contentType};base64,${base64Data}`;
    }

    // LOG SEGURO DE FINALIZACIÓN
    console.log('[generar-imagen] Generación exitosa:', {
      cuentoId,
      numeroEscena,
      modelo: modeloFinal,
      tieneReferenciaVisual,
      endpoint: endpointElegido,
      statusHttpPollinations: statusHttp,
      contentType,
      cantidadBytes: buffer.byteLength,
      storageUsado: storageGuardado,
    });

    return new Response(
      JSON.stringify({
        success: true,
        imageUrl: urlPublicaFinal,
        imagePath: storagePath,
        modeloUsado: modeloFinal,
        flujo: tieneReferenciaVisual ? 'edicion_con_referencia' : 'text_to_image',
        contentType,
        tamanoBytes: buffer.byteLength,
        storageGuardado,
      }),
      { status: 200, headers: jsonHeaders },
    );
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    // LOG SEGURO DE ERROR (Sin secretos)
    console.error('[generar-imagen] Fallo en proceso:', {
      cuentoId: bodyCuentoId,
      numeroEscena: bodyNumeroEscena,
      mensajeResumido: err.message.slice(0, 300),
    });

    return new Response(
      JSON.stringify({
        error: 'No se pudo generar la ilustración de la escena.',
        detalle: err.message,
      }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
