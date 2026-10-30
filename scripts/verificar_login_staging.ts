// scripts/verificar_login_staging.ts
/**
 * Herramienta Segura de Verificación de Autenticación en Staging
 *
 * ============================================================================
 * OBJETIVO:
 * 1. Probar el inicio de sesión real en Supabase Staging para las 7 cuentas
 *    utilizando las nuevas credenciales resguardadas bajo Windows DPAPI.
 * 2. Comprobar el rechazo de las contraseñas/PINs antiguos predeterminados.
 * 3. Verificar la lectura de perfil bajo RLS sin crear ni modificar datos académicos.
 * 4. Zero-Leak: Jamás imprime contraseñas, PINs ni tokens en consola.
 * ============================================================================
 */

import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';
if (typeof (process as any).loadEnvFile === 'function') {
  try {
    if (fs.existsSync('.env.staging')) {
      (process as any).loadEnvFile('.env.staging');
    } else {
      (process as any).loadEnvFile();
    }
  } catch {}
}

const SUPABASE_URL = process.env.SUPABASE_STAGING_URL || 'https://acxsyswrzdtstgqztojj.supabase.co';
const ANON_KEY =
  process.env.SUPABASE_STAGING_ANON_KEY ||
  process.env.SUPABASE_ANON_KEY;

if (!ANON_KEY) {
  console.error('❌ Falta configurar SUPABASE_STAGING_ANON_KEY o SUPABASE_ANON_KEY en las variables de entorno (.env).');
  process.exit(1);
}

// 1. Salvaguarda estricta de destino con new URL()
try {
  const parsed = new URL(SUPABASE_URL);
  if (
    parsed.protocol !== 'https:' ||
    parsed.hostname !== 'acxsyswrzdtstgqztojj.supabase.co' ||
    (parsed.port && parsed.port !== '443') ||
    parsed.username ||
    parsed.password
  ) {
    throw new Error(
      `Destino no autorizado: '${parsed.origin}'. Esta verificación solo puede ejecutarse contra Staging: 'https://acxsyswrzdtstgqztojj.supabase.co'.`
    );
  }
} catch (err: any) {
  console.error(`⛔ BLOQUEO DE SEGURIDAD: ${err.message}`);
  process.exit(1);
}

// 2. Recuperación en memoria de las credenciales rotadas mediante Windows DPAPI
const ARCHIVO_LOCAL_CIFRADO = path.join(process.cwd(), 'scripts', 'credenciales_rotadas.local.json');

function descifrarAlmacenDPAPI(): Record<string, any> {
  if (!fs.existsSync(ARCHIVO_LOCAL_CIFRADO)) {
    throw new Error(`No se encontró el almacén cifrado en: ${ARCHIVO_LOCAL_CIFRADO}`);
  }

  const raw = fs.readFileSync(ARCHIVO_LOCAL_CIFRADO, 'utf-8');
  const envelope = JSON.parse(raw);

  if (envelope.formato !== 'WINDOWS_DPAPI_CURRENT_USER' || !envelope.payload_cifrado_base64) {
    throw new Error('El archivo no posee el sobre cifrado DPAPI esperado.');
  }

  const psScript = `
    Add-Type -AssemblyName System.Security
    $b64 = [System.Console]::In.ReadToEnd().Trim()
    $enc = [System.Convert]::FromBase64String($b64)
    $dec = [System.Security.Cryptography.ProtectedData]::Unprotect(
      $enc,
      $null,
      [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [System.Console]::Write([System.Text.Encoding]::UTF8.GetString($dec))
  `;

  const proc = child_process.spawnSync(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', psScript],
    {
      input: envelope.payload_cifrado_base64,
      encoding: 'utf-8',
      windowsHide: true,
      maxBuffer: 10 * 1024 * 1024,
    }
  );

  if (proc.error || proc.status !== 0) {
    throw new Error(`Fallo descifrando DPAPI: ${proc.stderr?.trim() || proc.error?.message}`);
  }

  return JSON.parse(proc.stdout);
}

async function main() {
  console.log('='.repeat(75));
  console.log('🛡️  VERIFICACIÓN SEGURA DE ACCESOS Y RECHAZO DE CREDENCIALES ANTIGUAS');
  console.log('   Entorno:    Supabase Staging (acxsyswrzdtstgqztojj.supabase.co)');
  console.log('   Operación:  SOLO LECTURA / AUTENTICACIÓN (0 mutaciones de datos)');
  console.log('   Fecha/Hora: ' + new Date().toISOString());
  console.log('='.repeat(75));

  let vault: Record<string, any>;
  try {
    vault = descifrarAlmacenDPAPI();
    console.log(`\n🔓 Almacén DPAPI descifrado en memoria para el usuario actual (${Object.keys(vault).length} cuentas).\n`);
  } catch (err: any) {
    console.error('❌ Error accediendo al almacén cifrado:', err.message);
    process.exit(1);
  }

  const resultados: Array<{
    email: string;
    tipo: string;
    antiguaRechazada: boolean;
    nuevaAceptada: boolean;
    perfilLeido: boolean;
    userIdCoincide: boolean;
    mutaciones: number;
  }> = [];

  // Contraseñas/PINs antiguos conocidos que estaban en los scripts antes de la rotación
  const PIN_ANTIGUO_CONOCIDO = '123456';
  const PASSWORD_ANTIGUA_CONOCIDA = 'DocenteTest2026!';

  for (const [email, info] of Object.entries(vault)) {
    console.log(`▶ Verificando cuenta: ${email} (${info.tipo?.toUpperCase()})`);

    const client = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1. PRUEBA DE RECHAZO DE CREDENCIAL ANTIGUA
    const credencialAntigua = info.tipo === 'pin' ? PIN_ANTIGUO_CONOCIDO : PASSWORD_ANTIGUA_CONOCIDA;
    let antiguaRechazada = false;

    const { data: oldAuth, error: oldErr } = await client.auth.signInWithPassword({
      email,
      password: credencialAntigua,
    });

    if (oldErr) {
      antiguaRechazada = true;
      console.log(`  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: ${oldErr.message}`);
    } else {
      console.warn(`  ⚠️ [ALERTA] La credencial antigua fue aceptada para ${email}`);
      await client.auth.signOut();
    }

    // 2. PRUEBA DE INICIO DE SESIÓN CON NUEVA CREDENCIAL ROTADA
    let nuevaAceptada = false;
    let userIdCoincide = false;
    let perfilLeido = false;

    const { data: newAuth, error: newErr } = await client.auth.signInWithPassword({
      email,
      password: info.credencial,
    });

    if (newErr || !newAuth.user || !newAuth.session) {
      console.error(`  ❌ [FALLO] Error autenticando con nueva credencial: ${newErr?.message}`);
    } else {
      nuevaAceptada = true;
      userIdCoincide = newAuth.user.id === info.id;
      console.log(`  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: ${userIdCoincide ? 'SÍ' : 'NO'})`);

      // 3. PRUEBA DE LECTURA DE DATOS BAJO RLS (SOLO SELECT, 0 MODIFICACIONES)
      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: {
          headers: {
            Authorization: `Bearer ${newAuth.session.access_token}`,
          },
        },
        auth: { autoRefreshToken: false, persistSession: false },
      });

      const { data: perfilData, error: perfilErr } = await userClient
        .from('profiles')
        .select('id, nombre, rol, codigo_acceso')
        .eq('id', newAuth.user.id)
        .maybeSingle();

      if (!perfilErr && perfilData) {
        perfilLeido = true;
        console.log(`  ✅ [LECTURA RLS] Perfil consultado: rol='${perfilData.rol}', nombre='${perfilData.nombre || 'N/A'}'`);
      } else {
        console.log(`  ℹ️ [LECTURA RLS] Perfil no encontrado o restringido: ${perfilErr?.message || 'sin datos'}`);
      }

      await client.auth.signOut();
    }

    resultados.push({
      email,
      tipo: info.tipo,
      antiguaRechazada,
      nuevaAceptada,
      perfilLeido,
      userIdCoincide,
      mutaciones: 0,
    });

    console.log('-'.repeat(75));
  }

  // REPORTE DE RESULTADOS CONSOLIDADOS
  console.log('\n' + '='.repeat(75));
  console.log('📊 REPORTE CONSOLIDADO DE COMPROBACIÓN DE ACCESOS EN STAGING:');
  console.log('='.repeat(75));
  console.log('Cuenta                                  | Tipo     | Antig. Rechazada | Nueva Aceptada | RLS Leído | Mutaciones');
  console.log('-'.repeat(105));

  let todasNuevasOk = true;
  let todasAntiguasRechazadas = true;

  for (const r of resultados) {
    const padEmail = r.email.padEnd(39);
    const padTipo = r.tipo.toUpperCase().padEnd(8);
    const padAntig = (r.antiguaRechazada ? 'SÍ (400)' : 'NO').padEnd(16);
    const padNueva = (r.nuevaAceptada && r.userIdCoincide ? 'SÍ (200)' : 'NO').padEnd(14);
    const padRls = (r.perfilLeido ? 'SÍ' : 'PARCIAL').padEnd(9);
    const padMut = `${r.mutaciones} (lectura)`;

    console.log(`${padEmail} | ${padTipo} | ${padAntig} | ${padNueva} | ${padRls} | ${padMut}`);

    if (!r.nuevaAceptada) todasNuevasOk = false;
    if (!r.antiguaRechazada) todasAntiguasRechazadas = false;
  }

  console.log('-'.repeat(105));
  console.log(`\nResumen de auditoría:`);
  console.log(`• Cuentas con credenciales nuevas activas y funcionales:  ${resultados.filter(r => r.nuevaAceptada).length} / ${resultados.length}`);
  console.log(`• Cuentas con credenciales antiguas inválidas/rechazadas: ${resultados.filter(r => r.antiguaRechazada).length} / ${resultados.length}`);
  console.log(`• Registros creados o modificados en la base de datos:    0 (Garantía estricta de solo lectura)\n`);

  if (!todasNuevasOk || !todasAntiguasRechazadas) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Error no controlado en verificación de login:', err.message);
  process.exit(1);
});
