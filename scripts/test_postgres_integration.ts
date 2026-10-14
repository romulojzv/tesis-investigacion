/// <reference lib="deno.ns" />
/// <reference lib="dom" />
import { PGlite } from 'npm:@electric-sql/pglite';
import { assertEquals, assertRejects, assert } from 'jsr:@std/assert';

Deno.test('INTEGRACIÓN POSTGRESQL: Validación integral de RF-22, RF-26, migraciones y RPC', async () => {
  const db = new PGlite();

  // 1. Preparar esquema base en PostgreSQL
  console.log('--- 1. Aplicando esquema base ---');
  await db.exec(`
    DO $$ BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon;
      END IF;
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated;
      END IF;
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role;
      END IF;
    END $$;

    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE TABLE IF NOT EXISTS auth.users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT
    );

    CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
      SELECT NULL::UUID;
    $$ LANGUAGE sql STABLE;

    CREATE SCHEMA IF NOT EXISTS app_private;
    CREATE OR REPLACE FUNCTION app_private.es_docente() RETURNS BOOLEAN AS $$
      SELECT FALSE;
    $$ LANGUAGE sql STABLE;
    CREATE OR REPLACE FUNCTION app_private.es_docente_de_aula(p_aula UUID) RETURNS BOOLEAN AS $$
      SELECT FALSE;
    $$ LANGUAGE sql STABLE;
    CREATE OR REPLACE FUNCTION app_private.es_docente_de_estudiante(p_est UUID) RETURNS BOOLEAN AS $$
      SELECT FALSE;
    $$ LANGUAGE sql STABLE;

    CREATE TABLE IF NOT EXISTS public.profiles (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      nombre TEXT NOT NULL,
      rol TEXT NOT NULL CHECK (rol IN ('docente', 'estudiante'))
    );

    CREATE TABLE IF NOT EXISTS public.aulas (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nombre TEXT NOT NULL,
      codigo_aula TEXT UNIQUE NOT NULL
    );

    CREATE TABLE IF NOT EXISTS public.cuentos (
      id TEXT PRIMARY KEY,
      titulo TEXT NOT NULL,
      personaje_principal TEXT NOT NULL,
      estudiante_id UUID REFERENCES public.profiles(id)
    );
  `);

  // 2. Aplicar migración 20261008100000_quiz_comprension.sql
  console.log('--- 2. Aplicando migración 20261008100000_quiz_comprension.sql ---');
  const migration1 = await Deno.readTextFile('supabase/migrations/20261008100000_quiz_comprension.sql');
  await db.exec(migration1);

  // 3. Aplicar migración 20261014130000_quiz_niveles_feedback.sql
  console.log('--- 3. Aplicando migración 20261014130000_quiz_niveles_feedback.sql ---');
  const migration2 = await Deno.readTextFile('supabase/migrations/20261014130000_quiz_niveles_feedback.sql');
  await db.exec(migration2);

  // 4. Crear estudiantes de prueba y cuento
  console.log('--- 4. Creando fixtures de estudiantes y cuento ---');
  const estudianteA = '11111111-1111-1111-1111-111111111111';
  const estudianteB = '22222222-2222-2222-2222-222222222222';
  const cuentoId = 'cuento-prueba-01';

  await db.exec(`
    INSERT INTO auth.users (id, email) VALUES
      ('${estudianteA}', 'estudianteA@escuela.pe'),
      ('${estudianteB}', 'estudianteB@escuela.pe');

    INSERT INTO public.profiles (id, nombre, rol) VALUES
      ('${estudianteA}', 'Carlos Alumno', 'estudiante'),
      ('${estudianteB}', 'Beatriz Alumna', 'estudiante');

    INSERT INTO public.cuentos (id, titulo, personaje_principal, estudiante_id) VALUES
      ('${cuentoId}', 'El Dragón del Río', 'Tito', '${estudianteA}');
  `);

  // 5. Crear intento y 5 preguntas con distribución 2-2-1 (RF-22)
  console.log('--- 5. Registrando intento y 5 preguntas estructuradas (RF-22) ---');
  const intentoRes = await db.query<{ id: string }>(`
    INSERT INTO public.quiz_intentos (cuento_id, estudiante_id, estado, total_preguntas)
    VALUES ('${cuentoId}', '${estudianteA}', 'en_progreso', 5)
    RETURNING id;
  `);
  const intentoId = intentoRes.rows[0].id;
  assert(intentoId, 'El intentoId debe generarse');

  await db.query(`
    INSERT INTO public.quiz_respuestas (intento_id, numero_pregunta, pregunta, opciones, indice_correcto, explicacion, nivel_comprension)
    VALUES
      ('${intentoId}', 1, '¿Quién es el personaje?', '["Tito", "Beto", "Lalo", "Pepe"]'::jsonb, 0, 'Tito es el protagonista', 'literal'),
      ('${intentoId}', 2, '¿Dónde ocurre la historia?', '["Playa", "Río", "Montaña", "Bosque"]'::jsonb, 1, 'Ocurre en el río', 'literal'),
      ('${intentoId}', 3, '¿Por qué volaba bajo el dragón?', '["Tenía frío", "Estaba cansado", "Tenía hambre", "Jugaba"]'::jsonb, 1, 'Estaba cansado de viajar', 'inferencial'),
      ('${intentoId}', 4, '¿Qué sintió Tito al verlo?', '["Alegría", "Enojo", "Asombro", "Tristeza"]'::jsonb, 2, 'Sintió asombro', 'inferencial'),
      ('${intentoId}', 5, '¿Qué opinas de la decisión de Tito?', '["Fue valiente", "Fue egoísta", "Fue mala", "Fue aburrida"]'::jsonb, 0, 'Demuestra valentía y empatía', 'critico_reflexivo');
  `);

  // 6. Verificar persistencia de niveles de comprensión en BD
  const niveles = await db.query<{ nivel_comprension: string; c: number }>(`
    SELECT nivel_comprension, COUNT(*)::int as c
    FROM public.quiz_respuestas
    WHERE intento_id = '${intentoId}'
    GROUP BY nivel_comprension
    ORDER BY nivel_comprension;
  `);
  assertEquals(niveles.rows, [
    { nivel_comprension: 'critico_reflexivo', c: 1 },
    { nivel_comprension: 'inferencial', c: 2 },
    { nivel_comprension: 'literal', c: 2 },
  ]);

  // 7. Responder pregunta 1 (Correcta)
  console.log('--- 7. Respondiendo pregunta 1 (correcta) ---');
  const r1 = await db.query<{ responder_pregunta_segura: any }>(`
    SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 1::smallint, 0::smallint, '${estudianteA}'::uuid);
  `);
  const data1 = r1.rows[0].responder_pregunta_segura;
  assertEquals(data1.numero, 1);
  assertEquals(data1.esCorrecta, true);
  assertEquals(data1.quizFinalizado, false);
  assertEquals(data1.nivelComprension, 'literal');

  // 8. Responder pregunta 2 (Incorrecta)
  console.log('--- 8. Respondiendo pregunta 2 (incorrecta) ---');
  const r2 = await db.query<{ responder_pregunta_segura: any }>(`
    SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 2::smallint, 3::smallint, '${estudianteA}'::uuid);
  `);
  const data2 = r2.rows[0].responder_pregunta_segura;
  assertEquals(data2.numero, 2);
  assertEquals(data2.esCorrecta, false);
  assertEquals(data2.indiceCorrecto, 1);
  assertEquals(data2.quizFinalizado, false);

  // 9. Verificar IDEMPOTENCIA: reenvío de pregunta 1 con la misma opción
  console.log('--- 9. Probando idempotencia ante reenvío idéntico ---');
  const r1Reenvio = await db.query<{ responder_pregunta_segura: any }>(`
    SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 1::smallint, 0::smallint, '${estudianteA}'::uuid);
  `);
  assertEquals(r1Reenvio.rows[0].responder_pregunta_segura.esCorrecta, true);

  // 10. Verificar INMUTABILIDAD: intento de cambiar respuesta confirmada
  console.log('--- 10. Probando inmutabilidad ante intento de modificación ---');
  await assertRejects(
    async () => {
      await db.query(`
        SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 1::smallint, 2::smallint, '${estudianteA}'::uuid);
      `);
    },
    Error,
    'Respuesta ya confirmada y no modificable'
  );

  // 11. Verificar SEGURIDAD Y AUTORIZACIÓN: intento de responder por otro estudiante
  console.log('--- 11. Probando rechazo de autorización con otro estudiante ---');
  await assertRejects(
    async () => {
      await db.query(`
        SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 3::smallint, 1::smallint, '${estudianteB}'::uuid);
      `);
    },
    Error,
    'Intento no autorizado'
  );

  // 12. Verificar SECUENCIALIDAD: no se puede saltar a la pregunta 5 sin contestar la 3
  console.log('--- 12. Probando validación de orden secuencial ---');
  await assertRejects(
    async () => {
      await db.query(`
        SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 5::smallint, 0::smallint, '${estudianteA}'::uuid);
      `);
    },
    Error,
    'Debe responder las preguntas anteriores'
  );

  // 13. Reanudar respondiendo pregunta 3 y pregunta 4
  console.log('--- 13. Respondiendo preguntas 3 y 4 ---');
  await db.query(`SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 3::smallint, 1::smallint, '${estudianteA}'::uuid);`);
  await db.query(`SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 4::smallint, 2::smallint, '${estudianteA}'::uuid);`);

  // Verificar que sigue en progreso
  const estadoIntermedio = await db.query<{ estado: string; puntaje: number | null }>(`
    SELECT estado, puntaje FROM public.quiz_intentos WHERE id = '${intentoId}';
  `);
  assertEquals(estadoIntermedio.rows[0].estado, 'en_progreso');
  assertEquals(estadoIntermedio.rows[0].puntaje, null);

  // 14. Responder pregunta 5 (FINAL) y comprobar cierre atómico
  console.log('--- 14. Respondiendo pregunta 5 y comprobando cierre atómico ---');
  const r5 = await db.query<{ responder_pregunta_segura: any }>(`
    SELECT public.responder_pregunta_segura('${intentoId}'::uuid, 5::smallint, 0::smallint, '${estudianteA}'::uuid);
  `);
  assertEquals(r5.rows[0].responder_pregunta_segura.quizFinalizado, true);

  const intentoFinal = await db.query<{ estado: string; puntaje: number; porcentaje: number; completed_at: string }>(`
    SELECT estado, puntaje, porcentaje, completed_at FROM public.quiz_intentos WHERE id = '${intentoId}';
  `);
  assertEquals(intentoFinal.rows[0].estado, 'completado');
  assertEquals(intentoFinal.rows[0].puntaje, 4); // Preguntas 1, 3, 4, 5 correctas; pregunta 2 errada
  assertEquals(Number(intentoFinal.rows[0].porcentaje), 80);
  assert(intentoFinal.rows[0].completed_at !== null, 'completed_at debe tener fecha');

  // 15. Verificar retrocompatibilidad con quizzes históricos (sin_clasificar)
  console.log('--- 15. Probando retrocompatibilidad con quiz histórico ---');
  const cuentoHistorico = 'cuento-historico-99';
  await db.query(`
    INSERT INTO public.cuentos (id, titulo, personaje_principal, estudiante_id) VALUES
      ('${cuentoHistorico}', 'Aventura Pasada', 'Ana', '${estudianteB}');
  `);

  const intentoHistRes = await db.query<{ id: string }>(`
    INSERT INTO public.quiz_intentos (cuento_id, estudiante_id, estado, puntaje, porcentaje, completed_at)
    VALUES ('${cuentoHistorico}', '${estudianteB}', 'completado', 5, 100, NOW())
    RETURNING id;
  `);
  const histId = intentoHistRes.rows[0].id;

  // Insertar sin especificar nivel_comprension (debe tomar DEFAULT 'sin_clasificar')
  await db.query(`
    INSERT INTO public.quiz_respuestas (intento_id, numero_pregunta, pregunta, opciones, indice_correcto, indice_seleccionado, es_correcta, explicacion)
    VALUES
      ('${histId}', 1, 'Pregunta vieja 1', '["A","B","C","D"]'::jsonb, 0, 0, true, 'Explicacion vieja 1');
  `);

  const respHist = await db.query<{ nivel_comprension: string }>(`
    SELECT nivel_comprension FROM public.quiz_respuestas WHERE intento_id = '${histId}';
  `);
  assertEquals(respHist.rows[0].nivel_comprension, 'sin_clasificar');

  // 16. Probar interacción entre responder-pregunta y enviar-quiz (cero sobrescritura)
  console.log('--- 16. Probando que enviar-quiz no pueda sobrescribir respuestas confirmadas ---');
  const cuentoId2 = 'cuento-prueba-02';
  await db.query(`
    INSERT INTO public.cuentos (id, titulo, personaje_principal, estudiante_id) VALUES
      ('${cuentoId2}', 'El Árbol Mágico', 'Milo', '${estudianteB}');
  `);

  const intentoRes2 = await db.query<{ id: string }>(`
    INSERT INTO public.quiz_intentos (cuento_id, estudiante_id, estado, total_preguntas)
    VALUES ('${cuentoId2}', '${estudianteB}', 'en_progreso', 5)
    RETURNING id;
  `);
  const intentoId2 = intentoRes2.rows[0].id;

  await db.query(`
    INSERT INTO public.quiz_respuestas (intento_id, numero_pregunta, pregunta, opciones, indice_correcto, explicacion, nivel_comprension)
    VALUES
      ('${intentoId2}', 1, 'P1', '["A","B","C","D"]'::jsonb, 2, 'Exp1', 'literal'),
      ('${intentoId2}', 2, 'P2', '["A","B","C","D"]'::jsonb, 1, 'Exp2', 'literal'),
      ('${intentoId2}', 3, 'P3', '["A","B","C","D"]'::jsonb, 0, 'Exp3', 'inferencial'),
      ('${intentoId2}', 4, 'P4', '["A","B","C","D"]'::jsonb, 3, 'Exp4', 'inferencial'),
      ('${intentoId2}', 5, 'P5', '["A","B","C","D"]'::jsonb, 0, 'Exp5', 'critico_reflexivo');
  `);

  // Confirmar pregunta 1 con opción 2 (correcta) mediante responder_pregunta_segura
  await db.query(`
    SELECT public.responder_pregunta_segura('${intentoId2}'::uuid, 1::smallint, 2::smallint, '${estudianteB}'::uuid);
  `);

  // Simular lógica de enviar-quiz: leer preguntas y verificar si detecta intento de sobrescribir P1
  const pregs = (await db.query<{ id: string; numero_pregunta: number; indice_seleccionado: number | null; indice_correcto: number }>(`
    SELECT id, numero_pregunta, indice_seleccionado, indice_correcto
    FROM public.quiz_respuestas
    WHERE intento_id = '${intentoId2}'
    ORDER BY numero_pregunta;
  `)).rows;

  assertEquals(pregs[0].indice_seleccionado, 2);
  assertEquals(pregs[1].indice_seleccionado, null);

  // Si enviar-quiz recibiera p1 con indiceSeleccionado = 0 (conflicto con el 2 ya confirmado), se detecta:
  const payloadConflicto = [
    { numero: 1, indiceSeleccionado: 0 }, // CONFLICTO: Ya confirmado con 2
    { numero: 2, indiceSeleccionado: 1 },
    { numero: 3, indiceSeleccionado: 0 },
    { numero: 4, indiceSeleccionado: 3 },
    { numero: 5, indiceSeleccionado: 0 },
  ];

  let conflictoDetectado = false;
  for (const p of pregs) {
    const resp = payloadConflicto.find((r) => r.numero === p.numero_pregunta);
    if (p.indice_seleccionado !== null && resp && resp.indiceSeleccionado !== p.indice_seleccionado) {
      conflictoDetectado = true;
      break;
    }
  }
  assertEquals(conflictoDetectado, true, 'Debe detectar y rechazar el intento de modificar P1');

  // Si enviar-quiz recibe respuestas consistentes, solo actualiza las no confirmadas (2 a 5):
  const payloadValido = [
    { numero: 1, indiceSeleccionado: 2 }, // Coincide con lo confirmado
    { numero: 2, indiceSeleccionado: 1 }, // Nueva respuesta
    { numero: 3, indiceSeleccionado: 0 }, // Nueva respuesta
    { numero: 4, indiceSeleccionado: 3 }, // Nueva respuesta
    { numero: 5, indiceSeleccionado: 0 }, // Nueva respuesta
  ];

  for (const p of pregs) {
    const resp = payloadValido.find((r) => r.numero === p.numero_pregunta)!;
    if (p.indice_seleccionado === null) {
      await db.query(`
        UPDATE public.quiz_respuestas
        SET indice_seleccionado = ${resp.indiceSeleccionado},
            es_correcta = (${resp.indiceSeleccionado} = indice_correcto)
        WHERE id = '${p.id}';
      `);
    }
  }

  // Verificar que P1 no cambió y que todas las 5 preguntas quedaron contestadas
  const respuestasPost = (await db.query<{ numero_pregunta: number; indice_seleccionado: number; es_correcta: boolean }>(`
    SELECT numero_pregunta, indice_seleccionado, es_correcta
    FROM public.quiz_respuestas
    WHERE intento_id = '${intentoId2}'
    ORDER BY numero_pregunta;
  `)).rows;

  assertEquals(respuestasPost.map(r => r.indice_seleccionado), [2, 1, 0, 3, 0]);
  assertEquals(respuestasPost.every(r => r.es_correcta === true), true);

  console.log('✅ TODAS LAS 16 PRUEBAS DE INTEGRACIÓN POSTGRESQL PASARON SATISFACTORIAMENTE.');
});

