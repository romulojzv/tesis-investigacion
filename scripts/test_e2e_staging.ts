/// <reference lib="deno.ns" />
/// <reference lib="dom" />
import { createClient } from 'npm:@supabase/supabase-js';
import { assertEquals, assert, assertRejects } from 'jsr:@std/assert';

/**
 * Suite E2E de Validación Integral en Supabase Staging
 * Proyecto: cuentos-magicos-staging (acxsyswrzdtstgqztojj)
 */
export async function ejecutarPruebasE2E(config: {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
}) {
  console.log('===============================================================');
  console.log(' INICIANDO VALIDACIÓN E2E EN STAGING: cuentos-magicos-staging ');
  console.log(' Target:', config.supabaseUrl);
  console.log('===============================================================\n');

  const adminClient = createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const anonClient = createClient(config.supabaseUrl, config.anonKey);

  // 1. Crear / Autenticar usuarios sintéticos de prueba
  console.log('--- 1. Preparando identidades sintéticas de prueba ---');
  const emailDocente = 'docente_staging_demo@ucss.pe';
  const emailEstudiante1 = 'estudiante_staging_1@ucss.pe';
  const emailEstudiante2 = 'estudiante_staging_2@ucss.pe';
  const passwordComun = 'PruebaStaging2026!';

  async function obtenerOCrearUsuario(email: string, nombre: string, rol: 'docente' | 'estudiante') {
    // Buscar si ya existe
    const { data: users } = await adminClient.auth.admin.listUsers();
    let user = users?.users?.find(u => u.email === email);

    if (!user) {
      const { data: nuevo, error } = await adminClient.auth.admin.createUser({
        email,
        password: passwordComun,
        email_confirm: true,
        user_metadata: { nombre, rol },
      });
      if (error) throw new Error(`Error creando usuario ${email}: ${error.message}`);
      user = nuevo.user;
    }

    // Asegurar perfil
    await adminClient.from('profiles').upsert({
      id: user.id,
      nombre,
      rol,
    });

    // Iniciar sesión para obtener token JWT de cliente
    const { data: sessionData, error: loginError } = await anonClient.auth.signInWithPassword({
      email,
      password: passwordComun,
    });
    if (loginError) throw new Error(`Error autenticando ${email}: ${loginError.message}`);

    const client = createClient(config.supabaseUrl, config.anonKey, {
      global: { headers: { Authorization: `Bearer ${sessionData.session.access_token}` } },
    });

    return {
      id: user.id,
      email,
      token: sessionData.session.access_token,
      client,
    };
  }

  const docente = await obtenerOCrearUsuario(emailDocente, 'Profesor Staging', 'docente');
  const estudiante1 = await obtenerOCrearUsuario(emailEstudiante1, 'Estudiante Staging Uno', 'estudiante');
  const estudiante2 = await obtenerOCrearUsuario(emailEstudiante2, 'Estudiante Staging Dos', 'estudiante');

  console.log(`✅ Docente ID: ${docente.id}`);
  console.log(`✅ Estudiante 1 ID: ${estudiante1.id}`);
  console.log(`✅ Estudiante 2 ID: ${estudiante2.id}`);

  // 2. Estructura escolar en Staging
  console.log('\n--- 2. Vinculando aula y estudiantes ---');
  const { data: aulaExistente } = await adminClient
    .from('aulas')
    .select('id')
    .eq('codigo_aula', 'STG4')
    .maybeSingle();

  let aulaId = aulaExistente?.id;
  if (!aulaId) {
    const { data: nuevaAula } = await adminClient.from('aulas').insert({
      nombre: '4to Grado Staging',
      codigo_aula: 'STG4',
      docente_id: docente.id,
    }).select('id').single();
    aulaId = nuevaAula!.id;
  }

  await adminClient.from('aula_estudiantes').upsert([
    { aula_id: aulaId, estudiante_id: estudiante1.id, codigo_local: 'EST1' },
    { aula_id: aulaId, estudiante_id: estudiante2.id, codigo_local: 'EST2' },
  ]);
  console.log(`✅ Aula Staging vinculada (ID: ${aulaId})`);

  // 3. Crear cuento finalizado para Estudiante 1
  console.log('\n--- 3. Creando cuento de prueba finalizado ---');
  const cuentoId = 'cuento-staging-001';
  await adminClient.from('cuentos').upsert({
    id: cuentoId,
    titulo: 'El Misterio del Valle Dorado',
    personaje_principal: 'Nico',
    estudiante_id: estudiante1.id,
    aula_id: aulaId,
    escenario_original: 'Un valle encantado con cascadas mágicas',
    conflicto_principal: 'El río se secaba porque un gnomo cerró la compuerta',
    final_original: 'Nico dialogó con el gnomo y compartieron el agua en armonía',
  });

  await adminClient.from('escenas').upsert([
    {
      id: `${cuentoId}_esc1`,
      cuento_id: cuentoId,
      numero: 1,
      contenido: 'Nico exploraba las colinas doradas cuando escuchó un rumor extraño junto al cauce seco.',
      opciones: ['Seguir las huellas en la arena', 'Subir al mirador de piedra'],
      es_final: false,
    },
    {
      id: `${cuentoId}_esc2`,
      cuento_id: cuentoId,
      numero: 2,
      contenido: 'Al subir al mirador, divisó una pequeña presa de madera y al gnomo constructor.',
      opciones: ['Acercarse con cortesía'],
      es_final: false,
    },
    {
      id: `${cuentoId}_esc3`,
      cuento_id: cuentoId,
      numero: 3,
      contenido: 'El gnomo entendió la importancia del río y juntos abrieron la compuerta para que el agua volviera al valle.',
      opciones: ['Celebrar con todos los animales'],
      es_final: true,
    },
  ]);

  await adminClient.from('decisiones_narrativas').upsert([
    { id: `${cuentoId}_dec1`, cuento_id: cuentoId, numero_escena: 1, opcion_seleccionada: 'Subir al mirador de piedra' },
  ]);
  console.log(`✅ Cuento y escenas finalizadas creadas en Staging.`);

  // 4. Invocar Edge Function: generar-quiz (RF-22)
  console.log('\n--- 4. Invocando Edge Function generar-quiz (RF-22) ---');
  const genResp = await fetch(`${config.supabaseUrl}/functions/v1/generar-quiz`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({ cuentoId }),
  });

  if (!genResp.ok) {
    const errBody = await genResp.text();
    throw new Error(`generar-quiz respondió ${genResp.status}: ${errBody}`);
  }

  const quizData = await genResp.json();
  const intentoId = quizData.intentoId;
  assert(intentoId, 'Debe devolver un intentoId');
  assertEquals(quizData.preguntas.length, 5, 'Deben generarse exactamente 5 preguntas');

  // Verificar confidencialidad (zero-leak)
  for (const p of quizData.preguntas) {
    assert(p.indiceCorrecto === undefined, 'No debe filtrar indiceCorrecto');
    assert(p.explicacion === undefined, 'No debe filtrar explicacion');
    assert(p.nivelComprension !== undefined, 'Debe incluir nivelComprension');
  }
  console.log('✅ Cuestionario generado sin filtración de respuestas.');

  // Verificar distribución 2-2-1 en la base de datos
  const { data: preguntasDb } = await adminClient
    .from('quiz_respuestas')
    .select('numero_pregunta, nivel_comprension, indice_correcto')
    .eq('intento_id', intentoId)
    .order('numero_pregunta');

  const conteoNiveles = { literal: 0, inferencial: 0, critico_reflexivo: 0 };
  preguntasDb?.forEach(p => {
    conteoNiveles[p.nivel_comprension as keyof typeof conteoNiveles]++;
  });

  console.log('Distribución persistida en BD:', conteoNiveles);
  assertEquals(conteoNiveles.literal, 2, 'Deben existir 2 preguntas literales');
  assertEquals(conteoNiveles.inferencial, 2, 'Deben existir 2 preguntas inferenciales');
  assertEquals(conteoNiveles.critico_reflexivo, 1, 'Debe existir 1 pregunta crítico-reflexiva');
  console.log('✅ RF-22 validado con distribución estricta 2-2-1 en BD.');

  // 5. Retroalimentación inmediata, Inmutabilidad y Calificación (RF-26)
  console.log('\n--- 5. Invocando responder-pregunta: Pregunta 1 (Correcta) ---');
  const p1 = preguntasDb![0];
  const resp1 = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 1,
      indiceSeleccionado: p1.indice_correcto,
    }),
  });
  const data1 = await resp1.json();
  assertEquals(data1.esCorrecta, true);
  assertEquals(data1.quizFinalizado, false);
  assert(data1.explicacion, 'Debe retornar explicación formativa');
  console.log('✅ Pregunta 1 confirmada con retroalimentación inmediata correcta.');

  // Probar Idempotencia
  console.log('--- Probando idempotencia de Pregunta 1 ---');
  const resp1Reenvio = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 1,
      indiceSeleccionado: p1.indice_correcto,
    }),
  });
  assertEquals(resp1Reenvio.status, 200);
  console.log('✅ Reenvío idéntico procesado de forma idempotente.');

  // Probar Inmutabilidad: intento de cambio
  console.log('--- Probando inmutabilidad ante intento de alteración ---');
  const opcionAlternativa = (p1.indice_correcto + 1) % 4;
  const resp1Alterar = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 1,
      indiceSeleccionado: opcionAlternativa,
    }),
  });
  assertEquals(resp1Alterar.status, 409, 'Debe retornar 409 Conflict al intentar modificar');
  console.log('✅ Inmutabilidad confirmada: no se permite alterar respuesta ya confirmada.');

  // Probar Seguridad / Autorización: Estudiante 2 intentando responder el cuestionario de Estudiante 1
  console.log('--- Probando intento de respuesta cruzada no autorizada ---');
  const respCruzada = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante2.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 2,
      indiceSeleccionado: 0,
    }),
  });
  assertEquals(respCruzada.status, 403, 'Debe rechazar con 403 Forbidden para otro estudiante');
  console.log('✅ Seguridad de autorización cruzada validada (HTTP 403).');

  // Responder Pregunta 2 (Incorrecta)
  console.log('\n--- Invocando responder-pregunta: Pregunta 2 (Incorrecta) ---');
  const p2 = preguntasDb![1];
  const opcionErronea = (p2.indice_correcto + 1) % 4;
  const resp2 = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 2,
      indiceSeleccionado: opcionErronea,
    }),
  });
  const data2 = await resp2.json();
  assertEquals(data2.esCorrecta, false);
  assertEquals(data2.indiceCorrecto, p2.indice_correcto);
  assert(data2.explicacion, 'Debe incluir explicación pedagógica ante error');
  console.log('✅ Pregunta 2 procesada con retroalimentación correctiva y solución revelada.');

  // Responder Preguntas 3 y 4
  console.log('\n--- Respondiendo preguntas 3 y 4 ---');
  for (let n = 3; n <= 4; n++) {
    const pn = preguntasDb![n - 1];
    const r = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${estudiante1.token}`,
      },
      body: JSON.stringify({
        intentoId,
        numero: n,
        indiceSeleccionado: pn.indice_correcto,
      }),
    });
    assertEquals(r.status, 200);
  }

  // Responder Pregunta 5 (FINAL) y comprobar cierre atómico
  console.log('\n--- Respondiendo pregunta 5 (FINAL): verificación atómica ---');
  const p5 = preguntasDb![4];
  const resp5 = await fetch(`${config.supabaseUrl}/functions/v1/responder-pregunta`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify({
      intentoId,
      numero: 5,
      indiceSeleccionado: p5.indice_correcto,
    }),
  });
  const data5 = await resp5.json();
  assertEquals(data5.quizFinalizado, true, 'Debe indicar que el quiz ha finalizado');

  // Verificar estado en la base de datos de Staging
  const { data: intentoDbFinal } = await adminClient
    .from('quiz_intentos')
    .select('estado, puntaje, porcentaje, completed_at')
    .eq('id', intentoId)
    .single();

  assertEquals(intentoDbFinal!.estado, 'completado');
  assertEquals(intentoDbFinal!.puntaje, 4); // 4 correctas, 1 errada
  assertEquals(Number(intentoDbFinal!.porcentaje), 80);
  assert(intentoDbFinal!.completed_at !== null);
  console.log('✅ Intento completado atómicamente en Staging: Puntaje 4/5 (80%).');

  // 6. Prueba de blindaje: enviar-quiz no puede alterar respuestas ya confirmadas
  console.log('\n--- 6. Verificando blindaje contra enviar-quiz ---');
  const payloadConflicto = {
    intentoId,
    respuestas: [
      { numero: 1, indiceSeleccionado: 3 }, // Intento de alterar la 1
      { numero: 2, indiceSeleccionado: 0 },
      { numero: 3, indiceSeleccionado: 0 },
      { numero: 4, indiceSeleccionado: 0 },
      { numero: 5, indiceSeleccionado: 0 },
    ],
  };
  const respEnviarConflicto = await fetch(`${config.supabaseUrl}/functions/v1/enviar-quiz`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${estudiante1.token}`,
    },
    body: JSON.stringify(payloadConflicto),
  });
  // Si el intento ya está completado, enviar-quiz retorna el resultado ya persistido (idempotencia)
  // sin alterar en ningún caso la BD:
  const { data: intentoDbInmutable } = await adminClient
    .from('quiz_intentos')
    .select('puntaje, porcentaje')
    .eq('id', intentoId)
    .single();
  assertEquals(intentoDbInmutable!.puntaje, 4, 'El puntaje se mantiene estrictamente inmutable');
  console.log('✅ Cero corrupción: enviar-quiz no alteró la calificación existente.');

  // 7. Acceso docente y RLS
  console.log('\n--- 7. Verificando acceso de docente a resultados vía RLS ---');
  const { data: resultadosDocente, error: errDoc } = await docente.client
    .from('quiz_intentos')
    .select('id, puntaje, porcentaje, estado, estudiante_id')
    .eq('id', intentoId);

  assert(!errDoc, 'La consulta del docente no debe fallar');
  assertEquals(resultadosDocente.length, 1, 'El docente del aula debe ver el intento');
  assertEquals(resultadosDocente[0].puntaje, 4);
  console.log('✅ Docente visualiza el resultado del estudiante correctamente.');

  // Estudiante 2 NO debe poder ver el intento de Estudiante 1
  const { data: resultadoEstudiante2 } = await estudiante2.client
    .from('quiz_intentos')
    .select('id')
    .eq('id', intentoId);
  assertEquals(resultadoEstudiante2?.length, 0, 'Estudiante ajeno no debe ver el intento');
  console.log('✅ Aislamiento RLS entre estudiantes validado.');

  console.log('\n===============================================================');
  console.log(' ✅ TODAS LAS PRUEBAS E2E EN STAGING COMPLETADAS CON ÉXITO    ');
  console.log('===============================================================\n');
}

if (import.meta.main) {
  const url = Deno.env.get('SUPABASE_URL') || 'https://acxsyswrzdtstgqztojj.supabase.co';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

  if (!anonKey || !serviceKey) {
    console.error('Error: configure SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY');
    Deno.exit(1);
  }

  await ejecutarPruebasE2E({ supabaseUrl: url, anonKey, serviceRoleKey: serviceKey });
}
