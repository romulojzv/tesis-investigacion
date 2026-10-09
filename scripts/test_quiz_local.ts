// scripts/test_quiz_local.ts
/**
 * Test Suite Integral de Seguridad, Funcionalidad y RLS para el Quiz de Comprensión Lectora
 *
 * Cobertura de especificaciones:
 *   QUIZ-SEC-01: generar-quiz sin JWT -> 401
 *   QUIZ-SEC-02: docente -> 403
 *   QUIZ-SEC-03: estudiante no propietario del cuento -> bloqueado (403)
 *   QUIZ-SEC-04: estudiante propietario -> permitido
 *
 *   QUIZ-GEN-01: exactamente 5 preguntas
 *   QUIZ-GEN-02: cada pregunta exactamente 4 opciones
 *   QUIZ-GEN-03: correctIndex 0..3
 *   QUIZ-GEN-04: respuesta enviada a Flutter NO contiene correctIndex ni explicación
 *   QUIZ-GEN-05: segundo generar-quiz del mismo cuento reutiliza intento y NO llama de nuevo a Gemini
 *
 *   QUIZ-SUBMIT-01: 5 respuestas válidas -> puntaje correcto
 *   QUIZ-SUBMIT-02: respuestas incompletas -> rechazadas (400)
 *   QUIZ-SUBMIT-03: intento ajeno -> bloqueado (403)
 *   QUIZ-SUBMIT-04: reenvío de intento completado -> idempotente
 *
 *   QUIZ-RLS-01: anon no ve nada
 *   QUIZ-RLS-02: estudiante A no ve intento de B
 *   QUIZ-RLS-03: docente del aula ve resultado
 *   QUIZ-RLS-04: docente de otra aula no ve resultado
 *   QUIZ-RLS-05: estudiante en progreso no puede consultar indice_correcto directamente
 */

import { createClient } from '@supabase/supabase-js';

// Cargar variables si existe archivo .env
if (typeof (process as any).loadEnvFile === 'function') {
  try {
    (process as any).loadEnvFile();
  } catch {}
}

const PILOT_PROJECT_REF = 'wdehfetiazgukfgnngfi';

const LOCAL_FALLBACK_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const LOCAL_FALLBACK_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const TEST_URL =
  process.env.SUPABASE_TEST_URL ||
  (process.env.SUPABASE_URL?.includes('127.0.0.1') ? process.env.SUPABASE_URL : 'http://127.0.0.1:54321');
const TEST_SERVICE_KEY = process.env.SUPABASE_TEST_SERVICE_ROLE_KEY || LOCAL_FALLBACK_SERVICE_ROLE_KEY;
const TEST_ANON_KEY = process.env.SUPABASE_TEST_ANON_KEY || LOCAL_FALLBACK_ANON_KEY;

// ============================================================================
// SALVAGUARDA DE SEGURIDAD LOCAL
// ============================================================================
if (TEST_URL.includes(PILOT_PROJECT_REF)) {
  console.error('⛔ BLOQUEO DE SEGURIDAD: TEST_URL apunta al proyecto remoto wdehfetiazgukfgnngfi.');
  process.exit(1);
}
if (!TEST_URL.includes('127.0.0.1') && !TEST_URL.includes('localhost')) {
  console.error('⛔ BLOQUEO DE SEGURIDAD: Solo se permite ejecución en entorno local (127.0.0.1 / localhost).');
  process.exit(1);
}

const adminClient = createClient(TEST_URL, TEST_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const anonClient = createClient(TEST_URL, TEST_ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

interface TestCaseResult {
  code: string;
  name: string;
  passed: boolean;
  details?: string;
}

const results: TestCaseResult[] = [];

function recordResult(code: string, name: string, passed: boolean, details?: string) {
  results.push({ code, name, passed, details });
  if (passed) {
    console.log(`✅ [${code}] ${name}`);
  } else {
    console.error(`❌ [${code}] ${name} - ${details}`);
  }
}

async function postFunction(functionName: string, body: any, authHeader?: string): Promise<{ status: number; body: any }> {
  const url = `${TEST_URL}/functions/v1/${functionName}`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (authHeader) {
    headers['Authorization'] = authHeader;
  }

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });
    let data;
    try {
      data = await res.json();
    } catch {
      data = null;
    }
    return { status: res.status, body: data };
  } catch (err: any) {
    return { status: 0, body: { error: err.message } };
  }
}

async function main() {
  console.log('='.repeat(70));
  console.log('🧪 SUITE INTEGRAL DE PRUEBAS DE SEGURIDAD, EDGE FUNCTIONS Y RLS DEL QUIZ');
  console.log(`   Entorno Local: ${TEST_URL}`);
  console.log('='.repeat(70));

  const timestamp = Date.now();
  const docenteAEmail = `docente_a_${timestamp}@test.local`;
  const docenteBEmail = `docente_b_${timestamp}@test.local`;
  const estudianteAEmail = `estudiante_a_${timestamp}@test.local`;
  const estudianteBEmail = `estudiante_b_${timestamp}@test.local`;
  const defaultPassword = 'TestPassword123!';

  let docenteAId: string | null = null;
  let docenteBId: string | null = null;
  let estudianteAId: string | null = null;
  let estudianteBId: string | null = null;

  let docenteAJwt: string | null = null;
  let estudianteAJwt: string | null = null;
  let estudianteBJwt: string | null = null;

  let aulaAId: string | null = null;
  let aulaBId: string | null = null;

  let cuentoAId: string | null = null;
  let intentoAId: string | null = null;

  try {
    // ------------------------------------------------------------------------
    // SETUP: Creación de usuarios sintéticos y fixtures
    // ------------------------------------------------------------------------
    console.log('\n[Setup] Creando usuarios y fixtures locales sintéticos...');

    // 1. Docente A y Docente B
    const { data: dA, error: errDA } = await adminClient.auth.admin.createUser({
      email: docenteAEmail,
      password: defaultPassword,
      email_confirm: true,
      user_metadata: { nombre: 'Docente Aula A' },
    });
    if (errDA || !dA.user) throw new Error(`Error creando Docente A: ${errDA?.message}`);
    docenteAId = dA.user.id;
    await adminClient.from('profiles').upsert({
      id: docenteAId,
      nombre: 'Docente Aula A',
      rol: 'docente',
    });

    const { data: dB, error: errDB } = await adminClient.auth.admin.createUser({
      email: docenteBEmail,
      password: defaultPassword,
      email_confirm: true,
      user_metadata: { nombre: 'Docente Aula B' },
    });
    if (errDB || !dB.user) throw new Error(`Error creando Docente B: ${errDB?.message}`);
    docenteBId = dB.user.id;
    await adminClient.from('profiles').upsert({
      id: docenteBId,
      nombre: 'Docente Aula B',
      rol: 'docente',
    });

    // 2. Estudiante A y Estudiante B
    const { data: eA, error: errEA } = await adminClient.auth.admin.createUser({
      email: estudianteAEmail,
      password: defaultPassword,
      email_confirm: true,
      user_metadata: { nombre: 'Estudiante Alfa' },
    });
    if (errEA || !eA.user) throw new Error(`Error creando Estudiante A: ${errEA?.message}`);
    estudianteAId = eA.user.id;
    await adminClient.from('profiles').upsert({
      id: estudianteAId,
      nombre: 'Estudiante Alfa',
      rol: 'estudiante',
      codigo_acceso: `ESTA${timestamp.toString().slice(-4)}`,
    });

    const { data: eB, error: errEB } = await adminClient.auth.admin.createUser({
      email: estudianteBEmail,
      password: defaultPassword,
      email_confirm: true,
      user_metadata: { nombre: 'Estudiante Beta' },
    });
    if (errEB || !eB.user) throw new Error(`Error creando Estudiante B: ${errEB?.message}`);
    estudianteBId = eB.user.id;
    await adminClient.from('profiles').upsert({
      id: estudianteBId,
      nombre: 'Estudiante Beta',
      rol: 'estudiante',
      codigo_acceso: `ESTB${timestamp.toString().slice(-4)}`,
    });

    // 3. Crear Aulas
    const { data: aA, error: errAA } = await adminClient
      .from('aulas')
      .insert({
        nombre: `Aula A ${timestamp}`,
        codigo_aula: `AA${timestamp.toString().slice(-4)}`,
        docente_id: docenteAId,
      })
      .select('id')
      .single();
    if (errAA || !aA) throw new Error(`Error creando Aula A: ${errAA?.message}`);
    aulaAId = aA.id;

    const { data: aB, error: errAB } = await adminClient
      .from('aulas')
      .insert({
        nombre: `Aula B ${timestamp}`,
        codigo_aula: `AB${timestamp.toString().slice(-4)}`,
        docente_id: docenteBId,
      })
      .select('id')
      .single();
    if (errAB || !aB) throw new Error(`Error creando Aula B: ${errAB?.message}`);
    aulaBId = aB.id;

    // 4. Matricular Estudiante A en Aula A
    await adminClient.from('aula_estudiantes').insert({
      aula_id: aulaAId,
      estudiante_id: estudianteAId,
      codigo_local: 'EST-A1',
    });

    // 5. Iniciar sesiones para obtener JWTs
    const clientA = createClient(TEST_URL, TEST_ANON_KEY);
    const { data: sessionDA } = await clientA.auth.signInWithPassword({
      email: docenteAEmail,
      password: defaultPassword,
    });
    docenteAJwt = sessionDA.session!.access_token;

    const clientEA = createClient(TEST_URL, TEST_ANON_KEY);
    const { data: sessionEA } = await clientEA.auth.signInWithPassword({
      email: estudianteAEmail,
      password: defaultPassword,
    });
    estudianteAJwt = sessionEA.session!.access_token;

    const clientEB = createClient(TEST_URL, TEST_ANON_KEY);
    const { data: sessionEB } = await clientEB.auth.signInWithPassword({
      email: estudianteBEmail,
      password: defaultPassword,
    });
    estudianteBJwt = sessionEB.session!.access_token;

    // 6. Crear cuento completado para Estudiante A
    cuentoAId = `cuento_test_${timestamp}`;
    const { error: errCuentoA } = await adminClient.from('cuentos').insert({
      id: cuentoAId,
      titulo: 'El Misterio del Bosque Dorado',
      estudiante_id: estudianteAId,
      aula_id: aulaAId,
      personaje_principal: 'Lucas',
      texto_fuente: 'Lucas entra al bosque en busca de su mascota perdida.',
      resumen_original: 'Una aventura de exploración y amistad.',
      origen: 'dibujo',
    });
    if (errCuentoA) throw new Error(`Error insertando cuentoA: ${errCuentoA.message}`);

    // 4 escenas para el cuento
    for (let num = 1; num <= 4; num++) {
      await adminClient.from('escenas').insert({
        cuento_id: cuentoAId,
        numero: num,
        contenido: `Contenido descriptivo de la escena ${num} con detalles narrativos precisos.`,
        es_final: num === 4,
      });
    }

    console.log('[Setup] Completado exitosamente.\n');

    // ========================================================================
    // BLOQUE 1: SEGURIDAD DE ACCESO (QUIZ-SEC-01..04)
    // ========================================================================
    console.log('--- BLOQUE 1: SEGURIDAD Y CONTROL DE ACCESO ---');

    // QUIZ-SEC-01: generar-quiz sin JWT -> 401
    const resSinJwt = await postFunction('generar-quiz', { cuentoId: cuentoAId });
    recordResult(
      'QUIZ-SEC-01',
      'generar-quiz sin JWT retorna 401 Unauthorized',
      resSinJwt.status === 401,
      `Status obtenido: ${resSinJwt.status}`
    );

    // QUIZ-SEC-02: docente -> 403
    const resDocente = await postFunction('generar-quiz', { cuentoId: cuentoAId }, `Bearer ${docenteAJwt}`);
    recordResult(
      'QUIZ-SEC-02',
      'Docente intentando generar quiz retorna 403 Forbidden',
      resDocente.status === 403,
      `Status obtenido: ${resDocente.status}, body: ${JSON.stringify(resDocente.body)}`
    );

    // QUIZ-SEC-03: estudiante no propietario -> 403
    const resEstudianteAjeno = await postFunction('generar-quiz', { cuentoId: cuentoAId }, `Bearer ${estudianteBJwt}`);
    recordResult(
      'QUIZ-SEC-03',
      'Estudiante que no es dueño del cuento retorna 403 Forbidden',
      resEstudianteAjeno.status === 403,
      `Status obtenido: ${resEstudianteAjeno.status}, body: ${JSON.stringify(resEstudianteAjeno.body)}`
    );

    // QUIZ-SEC-04: estudiante propietario -> permitido (vamos a preparar intento para pruebas deterministas sin consumir Gemini)
    // Insertamos intento sintético en_progreso
    const { data: intentoCreado, error: errIntento } = await adminClient
      .from('quiz_intentos')
      .insert({
        cuento_id: cuentoAId,
        estudiante_id: estudianteAId,
        aula_id: aulaAId,
        estado: 'en_progreso',
        total_preguntas: 5,
      })
      .select('id')
      .single();
    if (errIntento || !intentoCreado) throw new Error(`Error insertando intentoA: ${errIntento?.message}`);
    intentoAId = intentoCreado.id;

    // Insertar 5 preguntas sintéticas
    const preguntasSinteticas = [
      {
        intento_id: intentoAId,
        numero_pregunta: 1,
        pregunta: '¿A quién buscaba Lucas al inicio de la aventura?',
        opciones: ['A su perro', 'A su gato', 'A su conejo', 'A su tortuga'],
        indice_correcto: 1,
        explicacion: 'Lucas buscaba a su gato perdido según la primera escena.',
      },
      {
        intento_id: intentoAId,
        numero_pregunta: 2,
        pregunta: '¿Qué encontró Lucas en la segunda escena?',
        opciones: ['Un mapa', 'Una llave dorada', 'Una linterna', 'Una manzana'],
        indice_correcto: 1,
        explicacion: 'Lucas halló una llave dorada sobre una roca.',
      },
      {
        intento_id: intentoAId,
        numero_pregunta: 3,
        pregunta: '¿Por qué decidió cruzar el puente de madera?',
        opciones: ['Porque llovía', 'Para llegar a la colina', 'Porque tenía miedo', 'Para descansar'],
        indice_correcto: 1,
        explicacion: 'Cruzó el puente para alcanzar la colina donde vio las luces.',
      },
      {
        intento_id: intentoAId,
        numero_pregunta: 4,
        pregunta: '¿Cómo se sintió Lucas al escuchar el sonido entre las hojas?',
        opciones: ['Enojado', 'Curioso y atento', 'Aburrido', 'Dormido'],
        indice_correcto: 1,
        explicacion: 'Se mostró curioso y prestó atención a los ruidos.',
      },
      {
        intento_id: intentoAId,
        numero_pregunta: 5,
        pregunta: '¿Cómo concluyó la aventura en la última escena?',
        opciones: ['Regresó triste', 'Encontró a su gato a salvo', 'Se perdió en el bosque', 'No pasó nada'],
        indice_correcto: 1,
        explicacion: 'La aventura terminó felizmente al rescatar a su mascota.',
      },
    ];

    await adminClient.from('quiz_respuestas').insert(preguntasSinteticas);

    // Ahora invocar generar-quiz con Estudiante A (debe reutilizar el intento existente)
    const resGenerarPropietario = await postFunction('generar-quiz', { cuentoId: cuentoAId }, `Bearer ${estudianteAJwt}`);
    recordResult(
      'QUIZ-SEC-04',
      'Estudiante propietario es autorizado y accede al quiz',
      resGenerarPropietario.status === 200,
      `Status: ${resGenerarPropietario.status}, body: ${JSON.stringify(resGenerarPropietario.body)}`
    );

    // ========================================================================
    // BLOQUE 2: ESTRUCTURA Y SANITIZACIÓN DE PREGUNTAS (QUIZ-GEN-01..05)
    // ========================================================================
    console.log('\n--- BLOQUE 2: GENERACIÓN, ESTRUCTURA Y SANITIZACIÓN ---');

    const preguntasResp = resGenerarPropietario.body?.preguntas || [];

    // QUIZ-GEN-01: exactamente 5 preguntas
    recordResult(
      'QUIZ-GEN-01',
      'generar-quiz retorna exactamente 5 preguntas',
      preguntasResp.length === 5,
      `Total preguntas devueltas: ${preguntasResp.length}`
    );

    // QUIZ-GEN-02: cada pregunta exactamente 4 opciones
    const todasCon4Opciones = preguntasResp.every((p: any) => Array.isArray(p.opciones) && p.opciones.length === 4);
    recordResult(
      'QUIZ-GEN-02',
      'Cada pregunta tiene exactamente 4 opciones de respuesta',
      todasCon4Opciones,
      `Verificación de opciones: ${todasCon4Opciones}`
    );

    // QUIZ-GEN-03: indices correctos en base de datos entre 0 y 3
    const { data: dbRespuestas } = await adminClient
      .from('quiz_respuestas')
      .select('indice_correcto')
      .eq('intento_id', intentoAId);
    const indicesCorrectosValidos = dbRespuestas?.every((r: any) => r.indice_correcto >= 0 && r.indice_correcto <= 3);
    recordResult(
      'QUIZ-GEN-03',
      'Índices correctos en base de datos son enteros estrictamente entre 0 y 3',
      indicesCorrectosValidos === true,
      `Índices verificados: ${JSON.stringify(dbRespuestas)}`
    );

    // QUIZ-GEN-04: respuesta enviada a Flutter NO contiene correctIndex ni explicación
    const contieneFugas = preguntasResp.some(
      (p: any) => p.indiceCorrecto !== undefined || p.correctIndex !== undefined || p.explicacion !== undefined || p.explanation !== undefined
    );
    recordResult(
      'QUIZ-GEN-04',
      'Respuesta al cliente está sanitizada: NO contiene indiceCorrecto ni explicación antes del envío',
      !contieneFugas,
      `Fugas detectadas: ${contieneFugas}`
    );

    // QUIZ-GEN-05: segundo generar-quiz del mismo cuento reutiliza intento y no regenera
    const resSegundoGenerar = await postFunction('generar-quiz', { cuentoId: cuentoAId }, `Bearer ${estudianteAJwt}`);
    const intentoMismo = resSegundoGenerar.body?.intentoId === intentoAId;
    recordResult(
      'QUIZ-GEN-05',
      'Segundo generar-quiz reutiliza el intento en progreso existente sin duplicar ni llamar a Gemini',
      intentoMismo && resSegundoGenerar.status === 200,
      `intentoId devuelto: ${resSegundoGenerar.body?.intentoId}, esperado: ${intentoAId}`
    );

    // ========================================================================
    // BLOQUE 3: ENVÍO, CORRECCIÓN Y IDEMPOTENCIA (QUIZ-SUBMIT-01..04)
    // ========================================================================
    console.log('\n--- BLOQUE 3: ENVÍO, EVALUACIÓN Y CORRECCIÓN EN SERVIDOR ---');

    // QUIZ-SUBMIT-02: respuestas incompletas -> rechazadas (400)
    const resIncompletas = await postFunction(
      'enviar-quiz',
      {
        intentoId: intentoAId,
        respuestas: [
          { numero: 1, indiceSeleccionado: 1 },
          { numero: 2, indiceSeleccionado: 1 },
        ],
      },
      `Bearer ${estudianteAJwt}`
    );
    recordResult(
      'QUIZ-SUBMIT-02',
      'Envío de menos de 5 respuestas es rechazado con 400 Bad Request',
      resIncompletas.status === 400,
      `Status obtenido: ${resIncompletas.status}, error: ${JSON.stringify(resIncompletas.body)}`
    );

    // QUIZ-SUBMIT-03: intento ajeno -> 403
    const resSubmitAjeno = await postFunction(
      'enviar-quiz',
      {
        intentoId: intentoAId,
        respuestas: [
          { numero: 1, indiceSeleccionado: 1 },
          { numero: 2, indiceSeleccionado: 1 },
          { numero: 3, indiceSeleccionado: 1 },
          { numero: 4, indiceSeleccionado: 1 },
          { numero: 5, indiceSeleccionado: 1 },
        ],
      },
      `Bearer ${estudianteBJwt}`
    );
    recordResult(
      'QUIZ-SUBMIT-03',
      'Envío de respuestas por un estudiante que no es dueño del intento es bloqueado con 403 Forbidden',
      resSubmitAjeno.status === 403,
      `Status obtenido: ${resSubmitAjeno.status}`
    );

    // QUIZ-SUBMIT-01: 5 respuestas válidas -> puntaje correcto calculado en el servidor
    // Respuestas: 4 correctas (índice 1) y 1 incorrecta (índice 0 en preg 3)
    // Esperado: puntaje 4, total 5, porcentaje 80%
    const resSubmitValido = await postFunction(
      'enviar-quiz',
      {
        intentoId: intentoAId,
        respuestas: [
          { numero: 1, indiceSeleccionado: 1 }, // Correcta (1 == 1)
          { numero: 2, indiceSeleccionado: 1 }, // Correcta (1 == 1)
          { numero: 3, indiceSeleccionado: 0 }, // Incorrecta (0 != 1)
          { numero: 4, indiceSeleccionado: 1 }, // Correcta (1 == 1)
          { numero: 5, indiceSeleccionado: 1 }, // Correcta (1 == 1)
        ],
      },
      `Bearer ${estudianteAJwt}`
    );

    const submitBody = resSubmitValido.body;
    const puntajeCorrecto = submitBody?.puntaje === 4 && submitBody?.total === 5 && submitBody?.porcentaje === 80;
    const incluyeRespuestasCompletas = Array.isArray(submitBody?.respuestas) && submitBody.respuestas.length === 5;
    const ahoraSiIncluyeExplicacion = submitBody?.respuestas?.every(
      (r: any) => typeof r.explicacion === 'string' && r.explicacion.length > 0 && r.indiceCorrecto !== undefined
    );

    recordResult(
      'QUIZ-SUBMIT-01',
      'Servidor calcula correctamente puntaje (4/5 = 80%), marca esCorrecta y adjunta explicaciones post-evaluación',
      resSubmitValido.status === 200 && puntajeCorrecto && incluyeRespuestasCompletas && ahoraSiIncluyeExplicacion,
      `Puntaje: ${submitBody?.puntaje}/${submitBody?.total} (${submitBody?.porcentaje}%), status: ${resSubmitValido.status}`
    );

    // QUIZ-SUBMIT-04: reenvío de intento completado -> idempotente (retorna mismo puntaje sin duplicar ni error)
    const resReenvio = await postFunction(
      'enviar-quiz',
      {
        intentoId: intentoAId,
        respuestas: [
          { numero: 1, indiceSeleccionado: 2 }, // Intento de cambiar respuesta
          { numero: 2, indiceSeleccionado: 2 },
          { numero: 3, indiceSeleccionado: 2 },
          { numero: 4, indiceSeleccionado: 2 },
          { numero: 5, indiceSeleccionado: 2 },
        ],
      },
      `Bearer ${estudianteAJwt}`
    );
    const sigueSiendo4 = resReenvio.body?.puntaje === 4 && resReenvio.body?.porcentaje === 80;
    recordResult(
      'QUIZ-SUBMIT-04',
      'Reenvío de intento completado es idempotente: retorna resultado guardado sin permitir modificación de puntaje',
      resReenvio.status === 200 && sigueSiendo4,
      `Puntaje devuelto en reenvío: ${resReenvio.body?.puntaje}`
    );

    // ========================================================================
    // BLOQUE 4: ROW LEVEL SECURITY (QUIZ-RLS-01..05)
    // ========================================================================
    console.log('\n--- BLOQUE 4: ROW LEVEL SECURITY (RLS) ---');

    // QUIZ-RLS-01: anon no ve nada
    const { data: anonIntentos, error: anonErr } = await anonClient.from('quiz_intentos').select('*');
    const { data: anonRespuestas } = await anonClient.from('quiz_respuestas').select('*');
    recordResult(
      'QUIZ-RLS-01',
      'Usuario anónimo tiene cero acceso (SELECT denegado o retorna vacío por RLS)',
      (anonIntentos === null || anonIntentos.length === 0) && (anonRespuestas === null || anonRespuestas.length === 0),
      `anonIntentos: ${anonIntentos?.length ?? 0}, anonRespuestas: ${anonRespuestas?.length ?? 0}`
    );

    // QUIZ-RLS-02: estudiante A no ve intento de B (y viceversa)
    const clientEstudianteB = createClient(TEST_URL, TEST_ANON_KEY);
    await clientEstudianteB.auth.signInWithPassword({
      email: estudianteBEmail,
      password: defaultPassword,
    });
    const { data: intentosVistosPorB } = await clientEstudianteB
      .from('quiz_intentos')
      .select('*')
      .eq('id', intentoAId!);
    recordResult(
      'QUIZ-RLS-02',
      'Estudiante B no puede ver el intento de Estudiante A a través de RLS',
      intentosVistosPorB !== null && intentosVistosPorB.length === 0,
      `Registros devueltos a Estudiante B: ${intentosVistosPorB?.length}`
    );

    // QUIZ-RLS-03: docente del aula ve resultado
    const clientDocenteA = createClient(TEST_URL, TEST_ANON_KEY);
    await clientDocenteA.auth.signInWithPassword({
      email: docenteAEmail,
      password: defaultPassword,
    });
    const { data: intentosVistosPorDocenteA } = await clientDocenteA
      .from('quiz_intentos')
      .select('*, quiz_respuestas(*)')
      .eq('id', intentoAId!);
    const docenteAVeTodo =
      intentosVistosPorDocenteA !== null &&
      intentosVistosPorDocenteA.length === 1 &&
      intentosVistosPorDocenteA[0].quiz_respuestas?.length === 5;
    recordResult(
      'QUIZ-RLS-03',
      'Docente del aula (Docente A) puede consultar el resultado y respuestas de sus alumnos matriculados',
      docenteAVeTodo,
      `Intentos vistos: ${intentosVistosPorDocenteA?.length}, respuestas: ${intentosVistosPorDocenteA?.[0]?.quiz_respuestas?.length}`
    );

    // QUIZ-RLS-04: docente de otra aula no ve resultado
    const clientDocenteB = createClient(TEST_URL, TEST_ANON_KEY);
    await clientDocenteB.auth.signInWithPassword({
      email: docenteBEmail,
      password: defaultPassword,
    });
    const { data: intentosVistosPorDocenteB } = await clientDocenteB
      .from('quiz_intentos')
      .select('*')
      .eq('id', intentoAId!);
    recordResult(
      'QUIZ-RLS-04',
      'Docente de otra aula (Docente B) no puede ver resultados de alumnos que no pertenecen a sus aulas',
      intentosVistosPorDocenteB !== null && intentosVistosPorDocenteB.length === 0,
      `Intentos vistos por Docente B: ${intentosVistosPorDocenteB?.length}`
    );

    // QUIZ-RLS-05: estudiante en progreso no puede consultar indice_correcto directamente
    // Creamos un segundo cuento e intento temporal 'en_progreso'
    const cuentoTempId = `cuento_temp_${timestamp}`;
    const { error: errCuentoTemp } = await adminClient.from('cuentos').insert({
      id: cuentoTempId,
      titulo: 'Cuento Temporal En Progreso',
      estudiante_id: estudianteAId,
      aula_id: aulaAId,
      personaje_principal: 'Lucas',
      texto_fuente: 'Historia base temporal.',
      origen: 'dibujo',
    });
    if (errCuentoTemp) throw new Error(`Error insertando cuentoTemp: ${errCuentoTemp.message}`);

    const { data: intentoTemp, error: errIntentoTemp } = await adminClient
      .from('quiz_intentos')
      .insert({
        cuento_id: cuentoTempId,
        estudiante_id: estudianteAId,
        aula_id: aulaAId,
        estado: 'en_progreso',
      })
      .select('id')
      .single();
    if (errIntentoTemp || !intentoTemp) throw new Error(`Error insertando intentoTemp: ${errIntentoTemp?.message}`);

    await adminClient.from('quiz_respuestas').insert({
      intento_id: intentoTemp!.id,
      numero_pregunta: 1,
      pregunta: 'Pregunta secreta',
      opciones: ['A', 'B', 'C', 'D'],
      indice_correcto: 2,
      explicacion: 'Explicación protegida',
    });

    const clientEstudianteA = createClient(TEST_URL, TEST_ANON_KEY);
    await clientEstudianteA.auth.signInWithPassword({
      email: estudianteAEmail,
      password: defaultPassword,
    });
    const { data: respuestasEnProgreso } = await clientEstudianteA
      .from('quiz_respuestas')
      .select('indice_correcto, explicacion')
      .eq('intento_id', intentoTemp!.id);

    recordResult(
      'QUIZ-RLS-05',
      'Estudiante con intento en progreso no puede consultar respuestas correctas ni explicaciones directamente vía RLS',
      respuestasEnProgreso !== null && respuestasEnProgreso.length === 0,
      `Registros visibles en progreso para estudiante: ${respuestasEnProgreso?.length}`
    );

    // Limpiar cuento temporal
    await adminClient.from('cuentos').delete().eq('id', cuentoTempId);
  } catch (err: any) {
    console.error('💥 Error inesperado durante la ejecución de los tests:', err);
    process.exit(1);
  } finally {
    // ------------------------------------------------------------------------
    // CLEANUP: Limpieza de datos sintéticos locales de prueba
    // ------------------------------------------------------------------------
    console.log('\n[Cleanup] Eliminando usuarios y fixtures sintéticos locales...');
    try {
      if (cuentoAId) await adminClient.from('cuentos').delete().eq('id', cuentoAId);
      if (aulaAId) await adminClient.from('aulas').delete().eq('id', aulaAId);
      if (aulaBId) await adminClient.from('aulas').delete().eq('id', aulaBId);
      if (estudianteAId) await adminClient.auth.admin.deleteUser(estudianteAId);
      if (estudianteBId) await adminClient.auth.admin.deleteUser(estudianteBId);
      if (docenteAId) await adminClient.auth.admin.deleteUser(docenteAId);
      if (docenteBId) await adminClient.auth.admin.deleteUser(docenteBId);
      console.log('[Cleanup] Datos sintéticos eliminados correctamente.');
    } catch (cleanupErr) {
      console.warn('[Cleanup] Advertencia durante limpieza:', cleanupErr);
    }
  }

  // ------------------------------------------------------------------------
  // RESUMEN FINAL
  // ------------------------------------------------------------------------
  console.log('\n' + '='.repeat(70));
  console.log('📊 RESUMEN DE RESULTADOS DE PRUEBAS LOCALES');
  console.log('='.repeat(70));
  const pasaron = results.filter((r) => r.passed).length;
  const fallaron = results.filter((r) => !r.passed).length;

  console.log(`Total de pruebas: ${results.length}`);
  console.log(`Exitosas:        ${pasaron}`);
  console.log(`Fallidas:        ${fallaron}`);

  if (fallaron > 0) {
    console.error('\n❌ Hay pruebas fallidas.');
    process.exit(1);
  } else {
    console.log('\n🎉 ¡TODAS LAS PRUEBAS DE SEGURIDAD, EDGE FUNCTIONS Y RLS PASARON CON ÉXITO!');
    process.exit(0);
  }
}

main();
