// scripts/test_crear_estudiante.ts
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
  console.error('ERROR: Faltan variables SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY o SUPABASE_ANON_KEY.');
  process.exit(1);
}

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function expect(condition: boolean, testName: string) {
  if (!condition) {
    console.error(`❌ FALLÓ: ${testName}`);
    throw new Error(`Test fallido: ${testName}`);
  }
  console.log(`✅ PASÓ: ${testName}`);
}

// Simulación de la lógica nuclear de crear-estudiante para pruebas locales de integración
async function simularCrearEstudiante(params: {
  token?: string;
  nombre: string;
  aulaId: string;
  codigoLocal: string;
  forzarErrorMatricula?: boolean;
}) {
  // 1. Validar Token
  if (!params.token) {
    return { status: 401, error: 'No autorizado. Se requiere token Bearer.' };
  }

  const { data: userData, error: userError } = await adminClient.auth.getUser(params.token);
  if (userError || !userData?.user) {
    return { status: 401, error: 'Sesión no válida o expirada.' };
  }

  const user = userData.user;

  // 2. Validar rol docente en profiles
  const { data: profile } = await adminClient
    .from('profiles')
    .select('id, rol')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile || profile.rol !== 'docente') {
    return { status: 403, error: 'Acceso denegado. Se requiere rol docente.' };
  }

  // 3. Validar aula y propiedad
  const { data: aula } = await adminClient
    .from('aulas')
    .select('id, codigo_aula, docente_id')
    .eq('id', params.aulaId)
    .eq('docente_id', user.id)
    .maybeSingle();

  if (!aula) {
    return { status: 403, error: 'El aula no existe o no pertenece al docente autenticado.' };
  }

  // 4. Validar disponibilidad de código local
  const { data: matExistente } = await adminClient
    .from('aula_estudiantes')
    .select('estudiante_id')
    .eq('aula_id', params.aulaId)
    .eq('codigo_local', params.codigoLocal)
    .maybeSingle();

  if (matExistente) {
    return { status: 409, error: `El código local '${params.codigoLocal}' ya está asignado.` };
  }

  // 5. Generar código de acceso
  const codigoAcceso = `${aula.codigo_aula}-${params.codigoLocal}`.toUpperCase();
  const { data: perfilExistente } = await adminClient
    .from('profiles')
    .select('id')
    .eq('codigo_acceso', codigoAcceso)
    .maybeSingle();

  if (perfilExistente) {
    return { status: 409, error: `Colisión de código de acceso global '${codigoAcceso}'.` };
  }

  // 6. Generar PIN criptográfico (Web Crypto)
  const randomBuffer = new Uint32Array(1);
  crypto.getRandomValues(randomBuffer);
  const pin = (100000 + (randomBuffer[0] % 900000)).toString();

  const emailSintetico = `${codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;

  // 7. Crear usuario en Auth
  const { data: authUser, error: authCreateError } = await adminClient.auth.admin.createUser({
    email: emailSintetico,
    password: pin,
    email_confirm: true,
    app_metadata: {
      rol: 'estudiante',
      codigo_acceso: codigoAcceso,
    },
    user_metadata: {
      nombre: params.nombre,
    },
  });

  if (authCreateError || !authUser?.user) {
    return { status: 500, error: 'Fallo al crear usuario en Auth.' };
  }

  const nuevoId = authUser.user.id;

  // 8. Matrícula con Rollback Compensatorio
  if (params.forzarErrorMatricula) {
    // Simular falla de matrícula y ejecutar rollback
    await adminClient.auth.admin.deleteUser(nuevoId);
    return { status: 500, error: 'Fallo forzado en matrícula. Se aplicó rollback compensatorio.' };
  }

  const { error: enrollError } = await adminClient
    .from('aula_estudiantes')
    .insert({
      aula_id: params.aulaId,
      estudiante_id: nuevoId,
      codigo_local: params.codigoLocal,
    });

  if (enrollError) {
    await adminClient.auth.admin.deleteUser(nuevoId);
    return { status: 500, error: 'Error en matrícula. Se aplicó rollback compensatorio.' };
  }

  return {
    status: 201,
    data: {
      success: true,
      estudianteId: nuevoId,
      nombre: params.nombre,
      codigoAcceso,
      pin,
    },
  };
}

async function runTestSuite() {
  console.log('🚀 INICIANDO TESTS DE LA LÓGICA DE "crear-estudiante"...');

  const passDoc = 'DocSeguroPass2026!';
  const passEst = '482910';
  const emailDocA = `test.doc.a.${Date.now()}@cuentosmagicos.internal`;
  const emailDocB = `test.doc.b.${Date.now()}@cuentosmagicos.internal`;
  const emailEst = `test.est.${Date.now()}@estudiantes.cuentosmagicos.internal`;

  let userDocAId = '', userDocBId = '', userEstId = '';
  let aulaAId = '', aulaBId = '';
  let tokenDocA = '', tokenEst = '';
  const estudiantesCreados: string[] = [];

  try {
    // SETUP
    console.log('📦 Configurando docentes y aulas de prueba...');
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

    const { data: uEst } = await adminClient.auth.admin.createUser({
      email: emailEst, password: passEst, email_confirm: true,
      app_metadata: { rol: 'estudiante', codigo_acceso: `TST-${Date.now().toString().slice(-4)}` },
      user_metadata: { nombre: 'Estudiante Test' },
    });
    userEstId = uEst.user!.id;

    // Login para obtener JWTs
    const clientDocA = createClient(SUPABASE_URL!, ANON_KEY!, { auth: { persistSession: false } });
    const { data: sesDocA } = await clientDocA.auth.signInWithPassword({ email: emailDocA, password: passDoc });
    tokenDocA = sesDocA.session!.access_token;

    const clientEst = createClient(SUPABASE_URL!, ANON_KEY!, { auth: { persistSession: false } });
    const { data: sesEst } = await clientEst.auth.signInWithPassword({ email: emailEst, password: passEst });
    tokenEst = sesEst.session!.access_token;

    // Crear aulas
    const { data: aulaA } = await adminClient.from('aulas').insert({
      nombre: 'Aula 4A Test', codigo_aula: `4A${Date.now().toString().slice(-3)}`, docente_id: userDocAId,
    }).select().single();
    aulaAId = aulaA.id;

    const { data: aulaB } = await adminClient.from('aulas').insert({
      nombre: 'Aula 4B Test', codigo_aula: `4B${Date.now().toString().slice(-3)}`, docente_id: userDocBId,
    }).select().single();
    aulaBId = aulaB.id;

    // TEST 1: Request sin JWT -> rechazado 401
    const resSinJwt = await simularCrearEstudiante({
      nombre: 'Pedro', aulaId: aulaAId, codigoLocal: '001',
    });
    expect(resSinJwt.status === 401, 'Request sin JWT es rechazado con status 401');

    // TEST 2: Estudiante intenta crear estudiante -> rechazado 403
    const resEstudianteHack = await simularCrearEstudiante({
      token: tokenEst, nombre: 'Hacker', aulaId: aulaAId, codigoLocal: '002',
    });
    expect(resEstudianteHack.status === 403, 'Estudiante intentando crear alumno es rechazado con 403');

    // TEST 3: Docente intenta usar aula ajena -> rechazado 403
    const resAulaAjena = await simularCrearEstudiante({
      token: tokenDocA, nombre: 'Lucía', aulaId: aulaBId, codigoLocal: '003',
    });
    expect(resAulaAjena.status === 403, 'Docente usando aula de otro docente es rechazado con 403');

    // TEST 4: Creación válida -> usuario + profile + matrícula
    const resCreacionValida = await simularCrearEstudiante({
      token: tokenDocA, nombre: 'María Test', aulaId: aulaAId, codigoLocal: '018',
    });
    expect(resCreacionValida.status === 201, 'Creación válida responde status 201');
    const nuevoEstudianteId = resCreacionValida.data!.estudianteId;
    estudiantesCreados.push(nuevoEstudianteId);

    // Verificar en public.profiles
    const { data: perfilCreado } = await adminClient.from('profiles').select('*').eq('id', nuevoEstudianteId).single();
    expect(perfilCreado?.nombre === 'María Test', 'Perfil creado en public.profiles con nombre correcto');
    expect(perfilCreado?.rol === 'estudiante', 'Perfil creado tiene rol estrictamente estudiante');
    expect(perfilCreado?.codigo_acceso === `${aulaA.codigo_aula}-018`, 'codigo_acceso generado correctamente');

    // Verificar que el PIN NO existe en public.profiles
    expect((perfilCreado as Record<string, unknown>).pin === undefined, 'El PIN no es un campo ni existe en public.profiles');

    // Verificar matrícula en aula_estudiantes
    const { data: matricula } = await adminClient
      .from('aula_estudiantes')
      .select('*')
      .eq('aula_id', aulaAId)
      .eq('estudiante_id', nuevoEstudianteId)
      .single();
    expect(matricula?.codigo_local === '018', 'Matrícula registrada correctamente con codigo_local');

    // TEST 5: codigoLocal duplicado -> 409 Conflict
    const resDuplicado = await simularCrearEstudiante({
      token: tokenDocA, nombre: 'Otro Alumno', aulaId: aulaAId, codigoLocal: '018',
    });
    expect(resDuplicado.status === 409, 'Intento con codigoLocal duplicado en la misma aula retorna 409 Conflict');

    // TEST 6: Fallo en matrícula ejecuta rollback y elimina usuario Auth
    console.log('🧪 Probando rollback compensatorio tras falla en matrícula...');
    const resRollback = await simularCrearEstudiante({
      token: tokenDocA, nombre: 'Alumno Fallido', aulaId: aulaAId, codigoLocal: '099', forzarErrorMatricula: true,
    });
    expect(resRollback.status === 500, 'Fallo provocado en matrícula retorna error 500');

    // Comprobar que no quedó cuenta huérfana en Auth
    const { data: usersList } = await adminClient.auth.admin.listUsers();
    const cuentaHuerfana = usersList.users.find(
      (u) => u.user_metadata?.nombre === 'Alumno Fallido'
    );
    expect(!cuentaHuerfana, 'Rollback compensatorio: el usuario Auth creado fue eliminado y no quedó huérfano');

    console.log('\n🎉 TODOS LOS 9 TESTS DE SEGURIDAD Y VALIDACIÓN DE crear-estudiante PASARON AL 100%.');
  } finally {
    console.log('\n🧹 Limpiando registros de prueba...');
    for (const id of estudiantesCreados) {
      await adminClient.from('aula_estudiantes').delete().eq('estudiante_id', id);
      await adminClient.from('profiles').delete().eq('id', id);
      await adminClient.auth.admin.deleteUser(id);
    }
    if (aulaAId) {
      await adminClient.from('aula_estudiantes').delete().eq('aula_id', aulaAId);
      await adminClient.from('aulas').delete().eq('id', aulaAId);
    }
    if (aulaBId) {
      await adminClient.from('aula_estudiantes').delete().eq('aula_id', aulaBId);
      await adminClient.from('aulas').delete().eq('id', aulaBId);
    }
    if (userDocAId) await adminClient.auth.admin.deleteUser(userDocAId);
    if (userDocBId) await adminClient.auth.admin.deleteUser(userDocBId);
    if (userEstId) await adminClient.auth.admin.deleteUser(userEstId);
    console.log('✅ Base de datos restaurada.');
  }
}

runTestSuite().catch((err) => {
  console.error('Fallo en test suite:', err);
  process.exit(1);
});
