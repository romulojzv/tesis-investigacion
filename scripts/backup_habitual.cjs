const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Cargar variables de entorno desde .env manualmente
function loadEnv() {
  const envPath = path.resolve(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) {
    throw new Error('Archivo .env no encontrado');
  }
  const lines = fs.readFileSync(envPath, 'utf8').split('\n');
  const env = {};
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx !== -1) {
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      env[key] = val;
    }
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const supabaseUrl = env.SUPABASE_URL;
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceKey) {
    throw new Error('Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en .env');
  }

  // Salvaguarda: Rechazar ejecución contra entornos de producción
  if (supabaseUrl.toLowerCase().includes('production') || process.env.ENVIRONMENT === 'production') {
    throw new Error('⛔ SEGURIDAD: Ejecución abortada. Este script no está autorizado para ejecutarse contra entornos de producción.');
  }

  console.log(`[Backup] Conectando a Supabase habitual: ${supabaseUrl.replace(/\/\/([^:]+):?.*@/, '//')}`);
  const client = createClient(supabaseUrl, serviceKey);

  const tables = [
    'aulas',
    'aula_estudiantes',
    'profiles',
    'cuentos',
    'escenas',
    'decisiones_narrativas',
    'quiz_intentos',
    'quiz_respuestas',
  ];

  const backupData = {
    timestamp: new Date().toISOString(),
    supabaseUrl,
    tables: {},
  };

  for (const table of tables) {
    const { data, error } = await client.from(table).select('*');
    if (error) {
      console.error(`[Backup] Error exportando tabla ${table}:`, error.message);
      throw error;
    }
    backupData.tables[table] = data;
    console.log(`[Backup] Tabla ${table}: ${data.length} registros respaldados.`);
  }

  const backupDir = path.resolve(__dirname, '..', 'backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestampStr = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFile = path.join(backupDir, `backup_habitual_${timestampStr}.json`);
  fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2), 'utf8');

  console.log(`[Backup] ✅ Copia de seguridad guardada exitosamente en:\n  ${backupFile}`);
}

main().catch((err) => {
  console.error('[Backup] ❌ Error:', err);
  process.exit(1);
});
