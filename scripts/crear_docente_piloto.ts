// scripts/crear_docente_piloto.ts
import { createClient } from '@supabase/supabase-js';

if (typeof process.loadEnvFile === 'function') {
  try {
    process.loadEnvFile();
  } catch {
    // Continúa con variables del sistema si .env no existe
  }
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const nombre = process.env.DOCENTE_NOMBRE;
const email = process.env.DOCENTE_EMAIL;
const password = process.env.DOCENTE_PASSWORD;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('ERROR: Faltan variables SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(1);
}

if (!nombre || !email || !password) {
  console.error('\nERROR: Las credenciales deben proporcionarse exclusivamente vía variables de entorno:');
  console.error('  DOCENTE_NOMBRE="Nombre del Docente"');
  console.error('  DOCENTE_EMAIL="correo@docente.edu.pe"');
  console.error('  DOCENTE_PASSWORD="PasswordSeguro2026!"');
  console.error('\nEjemplo de ejecución en terminal:');
  console.error('  DOCENTE_NOMBRE="Carlos" DOCENTE_EMAIL="carlos@escuela.pe" DOCENTE_PASSWORD="Pass" npx tsx scripts/crear_docente_piloto.ts\n');
  process.exit(1);
}

if (password.length < 8) {
  console.error('ERROR: La contraseña debe tener al menos 8 caracteres.');
  process.exit(1);
}

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function main(nombreDocente: string, emailDocente: string, passDocente: string) {
  console.log(`Aprovisionando cuenta docente para: ${emailDocente}...`);

  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    email: emailDocente,
    password: passDocente,
    email_confirm: true,
    app_metadata: {
      rol: 'docente', // Validado obligatoriamente por handle_new_user
    },
    user_metadata: {
      nombre: nombreDocente.trim(),
    },
  });

  if (error) {
    console.error('❌ Error al crear cuenta:', error.message);
    process.exit(1);
  }

  console.log(`✅ Docente creado exitosamente en auth.users.`);
  console.log(`   ID:    ${data.user.id}`);
  console.log(`   Email: ${data.user.email}`);
  console.log(`   Rol:   docente`);
}

main(nombre, email, password);
