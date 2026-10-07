// scripts/test_auth_rls.ts
import { createClient } from '@supabase/supabase-js';

if (typeof (process as any).loadEnvFile === 'function') {
  try {
    (process as any).loadEnvFile();
  } catch {}
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
  console.error('ERROR: Faltan variables SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY o SUPABASE_ANON_KEY.');
  process.exit(1);
}

// 1. Cliente Admin (para aprovisionar y limpiar con service_role)
const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// 2. Cliente Anónimo
const anonClient = createClient(SUPABASE_URL, ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Helper para crear cliente autenticado con credenciales de usuario
async function crearClienteUsuario(email: string, pass: string) {
  const client = createClient(SUPABASE_URL!, ANON_KEY!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email, password: pass });
  if (error || !data.session) throw new Error(`Fallo de login para ${email}: ${error?.message}`);
  return { client, user: data.user };
}

function expect(condition: boolean, testName: string) {
  if (!condition) {
    console.error(`❌ FALLÓ: ${testName}`);
    throw new Error(`Test fallido: ${testName}`);
  }
  console.log(`✅ PASÓ: ${testName}`);
}

async function runTests() {
  console.log('🚀 INICIANDO SUITE DE TESTS RLS CON USUARIOS REALES DE AUTH...');

  const passDoc = 'DocenteSecurePass2026!';
  const passEst = '482910';

  const emailDocA = `test.doc.a.${Date.now()}@cuentosmagicos.internal`;
  const emailDocB = `test.doc.b.${Date.now()}@cuentosmagicos.internal`;
  const emailEstA = `test.est.a.${Date.now()}@estudiantes.cuentosmagicos.internal`;
  const emailEstB = `test.est.b.${Date.now()}@estudiantes.cuentosmagicos.internal`;

  let userDocAId = '', userDocBId = '', userEstAId = '', userEstBId = '';
  let aulaAId = '', aulaBId = '';
  const cuentoAId = `cuento-test-${Date.now()}`;

  try {
    // ------------------------------------------------------------------------
    // FASE 1: APROVISIONAMIENTO CONTROLADO
    // ------------------------------------------------------------------------
    console.log('📦 Aprovisionando 4 usuarios reales...');
    const { data: uDocA } = await adminClient.auth.admin.createUser({
      email: emailDocA, password: passDoc, email_confirm: true,
      app_metadata: { rol: 'docente' }, user_metadata: { nombre: 'Docente A' },
    });
    userDocAId = uDocA.user!.id;

    const { data: uDocB } = await adminClient.auth.admin.createUser({
      email: emailDocB, password: passDoc, email_confirm: true,
      app_metadata: { rol: 'docente' }, user_metadata: { nombre: 'Docente B' },
    });
    userDocBId = uDocB.user!.id;

    const { data: uEstA } = await adminClient.auth.admin.createUser({
      email: emailEstA, password: passEst, email_confirm: true,
      app_metadata: { rol: 'estudiante', codigo_acceso: `4A-${Date.now().toString().slice(-4)}` },
      user_metadata: { nombre: 'Estudiante A' },
    });
    userEstAId = uEstA.user!.id;

    const { data: uEstB } = await adminClient.auth.admin.createUser({
      email: emailEstB, password: passEst, email_confirm: true,
      app_metadata: { rol: 'estudiante', codigo_acceso: `4B-${Date.now().toString().slice(-4)}` },
      user_metadata: { nombre: 'Estudiante B' },
    });
    userEstBId = uEstB.user!.id;

    // Conectar clientes autenticados
    const { client: clientDocA } = await crearClienteUsuario(emailDocA, passDoc);
    const { client: clientDocB } = await crearClienteUsuario(emailDocB, passDoc);
    const { client: clientEstA } = await crearClienteUsuario(emailEstA, passEst);
    const { client: clientEstB } = await crearClienteUsuario(emailEstB, passEst);

    // ------------------------------------------------------------------------
    // FASE 2: VERIFICACIÓN ANON (TABLAS PROTEGIDAS)
    // ------------------------------------------------------------------------
    console.log('\n--- PRUEBAS: ANON ---');
    const { data: anonProfiles, error: errAnonProf } = await anonClient.from('profiles').select('*');
    expect(!!errAnonProf || !anonProfiles || anonProfiles.length === 0, 'Anon no tiene acceso a tabla profiles');

    const { data: anonAulas, error: errAnonAulas } = await anonClient.from('aulas').select('*');
    expect(!!errAnonAulas || !anonAulas || anonAulas.length === 0, 'Anon no tiene acceso a tabla aulas');

    // ------------------------------------------------------------------------
    // FASE 3: VERIFICACIÓN DOCENTE Y MATRÍCULAS
    // ------------------------------------------------------------------------
    console.log('\n--- PRUEBAS: DOCENTE A Y AULAS ---');
    const { data: aulaACreada, error: errAulaA } = await clientDocA.from('aulas').insert({
      nombre: 'Aula 4A',
      codigo_aula: `4A-${Date.now().toString().slice(-4)}`,
      docente_id: userDocAId,
    }).select().single();
    expect(!errAulaA && !!aulaACreada, 'Docente A crea aula legítimamente');
    aulaAId = aulaACreada.id;

    const { data: aulaBCreada } = await clientDocB.from('aulas').insert({
      nombre: 'Aula 4B',
      codigo_aula: `4B-${Date.now().toString().slice(-4)}`,
      docente_id: userDocBId,
    }).select().single();
    aulaBId = aulaBCreada.id;

    // Anti-matrícula de docentes: Docente A no puede matricular a Docente B
    const { error: errMatDocenteB } = await clientDocA.from('aula_estudiantes').insert({
      aula_id: aulaAId,
      estudiante_id: userDocBId,
      codigo_local: '99',
    });
    expect(!!errMatDocenteB, 'Docente A es bloqueado al intentar matricular a Docente B (exige rol estudiante)');

    // Anti-auto-matrícula: Docente A no puede auto-matricularse
    const { error: errAutoMat } = await clientDocA.from('aula_estudiantes').insert({
      aula_id: aulaAId,
      estudiante_id: userDocAId,
      codigo_local: '00',
    });
    expect(!!errAutoMat, 'Docente A es bloqueado al intentar auto-matricularse');

    // Docente A matricula legítimamente a Estudiante A
    const { error: errMatriculaA } = await clientDocA.from('aula_estudiantes').insert({
      aula_id: aulaAId,
      estudiante_id: userEstAId,
      codigo_local: '01',
    });
    expect(!errMatriculaA, 'Docente A matricula con éxito a Estudiante A');

    // Docente B matricula a Estudiante B
    await clientDocB.from('aula_estudiantes').insert({
      aula_id: aulaBId,
      estudiante_id: userEstBId,
      codigo_local: '01',
    });

    // Aislamiento entre docentes: Docente A no ve aula B ni alumnos de B
    const { data: aulasDocA } = await clientDocA.from('aulas').select('*').eq('id', aulaBId);
    expect(!aulasDocA || aulasDocA.length === 0, 'Docente A no puede ver el aula de Docente B');

    // ------------------------------------------------------------------------
    // FASE 4: VERIFICACIÓN ANTI-RECURSIÓN Y ACCESO ESTUDIANTE
    // ------------------------------------------------------------------------
    console.log('\n--- PRUEBAS: ESTUDIANTE Y ANTI-RECURSIÓN 42P17 ---');
    // Estudiante A lee su aula sin error de recursión 42P17
    const { data: aulaEstA, error: errAulaEstA } = await clientEstA.from('aulas').select('*').eq('id', aulaAId);
    expect(!errAulaEstA && aulaEstA?.length === 1, 'Estudiante A lee su aula sin error de recursión 42P17');

    // Estudiante A lee su matrícula sin recursión
    const { data: matEstA, error: errMatEstA } = await clientEstA.from('aula_estudiantes').select('*').eq('aula_id', aulaAId);
    expect(!errMatEstA && matEstA?.length === 1, 'Estudiante A lee su matrícula sin error de recursión 42P17');

    // Estudiante A no ve perfil de Estudiante B
    const { data: profEstBDesdeA } = await clientEstA.from('profiles').select('*').eq('id', userEstBId);
    expect(!profEstBDesdeA || profEstBDesdeA.length === 0, 'Estudiante A no puede leer perfil de Estudiante B');

    // Estudiante A no puede crear aulas
    const { error: errCrearAulaEst } = await clientEstA.from('aulas').insert({
      nombre: 'Aula Hack',
      codigo_aula: 'HACK',
      docente_id: userEstAId,
    });
    expect(!!errCrearAulaEst, 'Estudiante A no puede crear aulas');

    // ------------------------------------------------------------------------
    // FASE 5: CREACIÓN DE CUENTOS Y PROTECCIÓN CONTRA MUTACIÓN DOCENTE
    // ------------------------------------------------------------------------
    console.log('\n--- PRUEBAS: CUENTOS Y PERMISOS ---');
    // Docente A no puede crear cuentos
    const { error: errDocCreaCuento } = await clientDocA.from('cuentos').insert({
      id: `cuento-doc-${Date.now()}`,
      titulo: 'Cuento Profe',
      personaje_principal: 'Profe',
      origen: 'dibujo',
      estudiante_id: userDocAId,
      aula_id: aulaAId,
    });
    expect(!!errDocCreaCuento, 'Docente A es bloqueado al intentar crear cuentos (exige rol estudiante)');

    // Estudiante A crea su cuento
    const { error: errCrearCuento } = await clientEstA.from('cuentos').insert({
      id: cuentoAId,
      titulo: 'El Dragón Amigo',
      personaje_principal: 'Dragón',
      origen: 'dibujo',
      estudiante_id: userEstAId,
      aula_id: aulaAId,
    });
    expect(!errCrearCuento, 'Estudiante A crea cuento en su aula');

    // Estudiante B no puede ver el cuento de Estudiante A
    const { data: cuentosDesdeB } = await clientEstB.from('cuentos').select('*').eq('id', cuentoAId);
    expect(!cuentosDesdeB || cuentosDesdeB.length === 0, 'Aislamiento: Estudiante B no puede ver cuento de Estudiante A');

    // Docente A puede auditar el cuento de Estudiante A
    const { data: cuentoVistoPorDocA } = await clientDocA.from('cuentos').select('*').eq('id', cuentoAId);
    expect(cuentoVistoPorDocA?.length === 1, 'Docente A puede leer y auditar el cuento de su alumno');

    // Docente A intenta modificar el cuento del alumno (Debe fallar o afectar 0 filas)
    const { data: updateDocRes, error: errModCuentoDoc } = await clientDocA
      .from('cuentos')
      .update({ titulo: 'Titulo Alterado Por Docente' })
      .eq('id', cuentoAId)
      .select();

    // Verificación estricta: o arrojó error de política, o afectó 0 filas
    const mutacionRechazada = !!errModCuentoDoc || (!updateDocRes || updateDocRes.length === 0);
    expect(mutacionRechazada, 'Docente A no puede modificar el cuento del alumno');

    // Confirmación de inmutabilidad: el título original sigue intacto
    const { data: cuentoVerificado } = await adminClient.from('cuentos').select('titulo').eq('id', cuentoAId).single();
    expect(cuentoVerificado?.titulo === 'El Dragón Amigo', 'El contenido del cuento del alumno permanece intacto');

    // ------------------------------------------------------------------------
    // FASE 6: PREVENCIÓN DE ESCALACIÓN DE PRIVILEGIOS
    // ------------------------------------------------------------------------
    console.log('\n--- PRUEBAS: ESCALACIÓN DE PRIVILEGIOS ---');
    const { error: errEscalarRol } = await clientEstA.from('profiles').update({ rol: 'docente' }).eq('id', userEstAId);
    expect(!!errEscalarRol, 'Estudiante no puede alterar su rol (trigger lo rechaza)');

    const { error: errAlterarCod } = await clientEstA.from('profiles').update({ codigo_acceso: 'HACK-000' }).eq('id', userEstAId);
    expect(!!errAlterarCod, 'Estudiante no puede alterar su código de acceso (trigger lo rechaza)');

    console.log('\n🎉 TODOS LOS CASOS DE SEGURIDAD, AISLAMIENTO Y ANTI-RECURSIÓN SUPERADOS.');
  } finally {
    console.log('\n🧹 Limpiando identidades y datos de prueba...');
    if (cuentoAId) await adminClient.from('cuentos').delete().eq('id', cuentoAId);
    if (aulaAId) await adminClient.from('aulas').delete().eq('id', aulaAId);
    if (aulaBId) await adminClient.from('aulas').delete().eq('id', aulaBId);
    if (userDocAId) await adminClient.auth.admin.deleteUser(userDocAId);
    if (userDocBId) await adminClient.auth.admin.deleteUser(userDocBId);
    if (userEstAId) await adminClient.auth.admin.deleteUser(userEstAId);
    if (userEstBId) await adminClient.auth.admin.deleteUser(userEstBId);
    console.log('✅ Base de datos limpia.');
  }
}

runTests().catch((err) => {
  console.error('Fallo en suite:', err);
  process.exit(1);
});
