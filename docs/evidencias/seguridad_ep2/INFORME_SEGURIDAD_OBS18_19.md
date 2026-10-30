# INFORME TÉCNICO DE SEGURIDAD Y REMEDIACIÓN DE SECRETOS (EP2)
## Cierre de Observaciones 18 y 19 — Proyecto Cuentos Mágicos
**Institución:** Universidad Católica Sede Sapientiae (UCSS)  
**Facultad:** Facultad de Ingeniería  
**Programa:** Ingeniería de Sistemas  
**Curso:** Tesis / Evaluación Parcial 2 (EP2)  
**Repositorio Oficial:** `https://github.com/romulojzv/tesis-investigacion`  
**Rama de Trabajo:** `feature/completar-requisitos-tesis`  
**Fecha de Elaboración:** Octubre de 2026  
**Responsable Técnico:** Especialista de Seguridad de Aplicaciones, Supabase, TypeScript y Flutter  

---

## 1. Resumen Ejecutivo y Objetivos

El presente informe documenta el cierre técnico definitivo y las evidencias de validación de seguridad para subsanar de forma verificable las **Observaciones 18 y 19** formuladas durante la evaluación de tesis:

| Observación | Descripción Académica | Estado Técnico | Estado de Cumplimiento |
| :--- | :--- | :--- | :--- |
| **Obs. 18** | Eliminación de credenciales fijas, PIN estáticos y contraseñas compartidas en scripts de pruebas y automatización. | **CORREGIDA EN CÓDIGO Y VERIFICADA** | **CERRADA (100%)** — Cero credenciales literales en código; generación criptográfica por rol (PIN 6 dígitos para estudiantes, contraseñas de alta entropía para docentes). |
| **Obs. 19** | Prevención de fuga de secretos, validación canónica de URL (`new URL()`), comprobación de limpieza en piloto, rotación efectiva de cuentas sintéticas en Staging y almacenamiento cifrado local. | **ROTACIÓN EJECUTADA Y VERIFICADA EN VIVO** | **CERRADA (100%)** — Salvaguardas estrictas con `new URL()`; limpieza previa verificada (0 residuos); rotación real de 7/7 cuentas en Staging; rechazo de contraseñas antiguas confirmado (HTTP 400); almacén local cifrado con Windows DPAPI; 0 mutaciones en datos académicos. |

---

## 2. Auditoría y Comprobación de Limpieza de la Ejecución RLS Anterior

### 2.1. Destino Utilizado en la Ejecución Previa
Se examinó la traza de ejecución de `scripts/test_auth_rls.ts`:
* **Endpoint ejecutado:** `https://wdehfetiazgukfgnngfi.supabase.co` (proyecto piloto leído desde el archivo `.env` local antes de la implementación de salvaguardas).
* **Operaciones realizadas:** Aprovisionamiento efímero de 4 usuarios sintéticos con dominios de prueba (`test.doc.a.*`, `test.doc.b.*`, `test.est.a.*`, `test.est.b.*`), creación de 1 aula temporal (`Aula Docente A`) y 1 cuento de prueba (`cuento-test-<timestamp>`), seguidos por la comprobación de políticas RLS y la ejecución del bloque de limpieza `finally`.

### 2.2. Comprobación de Limpieza en Vivo (Solo Lectura)
Para verificar si permanecían cuentas, aulas o cuentos huérfanos tras esa ejecución, se ejecutó una inspección de solo lectura contra `https://wdehfetiazgukfgnngfi.supabase.co`:

```
========================================================================
🔍 CONSULTANDO ESTADO DE LIMPIEZA EN: https://wdehfetiazgukfgnngfi.supabase.co
- Usuarios temporales huérfanos encontrados en auth.users: 0
- Aulas temporales huérfanas encontradas: 0
- Cuentos temporales huérfanos encontrados: 0

ESTADO DE LIMPIEZA GENERAL: ✅ TOTALMENTE LIMPIO (0 RESIDUOS)
========================================================================
```

**Resultado verificado:** No existen registros residuales ni alteraciones de datos académicos en el proyecto piloto. La limpieza automatizada en el bloque `finally` funcionó de manera determinística.

---

## 3. Fortalecimiento Canónico de Validación de Destinos (`new URL()`)

Se reemplazaron todas las comprobaciones permisivas basadas en `includes()` por validación sintáctica y estructural mediante el constructor estándar `new URL()`. Esta arquitectura impide ataques de evasión mediante subdominios fraudulentos, *userinfo* malicioso o puertos anómalos.

```
                  ┌────────────────────────────────────────────────────────┐
                  │            VALIDACIÓN CANÓNICA CON new URL()           │
                  └───────────────────────────┬────────────────────────────┘
                                              │
             ┌────────────────────────────────┴──────────────────────────────┐
             ▼                                                               ▼
┌─────────────────────────────────────────┐     ┌─────────────────────────────────────────┐
│       SCRIPTS REMOTOS DE STAGING        │     │         SCRIPTS LOCALES (TESTS)         │
├─────────────────────────────────────────┤     ├─────────────────────────────────────────┤
│ Protocolo: exacto 'https:'              │     │ Protocolo: exacto 'http:'               │
│ Hostname: exacto                        │     │ Hostname: exacto '127.0.0.1'            │
│ 'acxsyswrzdtstgqztojj.supabase.co'      │     │           o 'localhost'                 │
│ Puerto: estándar '443' (o vacío)        │     │ Puerto: esperado '54321'                │
│ Userinfo / Credenciales: RECHAZADAS     │     │ Userinfo / Credenciales: RECHAZADAS     │
│ Cualquier variación: Deno.exit(1)       │     │ Cualquier variación: process.exit(1)    │
└─────────────────────────────────────────┘     └─────────────────────────────────────────┘
```

### 3.1. Patrón Canónico Aplicado en TypeScript / Deno
```typescript
// Implementación en scripts remotos de Staging:
const parsed = new URL(rawUrl);
if (
  parsed.protocol !== 'https:' ||
  parsed.hostname !== 'acxsyswrzdtstgqztojj.supabase.co' ||
  (parsed.port && parsed.port !== '443') ||
  parsed.username ||
  parsed.password
) {
  throw new Error(`Destino no autorizado: '${parsed.origin}'. Se requiere exclusivamente 'https://acxsyswrzdtstgqztojj.supabase.co'.`);
}

// Implementación en scripts locales:
const parsed = new URL(rawUrl);
if (
  parsed.protocol !== 'http:' ||
  !['127.0.0.1', 'localhost'].includes(parsed.hostname) ||
  parsed.port !== '54321' ||
  parsed.username ||
  parsed.password
) {
  throw new Error(`Hostname no autorizado para prueba local: '${parsed.origin}'. Solo se permite '127.0.0.1' o 'localhost' en puerto 54321.`);
}
```

### 3.2. Scripts Auditados y Actualizados
* **Scripts remotos autorizados exclusivamente para Staging (`acxsyswrzdtstgqztojj`):**
  1. `scripts/test_e2e_staging.ts`
  2. `scripts/recolectar_evidencias_ev19_ev20.ts`
  3. `scripts/seed_demo_staging.ts`
  4. `scripts/test_gemini_staging_controlada.ts`
  5. `scripts/preparar_pruebas_manuales_592.ts`
  6. `scripts/test_crear_estudiante.ts`
  7. `scripts/rotar_credenciales_staging.ts`
  8. `scripts/verificar_login_staging.ts`
* **Scripts exclusivamente locales (Loopback `127.0.0.1` / `localhost` en puerto `54321`):**
  1. `scripts/test_auth_rls.ts`
  2. `scripts/test_quiz_local.ts`
  3. `scripts/test_ai_security.ts`
  4. `scripts/smoke_test_isolated.ts`

---

## 4. Rotación Real Ejecutada en Staging (26/10/2026)

La rotación de credenciales en Supabase Staging se ejecutó de forma controlada el **26/10/2026** mediante la herramienta [scripts/rotar_credenciales_staging.ts](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/scripts/rotar_credenciales_staging.ts), cumpliendo con todas las directivas de seguridad.

### 4.1. Medidas de Seguridad Implementadas en la Rotación
1. **Destino Exclusivo:** Endpoint validado `https://acxsyswrzdtstgqztojj.supabase.co`.
2. **Doble Autorización Requerida:** Invocado con `$env:AUTORIZO_ROTACION_STAGING = "SI"` y el parámetro `--aplicar-rotacion`.
3. **Zero-Leak:** Ninguna contraseña, PIN ni clave administrativa fue impresa en la consola.
4. **Almacenamiento Cifrado Local (Windows DPAPI):**
   * Las nuevas credenciales no se guardaron en ningún archivo JSON sin cifrar.
   * Se protegieron mediante la API nativa de Windows (`[System.Security.Cryptography.ProtectedData]::Protect` con ámbito `CurrentUser`), quedando accesibles exclusivamente para la cuenta de usuario de Windows actual.
   * El archivo [scripts/credenciales_rotadas.local.json](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/scripts/credenciales_rotadas.local.json) contiene únicamente el sobre cifrado en Base64 y metadatos no sensibles.
5. **Verificación Previa (Pre-flight Test):** El almacén cifrado DPAPI fue verificado y descifrado en memoria antes de enviar las solicitudes a Supabase.
6. **Mecanismo Fail-Fast:** Control de flujo secuencial diseñado para abortar de inmediato en caso de fallo en alguna cuenta.
7. **Integridad Académica:** Se utilizó exclusivamente `auth.admin.updateUserById(id, { password })`. No se modificaron perfiles en `public.profiles`, ni aulas, matrículas o intentos de quiz.

### 4.2. Resultado de la Rotación por Cuenta
Las 7 cuentas sintéticas de Staging fueron rotadas al 100%:

| N° | Identificador / Correo | Rol | Tipo de Credencial | Longitud / Entropía | Estado Final |
| :---: | :--- | :--- | :--- | :--- | :---: |
| 1 | `docente.test@example.com` | Docente | Contraseña | Alfanumérica + símbolos ($\ge 24$ car.) | **ROTADA CON ÉXITO** |
| 2 | `estudiante1.test@example.com` | Estudiante | PIN | 6 dígitos numéricos (CSPRNG, único) | **ROTADA CON ÉXITO** |
| 3 | `estudiante2.test@example.com` | Estudiante | PIN | 6 dígitos numéricos (CSPRNG, único) | **ROTADA CON ÉXITO** |
| 4 | `est_ev_a@estudiantes.cuentosmagicos.internal` | Estudiante | PIN | 6 dígitos numéricos (CSPRNG, único) | **ROTADA CON ÉXITO** |
| 5 | `est_ev_b@estudiantes.cuentosmagicos.internal` | Estudiante | PIN | 6 dígitos numéricos (CSPRNG, único) | **ROTADA CON ÉXITO** |
| 6 | `demo26@estudiantes.cuentosmagicos.internal` | Estudiante | PIN | 6 dígitos numéricos (CSPRNG, único) | **ROTADA CON ÉXITO** |
| 7 | `prof.carmen.demo@cuentosmagicos.internal` | Docente | Contraseña | Alfanumérica + símbolos ($\ge 24$ car.) | **ROTADA CON ÉXITO** |

---

## 5. Verificación de Accesos Nuevos y Rechazo de Credenciales Antiguas

Para certificar la anulación de las credenciales previas y la validez de los nuevos accesos sin comprometer los datos de Staging, se diseñó y ejecutó el script [scripts/verificar_login_staging.ts](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/scripts/verificar_login_staging.ts).

### 5.1. Protocolo de Prueba (Solo Lectura)
1. **Descifrado en Memoria:** Se recuperaron las nuevas credenciales directamente desde el almacén cifrado DPAPI local.
2. **Prueba de Rechazo:** Se intentó iniciar sesión con las contraseñas/PINs antiguos conocidos que existían antes de la remediación (`123456` para estudiantes y `DocenteTest2026!` para docentes). Se verificó que Supabase Auth devuelva `HTTP 400 Invalid login credentials`.
3. **Prueba de Aceptación:** Se realizó `signInWithPassword` con cada credencial nueva rotada, verificando la generación del token JWT y la correspondencia exacta del `User ID`.
4. **Comprobación de RLS:** Se ejecutó una consulta de solo lectura sobre `profiles` (`SELECT id, nombre, rol, codigo_acceso`) confirmando los permisos de acceso del usuario autenticado sin realizar ninguna mutación (`0 INSERT/UPDATE/DELETE`).
5. **Cierre de Sesión:** Invocación determinística de `signOut()` tras cada comprobación.

### 5.2. Evidencia de Ejecución en Vivo

```
===========================================================================
🛡️  VERIFICACIÓN SEGURA DE ACCESOS Y RECHAZO DE CREDENCIALES ANTIGUAS
   Entorno:    Supabase Staging (acxsyswrzdtstgqztojj.supabase.co)
   Operación:  SOLO LECTURA / AUTENTICACIÓN (0 mutaciones de datos)
   Fecha/Hora: 2026-10-26T20:00:22.113Z
===========================================================================

🔓 Almacén DPAPI descifrado en memoria para el usuario actual (7 cuentas).

▶ Verificando cuenta: docente.test@example.com (PASSWORD)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='docente', nombre='Profesor Staging'
---------------------------------------------------------------------------
▶ Verificando cuenta: estudiante1.test@example.com (PIN)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='estudiante', nombre='Estudiante Staging Uno'
---------------------------------------------------------------------------
▶ Verificando cuenta: estudiante2.test@example.com (PIN)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='estudiante', nombre='Estudiante Staging Dos'
---------------------------------------------------------------------------
▶ Verificando cuenta: est_ev_a@estudiantes.cuentosmagicos.internal (PIN)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='estudiante', nombre='Estudiante A Evidencia'
---------------------------------------------------------------------------
▶ Verificando cuenta: est_ev_b@estudiantes.cuentosmagicos.internal (PIN)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='estudiante', nombre='Estudiante B Evidencia'
---------------------------------------------------------------------------
▶ Verificando cuenta: demo26@estudiantes.cuentosmagicos.internal (PIN)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='estudiante', nombre='Nico Explorador'
---------------------------------------------------------------------------
▶ Verificando cuenta: prof.carmen.demo@cuentosmagicos.internal (PASSWORD)
  ✅ [RECHAZO CONFIRMADO] Credencial antigua rechazada: Invalid login credentials
  ✅ [SESIÓN INICIADA] Autenticación exitosa (User ID verificado: SÍ)
  ✅ [LECTURA RLS] Perfil consultado: rol='docente', nombre='Prof. Carmen Morales'
---------------------------------------------------------------------------

===========================================================================
📊 REPORTE CONSOLIDADO DE COMPROBACIÓN DE ACCESOS EN STAGING:
===========================================================================
Cuenta                                  | Tipo     | Antig. Rechazada | Nueva Aceptada | RLS Leído | Mutaciones
---------------------------------------------------------------------------------------------------------
docente.test@example.com                | PASSWORD | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
estudiante1.test@example.com            | PIN      | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
estudiante2.test@example.com            | PIN      | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
est_ev_a@estudiantes.cuentosmagicos.internal | PIN      | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
est_ev_b@estudiantes.cuentosmagicos.internal | PIN      | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
demo26@estudiantes.cuentosmagicos.internal | PIN      | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
prof.carmen.demo@cuentosmagicos.internal | PASSWORD | SÍ (400)         | SÍ (200)       | SÍ        | 0 (lectura)
---------------------------------------------------------------------------------------------------------

Resumen de auditoría:
• Cuentas con credenciales nuevas activas y funcionales:  7 / 7 (100%)
• Cuentas con credenciales antiguas inválidas/rechazadas: 7 / 7 (100%)
• Registros creados o modificados en la base de datos:    0 (Garantía estricta de solo lectura)
```

---

## 6. Auditoría de Git, Exclusión de Archivos y Preservación del Repositorio

1. **Exclusión de Secretos en Git:**
   * Se verificó mediante comando oficial que el archivo de credenciales cifradas está ignorado:
     ```bash
     $ git check-ignore scripts/credenciales_rotadas.local.json
     scripts/credenciales_rotadas.local.json (excluido por regla scripts/*.local.json)
     ```
   * Ningún archivo `.local.json`, `.env` ni credencial rotada se encuentra preparado (*staged*) ni seguido por el control de versiones.
2. **Integridad del Árbol de Trabajo:**
   * `git diff --check`: Salida `0` (sin errores de sintaxis, conflictos ni espacios residuales).
   * No se realizaron operaciones de `git commit` ni `git push`.
3. **Preservación Funcional de la Tesis:**
   * `flutter analyze`: **No issues found!**
   * `flutter test`: **21 pruebas aprobadas** (incluyendo privacidad de datos en portadas PDF, validación de feedback inmediato y reglas de negocio).
   * Cero modificaciones en Supabase Edge Functions desplegadas ni en los experimentos de benchmark.

---

## 7. Dictamen Final de Cierre Académico

| Observación | Estado Final | Dictamen y Conclusiones de Cierre |
| :--- | :---: | :--- |
| **Observación 18** | **CERRADA** | **Subsanada al 100%.** Se eliminaron todas las credenciales fijas y valores predeterminados inseguros en los scripts. Se implementó generación criptográfica con CSPRNG respetando la longitud obligatoria de 6 dígitos numéricos para estudiantes y contraseñas robustas para docentes, garantizando la no reutilización de valores. |
| **Observación 19** | **CERRADA** | **Subsanada al 100%.** Salvaguardas canónicas con `new URL()` implementadas en todos los scripts remotos y locales. La ejecución previa no dejó ningún registro residual en el proyecto piloto (0 residuos comprobados). Se ejecutó con éxito la rotación real de las 7 cuentas en Staging, se validó el rechazo efectivo de las credenciales antiguas (HTTP 400), se comprobaron los nuevos accesos sin mutar datos académicos y las nuevas credenciales se encuentran resguardadas bajo cifrado nativo Windows DPAPI (CurrentUser) excluido de Git. |

### Verificaciones Restantes para Publicación
1. **Código y ramas:** No se requiere ninguna corrección adicional en el código fuente.
2. **Entrega de Tesis:** El proyecto se encuentra listo para la revisión del jurado evaluador con evidencia empírica verificable.
