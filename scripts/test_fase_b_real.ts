// scripts/test_fase_b_real.ts
import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';

if (typeof (process as any).loadEnvFile === 'function') {
  try {
    (process as any).loadEnvFile();
  } catch {}
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DOCENTE_EMAIL = process.env.DOCENTE_EMAIL;
const DOCENTE_PASSWORD = process.env.DOCENTE_PASSWORD;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('ERROR: Faltan variables SUPABASE_URL, SUPABASE_ANON_KEY o SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(1);
}

// Cargar credenciales del piloto local
const credsPath = path.join(process.cwd(), 'credenciales_estudiantes_piloto.local.json');
if (!fs.existsSync(credsPath)) {
  console.error('ERROR: No se encontró credenciales_estudiantes_piloto.local.json');
  process.exit(1);
}

const creds = JSON.parse(fs.readFileSync(credsPath, 'utf-8'));
const estA = creds.estudianteA;
const estB = creds.estudianteB;

const emailEstA = `${estA.codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
const pinEstA = estA.pin;

const emailEstB = `${estB.codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
const pinEstB = estB.pin;

// Clientes
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function crearCliente(email: string, pass: string) {
  const client = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email, password: pass });
  if (error || !data.session) {
    throw new Error(`Error en login para usuario [REDACTED]: ${error?.message}`);
  }
  return { client, user: data.user! };
}

function expect(condition: boolean, msg: string) {
  if (!condition) {
    console.error(`❌ FALLÓ: ${msg}`);
    throw new Error(`Test assertion failed: ${msg}`);
  }
  console.log(`✅ PASÓ: ${msg}`);
}

async function main() {
  console.log('====================================================');
  console.log('🧪 EJECUTANDO SUITE DE VALIDACIÓN RLS — FASE B');
  console.log('====================================================\n');

  // Buscar el aula del piloto
  const { data: aulaPiloto, error: errAula } = await adminClient
    .from('aulas')
    .select('id, nombre, codigo_aula')
    .eq('codigo_aula', '4A26')
    .single();

  if (errAula || !aulaPiloto) {
    throw new Error('No se encontró el aula piloto 4A26 en Supabase');
  }
  console.log(`Aula piloto encontrada: "${aulaPiloto.nombre}" (${aulaPiloto.codigo_aula})`);

  // 1. INICIAR SESIÓN CON USUARIOS REALES
  console.log('\n--- 1. Autenticación de usuarios piloto ---');
  const { client: clientEstA, user: userA } = await crearCliente(emailEstA, pinEstA);
  console.log('Estudiante A autenticado correctamente.');

  const { client: clientEstB, user: userB } = await crearCliente(emailEstB, pinEstB);
  console.log('Estudiante B autenticado correctamente.');

  let clientDoc: any = null;
  if (DOCENTE_EMAIL && DOCENTE_PASSWORD) {
    const resDoc = await crearCliente(DOCENTE_EMAIL, DOCENTE_PASSWORD);
    clientDoc = resDoc.client;
    console.log('Docente piloto autenticado correctamente.');
  } else {
    console.warn('⚠️ No se proporcionó DOCENTE_EMAIL o DOCENTE_PASSWORD en .env; saltando tests de docente.');
  }

  const cuentoTestId = `cuento-piloto-test-${Date.now()}`;

  try {
    // ----------------------------------------------------
    // PRUEBAS ANON
    // ----------------------------------------------------
    console.log('\n--- 2. Verificación de permisos ANON ---');
    const { data: anonCuentos, error: errAnonSelect } = await anonClient.from('cuentos').select('*');
    expect(!!errAnonSelect || !anonCuentos || anonCuentos.length === 0, 'ANON no puede hacer SELECT en cuentos');

    const { error: errAnonInsert } = await anonClient.from('cuentos').insert({
      id: `anon-${Date.now()}`,
      titulo: 'Cuento Hacker',
      personaje_principal: 'Fantasma',
      origen: 'dibujo',
    });
    expect(!!errAnonInsert, 'ANON no puede hacer INSERT en cuentos (42501 o permiso denegado)');

    const { error: errAnonEscenas } = await anonClient.from('escenas').insert({
      id: `anon-esc-${Date.now()}`,
      cuento_id: cuentoTestId,
      numero_escena: 1,
      texto_narrativo: 'Texto no autorizado',
    });
    expect(!!errAnonEscenas, 'ANON no puede hacer INSERT en escenas');

    // ----------------------------------------------------
    // PRUEBAS ESTUDIANTE A
    // ----------------------------------------------------
    console.log('\n--- 3. Verificación de Estudiante A (Autor legítimo) ---');
    // Inserción legítima
    const { error: errInsertA } = await clientEstA.from('cuentos').insert({
      id: cuentoTestId,
      titulo: 'El Misterio del Bosque Verde',
      personaje_principal: 'Pepito',
      descripcion_personaje: 'Un conejito con capa mágica',
      origen: 'dibujo',
      estudiante_id: userA.id,
      aula_id: aulaPiloto.id,
      es_demo: false,
    });
    expect(!errInsertA, 'Estudiante A puede insertar su propio cuento');

    // Insertar escena asociada
    const { error: errInsertEscena } = await clientEstA.from('escenas').insert({
      cuento_id: cuentoTestId,
      numero: 1,
      contenido: 'Había una vez en el bosque verde...',
      es_final: false,
    });
    if (errInsertEscena) {
      console.error('Detalle error insert escena:', errInsertEscena);
    }
    expect(!errInsertEscena, 'Estudiante A puede insertar escenas para su cuento');

    // Insertar decisión asociada
    const { error: errInsertDecision } = await clientEstA.from('decisiones_narrativas').insert({
      cuento_id: cuentoTestId,
      numero_escena: 1,
      opcion_seleccionada: 'Explorar la cueva misteriosa',
    });
    if (errInsertDecision) {
      console.error('Detalle error insert decisión:', errInsertDecision);
    }
    expect(!errInsertDecision, 'Estudiante A puede registrar decisiones narrativas para su cuento');

    // Intentar insertar cuento para Estudiante B (debe fallar)
    const { error: errSpoofAutor } = await clientEstA.from('cuentos').insert({
      id: `spoof-${Date.now()}`,
      titulo: 'Cuento Suplantado',
      personaje_principal: 'Otro',
      origen: 'dibujo',
      estudiante_id: userB.id,
      aula_id: aulaPiloto.id,
      es_demo: false,
    });
    expect(!!errSpoofAutor, 'Estudiante A no puede insertar cuento con estudiante_id de otro alumno');

    // Intentar asociar cuento a un aula ajena donde no está matriculado
    const fakeAulaId = '00000000-0000-0000-0000-000000000000';
    const { error: errAulaAjena } = await clientEstA.from('cuentos').insert({
      id: `aula-ajena-${Date.now()}`,
      titulo: 'Cuento Aula Falsa',
      personaje_principal: 'Otro',
      origen: 'dibujo',
      estudiante_id: userA.id,
      aula_id: fakeAulaId,
      es_demo: false,
    });
    expect(!!errAulaAjena, 'Estudiante A no puede asociar su cuento a un aula donde no está matriculado');

    // Estudiante A puede leer su propio cuento
    const { data: misCuentosA } = await clientEstA.from('cuentos').select('*').eq('id', cuentoTestId);
    expect(misCuentosA?.length === 1, 'Estudiante A puede leer su cuento');

    // ----------------------------------------------------
    // PRUEBAS ESTUDIANTE B (Aislamiento)
    // ----------------------------------------------------
    console.log('\n--- 4. Verificación de Estudiante B (Aislamiento entre alumnos) ---');
    const { data: cuentosDesdeB } = await clientEstB.from('cuentos').select('*').eq('id', cuentoTestId);
    expect(!cuentosDesdeB || cuentosDesdeB.length === 0, 'Estudiante B NO puede ver el cuento de Estudiante A');

    const { data: escenasDesdeB } = await clientEstB.from('escenas').select('*').eq('cuento_id', cuentoTestId);
    expect(!escenasDesdeB || escenasDesdeB.length === 0, 'Estudiante B NO puede ver las escenas del cuento de Estudiante A');

    const { data: updateResB, error: errUpdateB } = await clientEstB
      .from('cuentos')
      .update({ titulo: 'Hacked By B' })
      .eq('id', cuentoTestId)
      .select();
    expect(!!errUpdateB || !updateResB || updateResB.length === 0, 'Estudiante B no puede modificar el cuento de Estudiante A');

    // ----------------------------------------------------
    // PRUEBAS DOCENTE
    // ----------------------------------------------------
    if (clientDoc) {
      console.log('\n--- 5. Verificación de Docente (Auditoría e Inmutabilidad) ---');
      // Puede leer el cuento de su estudiante
      const { data: cuentoVistoDoc } = await clientDoc.from('cuentos').select('*').eq('id', cuentoTestId);
      expect(cuentoVistoDoc?.length === 1, 'Docente puede consultar cuentos de sus estudiantes');

      // Puede leer las escenas
      const { data: escenasVistasDoc } = await clientDoc.from('escenas').select('*').eq('cuento_id', cuentoTestId);
      expect(escenasVistasDoc?.length === 1, 'Docente puede consultar escenas del cuento de su estudiante');

      // Docente NO puede insertar cuentos
      const { error: errDocInsertCuento } = await clientDoc.from('cuentos').insert({
        id: `doc-story-${Date.now()}`,
        titulo: 'Cuento de Profesor',
        personaje_principal: 'Profesor',
        origen: 'dibujo',
        estudiante_id: clientDoc.auth?.currentUser?.id,
        aula_id: aulaPiloto.id,
      });
      expect(!!errDocInsertCuento, 'Docente NO puede insertar cuentos (exige rol estudiante)');

      // Docente NO puede modificar el cuento del alumno
      const { data: docUpdateRes, error: errDocUpdate } = await clientDoc
        .from('cuentos')
        .update({ titulo: 'Cuento Modificado Por Docente' })
        .eq('id', cuentoTestId)
        .select();
      expect(
        !!errDocUpdate || !docUpdateRes || docUpdateRes.length === 0,
        'Docente NO puede modificar cuentos de sus estudiantes (inmutabilidad)',
      );

      // Docente NO puede borrar el cuento del alumno
      const { data: docDeleteRes, error: errDocDelete } = await clientDoc
        .from('cuentos')
        .delete()
        .eq('id', cuentoTestId)
        .select();
      expect(
        !!errDocDelete || !docDeleteRes || docDeleteRes.length === 0,
        'Docente NO puede eliminar cuentos de sus estudiantes',
      );
    }

    console.log('\n🎉 ¡TODAS LAS POLÍTICAS DE FASE B FUERON VALIDARAS EXITOSAMENTE!');
  } finally {
    console.log('\n🧹 Limpiando cuento y escenas de prueba...');
    await adminClient.from('escenas').delete().eq('cuento_id', cuentoTestId);
    await adminClient.from('cuentos').delete().eq('id', cuentoTestId);
    console.log('✅ Base de datos limpia de datos de prueba.');
  }
}

main().catch((e) => {
  console.error('\n❌ Error ejecutando suite:', e);
  process.exit(1);
});
