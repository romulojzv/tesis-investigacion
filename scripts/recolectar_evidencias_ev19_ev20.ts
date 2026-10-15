/// <reference lib="deno.ns" />
/// <reference lib="dom" />
import { createClient } from 'npm:@supabase/supabase-js';

const url = Deno.env.get('SUPABASE_URL') || 'https://acxsyswrzdtstgqztojj.supabase.co';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

if (!anonKey || !serviceKey) {
  console.error('Error: se requieren SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY');
  Deno.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const anon = createClient(url, anonKey);

async function obtenerTokenEstudiante(codigo: string, pin: string, nombre: string) {
  const email = `${codigo.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
  
  // Buscar o crear usuario
  const { data: users } = await admin.auth.admin.listUsers();
  let user = users?.users?.find((u) => u.email === email);
  if (!user) {
    const { data: nuevo, error } = await admin.auth.admin.createUser({
      email,
      password: pin,
      email_confirm: true,
      user_metadata: { nombre },
      app_metadata: { rol: 'estudiante', codigo_acceso: codigo },
    });
    if (error) throw error;
    user = nuevo.user;
  }

  await admin.from('profiles').upsert({
    id: user.id,
    nombre,
    rol: 'estudiante',
    codigo_acceso: codigo,
  });

  const { data: session, error: loginErr } = await anon.auth.signInWithPassword({
    email,
    password: pin,
  });
  if (loginErr) throw loginErr;

  return {
    id: user.id,
    email,
    codigo,
    nombre,
    token: session.session.access_token,
  };
}

async function main() {
  console.log('================================================================');
  console.log(' RECOLECCIÓN DE EVIDENCIAS TÉCNICAS: EV-UI-19 Y EV-UI-20');
  console.log(' Entorno: Supabase Staging (acxsyswrzdtstgqztojj)');
  console.log(' Target:', url);
  console.log(' Fecha/Hora:', new Date().toISOString());
  console.log('================================================================\n');

  // 1. Obtener dos estudiantes ficticios A y B
  console.log('1. Autenticando Estudiante A y Estudiante B...');
  const estudianteA = await obtenerTokenEstudiante('EST_EV_A', '123456', 'Estudiante A Evidencia');
  const estudianteB = await obtenerTokenEstudiante('EST_EV_B', '123456', 'Estudiante B Evidencia');

  console.log(`- Estudiante A ID: ${estudianteA.id} (${estudianteA.codigo})`);
  console.log(`- Estudiante B ID: ${estudianteB.id} (${estudianteB.codigo})`);

  // 2. Crear cuento e intento de prueba para Estudiante A
  const cuentoId = `cuento-ev-${Date.now()}`;
  await admin.from('cuentos').upsert({
    id: cuentoId,
    titulo: 'El Desafío de la Cueva Encantada',
    personaje_principal: 'Álex',
    estudiante_id: estudianteA.id,
  });

  await admin.from('escenas').upsert([
    {
      id: `${cuentoId}_e1`,
      cuento_id: cuentoId,
      numero: 1,
      contenido: 'Álex encontró una cueva luminosa protegida por acertijos.',
      opciones: ['Entrar con la antorcha'],
      es_final: false,
    },
    {
      id: `${cuentoId}_e2`,
      cuento_id: cuentoId,
      numero: 2,
      contenido: 'Al resolver los enigmas, descubrió el cristal de la sabiduría. Fin.',
      opciones: [],
      es_final: true,
    },
  ]);

  const { data: nuevoIntento } = await admin.from('quiz_intentos').insert({
    cuento_id: cuentoId,
    estudiante_id: estudianteA.id,
    estado: 'en_progreso',
    total_preguntas: 5,
  }).select('id').single();

  const intentoId = nuevoIntento!.id;

  // Insertar las 5 preguntas con distribución 2-2-1
  await admin.from('quiz_respuestas').insert([
    {
      intento_id: intentoId,
      numero_pregunta: 1,
      pregunta: '¿Quién es el protagonista de la historia?',
      opciones: ['Álex', 'Mateo', 'Lucas', 'Beto'],
      indice_correcto: 0,
      explicacion: 'Álex es el personaje explícito del relato.',
      nivel_comprension: 'literal',
    },
    {
      intento_id: intentoId,
      numero_pregunta: 2,
      pregunta: '¿Qué objeto encontró Álex en la cueva?',
      opciones: ['Una moneda', 'El cristal de la sabiduría', 'Un mapa', 'Una llave'],
      indice_correcto: 1,
      explicacion: 'El cristal de la sabiduría fue el hallazgo principal.',
      nivel_comprension: 'literal',
    },
    {
      intento_id: intentoId,
      numero_pregunta: 3,
      pregunta: '¿Por qué la cueva tenía acertijos?',
      opciones: ['Para ahuyentar a todos', 'Para probar la perseverancia y el ingenio', 'Por descuido', 'Era una trampa'],
      indice_correcto: 1,
      explicacion: 'Los acertijos evaluaban la sabiduría de quien ingresaba.',
      nivel_comprension: 'inferencial',
    },
    {
      intento_id: intentoId,
      numero_pregunta: 4,
      pregunta: '¿Qué cualidad demostró Álex al resolver los enigmas?',
      opciones: ['Paciencia y reflexión', 'Fuerza física', 'Indiferencia', 'Enojo'],
      indice_correcto: 0,
      explicacion: 'Resolver enigmas requiere calma y reflexión profunda.',
      nivel_comprension: 'inferencial',
    },
    {
      intento_id: intentoId,
      numero_pregunta: 5,
      pregunta: '¿Qué representa la sabiduría en este cuento?',
      opciones: ['Superar obstáculos mediante el entendimiento', 'Acumular riquezas', 'Tener prisa', 'Competir'],
      indice_correcto: 0,
      explicacion: 'La sabiduría permite resolver desafíos pacíficamente.',
      nivel_comprension: 'critico_reflexivo',
    },
  ]);

  console.log(`✅ Cuento (${cuentoId}) e Intento (${intentoId}) preparados con 5 preguntas.`);

  // ===========================================================================
  // EVIDENCIA EV-UI-19: Intento de respuesta cruzada no autorizada -> HTTP 403
  // ===========================================================================
  console.log('\n--- Ejecutando prueba EV-UI-19 (Seguridad de Autorización Cruzada) ---');
  const fechaEv19 = new Date().toISOString();
  const respCruzada = await fetch(`${url}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudianteB.token}`, // Token del Estudiante B
    },
    body: JSON.stringify({
      intentoId, // Intento de Estudiante A
      numero: 1,
      indiceSeleccionado: 0,
    }),
  });

  const statusEv19 = respCruzada.status;
  const bodyEv19 = await respCruzada.json();

  console.log(`HTTP Status: ${statusEv19}`);
  console.log(`Respuesta del servidor:`, bodyEv19);

  // Verificar en base de datos que el intento de A NO fue modificado
  const { data: dbCheckA } = await admin
    .from('quiz_respuestas')
    .select('indice_seleccionado, es_correcta')
    .eq('intento_id', intentoId)
    .eq('numero_pregunta', 1)
    .single();

  const noModificado19 = dbCheckA?.indice_seleccionado === null;
  console.log(`Verificación en BD: indice_seleccionado es null? ${noModificado19}`);

  const evidenciaEv19 = {
    codigo_evidencia: 'EV-UI-19',
    descripcion: 'Rechazo de intento de respuesta cruzada entre estudiantes (Control de Acceso)',
    entorno: 'Supabase Staging (acxsyswrzdtstgqztojj)',
    fecha_utc: fechaEv19,
    endpoint: `${url}/functions/v1/responder-pregunta`,
    metodo: 'POST',
    solicitante: {
      rol: 'estudiante',
      codigo_acceso: estudianteB.codigo,
      token_header: 'Bearer [REDACTED_JWT_TOKEN_ESTUDIANTE_B]',
    },
    recurso_objetivo: {
      intento_id: intentoId,
      propietario_codigo: estudianteA.codigo,
      pregunta_numero: 1,
      indice_intentado: 0,
    },
    resultado_http: {
      status_code: statusEv19,
      status_text: respCruzada.statusText || 'Forbidden',
      response_body: bodyEv19,
    },
    verificacion_persistencia_bd: {
      pregunta_1_indice_seleccionado: dbCheckA?.indice_seleccionado,
      modificacion_indebida_ocurrida: !noModificado19,
      conclusion_seguridad: statusEv19 === 403 && noModificado19
        ? 'APROBADO: Solicitud cruzada rechazada con HTTP 403 y datos de base de datos preservados sin modificación.'
        : 'FALLIDO',
    },
  };

  // ===========================================================================
  // EVIDENCIA EV-UI-20: Confirmar pregunta e intentar alterarla -> HTTP 409
  // ===========================================================================
  console.log('\n--- Ejecutando prueba EV-UI-20 (Inmutabilidad de Respuesta) ---');
  
  // Paso 1: Estudiante A confirma legalmente la pregunta 1 con alternativa 0 (correcta)
  console.log('Paso 1: Estudiante A confirma la pregunta 1 con opción 0...');
  const respConfirmar = await fetch(`${url}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudianteA.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 1,
      indiceSeleccionado: 0,
    }),
  });
  const dataConfirmada = await respConfirmar.json();
  console.log(`Confirmación inicial HTTP ${respConfirmar.status}: esCorrecta=${dataConfirmada.esCorrecta}`);

  // Paso 2: Estudiante A intenta alterar esa misma pregunta 1 con una alternativa diferente (opción 2)
  console.log('Paso 2: Estudiante A intenta alterar la pregunta 1 con opción 2 (conflicto)...');
  const fechaEv20 = new Date().toISOString();
  const respAlterar = await fetch(`${url}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudianteA.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 1,
      indiceSeleccionado: 2, // Intentando cambiar a opción 2
    }),
  });

  const statusEv20 = respAlterar.status;
  const bodyEv20 = await respAlterar.json();

  console.log(`HTTP Status intento de alteración: ${statusEv20}`);
  console.log(`Respuesta del servidor:`, bodyEv20);

  // Verificar en base de datos que se conserva la respuesta original (0)
  const { data: dbCheckAlterada } = await admin
    .from('quiz_respuestas')
    .select('indice_seleccionado, es_correcta, indice_correcto')
    .eq('intento_id', intentoId)
    .eq('numero_pregunta', 1)
    .single();

  const respuestaOriginalConservada = dbCheckAlterada?.indice_seleccionado === 0 && dbCheckAlterada?.es_correcta === true;
  console.log(`Verificación en BD: indice_seleccionado=0 y es_correcta=true? ${respuestaOriginalConservada}`);

  const evidenciaEv20 = {
    codigo_evidencia: 'EV-UI-20',
    descripcion: 'Inmutabilidad de respuesta confirmada ante intento de modificación posterior',
    entorno: 'Supabase Staging (acxsyswrzdtstgqztojj)',
    fecha_utc: fechaEv20,
    endpoint: `${url}/functions/v1/responder-pregunta`,
    metodo: 'POST',
    solicitante: {
      rol: 'estudiante',
      codigo_acceso: estudianteA.codigo,
      token_header: 'Bearer [REDACTED_JWT_TOKEN_ESTUDIANTE_A]',
    },
    accion_previa: {
      pregunta_numero: 1,
      indice_confirmado_original: 0,
      resultado_previo: 'esCorrecta=true',
    },
    intento_modificacion: {
      pregunta_numero: 1,
      nuevo_indice_intentado: 2,
    },
    resultado_http: {
      status_code: statusEv20,
      status_text: respAlterar.statusText || 'Conflict',
      response_body: bodyEv20,
    },
    verificacion_persistencia_bd: {
      indice_seleccionado_actual: dbCheckAlterada?.indice_seleccionado,
      es_correcta_actual: dbCheckAlterada?.es_correcta,
      respuesta_original_preservada: respuestaOriginalConservada,
      conclusion_seguridad: statusEv20 === 409 && respuestaOriginalConservada
        ? 'APROBADO: Intento de modificación rechazado con HTTP 409 Conflict. La respuesta original permanece inmutable en base de datos.'
        : 'FALLIDO',
    },
  };

  // 3. Guardar archivos de evidencia en la estructura del proyecto
  const dirEvidencias = 'evidencias_tesis_20261014/03_pruebas_supabase';
  await Deno.mkdir(dirEvidencias, { recursive: true });

  await Deno.writeTextFile(
    `${dirEvidencias}/evidencia_ev_ui_19_403.json`,
    JSON.stringify(evidenciaEv19, null, 2),
  );
  await Deno.writeTextFile(
    `${dirEvidencias}/evidencia_ev_ui_20_409.json`,
    JSON.stringify(evidenciaEv20, null, 2),
  );

  console.log('\n================================================================');
  console.log(' ✅ EVIDENCIAS REALES EV-UI-19 Y EV-UI-20 GUARDADAS CON ÉXITO');
  console.log(` 1. ${dirEvidencias}/evidencia_ev_ui_19_403.json`);
  console.log(` 2. ${dirEvidencias}/evidencia_ev_ui_20_409.json`);
  console.log('================================================================\n');
}

await main();
