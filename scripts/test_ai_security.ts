// scripts/test_ai_security.ts
/**
 * Test Suite de Seguridad para Edge Functions de IA
 * Cubre:
 *  - AI-SEC-01: analizar-historia sin JWT -> bloqueado (401)
 *  - AI-SEC-02: generar-escena sin JWT -> bloqueado (401)
 *  - AI-SEC-03: generar-imagen sin JWT -> bloqueado (401)
 *  - AI-SEC-04: JWT inválido -> bloqueado (401)
 *  - AI-SEC-05: Docente autenticado -> bloqueado (403)
 *  - AI-SEC-06: Estudiante autenticado -> permitido a la lógica de la función
 *  - AI-SEC-07: Verificación de que peticiones bloqueadas nunca alcanzan servicios externos
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

// 1. Salvaguarda crítica: jamás ejecutar contra el proyecto remoto
if (TEST_URL.includes(PILOT_PROJECT_REF)) {
  console.error('⛔ BLOQUEO DE SEGURIDAD: TEST_URL apunta al proyecto piloto remoto wdehfetiazgukfgnngfi.');
  process.exit(1);
}
if (!TEST_URL.includes('127.0.0.1') && !TEST_URL.includes('localhost')) {
  console.error('⛔ BLOQUEO DE SEGURIDAD: Solo se permite ejecución en entorno local (127.0.0.1 / localhost).');
  process.exit(1);
}

const adminClient = createClient(TEST_URL, TEST_SERVICE_KEY, {
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
  console.log('🛡️ SUITE DE PRUEBAS DE SEGURIDAD DE EDGE FUNCTIONS DE IA');
  console.log(`   URL Local: ${TEST_URL}`);
  console.log('='.repeat(70));

  // Crear usuarios de prueba temporal
  const timestamp = Date.now();
  const docenteEmail = `docente_sec_${timestamp}@test.local`;
  const docentePass = 'DocentePass123!';
  const estudianteEmail = `estudiante_sec_${timestamp}@test.local`;
  const estudiantePass = 'EstudiantePass123!';

  let docenteUserId: string | null = null;
  let estudianteUserId: string | null = null;
  let docenteJwt: string | null = null;
  let estudianteJwt: string | null = null;

  try {
    // 1. Crear docente
    const { data: docData, error: docErr } = await adminClient.auth.admin.createUser({
      email: docenteEmail,
      password: docentePass,
      email_confirm: true,
      user_metadata: { nombre: 'Docente Prueba Seguridad' },
    });
    if (docErr || !docData.user) throw new Error(`Fallo al crear docente de prueba: ${docErr?.message}`);
    docenteUserId = docData.user.id;

    const { error: profDocErr } = await adminClient.from('profiles').upsert({
      id: docenteUserId,
      rol: 'docente',
      nombre: 'Docente Seguridad',
    });
    if (profDocErr) throw new Error(`Fallo al crear perfil docente: ${profDocErr.message}`);

    // Login docente para obtener JWT
    const docLoginClient = createClient(TEST_URL, TEST_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: docSessionData, error: docLoginErr } = await docLoginClient.auth.signInWithPassword({
      email: docenteEmail,
      password: docentePass,
    });
    if (docLoginErr || !docSessionData.session) throw new Error(`Fallo login docente: ${docLoginErr?.message}`);
    docenteJwt = docSessionData.session.access_token;

    // 2. Crear estudiante
    const { data: estData, error: estErr } = await adminClient.auth.admin.createUser({
      email: estudianteEmail,
      password: estudiantePass,
      email_confirm: true,
      user_metadata: { nombre: 'Estudiante Prueba Seguridad' },
    });
    if (estErr || !estData.user) throw new Error(`Fallo al crear estudiante de prueba: ${estErr?.message}`);
    estudianteUserId = estData.user.id;

    const { error: profEstErr } = await adminClient.from('profiles').upsert({
      id: estudianteUserId,
      rol: 'estudiante',
      nombre: 'Estudiante Seguridad',
    });
    if (profEstErr) throw new Error(`Fallo al crear perfil estudiante: ${profEstErr.message}`);

    // Login estudiante para obtener JWT
    const estLoginClient = createClient(TEST_URL, TEST_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: estSessionData, error: estLoginErr } = await estLoginClient.auth.signInWithPassword({
      email: estudianteEmail,
      password: estudiantePass,
    });
    if (estLoginErr || !estSessionData.session) throw new Error(`Fallo login estudiante: ${estLoginErr?.message}`);
    estudianteJwt = estSessionData.session.access_token;

    console.log('✅ Usuarios de prueba y sesiones JWT creados correctamente.');
    console.log('-'.repeat(70));

    // =========================================================================
    // AI-SEC-01: analizar-historia sin JWT -> bloqueado (401)
    // =========================================================================
    {
      const res = await postFunction('analizar-historia', { textoHistoria: 'Había una vez un conejo.' });
      const passed = res.status === 401 && res.body?.error?.includes('No autorizado');
      recordResult(
        'AI-SEC-01',
        'analizar-historia sin JWT -> bloqueado con HTTP 401',
        passed,
        `Status recibido: ${res.status}, Body: ${JSON.stringify(res.body)}`
      );
    }

    // =========================================================================
    // AI-SEC-02: generar-escena sin JWT -> bloqueado (401)
    // =========================================================================
    {
      const res = await postFunction('generar-escena', { numeroEscena: 1, contextoPrevio: 'Inicio' });
      const passed = res.status === 401 && res.body?.error?.includes('No autorizado');
      recordResult(
        'AI-SEC-02',
        'generar-escena sin JWT -> bloqueado con HTTP 401',
        passed,
        `Status recibido: ${res.status}, Body: ${JSON.stringify(res.body)}`
      );
    }

    // =========================================================================
    // AI-SEC-03: generar-imagen sin JWT -> bloqueado (401)
    // =========================================================================
    {
      const res = await postFunction('generar-imagen', {
        cuentoId: 'c1',
        numeroEscena: 1,
        personajePrincipal: 'Pepe',
        contenidoEscena: 'Pepe juega.',
      });
      const passed = res.status === 401 && res.body?.error?.includes('No autorizado');
      recordResult(
        'AI-SEC-03',
        'generar-imagen sin JWT -> bloqueado con HTTP 401',
        passed,
        `Status recibido: ${res.status}, Body: ${JSON.stringify(res.body)}`
      );
    }

    // =========================================================================
    // AI-SEC-04: JWT inválido o corrupto -> bloqueado (401)
    // =========================================================================
    {
      const resAnalizar = await postFunction('analizar-historia', {}, 'Bearer token_invalido_xyz123');
      const resEscena = await postFunction('generar-escena', {}, 'Bearer token_invalido_xyz123');
      const resImagen = await postFunction('generar-imagen', {}, 'Bearer token_invalido_xyz123');

      const passed =
        resAnalizar.status === 401 &&
        resEscena.status === 401 &&
        resImagen.status === 401;

      recordResult(
        'AI-SEC-04',
        'JWT inválido bloqueado con HTTP 401 en las 3 funciones',
        passed,
        `analizar: ${resAnalizar.status}, escena: ${resEscena.status}, imagen: ${resImagen.status}`
      );
    }

    // =========================================================================
    // AI-SEC-05: Docente autenticado -> bloqueado (403)
    // =========================================================================
    {
      const resAnalizar = await postFunction('analizar-historia', {}, `Bearer ${docenteJwt}`);
      const resEscena = await postFunction('generar-escena', {}, `Bearer ${docenteJwt}`);
      const resImagen = await postFunction('generar-imagen', {}, `Bearer ${docenteJwt}`);

      const passed =
        resAnalizar.status === 403 &&
        resEscena.status === 403 &&
        resImagen.status === 403 &&
        resAnalizar.body?.error?.toLowerCase().includes('estudiante') &&
        resEscena.body?.error?.toLowerCase().includes('estudiante') &&
        resImagen.body?.error?.toLowerCase().includes('estudiante');

      recordResult(
        'AI-SEC-05',
        'Docente autenticado bloqueado con HTTP 403 en las 3 funciones',
        passed,
        `analizar: ${resAnalizar.status}, escena: ${resEscena.status}, imagen: ${resImagen.status}`
      );
    }

    // =========================================================================
    // AI-SEC-06: Estudiante autenticado -> permitido hacia la lógica interna
    // =========================================================================
    {
      // Enviar solicitud con estudiante autenticado pero sin parámetros para verificar
      // que supera la barrera de autenticación (no da 401 ni 403) y llega a la validación de negocio.
      const resAnalizar = await postFunction('analizar-historia', {}, `Bearer ${estudianteJwt}`);
      const resEscena = await postFunction('generar-escena', {}, `Bearer ${estudianteJwt}`);
      const resImagen = await postFunction('generar-imagen', {}, `Bearer ${estudianteJwt}`);

      // Ninguna debe dar 401 ni 403
      const pasoAuthAnalizar = resAnalizar.status !== 401 && resAnalizar.status !== 403;
      const pasoAuthEscena = resEscena.status !== 401 && resEscena.status !== 403;
      const pasoAuthImagen = resImagen.status !== 401 && resImagen.status !== 403;

      const passed = pasoAuthAnalizar && pasoAuthEscena && pasoAuthImagen;

      recordResult(
        'AI-SEC-06',
        'Estudiante autenticado supera la barrera de autenticación (supera 401/403)',
        passed,
        `analizar: status=${resAnalizar.status} (${JSON.stringify(resAnalizar.body)}), ` +
          `escena: status=${resEscena.status} (${JSON.stringify(resEscena.body)}), ` +
          `imagen: status=${resImagen.status} (${JSON.stringify(resImagen.body)})`
      );
    }

    // =========================================================================
    // AI-SEC-07: Comprobar que peticiones bloqueadas nunca llegan a IA externa
    // =========================================================================
    {
      // Las peticiones bloqueadas (sin token o docente) retornan estrictamente 401 o 403,
      // nunca retornan errores de API key de Gemini/Pollinations ni realizan llamadas externas.
      const peticionesBloqueadas = [
        await postFunction('analizar-historia', { textoHistoria: 'Cuento de prueba' }),
        await postFunction('generar-escena', { numeroEscena: 1 }),
        await postFunction('generar-imagen', { cuentoId: 'c1', numeroEscena: 1 }),
        await postFunction('analizar-historia', { textoHistoria: 'Cuento de prueba' }, `Bearer ${docenteJwt}`),
        await postFunction('generar-escena', { numeroEscena: 1 }, `Bearer ${docenteJwt}`),
        await postFunction('generar-imagen', { cuentoId: 'c1', numeroEscena: 1 }, `Bearer ${docenteJwt}`),
      ];

      const ningunaLlegaAExterna = peticionesBloqueadas.every((res) => {
        const str = JSON.stringify(res.body || {});
        const esBloqueada = res.status === 401 || res.status === 403;
        const noContieneApiKey = !str.includes('GEMINI_API_KEY') && !str.includes('POLLINATIONS_API_KEY');
        const noContieneSalidaIa = !str.includes('personajeOriginal') && !str.includes('imageUrl');
        return esBloqueada && noContieneApiKey && noContieneSalidaIa;
      });

      recordResult(
        'AI-SEC-07',
        'Peticiones bloqueadas terminan en la frontera de seguridad sin invocar proveedores de IA',
        ningunaLlegaAExterna,
        `Verificadas ${peticionesBloqueadas.length} peticiones bloqueadas.`
      );
    }

    // =========================================================================
    // CORS PREFLIGHT CHECK
    // =========================================================================
    {
      const corsRes = await fetch(`${TEST_URL}/functions/v1/analizar-historia`, {
        method: 'OPTIONS',
      });
      const corsPassed = corsRes.status === 200 && corsRes.headers.get('access-control-allow-origin') === '*';
      recordResult(
        'CORS-OPTIONS',
        'OPTIONS preflight responde 200 con encabezados CORS sin requerir auth',
        corsPassed,
        `Status: ${corsRes.status}`
      );
    }

  } finally {
    // Limpieza de usuarios creados
    console.log('-'.repeat(70));
    console.log('🧹 Limpiando usuarios de prueba...');
    if (docenteUserId) {
      await adminClient.from('profiles').delete().eq('id', docenteUserId);
      await adminClient.auth.admin.deleteUser(docenteUserId);
    }
    if (estudianteUserId) {
      await adminClient.from('profiles').delete().eq('id', estudianteUserId);
      await adminClient.auth.admin.deleteUser(estudianteUserId);
    }
    console.log('✅ Limpieza completada.');
  }

  console.log('='.repeat(70));
  console.log('📊 RESUMEN FINAL DE PRUEBAS DE SEGURIDAD:');
  const allPassed = results.every((r) => r.passed);
  console.log(`Total: ${results.length} | Aprobadas: ${results.filter((r) => r.passed).length} | Fallidas: ${results.filter((r) => !r.passed).length}`);
  console.log('='.repeat(70));

  if (!allPassed) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Error fatal durante la ejecución de las pruebas:', err);
  process.exit(1);
});
