// supabase/functions/generar-imagen/pollinations_multipart_test.ts
import { assertEquals, assert } from "jsr:@std/assert";
import { construirFormDataEdicionPollinations } from "./pollinations_client.ts";

Deno.test("Pollinations multipart: estructura exacta de petición a /v1/images/edits", async () => {
  // Simular bytes de dibujo infantil original (PNG mágico)
  const dibujoOriginalBytes = new Uint8Array([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  ]);

  const prompt = "Children's storybook illustration, Protagonist: Pollito Pepe";
  const modelo = "black-forest-labs/flux.2-klein-4b";
  const seed = 424242;

  // Construir la petición multipart para Pollinations
  const formData = construirFormDataEdicionPollinations({
    prompt,
    modelo,
    referenciaBytes: dibujoOriginalBytes,
    mimeType: "image/png",
    ext: "png",
    seed,
  });

  // 1. Verificar campo principal 'image'
  assert(formData.has("image"), "Debe contener el campo 'image'");
  const imageEntry = formData.get("image");
  assert(imageEntry instanceof Blob, "El campo 'image' debe ser un Blob/File");
  
  // En Deno/Browser File, comprobar nombre de archivo y tipo MIME
  const file = imageEntry as File;
  assertEquals(file.name, "referencia_protagonista.png");
  assertEquals(file.type, "image/png");

  // Comprobar bytes exactos del dibujo original
  const arrayBuffer = await file.arrayBuffer();
  const bytesObtenidos = new Uint8Array(arrayBuffer);
  assertEquals(bytesObtenidos.length, dibujoOriginalBytes.length);
  assertEquals(bytesObtenidos, dibujoOriginalBytes);

  // 2. VERIFICACIÓN CRÍTICA: NO debe existir el campo inventado 'image_anchor'
  assertEquals(
    formData.has("image_anchor"),
    false,
    "CRÍTICO: No debe enviarse el campo no soportado 'image_anchor'",
  );
  assertEquals(formData.get("image_anchor"), null);

  // 3. Comprobar parámetros requeridos por la API oficial de Pollinations
  assertEquals(formData.get("model"), "black-forest-labs/flux.2-klein-4b");
  assertEquals(formData.get("size"), "1024x768");
  assertEquals(formData.get("seed"), "424242");
  assertEquals(formData.get("prompt"), prompt);

  // 4. Comprobar que solo existan los campos oficiales válidos
  const campos = Array.from(formData.keys());
  const camposEsperados = ["image", "prompt", "model", "size", "seed"];
  assertEquals(campos.sort(), camposEsperados.sort());
});

Deno.test("Pollinations multipart: en escenas 2, 3 y 4 en modo dibujo, 'image' es SIEMPRE el dibujo original", async () => {
  const dibujoOriginalBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 10, 20, 30, 40]);
  const escenaPreviaRenderizadaBytes = new Uint8Array([0x52, 0x49, 0x46, 0x46, 99, 99, 99]); // webp escena 1

  // Al generar escena 2, la función debe usar el dibujo original como 'image'
  // y NO adjuntar la escena previa ni como 'image' ni como 'image_anchor'
  const formDataEscena2 = construirFormDataEdicionPollinations({
    prompt: "Escena 2: Pollito Pepe cruza el río caudaloso en un tronco",
    modelo: "black-forest-labs/flux.2-klein-4b",
    referenciaBytes: dibujoOriginalBytes, // Siempre el dibujo original
    mimeType: "image/png",
    ext: "png",
    seed: 999,
  });

  // 'image' contiene el dibujo original
  const file = formDataEscena2.get("image") as File;
  const bytes = new Uint8Array(await file.arrayBuffer());
  assertEquals(bytes, dibujoOriginalBytes);
  assert(bytes !== escenaPreviaRenderizadaBytes, "No debe usar la escena previa como 'image'");

  // 'image_anchor' no existe
  assertEquals(formDataEscena2.has("image_anchor"), false);
});
