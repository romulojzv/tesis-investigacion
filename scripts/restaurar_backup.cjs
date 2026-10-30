// scripts/restaurar_backup.cjs
/**
 * Herramienta de Restauración Segura de Copias de Seguridad Lógicas (JSON)
 *
 * Uso:
 *   node scripts/restaurar_backup.cjs [--file <ruta_archivo>] [--dry-run]
 *
 * Variables de entorno requeridas para ejecución real:
 *   TARGET_SUPABASE_URL (ej. http://127.0.0.1:54321 o https://acxsyswrzdtstgqztojj.supabase.co)
 *   TARGET_SUPABASE_SERVICE_ROLE_KEY
 *
 * SALVAGUARDAS DE SEGURIDAD:
 * 1. Por defecto rechaza la restauración contra el proyecto de Producción (wdehfetiazgukfgnngfi).
 * 2. Valida la integridad del JSON antes de realizar cualquier operación.
 * 3. Restaura en estricto orden de integridad referencial (claves foráneas).
 * 4. Soporta modo --dry-run para verificar la estructura sin tocar la base de datos.
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const PROD_PROJECT_REF = 'wdehfetiazgukfgnngfi';

function parseArgs() {
  const args = process.argv.slice(2);
  let file = null;
  let dryRun = false;
  let forceProd = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--file' && i + 1 < args.length) {
      file = args[++i];
    } else if (args[i] === '--dry-run') {
      dryRun = true;
    } else if (args[i] === '--allow-production-restore') {
      forceProd = true;
    }
  }

  return { file, dryRun, forceProd };
}

function getLatestBackupFile() {
  const backupsDir = path.resolve(__dirname, '..', 'backups');
  if (!fs.existsSync(backupsDir)) {
    throw new Error('El directorio de backups no existe: ' + backupsDir);
  }

  const files = fs
    .readdirSync(backupsDir)
    .filter((f) => f.startsWith('backup_habitual_') && f.endsWith('.json'))
    .sort()
    .reverse();

  if (files.length === 0) {
    throw new Error('No se encontraron copias de seguridad en ' + backupsDir);
  }

  return path.join(backupsDir, files[0]);
}

async function main() {
  const { file, dryRun, forceProd } = parseArgs();
  const backupPath = file ? path.resolve(file) : getLatestBackupFile();

  console.log('='.repeat(75));
  console.log('📦 RESTAURADOR DE COPIAS DE SEGURIDAD LÓGICAS (SUPABASE)');
  console.log('   Archivo origen: ' + path.basename(backupPath));
  console.log('   Modo Dry-Run:   ' + (dryRun ? 'SÍ (Solo validación, 0 escrituras)' : 'NO (Restauración real)'));
  console.log('='.repeat(75));

  if (!fs.existsSync(backupPath)) {
    throw new Error('No se encontró el archivo de respaldo: ' + backupPath);
  }

  const raw = fs.readFileSync(backupPath, 'utf8');
  const backup = JSON.parse(raw);

  if (!backup.timestamp || !backup.tables) {
    throw new Error('El archivo no posee el formato canónico de respaldo (falta timestamp o tables).');
  }

  console.log(`\n📅 Metadatos del Respaldo:`);
  console.log(`   Timestamp: ${backup.timestamp}`);
  console.log(`   URL origen: ${backup.supabaseUrl || 'N/A'}`);
  console.log(`   Tablas presentes en el archivo:`);

  const order = [
    'profiles',
    'aulas',
    'aula_estudiantes',
    'cuentos',
    'escenas',
    'decisiones_narrativas',
    'quiz_intentos',
    'quiz_respuestas',
  ];

  for (const table of order) {
    const rows = backup.tables[table] || [];
    console.log(`   - ${table.padEnd(25)}: ${rows.length} registros`);
  }

  if (dryRun) {
    console.log('\n✅ [DRY-RUN EXITOSO] El archivo de respaldo es íntegro y restaurable.');
    return;
  }

  // Si no es dry-run, validar credenciales de destino
  const targetUrl = process.env.TARGET_SUPABASE_URL;
  const targetKey = process.env.TARGET_SUPABASE_SERVICE_ROLE_KEY;

  if (!targetUrl || !targetKey) {
    throw new Error(
      'Para ejecutar la restauración real, defina TARGET_SUPABASE_URL y TARGET_SUPABASE_SERVICE_ROLE_KEY.\n' +
      'Para probar sin escribir datos, utilice: node scripts/restaurar_backup.cjs --dry-run'
    );
  }

  // BLOQUEO ABSOLUTO: Prohibir bajo cualquier circunstancia restaurar en Producción
  if (targetUrl.includes(PROD_PROJECT_REF) || targetUrl.toLowerCase().includes('wdehfetiazgukfgnngfi')) {
    throw new Error(
      `⛔ BLOQUEO ABSOLUTO DE SEGURIDAD: El destino '${targetUrl}' corresponde al proyecto de Producción (${PROD_PROJECT_REF}).\n` +
      'La restauración sobre la base de producción está TERMINANTEMENTE PROHIBIDA por software para proteger los datos de la tesis.\n' +
      'Este script únicamente autoriza restauraciones sobre entornos locales de prueba (127.0.0.1) o instancias efímeras aisladas.'
    );
  }

  console.log(`\n🚀 Conectando a destino: ${targetUrl}...`);
  const client = createClient(targetUrl, targetKey);

  for (const table of order) {
    const rows = backup.tables[table] || [];
    if (rows.length === 0) continue;

    console.log(`▶ Restaurando ${rows.length} registros en '${table}'...`);

    // Inserción en bloques de 50 para evitar sobrecarga de payload
    const CHUNK_SIZE = 50;
    for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
      const chunk = rows.slice(i, i + CHUNK_SIZE);
      const { error } = await client.from(table).upsert(chunk);
      if (error) {
        throw new Error(`Error restaurando tabla ${table} (bloque ${i}): ${error.message}`);
      }
    }
    console.log(`  ✅ ${table} restaurada exitosamente.`);
  }

  console.log('\n🎉 RESTAURACIÓN COMPLETADA EXITOSAMENTE.');
}

main().catch((err) => {
  console.error('\n❌ ERROR:', err.message);
  process.exit(1);
});
