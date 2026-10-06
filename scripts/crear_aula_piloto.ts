// scripts/crear_aula_piloto.ts
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const docenteEmail = process.env.DOCENTE_EMAIL;
const docenteId = process.env.DOCENTE_ID;
const aulaNombre = process.env.AULA_NOMBRE;
const aulaCodigo = process.env.AULA_CODIGO;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('ERROR: Faltan variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(1);
}

if ((!docenteEmail && !docenteId) || !aulaNombre || !aulaCodigo) {
  console.error('\nERROR: Debes proporcionar las variables de entorno requeridas:');
  console.error('  DOCENTE_EMAIL o DOCENTE_ID');
  console.error('  AULA_NOMBRE (ej: "4to Grado A")');
  console.error('  AULA_CODIGO (ej: "4A26")');
  console.error('\nEjemplo de ejecución:');
  console.error('  DOCENTE_EMAIL="docente@escuela.pe" AULA_NOMBRE="4to Grado A" AULA_CODIGO="4A26" npx tsx scripts/crear_aula_piloto.ts\n');
  process.exit(1);
}

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function main() {
  console.log('Iniciando creación de aula de prueba...');

  let targetDocenteId = docenteId;

  if (!targetDocenteId && docenteEmail) {
    console.log(`Localizando usuario docente con correo: ${docenteEmail}...`);
    const { data: usersData, error: listError } = await supabaseAdmin.auth.admin.listUsers({
      page: 1,
      perPage: 100,
    });

    if (listError) {
      console.error('❌ Error listando usuarios de auth:', listError.message);
      process.exit(1);
    }

    const matchedUser = usersData.users.find(
      (u) => u.email?.toLowerCase() === docenteEmail.toLowerCase().trim()
    );

    if (!matchedUser) {
      console.error(`❌ No se encontró usuario en Auth con el email: ${docenteEmail}`);
      process.exit(1);
    }

    targetDocenteId = matchedUser.id;
  }

  // 1. Verificar perfil y rol en public.profiles
  const { data: profile, error: profError } = await supabaseAdmin
    .from('profiles')
    .select('id, nombre, rol')
    .eq('id', targetDocenteId)
    .single();

  if (profError || !profile) {
    console.error(`❌ No existe perfil en public.profiles para el usuario: ${targetDocenteId}`);
    process.exit(1);
  }

  if (profile.rol !== 'docente') {
    console.error(`❌ El usuario ${profile.nombre} (${profile.id}) no tiene rol docente (rol actual: ${profile.rol}).`);
    process.exit(1);
  }

  const cleanNombre = aulaNombre.trim();
  const cleanCodigo = aulaCodigo.trim().toUpperCase();

  // 2. Comprobar si el código de aula ya existe
  const { data: aulaExistente } = await supabaseAdmin
    .from('aulas')
    .select('id, nombre, codigo_aula')
    .eq('codigo_aula', cleanCodigo)
    .maybeSingle();

  if (aulaExistente) {
    console.log(`ℹ️ El aula con código "${cleanCodigo}" ya existe.`);
    console.log(`   ID:     ${aulaExistente.id}`);
    console.log(`   Nombre: ${aulaExistente.nombre}`);
    return;
  }

  // 3. Crear aula
  const { data: nuevaAula, error: aulaError } = await supabaseAdmin
    .from('aulas')
    .insert({
      nombre: cleanNombre,
      codigo_aula: cleanCodigo,
      docente_id: profile.id,
    })
    .select()
    .single();

  if (aulaError || !nuevaAula) {
    console.error('❌ Error al insertar aula:', aulaError?.message);
    process.exit(1);
  }

  console.log('✅ Aula creada exitosamente:');
  console.log(`   ID:          ${nuevaAula.id}`);
  console.log(`   Nombre:      ${nuevaAula.nombre}`);
  console.log(`   Código Aula: ${nuevaAula.codigo_aula}`);
  console.log(`   Docente:     ${profile.nombre} (${profile.id})`);
}

main();
