// scripts/run_estudiantes_pilot.ts
import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';

if (typeof process.loadEnvFile === 'function') {
  try {
    process.loadEnvFile();
  } catch {
    // Continua
  }
}

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY!;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const docenteEmail = process.env.DOCENTE_EMAIL!;
const docentePass = process.env.DOCENTE_PASSWORD!;

const aulaNombre = process.env.AULA_NOMBRE!;
const aulaCodigo = process.env.AULA_CODIGO!;

async function main() {
  console.log('=== 1. OBTENIENDO JWT DEL DOCENTE PILOTO ===');
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: docLogin, error: docLoginErr } = await anonClient.auth.signInWithPassword({
    email: docenteEmail,
    password: docentePass,
  });

  if (docLoginErr || !docLogin.session) {
    console.error('Error al iniciar sesión como docente:', docLoginErr?.message);
    process.exit(1);
  }

  const teacherJwt = docLogin.session.access_token;
  const teacherId = docLogin.session.user.id;
  console.log(`Docente autenticado con ID: ${teacherId}`);

  console.log('\n=== 2. LOCALIZANDO AULA PILOTO ===');
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: aula, error: aulaErr } = await adminClient
    .from('aulas')
    .select('id, nombre, codigo_aula, docente_id')
    .eq('codigo_aula', aulaCodigo)
    .single();

  if (aulaErr || !aula) {
    console.error('No se pudo encontrar el aula piloto:', aulaErr?.message);
    process.exit(1);
  }
  const aulaId = aula.id;

  interface EstudianteCreado {
    estudianteId: string;
    nombre: string;
    codigoAcceso: string;
    pin: string;
  }

  // Endpoint de Edge Function remota
  const edgeFunctionUrl = `${SUPABASE_URL}/functions/v1/crear-estudiante`;

  async function invocarCrearEstudiante(
    nombre: string,
    codigoLocal: string,
  ): Promise<{ status: number; body: EstudianteCreado }> {
    console.log(`\nInvocando crear-estudiante para "${nombre}" (codigoLocal: ${codigoLocal})...`);
    const resp = await fetch(edgeFunctionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${teacherJwt}`,
      },
      body: JSON.stringify({
        nombre,
        aulaId,
        codigoLocal,
      }),
    });

    const status = resp.status;
    const body = (await resp.json()) as EstudianteCreado;
    return { status, body };
  }

  // PASO 5: Crear Estudiante A
  console.log('\n==================================================');
  console.log('5. CREANDO ESTUDIANTE A');
  console.log('==================================================');
  const resA = await invocarCrearEstudiante('Estudiante A', '001');
  if (resA.status !== 201) {
    console.error(`Error al crear Estudiante A: status ${resA.status}:`, resA.body);
    process.exit(1);
  }

  const estudianteA = resA.body;
  console.log('✅ Estudiante A creado vía Edge Function:');
  console.log(`   ID:            ${estudianteA.estudianteId}`);
  console.log(`   Nombre:        ${estudianteA.nombre}`);
  console.log(`   Código Acceso: ${estudianteA.codigoAcceso}`);
  console.log(`   PIN longitud:  ${estudianteA.pin?.length} dígitos`);

  // Verificar en BD para Estudiante A
  const { data: authA } = await adminClient.auth.admin.getUserById(estudianteA.estudianteId);
  console.log('Verificación auth.users (A):', {
    idMatches: authA.user?.id === estudianteA.estudianteId,
    appRol: authA.user?.app_metadata?.rol,
    appCod: authA.user?.app_metadata?.codigo_acceso,
  });

  const { data: profA } = await adminClient
    .from('profiles')
    .select('id, nombre, rol, codigo_acceso')
    .eq('id', estudianteA.estudianteId)
    .single();
  console.log('Verificación profiles (A):', profA);

  const { data: matA } = await adminClient
    .from('aula_estudiantes')
    .select('aula_id, estudiante_id, codigo_local')
    .eq('estudiante_id', estudianteA.estudianteId)
    .single();
  console.log('Verificación aula_estudiantes (A):', matA);

  // PASO 6: Crear Estudiante B
  console.log('\n==================================================');
  console.log('6. CREANDO ESTUDIANTE B');
  console.log('==================================================');
  const resB = await invocarCrearEstudiante('Estudiante B', '002');
  if (resB.status !== 201) {
    console.error(`Error al crear Estudiante B: status ${resB.status}:`, resB.body);
    process.exit(1);
  }

  const estudianteB = resB.body;
  console.log('✅ Estudiante B creado vía Edge Function:');
  console.log(`   ID:            ${estudianteB.estudianteId}`);
  console.log(`   Nombre:        ${estudianteB.nombre}`);
  console.log(`   Código Acceso: ${estudianteB.codigoAcceso}`);
  console.log(`   PIN longitud:  ${estudianteB.pin?.length} dígitos`);
  console.log(`   Código distinto de A: ${estudianteA.codigoAcceso !== estudianteB.codigoAcceso}`);

  // Verificar en BD para Estudiante B
  const { data: authB } = await adminClient.auth.admin.getUserById(estudianteB.estudianteId);
  console.log('Verificación auth.users (B):', {
    idMatches: authB.user?.id === estudianteB.estudianteId,
    appRol: authB.user?.app_metadata?.rol,
    appCod: authB.user?.app_metadata?.codigo_acceso,
  });

  const { data: profB } = await adminClient
    .from('profiles')
    .select('id, nombre, rol, codigo_acceso')
    .eq('id', estudianteB.estudianteId)
    .single();
  console.log('Verificación profiles (B):', profB);

  const { data: matB } = await adminClient
    .from('aula_estudiantes')
    .select('aula_id, estudiante_id, codigo_local')
    .eq('estudiante_id', estudianteB.estudianteId)
    .single();
  console.log('Verificación aula_estudiantes (B):', matB);

  // Guardar credenciales de forma LOCAL para futura prueba de LoginView
  const credsPath = path.join(process.cwd(), 'credenciales_estudiantes_piloto.local.json');
  fs.writeFileSync(
    credsPath,
    JSON.stringify(
      {
        estudianteA: {
          id: estudianteA.estudianteId,
          nombre: estudianteA.nombre,
          codigoAcceso: estudianteA.codigoAcceso,
          pin: estudianteA.pin,
        },
        estudianteB: {
          id: estudianteB.estudianteId,
          nombre: estudianteB.nombre,
          codigoAcceso: estudianteB.codigoAcceso,
          pin: estudianteB.pin,
        },
      },
      null,
      2,
    ),
  );
  console.log(`\n💾 Credenciales guardadas localmente en ${credsPath} para futura prueba de LoginView.`);

  // PASO 7: LOGIN REAL DE A Y B
  console.log('\n==================================================');
  console.log('7. LOGIN REAL DE ESTUDIANTES A Y B');
  console.log('==================================================');

  // Login Estudiante A
  const emailA = `${estudianteA.codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
  const clientA = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: sesA, error: errLoginA } = await clientA.auth.signInWithPassword({
    email: emailA,
    password: estudianteA.pin,
  });

  if (errLoginA || !sesA.session) {
    console.error('❌ Error en login real de Estudiante A:', errLoginA?.message);
    process.exit(1);
  }

  console.log('✅ Login Estudiante A:');
  console.log('   Login exitoso:              true');
  console.log('   Sesión válida:              true');
  console.log(`   user.id correcto:           ${sesA.session.user.id === estudianteA.estudianteId}`);

  // Consultar perfil usando el cliente con la sesión autenticada de Estudiante A
  const { data: profClientA, error: pErrA } = await clientA
    .from('profiles')
    .select('id, nombre, rol, codigo_acceso')
    .eq('id', sesA.session.user.id)
    .single();

  if (pErrA || !profClientA) {
    console.error('❌ Error consultando perfil de A como estudiante autenticado:', pErrA?.message);
    process.exit(1);
  }
  console.log(`   profile.rol = estudiante:   ${profClientA.rol === 'estudiante'}`);

  // Verificar matrícula
  const { data: matClientA, error: mErrA } = await clientA
    .from('aula_estudiantes')
    .select('aula_id, codigo_local')
    .eq('estudiante_id', sesA.session.user.id)
    .single();
  console.log(`   matrícula accesible vía RLS: ${matClientA?.codigo_local === '001'}`);

  // Login Estudiante B
  const emailB = `${estudianteB.codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
  const clientB = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: sesB, error: errLoginB } = await clientB.auth.signInWithPassword({
    email: emailB,
    password: estudianteB.pin,
  });

  if (errLoginB || !sesB.session) {
    console.error('❌ Error en login real de Estudiante B:', errLoginB?.message);
    process.exit(1);
  }

  console.log('\n✅ Login Estudiante B:');
  console.log('   Login exitoso:              true');
  console.log('   Sesión válida:              true');
  console.log(`   user.id correcto:           ${sesB.session.user.id === estudianteB.estudianteId}`);

  const { data: profClientB, error: pErrB } = await clientB
    .from('profiles')
    .select('id, nombre, rol, codigo_acceso')
    .eq('id', sesB.session.user.id)
    .single();

  if (pErrB || !profClientB) {
    console.error('❌ Error consultando perfil de B como estudiante autenticado:', pErrB?.message);
    process.exit(1);
  }
  console.log(`   profile.rol = estudiante:   ${profClientB.rol === 'estudiante'}`);

  const { data: matClientB } = await clientB
    .from('aula_estudiantes')
    .select('aula_id, codigo_local')
    .eq('estudiante_id', sesB.session.user.id)
    .single();
  console.log(`   matrícula accesible vía RLS: ${matClientB?.codigo_local === '002'}`);

  console.log('\n🎉 PASOS 5, 6 Y 7 COMPLETADOS CON ÉXITO.');
}

main().catch((err) => {
  console.error('Excepción general:', err);
  process.exit(1);
});
