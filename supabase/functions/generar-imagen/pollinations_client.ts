// supabase/functions/generar-imagen/pollinations_client.ts

export const MODELO_TEXT_TO_IMAGE = 'black-forest-labs/flux.1-schnell';
export const MODELO_CON_REFERENCIA = 'black-forest-labs/flux.2-klein-4b';
export const POLLINATIONS_BASE_URL = 'https://gen.pollinations.ai';

/**
 * Construye el cuerpo multipart/form-data oficial para la API de Pollinations
 * Endpoint: POST /v1/images/edits
 *
 * Verificación técnica oficial:
 * La especificación OpenAPI de Pollinations (https://gen.pollinations.ai/openapi.json)
 * define únicamente los campos 'image' o 'image[]' para archivos de imagen.
 * NO soporta campos inventados como 'image_anchor'.
 *
 * En modo dibujo, para preservar la identidad única del personaje creado por el niño
 * y evitar que escenas anteriores congelen el fondo, encuadre o pose en escenas 2, 3 y 4,
 * se envía ÚNICAMENTE el dibujo original como 'image'.
 */
export function construirFormDataEdicionPollinations(params: {
  prompt: string;
  modelo: string;
  referenciaBytes: Uint8Array;
  mimeType: string;
  ext: string;
  seed: number;
}): FormData {
  const formData = new FormData();

  const fileBlob = new Blob([params.referenciaBytes as BlobPart], { type: params.mimeType });
  formData.append('image', fileBlob, `referencia_protagonista.${params.ext}`);

  formData.append('prompt', params.prompt);
  formData.append('model', params.modelo);
  formData.append('size', '1024x768');
  formData.append('seed', params.seed.toString());

  return formData;
}
