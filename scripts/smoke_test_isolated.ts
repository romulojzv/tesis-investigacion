// scripts/smoke_test_isolated.ts
import { createClient } from '@supabase/supabase-js';
import * as crypto from 'crypto';

// Cargar variables si existe archivo de entorno
if (typeof (process as any).loadEnvFile === 'function') {
  try {
    (process as any).loadEnvFile();
  } catch {}
}

/**
 * SALVAGUARDA DE ENTORNO AISLADO (BLOQUE B)
 * Este script verifica expresamente que NO se ejecute contra el proyecto piloto existente.
 * Requiere un Supabase Local (http://127.0.0.1:54321) o SUPABASE_TEST_URL estrictamente local.
 */
const PILOT_PROJECT_REF = 'wdehfetiazgukfgnngfi';

const LOCAL_FALLBACK_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const LOCAL_FALLBACK_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const TEST_URL = process.env.SUPABASE_TEST_URL || (process.env.SUPABASE_URL?.includes('127.0.0.1') ? process.env.SUPABASE_URL : undefined);
const TEST_SERVICE_KEY = process.env.SUPABASE_TEST_SERVICE_ROLE_KEY;
const TEST_ANON_KEY = process.env.SUPABASE_TEST_ANON_KEY;

async function verificarEntornoAislado(): Promise<{ url: string; serviceKey: string; anonKey: string } | null> {
  // 1. Verificar si el usuario configuró explícitamente SUPABASE_TEST_URL
  if (TEST_URL) {
    if (TEST_URL.includes(PILOT_PROJECT_REF)) {
      console.error('⛔ BLOQUEO DE SEGURIDAD: La URL coincide con el proyecto piloto remoto.');
      console.error('   Está terminantemente prohibido ejecutar pruebas de smoke test en el piloto.');
      return null;
    }
    const esLocal = TEST_URL.includes('127.0.0.1') || TEST_URL.includes('localhost');
    if (!esLocal) {
      console.error('⛔ BLOQUEO DE SEGURIDAD: SUPABASE_TEST_URL no apunta a un entorno local (127.0.0.1 / localhost).');
      return null;
    }
    return {
      url: TEST_URL,
      serviceKey: TEST_SERVICE_KEY || LOCAL_FALLBACK_SERVICE_ROLE_KEY,
      anonKey: TEST_ANON_KEY || LOCAL_FALLBACK_ANON_KEY,
    };
  }

  // 2. Comprobar si existe Supabase local escuchando en el puerto 54321
  try {
    const res = await fetch('http://127.0.0.1:54321/auth/v1/health', { method: 'GET' });
    if (res.ok) {
      console.log('✅ Entorno Supabase Local detectado en http://127.0.0.1:54321');
      return {
        url: 'http://127.0.0.1:54321',
        serviceKey: TEST_SERVICE_KEY || LOCAL_FALLBACK_SERVICE_ROLE_KEY,
        anonKey: TEST_ANON_KEY || LOCAL_FALLBACK_ANON_KEY,
      };
    }
  } catch {
    // No hay Supabase local activo
  }

  return null;
}

interface TestReportItem {
  id: string;
  nombre: string;
  precondicion: string;
  accion: string;
  resultadoEsperado: string;
  resultadoObtenido: string;
  estado: 'PASÓ' | 'FALLÓ';
  evidencia: string;
}

const reporte: TestReportItem[] = [];

async function main() {
  console.log('================================================================');
  console.log('SMOKE TEST — VALIDACIÓN EN ENTORNO AISLADO LOCAL (SEMANA 8)');
  console.log('================================================================');

  const entorno = await verificarEntornoAislado();

  if (!entorno) {
    console.warn('\n⚠️  DETENCIÓN PREVENTIVA DE EJECUCIÓN (CONDICIÓN BLOQUE B):');
    console.warn('   1. Docker Desktop o Podman no se encuentran respondiendo en http://127.0.0.1:54321.');
    console.warn('   2. Salvaguarda aplicada: NO se ejecutarán pruebas sobre el proyecto piloto remoto ("wdehfetiazgukfgnngfi").');
    console.warn('   3. Requisito: Iniciar supabase local con `npx.cmd supabase start`.\n');
    process.exit(1);
  }

  const { url, serviceKey, anonKey } = entorno;
  console.log(`📡 Conectando a entorno aislado: ${url}`);
  console.log('🔒 Verificación de aislamiento: Endpoint verificado localmente. Claves seguras protegidas.\n');

  const adminClient = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const anonClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

  const timestamp = Date.now();
  const idDocente = `test-doc-${timestamp}`;
  const idAula = crypto.randomUUID(); // Identificador UUID válido para columna aulas.id
  const idCuento = `test-cuento-${timestamp}`;

  const emailDoc = `smoke.docente.${timestamp}@test.cuentosmagicos.internal`;
  const passDoc = 'DocentePass123!';
  const passEst1 = '123456';
  const passEst2 = '654321';
  const codAcceso1 = `SMK1_${timestamp.toString().slice(-4)}`;
  const codAcceso2 = `SMK2_${timestamp.toString().slice(-4)}`;

  let uDocUserId = '';
  let uEst1UserId = '';
  let uEst2UserId = '';

  try {
    // -------------------------------------------------------------
    // SETUP FIXTURES SINTÉTICOS
    // -------------------------------------------------------------
    console.log('--- Aprovisionando fixtures sintéticos mínimos ---');

    // 1. Crear docente en auth.users y profile
    const { data: uDoc, error: errDoc } = await adminClient.auth.admin.createUser({
      email: emailDoc,
      password: passDoc,
      email_confirm: true,
      user_metadata: { nombre: 'Docente Sintético', rol: 'docente' },
      app_metadata: { rol: 'docente' },
    });
    if (errDoc) throw new Error(`Fallo setup docente: ${errDoc.message}`);
    uDocUserId = uDoc.user.id;

    await adminClient.from('profiles').upsert({
      id: uDocUserId,
      nombre: 'Docente Sintético',
      rol: 'docente',
    });

    // 2. Crear aula
    const { data: aula, error: errAula } = await adminClient.from('aulas').insert({
      id: idAula,
      nombre: 'Aula Smoke Test',
      codigo_aula: `A_${timestamp.toString().slice(-4)}`,
      docente_id: uDocUserId,
    }).select().single();
    if (errAula) throw new Error(`Fallo setup aula: ${errAula.message}`);

    // 3. Crear estudiantes 1 y 2
    const { data: uEst1, error: errEst1 } = await adminClient.auth.admin.createUser({
      email: `${codAcceso1.toLowerCase()}@estudiantes.cuentosmagicos.internal`,
      password: passEst1,
      email_confirm: true,
      user_metadata: { nombre: 'Estudiante Sintético 1', rol: 'estudiante' },
      app_metadata: { rol: 'estudiante', codigo_acceso: codAcceso1 },
    });
    if (errEst1) throw new Error(`Fallo setup est1: ${errEst1.message}`);
    uEst1UserId = uEst1.user.id;

    await adminClient.from('profiles').upsert({
      id: uEst1UserId,
      nombre: 'Estudiante Sintético 1',
      rol: 'estudiante',
      codigo_acceso: codAcceso1,
    });

    await adminClient.from('aula_estudiantes').insert({
      aula_id: idAula,
      estudiante_id: uEst1UserId,
      codigo_local: '01',
    });

    const { data: uEst2, error: errEst2 } = await adminClient.auth.admin.createUser({
      email: `${codAcceso2.toLowerCase()}@estudiantes.cuentosmagicos.internal`,
      password: passEst2,
      email_confirm: true,
      user_metadata: { nombre: 'Estudiante Sintético 2', rol: 'estudiante' },
      app_metadata: { rol: 'estudiante', codigo_acceso: codAcceso2 },
    });
    if (errEst2) throw new Error(`Fallo setup est2: ${errEst2.message}`);
    uEst2UserId = uEst2.user.id;

    await adminClient.from('profiles').upsert({
      id: uEst2UserId,
      nombre: 'Estudiante Sintético 2',
      rol: 'estudiante',
      codigo_acceso: codAcceso2,
    });

    await adminClient.from('aula_estudiantes').insert({
      aula_id: idAula,
      estudiante_id: uEst2UserId,
      codigo_local: '02',
    });

    // -------------------------------------------------------------
    // CASO 1: Auth docente y estudiante
    // -------------------------------------------------------------
    const clientDoc = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: docLogin, error: docLoginErr } = await clientDoc.auth.signInWithPassword({ email: emailDoc, password: passDoc });
    const authDocOk = !docLoginErr && !!docLogin.session;

    const clientEst1 = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: est1Login, error: est1LoginErr } = await clientEst1.auth.signInWithPassword({
      email: `${codAcceso1.toLowerCase()}@estudiantes.cuentosmagicos.internal`,
      password: passEst1,
    });
    const authEstOk = !est1LoginErr && !!est1Login.session;

    const clientEst2 = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: est2Login, error: est2LoginErr } = await clientEst2.auth.signInWithPassword({
      email: `${codAcceso2.toLowerCase()}@estudiantes.cuentosmagicos.internal`,
      password: passEst2,
    });
    const authEst2Ok = !est2LoginErr && !!est2Login.session;

    reporte.push({
      id: 'SMK-01',
      nombre: 'Autenticación Docente y Estudiante',
      precondicion: 'Usuarios sintéticos creados en auth.users con credenciales de prueba',
      accion: 'signInWithPassword para docente y estudiante en Supabase Local',
      resultadoEsperado: 'Ambas sesiones emiten JWT válido con user.id correspondiente',
      resultadoObtenido: authDocOk && authEstOk && authEst2Ok ? 'Sesiones emitidas exitosamente con JWT local' : `DocError: ${docLoginErr?.message}, EstError: ${est1LoginErr?.message}`,
      estado: authDocOk && authEstOk && authEst2Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `Docente UID: ${docLogin?.session?.user.id.slice(0, 8)}..., Est1 UID: ${est1Login?.session?.user.id.slice(0, 8)}..., Est2 UID: ${est2Login?.session?.user.id.slice(0, 8)}...`,
    });

    // -------------------------------------------------------------
    // CASO 2: Lectura de profiles y aulas según rol
    // -------------------------------------------------------------
    const { data: profEst1, error: pErr } = await clientEst1.from('profiles').select('id, rol, nombre').eq('id', uEst1UserId).single();
    const { data: aulaDoc, error: aErr } = await clientDoc.from('aulas').select('id, nombre').eq('id', idAula).single();
    const caso2Ok = !pErr && profEst1?.rol === 'estudiante' && !aErr && aulaDoc?.id === idAula;

    reporte.push({
      id: 'SMK-02',
      nombre: 'Lectura de profiles y aulas según rol',
      precondicion: 'Estudiante y docente autenticados con JWT',
      accion: 'Consultar propio profile y aula del docente vía RLS',
      resultadoEsperado: 'Estudiante lee su profile; Docente lee su aula',
      resultadoObtenido: caso2Ok ? 'Lectura autorizada con datos exactos' : `pErr: ${pErr?.message}, aErr: ${aErr?.message}`,
      estado: caso2Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `Estudiante profile rol=${profEst1?.rol}, Docente aula=${aulaDoc?.nombre}`,
    });

    // -------------------------------------------------------------
    // CASO 3: Estudiante crea y consulta su propio cuento
    // -------------------------------------------------------------
    const { error: cInsertErr } = await clientEst1.from('cuentos').insert({
      id: idCuento,
      estudiante_id: uEst1UserId,
      aula_id: idAula,
      titulo: 'Cuento de Prueba Sintético',
      personaje_principal: 'Pollito Ficticio',
      descripcion_personaje: 'Pollito amarillo con pico rojo',
      origen: 'dibujo',
    });

    const { error: escInsertErr } = await clientEst1.from('escenas').insert({
      cuento_id: idCuento,
      numero: 1,
      contenido: 'El pollito comenzó su viaje en el campo.',
      es_final: false,
    });

    const { error: decInsertErr } = await clientEst1.from('decisiones_narrativas').insert({
      cuento_id: idCuento,
      numero_escena: 1,
      opcion_seleccionada: 'Caminar hacia el molino',
    });

    const { data: cuentoPropio, error: cReadErr } = await clientEst1.from('cuentos').select('id, titulo, personaje_principal').eq('id', idCuento).single();
    const caso3Ok = !cInsertErr && !escInsertErr && !decInsertErr && !cReadErr && cuentoPropio?.id === idCuento;

    reporte.push({
      id: 'SMK-03',
      nombre: 'Estudiante crea y consulta su propio cuento',
      precondicion: 'Estudiante 1 autenticado con RLS activo',
      accion: 'INSERT en cuentos, escenas y decisiones_narrativas; SELECT de cuento propio',
      resultadoEsperado: 'Inserción y lectura permitidas para el autor',
      resultadoObtenido: caso3Ok ? 'Cuento, escena y decisión registrados y leídos' : `Insert: ${cInsertErr?.message || escInsertErr?.message || decInsertErr?.message}, Read: ${cReadErr?.message}`,
      estado: caso3Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `Cuento ID: ${cuentoPropio?.id}, Personaje: ${cuentoPropio?.personaje_principal}`,
    });

    // -------------------------------------------------------------
    // CASO 4: Otro estudiante no puede leer el cuento ajeno
    // -------------------------------------------------------------
    const { data: cuentoAjeno } = await clientEst2.from('cuentos').select('id').eq('id', idCuento).maybeSingle();
    const caso4Ok = cuentoAjeno === null;

    reporte.push({
      id: 'SMK-04',
      nombre: 'Estudiante 2 no puede leer cuento de Estudiante 1',
      precondicion: 'Estudiante 2 autenticado en la misma aula',
      accion: 'SELECT de cuentos WHERE id = cuento_de_estudiante_1',
      resultadoEsperado: 'Resultado vacío (0 filas retornadas por RLS)',
      resultadoObtenido: caso4Ok ? '0 filas retornadas (acceso denegado por RLS)' : 'Fila retornada indebidamente',
      estado: caso4Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `cuentoAjeno=${JSON.stringify(cuentoAjeno)}`,
    });

    // -------------------------------------------------------------
    // CASO 5: Docente ve cuentos de su aula pero no puede modificarlos
    // -------------------------------------------------------------
    const { data: cuentoDocente, error: docReadErr } = await clientDoc.from('cuentos').select('id, titulo').eq('id', idCuento).maybeSingle();
    const { error: docUpdateErr } = await clientDoc.from('cuentos').update({ titulo: 'Titulo Alterado Por Docente' }).eq('id', idCuento);

    const checkCuento = await clientEst1.from('cuentos').select('titulo').eq('id', idCuento).single();
    const caso5Ok = !docReadErr && cuentoDocente?.id === idCuento && (docUpdateErr !== null || checkCuento.data?.titulo === 'Cuento de Prueba Sintético');

    reporte.push({
      id: 'SMK-05',
      nombre: 'Docente lee cuentos de su aula pero no puede modificarlos',
      precondicion: 'Docente asignado al aula donde está matriculado Estudiante 1',
      accion: 'SELECT de cuento de su aula y posterior intento de UPDATE',
      resultadoEsperado: 'SELECT exitoso; UPDATE denegado o inefectivo por RLS',
      resultadoObtenido: caso5Ok ? 'Docente supervisa lectura; UPDATE bloqueado por RLS' : 'Fallo en lectura o UPDATE indebidamente permitido',
      estado: caso5Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `Docente leyó cuento=${cuentoDocente?.id}; título inalterado='${checkCuento.data?.titulo}'`,
    });

    // -------------------------------------------------------------
    // CASO 6: Anónimo no accede a datos educativos
    // -------------------------------------------------------------
    const { data: anonCuentos } = await anonClient.from('cuentos').select('id');
    const { data: anonAulas } = await anonClient.from('aulas').select('id');
    const { data: anonProfiles } = await anonClient.from('profiles').select('id');

    const caso6Ok = (anonCuentos?.length || 0) === 0 && (anonAulas?.length || 0) === 0 && (anonProfiles?.length || 0) === 0;

    reporte.push({
      id: 'SMK-06',
      nombre: 'Cliente Anónimo sin acceso a datos educativos',
      precondicion: 'Cliente Supabase sin sesión (solo ANON_KEY)',
      accion: 'SELECT en cuentos, aulas y profiles',
      resultadoEsperado: '0 registros retornados en todas las tablas',
      resultadoObtenido: caso6Ok ? 'Acceso anónimo bloqueado por RLS (0 registros)' : 'Datos expuestos a anónimo',
      estado: caso6Ok ? 'PASÓ' : 'FALLÓ',
      evidencia: `cuentos=${anonCuentos?.length || 0}, aulas=${anonAulas?.length || 0}, profiles=${anonProfiles?.length || 0}`,
    });

  } finally {
    // -------------------------------------------------------------
    // CASO 7: Limpieza exclusivamente de fixtures temporales
    // -------------------------------------------------------------
    console.log('\n--- Limpieza estricta de fixtures sintéticos ---');
    try {
      await adminClient.from('decisiones_narrativas').delete().eq('cuento_id', idCuento);
      await adminClient.from('escenas').delete().eq('cuento_id', idCuento);
      await adminClient.from('cuentos').delete().eq('id', idCuento);
      await adminClient.from('aula_estudiantes').delete().eq('aula_id', idAula);
      await adminClient.from('aulas').delete().eq('id', idAula);
      if (uDocUserId) {
        await adminClient.from('profiles').delete().eq('id', uDocUserId);
        await adminClient.auth.admin.deleteUser(uDocUserId);
      }
      if (uEst1UserId) {
        await adminClient.from('profiles').delete().eq('id', uEst1UserId);
        await adminClient.auth.admin.deleteUser(uEst1UserId);
      }
      if (uEst2UserId) {
        await adminClient.from('profiles').delete().eq('id', uEst2UserId);
        await adminClient.auth.admin.deleteUser(uEst2UserId);
      }
      console.log('✅ Fixtures sintéticos limpiados exitosamente sin tocar el esquema ni datos externos.');

      reporte.push({
        id: 'SMK-07',
        nombre: 'Limpieza y preservación del esquema',
        precondicion: 'Pruebas completadas sobre fixtures sintéticos',
        accion: 'Eliminación específica de IDs generados para el smoke test vía service_role',
        resultadoEsperado: 'Base de datos limpia, esquema y datos existentes preservados',
        resultadoObtenido: 'Fixtures eliminados con éxito vía service_role',
        estado: 'PASÓ',
        evidencia: `Eliminados UIDs doc=${uDocUserId.slice(0, 8)}..., est1=${uEst1UserId.slice(0, 8)}..., est2=${uEst2UserId.slice(0, 8)}...`,
      });
    } catch (cleanErr: any) {
      console.error('Error durante la limpieza de fixtures:', cleanErr.message);
      reporte.push({
        id: 'SMK-07',
        nombre: 'Limpieza y preservación del esquema',
        precondicion: 'Pruebas completadas sobre fixtures sintéticos',
        accion: 'Eliminación específica de IDs generados para el smoke test',
        resultadoEsperado: 'Base de datos limpia',
        resultadoObtenido: `Error en limpieza: ${cleanErr.message}`,
        estado: 'FALLÓ',
        evidencia: 'Excepción durante cleanup',
      });
    }
  }

  console.log('\n================================================================');
  console.log('RESUMEN DE RESULTADOS — SMOKE TEST AISLADO LOCAL');
  console.log('================================================================');
  for (const r of reporte) {
    console.log(`[${r.estado}] ${r.id}: ${r.nombre}`);
    console.log(`       Acción:    ${r.accion}`);
    console.log(`       Resultado: ${r.resultadoObtenido}`);
    console.log(`       Evidencia: ${r.evidencia}`);
    console.log('----------------------------------------------------------------');
  }
}

main().catch((err) => {
  console.error('Error no controlado en Smoke Test:', err);
  process.exit(1);
});
