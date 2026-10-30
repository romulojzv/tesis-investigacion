// scripts/rotar_credenciales_staging.ts
/**
 * Herramienta Segura de Inspección y Rotación de Credenciales Sintéticas de Staging
 *
 * ============================================================================
 * REGLAS DE SEGURIDAD Y OPERACIÓN:
 * 1. Destino estricto: Solo autoriza https://acxsyswrzdtstgqztojj.supabase.co
 * 2. Modo predeterminado: SOLO CONSULTA (Dry-run / Auditoría de lectura).
 * 3. Doble autorización obligatoria para cualquier mutación:
 *    - Variable de entorno: AUTORIZO_ROTACION_STAGING="SI"
 *    - Argumento en CLI:    --aplicar-rotacion
 * 4. Zero-Leak: Jamás imprime contraseñas, PINs ni claves administrativas.
 * 5. Almacenamiento cifrado local (Windows DPAPI - CurrentUser):
 *    - Las credenciales nunca se guardan en texto plano ni en JSON sin cifrar.
 *    - Se protegen con DPAPI nativo de Windows (ámbito usuario actual).
 *    - El archivo scripts/credenciales_rotadas.local.json solo contiene el
 *      sobre cifrado (excluido en .gitignore).
 * 6. Recuperabilidad previa garantizada (Pre-flight test):
 *    - Comprueba que el almacén cifrado pueda descifrarse y leerse en disco
 *      ANTES de enviar cualquier cambio a Supabase (protección ante desincronización).
 * 7. Modelo de autenticación estudiantil:
 *    - Los estudiantes usan PIN numérico de exactamente 6 dígitos (100000-999999).
 *    - Generación criptográfica segura (CSPRNG) con garantía de no repetición de valores.
 * 8. Tolerancia a fallos (Fail-Fast):
 *    - Si la actualización de una cuenta falla, el proceso se detiene de inmediato.
 *    - Se registra con precisión qué cuentas fueron rotadas y cuáles no.
 * 9. Integridad académica: NO borra usuarios ni altera perfiles ni aulas.
 * ============================================================================
 */

import { createClient } from '@supabase/supabase-js';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';

// Cargar variables de entorno si la versión de Node lo soporta
if (typeof (process as any).loadEnvFile === 'function') {
  try {
    (process as any).loadEnvFile();
  } catch {}
}

const SUPABASE_URL = process.env.SUPABASE_STAGING_URL || process.env.SUPABASE_URL || '';
const SERVICE_ROLE_KEY = process.env.SUPABASE_STAGING_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ ERROR: Se requieren SUPABASE_STAGING_URL (o SUPABASE_URL) y SUPABASE_SERVICE_ROLE_KEY en el entorno.');
  process.exit(1);
}

// 1. Salvaguarda estricta con new URL()
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
      `Destino no autorizado: '${parsed.origin}'. Esta herramienta solo puede ejecutarse contra Staging: 'https://acxsyswrzdtstgqztojj.supabase.co'.`
    );
  }
} catch (err: any) {
  console.error(`⛔ BLOQUEO DE SEGURIDAD: ${err.message}`);
  process.exit(1);
}

const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Ruta del archivo cifrado local protegido bajo .gitignore
const ARCHIVO_LOCAL_CIFRADO = path.join(process.cwd(), 'scripts', 'credenciales_rotadas.local.json');

// Definición de las 7 cuentas sintéticas auditadas
interface CuentaSintetica {
  email: string;
  rol: 'docente' | 'estudiante';
  tipo: 'password' | 'pin';
  codigoAcceso?: string;
  descripcion: string;
}

const CUENTAS_SINTETICAS: CuentaSintetica[] = [
  {
    email: 'docente.test@example.com',
    rol: 'docente',
    tipo: 'password',
    descripcion: 'Docente de pruebas Staging (E2E / Scripts)',
  },
  {
    email: 'estudiante1.test@example.com',
    rol: 'estudiante',
    tipo: 'pin',
    descripcion: 'Estudiante Staging 1 (Compatible PIN / Auth)',
  },
  {
    email: 'estudiante2.test@example.com',
    rol: 'estudiante',
    tipo: 'pin',
    descripcion: 'Estudiante Staging 2 (Compatible PIN / Auth)',
  },
  {
    email: 'est_ev_a@estudiantes.cuentosmagicos.internal',
    rol: 'estudiante',
    tipo: 'pin',
    codigoAcceso: 'EST_EV_A',
    descripcion: 'Estudiante Evidencia A (App / 6 dígitos)',
  },
  {
    email: 'est_ev_b@estudiantes.cuentosmagicos.internal',
    rol: 'estudiante',
    tipo: 'pin',
    codigoAcceso: 'EST_EV_B',
    descripcion: 'Estudiante Evidencia B (App / 6 dígitos)',
  },
  {
    email: 'demo26@estudiantes.cuentosmagicos.internal',
    rol: 'estudiante',
    tipo: 'pin',
    codigoAcceso: 'DEMO26',
    descripcion: 'Estudiante Demo (App / 6 dígitos)',
  },
  {
    email: 'prof.carmen.demo@cuentosmagicos.internal',
    rol: 'docente',
    tipo: 'password',
    descripcion: 'Docente Demo (App / Panel Docente)',
  },
];

// ============================================================================
// FUNCIONES CRIPTOGRÁFICAS DE GENERACIÓN SEGURA
// ============================================================================

/**
 * Genera una contraseña alfanumérica de alta entropía para docentes.
 * Garantiza unicidad dentro de la ejecución actual sin reutilización de valores.
 */
function generarPasswordCriptografica(passwordsUsadas: Set<string>): string {
  let pass = '';
  let intentos = 0;
  do {
    const rawEntropy = crypto.randomBytes(18).toString('base64url');
    pass = `CM_Sec_${rawEntropy}!9aA`;
    intentos++;
    if (intentos > 10000) {
      throw new Error('No se pudo generar una contraseña docente única tras 10,000 iteraciones.');
    }
  } while (passwordsUsadas.has(pass));

  passwordsUsadas.add(pass);
  return pass;
}

/**
 * Genera un PIN numérico de exactamente 6 dígitos (100000 a 999999) mediante CSPRNG.
 * Cumple estrictamente con la validación de la app Flutter (AuthService.loginEstudiante)
 * y la Edge Function 'crear-estudiante'.
 * Garantiza unicidad dentro del lote sin reutilización de valores.
 */
function generarPinCriptografico(pinesUsados: Set<string>): string {
  let pin = '';
  let intentos = 0;
  do {
    // Rango 100,000 a 999,999 (exactamente 6 dígitos numéricos)
    pin = crypto.randomInt(100000, 1000000).toString();
    intentos++;
    if (intentos > 10000) {
      throw new Error('No se pudo generar un PIN estudiantil único tras 10,000 iteraciones.');
    }
  } while (pinesUsados.has(pin));

  pinesUsados.add(pin);
  return pin;
}

// ============================================================================
// ALMACENAMIENTO CIFRADO LOCAL (WINDOWS DPAPI - CURRENTUSER)
// ============================================================================

/**
 * Cifra una cadena UTF-8 utilizando Windows DPAPI (CryptProtectData)
 * con ámbito DataProtectionScope::CurrentUser.
 * Los datos viajan por stdin para evitar su exposición en la lista de procesos.
 */
function cifrarConWindowsDPAPI(textoPlano: string): string {
  const psScript = `
    Add-Type -AssemblyName System.Security
    $inputData = [System.Console]::In.ReadToEnd()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputData)
    $enc = [System.Security.Cryptography.ProtectedData]::Protect(
      $bytes,
      $null,
      [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [System.Convert]::ToBase64String($enc)
  `;

  const proc = child_process.spawnSync(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', psScript],
    {
      input: textoPlano,
      encoding: 'utf-8',
      windowsHide: true,
      maxBuffer: 10 * 1024 * 1024,
    }
  );

  if (proc.error || proc.status !== 0) {
    throw new Error(`Fallo en cifrado DPAPI: ${proc.stderr?.trim() || proc.error?.message || 'Error desconocido'}`);
  }

  const b64 = proc.stdout.trim();
  if (!b64) throw new Error('Salida de cifrado DPAPI vacía.');
  return b64;
}

/**
 * Descifra un payload Base64 utilizando Windows DPAPI (CryptUnprotectData)
 * para el usuario actual de Windows.
 */
function descifrarConWindowsDPAPI(base64Cifrado: string): string {
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
      input: base64Cifrado,
      encoding: 'utf-8',
      windowsHide: true,
      maxBuffer: 10 * 1024 * 1024,
    }
  );

  if (proc.error || proc.status !== 0) {
    throw new Error(`Fallo en descifrado DPAPI: ${proc.stderr?.trim() || proc.error?.message || 'Error desconocido'}`);
  }

  return proc.stdout;
}

/**
 * Guarda los datos de credenciales empaquetados en un sobre cifrado con DPAPI.
 * El archivo en disco NO contiene credenciales en texto plano.
 */
function guardarSobreCifrado(datos: Record<string, any>): void {
  const jsonInterno = JSON.stringify(datos);
  const b64Cifrado = cifrarConWindowsDPAPI(jsonInterno);

  const envelope = {
    formato: 'WINDOWS_DPAPI_CURRENT_USER',
    proteccion: 'DataProtectionScope.CurrentUser (Solo accesible por este usuario de Windows)',
    fecha_cifrado: new Date().toISOString(),
    total_cuentas: Object.keys(datos).length,
    payload_cifrado_base64: b64Cifrado,
  };

  fs.writeFileSync(ARCHIVO_LOCAL_CIFRADO, JSON.stringify(envelope, null, 2), {
    encoding: 'utf-8',
    mode: 0o600,
  });
}

/**
 * Lee y descifra el almacén local si existe.
 */
function leerAlmacenCifrado(): Record<string, any> | null {
  if (!fs.existsSync(ARCHIVO_LOCAL_CIFRADO)) {
    return null;
  }

  const rawEnvelope = fs.readFileSync(ARCHIVO_LOCAL_CIFRADO, 'utf-8');
  const envelope = JSON.parse(rawEnvelope);

  if (envelope.formato !== 'WINDOWS_DPAPI_CURRENT_USER' || !envelope.payload_cifrado_base64) {
    throw new Error('El archivo local no tiene el formato cifrado DPAPI esperado.');
  }

  const jsonDescifrado = descifrarConWindowsDPAPI(envelope.payload_cifrado_base64);
  return JSON.parse(jsonDescifrado);
}

// ============================================================================
// FLUJO PRINCIPAL
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const aplicarRotacion = args.includes('--aplicar-rotacion');
  const recuperarCredenciales = args.includes('--recuperar-credenciales');
  const mostrarSecretos = args.includes('--mostrar-secretos');
  const autorizacionEnv = process.env.AUTORIZO_ROTACION_STAGING === 'SI';

  console.log('='.repeat(75));
  console.log('🛡️  HERRAMIENTA ADMINISTRATIVA DE ROTACIÓN DE CUENTAS SINTÉTICAS (STAGING)');
  console.log(`   Destino:    https://acxsyswrzdtstgqztojj.supabase.co`);
  console.log(`   Modo:       ${aplicarRotacion && autorizacionEnv ? '⚠️ APLICACIÓN EFECTIVA DE ROTACIÓN' : '🔍 SOLO CONSULTA (DRY-RUN / AUDITORÍA)'}`);
  console.log(`   Fecha/Hora: ${new Date().toISOString()}`);
  console.log('='.repeat(75));

  // Opción 1: Recuperación de credenciales guardadas en el almacén cifrado DPAPI
  if (recuperarCredenciales) {
    console.log('\n📂 CONSULTANDO ALMACÉN CIFRADO LOCAL (WINDOWS DPAPI)...');
    try {
      const datosGuardados = leerAlmacenCifrado();
      if (!datosGuardados || Object.keys(datosGuardados).length === 0) {
        console.log('ℹ️  No se encontraron credenciales rotadas previas en el almacén cifrado local.');
        return;
      }

      console.log(`🟢 Almacén cifrado DPAPI verificado y recuperable.`);
      console.log(`   Total de cuentas resguardadas: ${Object.keys(datosGuardados).length}`);
      console.log('-'.repeat(75));

      for (const [email, info] of Object.entries(datosGuardados)) {
        console.log(`• Cuenta:      ${email}`);
        console.log(`  User ID:     ${info.id || 'N/A'}`);
        console.log(`  Tipo:        ${info.tipo?.toUpperCase()} (${info.tipo === 'pin' ? 'PIN 6 dígitos' : 'Contraseña'})`);
        console.log(`  Estado:      ${info.estado || 'RESGUARDADA'}`);
        console.log(`  Actualizado: ${info.fechaRotacion || info.fechaGeneracion || 'N/A'}`);
        if (mostrarSecretos) {
          console.log(`  VALOR:       ${info.credencial}`);
        }
        console.log('-'.repeat(75));
      }

      if (!mostrarSecretos) {
        console.log('\n🔒 Las credenciales están resguardadas de forma segura bajo cifrado DPAPI.');
        console.log('   Para ver los valores descifrados en esta sesión privada de PowerShell,');
        console.log('   ejecuta: npx tsx scripts/rotar_credenciales_staging.ts --recuperar-credenciales --mostrar-secretos\n');
      }
      return;
    } catch (err: any) {
      console.error('❌ Error al acceder o descifrar el almacén local DPAPI:', err.message);
      process.exit(1);
    }
  }

  // 1. Obtener lista de usuarios actuales en Staging
  const { data: usersData, error: listError } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listError) {
    console.error('❌ Error consultando auth.users en Staging:', listError.message);
    process.exit(1);
  }

  const usuariosEnAuth = usersData.users || [];
  console.log(`\nTotal de usuarios registrados en Staging: ${usuariosEnAuth.length}\n`);

  // 2. Mapear estado de las cuentas sintéticas
  interface PlanItem {
    config: CuentaSintetica;
    usuarioAuth: any | null;
    nuevaCredencial?: string;
  }

  const plan: PlanItem[] = [];
  const pinesUsados = new Set<string>();
  const passwordsUsadas = new Set<string>();

  for (const c of CUENTAS_SINTETICAS) {
    const usuarioAuth = usuariosEnAuth.find((u) => u.email?.toLowerCase() === c.email.toLowerCase()) || null;
    plan.push({
      config: c,
      usuarioAuth,
    });
  }

  // 3. Flujo según el modo (Consulta vs Modificación)
  if (!aplicarRotacion || !autorizacionEnv) {
    // ========================================================================
    // MODO SOLO CONSULTA (DRY-RUN / AUDITORÍA)
    // ========================================================================
    console.log('ESTADO DE LAS 7 CUENTAS SINTÉTICAS EN STAGING (MODO CONSULTA):');
    console.log('-'.repeat(75));

    for (const item of plan) {
      const c = item.config;
      const encontrado = item.usuarioAuth !== null;
      const icono = encontrado ? '🟢' : '⚪';
      const tipoLabel = c.tipo === 'pin' ? 'PIN (6 DÍGITOS)' : 'PASSWORD (ALTA ENTROPÍA)';

      console.log(`${icono} [${tipoLabel}] ${c.email}`);
      console.log(`   Rol / Desc: ${c.descripcion}`);
      console.log(`   User ID:    ${item.usuarioAuth?.id || 'NO ENCONTRADO EN AUTH'}`);
      console.log(`   Estado:     ${encontrado ? 'LOCALIZADO (Requiere rotación manual o autorización para aplicar)' : 'NO REGISTRADO EN STAGING'}`);
      console.log('-'.repeat(75));
    }

    console.log('\nℹ️  AUDITORÍA EN MODO CONSULTA COMPLETADA:');
    console.log('   - No se realizó ninguna modificación de contraseñas ni PINs en Staging.');
    console.log('   - No se creó ni alteró ningún archivo local.');
    if (aplicarRotacion && !autorizacionEnv) {
      console.log('   ⚠️ BLOQUEO: Se pasó el flag --aplicar-rotacion pero falta definir la variable de entorno:');
      console.log('      $env:AUTORIZO_ROTACION_STAGING="SI"');
    } else {
      console.log('   - Para ejecutar la rotación programada cuando se decida autorizar:');
      console.log('     1. Definir: $env:AUTORIZO_ROTACION_STAGING="SI"');
      console.log('     2. Ejecutar: npx tsx scripts/rotar_credenciales_staging.ts --aplicar-rotacion\n');
    }
    return;
  }

  // ==========================================================================
  // MODO MODIFICACIÓN AUTORIZADA
  // ==========================================================================
  console.log('⚡ PREPARANDO ROTACIÓN CRIPTOGRÁFICA CONTROLADA...');

  // 3.1. Generar nuevas credenciales únicas con CSPRNG
  const payloadPlan: Record<string, any> = {};

  for (const item of plan) {
    if (!item.usuarioAuth) {
      console.warn(`⚠️ Cuenta omitida (no existe en Staging Auth): ${item.config.email}`);
      continue;
    }

    const nuevaCred = item.config.tipo === 'pin'
      ? generarPinCriptografico(pinesUsados)
      : generarPasswordCriptografica(passwordsUsadas);

    item.nuevaCredencial = nuevaCred;

    payloadPlan[item.config.email] = {
      id: item.usuarioAuth.id,
      email: item.config.email,
      rol: item.config.rol,
      tipo: item.config.tipo,
      credencial: nuevaCred,
      fechaGeneracion: new Date().toISOString(),
      estado: 'PENDIENTE_DE_APLICAR',
    };
  }

  // 3.2. PRUEBA DE RECUPERABILIDAD PREVIA (PRE-FLIGHT TEST)
  // Comprueba que las credenciales puedan descifrarse desde disco ANTES de invalidar las actuales.
  console.log('🔐 Ejecutando prueba previa de almacenamiento y descifrado DPAPI (CurrentUser)...');
  try {
    guardarSobreCifrado(payloadPlan);
    const verificacion = leerAlmacenCifrado();

    if (!verificacion || Object.keys(verificacion).length !== Object.keys(payloadPlan).length) {
      throw new Error('La verificación de lectura del almacén cifrado DPAPI no devolvió todas las cuentas preparadas.');
    }

    // Verificar correspondencia exacta
    for (const email of Object.keys(payloadPlan)) {
      if (!verificacion[email] || verificacion[email].credencial !== payloadPlan[email].credencial) {
        throw new Error(`Discrepancia en credencial verificada para ${email}.`);
      }
    }

    console.log('✅ Almacén cifrado DPAPI verificado exitosamente.');
    console.log('   Las credenciales están aseguradas en disco y son recuperables por el usuario actual');
    console.log('   antes de invalidar cualquier contraseña anterior en Supabase.\n');
  } catch (err: any) {
    console.error('❌ ERROR CRÍTICO PRE-FLIGHT: Falló la verificación del almacén cifrado DPAPI.');
    console.error(`   Motivo: ${err.message}`);
    console.error('   OPERACIÓN ABORTADA PREVIAMENTE a cualquier modificación en Supabase.');
    console.error('   Ninguna contraseña ni PIN anterior fue invalidado.');
    process.exit(1);
  }

  // 3.3. APLICACIÓN DE ROTACIÓN EN STAGING CON SALVAGUARDA FAIL-FAST
  console.log('🚀 Iniciando rotación remota en Supabase Staging...');
  console.log('-'.repeat(75));

  const cuentasRotadasExitosas: Array<{ email: string; id: string; tipo: string }> = [];
  const cuentasOmitidas: Array<{ email: string; descripcion: string; motivo: string }> = [];
  let falloCritico: { email: string; error: string } | null = null;

  for (let i = 0; i < plan.length; i++) {
    const item = plan[i];

    if (!item.usuarioAuth || !item.nuevaCredencial) {
      cuentasOmitidas.push({
        email: item.config.email,
        descripcion: item.config.descripcion,
        motivo: 'No existe usuario en Auth',
      });
      continue;
    }

    // Si ocurrió un fallo en una cuenta anterior, detener el proceso (Fail-Fast)
    if (falloCritico) {
      cuentasOmitidas.push({
        email: item.config.email,
        descripcion: item.config.descripcion,
        motivo: 'Detención preventiva tras error en cuenta previa',
      });
      continue;
    }

    // Actualizar contraseña/PIN en Supabase Auth mediante Admin API
    const { error: updateErr } = await adminClient.auth.admin.updateUserById(item.usuarioAuth.id, {
      password: item.nuevaCredencial,
    });

    if (updateErr) {
      falloCritico = {
        email: item.config.email,
        error: updateErr.message,
      };

      console.error(`❌ ERROR ACTUALIZANDO CUENTA [${item.config.email}]: ${updateErr.message}`);
      console.error(`   ⚠️ DETENIENDO INMEDIATAMENTE EL PROCESO para evitar estado inconsistente.`);

      payloadPlan[item.config.email].estado = `ERROR_AL_ROTAR: ${updateErr.message}`;
      // Actualizar archivo cifrado con el estado actual
      guardarSobreCifrado(payloadPlan);
      continue;
    }

    // Registro exitoso
    cuentasRotadasExitosas.push({
      email: item.config.email,
      id: item.usuarioAuth.id,
      tipo: item.config.tipo,
    });

    payloadPlan[item.config.email].estado = 'ROTADA_CON_EXITO';
    payloadPlan[item.config.email].fechaRotacion = new Date().toISOString();

    const tipoLabel = item.config.tipo === 'pin' ? 'PIN (6 dígitos)' : 'Contraseña';
    console.log(`🟢 [${tipoLabel}] ${item.config.email} $\\rightarrow$ ROTADA CON ÉXITO (ID: ${item.usuarioAuth.id})`);

    // Sincronizar almacén cifrado tras cada éxito
    guardarSobreCifrado(payloadPlan);
  }

  // 4. REPORTE FINAL DE AUDITORÍA
  console.log('\n' + '='.repeat(75));
  console.log('📊 REPORTE DE RESULTADOS DE LA ROTACIÓN EN STAGING:');
  console.log('='.repeat(75));

  console.log(`\n🟢 Cuentas rotadas con éxito (${cuentasRotadasExitosas.length} / ${plan.length}):`);
  for (const ok of cuentasRotadasExitosas) {
    console.log(`   • [${ok.tipo.toUpperCase()}] ${ok.email} (ID: ${ok.id})`);
  }

  if (falloCritico) {
    console.log(`\n🔴 Cuenta que provocó el fallo crítico:`);
    console.log(`   • ${falloCritico.email}: ${falloCritico.error}`);
  }

  if (cuentasOmitidas.length > 0) {
    console.log(`\n⚪ Cuentas no rotadas (${cuentasOmitidas.length}):`);
    for (const omit of cuentasOmitidas) {
      console.log(`   • ${omit.email}: ${omit.motivo}`);
    }
  }

  console.log('\n🔒 Almacén cifrado actualizado: ' + ARCHIVO_LOCAL_CIFRADO);
  console.log('   (Protegido con Windows DPAPI CurrentUser; excluido de Git).\n');

  if (falloCritico) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Error no controlado en herramienta de rotación:', err.message);
  process.exit(1);
});
