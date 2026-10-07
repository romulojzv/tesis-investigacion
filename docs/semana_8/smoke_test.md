# Smoke Test — Validación en Entorno Aislado Local

**Proyecto:** Cuentos Mágicos (Flutter Windows + Supabase)  
**Fase:** Semana 8 — Entrega de Evaluación y Cierre de Prototipo  
**Fecha de Ejecución Real:** 7 de Octubre de 2026  
**Script Ejecutable:** [`scripts/smoke_test_isolated.ts`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/scripts/smoke_test_isolated.ts)  
**Entorno de Ejecución:** Supabase Local (Docker Desktop) — PostgreSQL `127.0.0.1:54322` / API `http://127.0.0.1:54321`

---

## 1. Objetivo y Alcance

El objetivo de este Smoke Test es validar de extremo a extremo las políticas de seguridad a nivel de fila (Row Level Security - RLS), autenticación basada en roles (docente vs. estudiante vs. anónimo) y el aislamiento de autoría de cuentos sobre un conjunto de **datos sintéticos mínimos y controlados**, ejecutado **100% de manera real** sobre una instancia local de Supabase.

### Reglas de Seguridad Innegociables
1. **NO modificar el proyecto remoto del piloto:** El proyecto remoto `wdehfetiazgukfgnngfi` contiene cuentas y cuentos reales de los estudiantes del piloto. Cero comandos destructivos, migraciones remotas (`--linked`) o consultas remotas fueron ejecutadas contra él.
2. **NO consumir APIs de IA en smoke tests:** No se invocaron ni consumieron créditos de Gemini ni Pollinations para estas verificaciones de acceso y persistencia.
3. **Cero exposición de secretos:** No se imprimen contraseñas en texto plano, PINs completos ni tokens JWT en los reportes o logs.
4. **Verificación de conexión local:** Conexión estrictamente dirigida a `127.0.0.1:54322` / `http://127.0.0.1:54321`.

---

## 2. Verificación del Entorno Local y Diagnóstico Inicial

Con Docker Desktop y Deno 2.9.7 operativos en el sistema anfitrión Windows, se ejecutó la inicialización e inspección del emulador local:

```powershell
npx.cmd supabase start
npx.cmd supabase status
```

### Endpoints Locales Verificados
| Servicio | Endpoint / Conexión |
| :--- | :--- |
| **API Gateway / PostgREST** | `http://127.0.0.1:54321` |
| **Studio Web** | `http://127.0.0.1:54323` |
| **PostgreSQL Local** | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| **Mailpit** | `http://127.0.0.1:54324` |

### Diagnóstico de Tablas Iniciales en Supabase Local
Se inspeccionó el esquema `public` inicial mediante `npx.cmd supabase db query --local`:

```sql
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
```
**Resultado inicial:** `{"rows": []}` (0 tablas encontradas). La instancia local inició limpia sin el esquema de Cuentos Mágicos.

---

## 3. Reproducción del Esquema Local para Pruebas

Para reproducir el esquema sin afectar producción ni depender de datos remotos, se preparó la migración oficial [`supabase/migrations/20261007000000_schema_local.sql`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/supabase/migrations/20261007000000_schema_local.sql) conteniendo:

1. **Extensiones y Esquema:** `uuid-ossp`, `pgcrypto`, y esquema `app_private`.
2. **Tablas Base:**
   - `public.profiles`: Roles `docente` y `estudiante`, `codigo_acceso` único, FK a `auth.users(id)` en cascada.
   - `public.aulas`: `codigo_aula`, FK `docente_id` a `profiles(id)`.
   - `public.aula_estudiantes`: Matrícula con `codigo_local` y unicidad compuesta `(aula_id, estudiante_id)`.
   - `public.cuentos`: Soporte de autoría (`estudiante_id`), asociación opcional a aula (`aula_id`), bandera `es_demo`.
   - `public.escenas`: Secuencia narrativa con `numero`, `contenido`, `image_url`, `opciones` y `es_final`.
   - `public.decisiones_narrativas`: Registro de ramificaciones por `numero_escena` y `opcion_seleccionada`.
   - `public.decisiones`: Vista compatible con `security_invoker = on` sobre `decisiones_narrativas`.
3. **Funciones Helper de Seguridad (`app_private`):**
   - `app_private.es_docente()`: Valida rol docente del usuario autenticado.
   - `app_private.es_estudiante(UUID)`: Valida rol estudiante.
   - `app_private.es_docente_de_estudiante(UUID)`: Valida vínculo pedagógico entre docente y alumno vía matrícula.
   - `app_private.es_docente_de_aula(UUID)`: Valida titularidad del aula.
   - `app_private.es_estudiante_de_aula(UUID)`: Valida pertenencia del estudiante al aula.
4. **Triggers y Procedimientos:**
   - `tr_prevenir_cambio_campos_sensibles` sobre `profiles` (inmutabilidad de rol, id y código de acceso).
   - `on_auth_user_created` (`handle_new_user`) para sincronización automática de metadatos de usuario a perfil.
5. **Permisos y Políticas RLS Activas:**
   - `profiles`: RLS habilitado, consulta restringida al propio usuario o su docente.
   - `aulas`: RLS habilitado, gestión exclusiva del docente titular.
   - `aula_estudiantes`: RLS habilitado, administración por docente titular y visibilidad para alumnos matriculados.
   - `cuentos`: RLS habilitado, inserción/edición restringida al alumno autor; lectura autorizada al autor y a su docente.
   - `escenas` y `decisiones_narrativas`: RLS condicionado a la propiedad del cuento padre.

### Aplicación y Verificación de la Migración Local
```powershell
npx.cmd supabase migration up --local
```
**Salida obtenida:** `{"applied":["...20261007000000_schema_local.sql"],"message":"Migrations applied"}`.

Verificación de activación de RLS en las 6 tablas (`npx.cmd supabase db query --local`):
```text
profiles              | relrowsecurity: true
aulas                 | relrowsecurity: true
aula_estudiantes      | relrowsecurity: true
cuentos               | relrowsecurity: true
escenas               | relrowsecurity: true
decisiones_narrativas | relrowsecurity: true
```

---

## 4. Ejecución Real del Smoke Test

Se ejecutó la suite automatizada sobre el puerto local `54321`:

```powershell
npx.cmd tsx scripts/smoke_test_isolated.ts
```

### Matriz de Resultados Reales Obtenidos

| ID | Caso de Prueba | Precondición | Acción Ejecutada | Resultado Esperado | Resultado Real Obtenido | Estado | Evidencia Real Registrada |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SMK-01** | **Autenticación Docente y Estudiante** | Usuarios sintéticos creados en `auth.users` vía Admin API | `auth.signInWithPassword` para docente y estudiantes en Supabase Local | Ambas sesiones emiten JWT válido con `user.id` | Sesiones emitidas exitosamente con JWT local | **PASÓ** | Docente UID: `6d81a2a8...`, Est1 UID: `8e233c36...`, Est2 UID: `7e91154b...` |
| **SMK-02** | **Lectura de profiles y aulas según rol** | Docente y estudiante autenticados con JWT local | Consultar propio profile y aula del docente vía RLS | Estudiante lee únicamente su perfil; docente lee su aula | Lectura autorizada con datos exactos | **PASÓ** | Estudiante profile rol=`estudiante`, Docente aula=`Aula Smoke Test` |
| **SMK-03** | **Estudiante crea y consulta su propio cuento** | Estudiante 1 autenticado con RLS activo | INSERT en `cuentos`, `escenas` y `decisiones_narrativas`; luego SELECT | Inserción y lectura permitidas para el autor | Cuento, escena y decisión registrados y leídos | **PASÓ** | Cuento ID: `test-cuento-1791344781293`, Personaje: `Pollito Ficticio` |
| **SMK-04** | **Aislamiento: Estudiante 2 no lee cuento ajeno** | Estudiante 2 autenticado en la misma aula | SELECT en `cuentos` WHERE `id = cuento_de_estudiante_1` | 0 filas retornadas por RLS (`null`) | 0 filas retornadas (acceso denegado por RLS) | **PASÓ** | `cuentoAjeno=null` |
| **SMK-05** | **Supervisión docente sin alteración** | Docente asignado al aula del Estudiante 1 | SELECT de cuento de su aula y posterior intento de UPDATE | SELECT exitoso (supervisión); UPDATE denegado por RLS | Docente supervisa lectura; UPDATE bloqueado por RLS | **PASÓ** | Docente leyó `cuento=test-cuento-1791344781293`; título inalterado=`'Cuento de Prueba Sintético'` |
| **SMK-06** | **Cliente Anónimo sin acceso a datos educativos** | Cliente Supabase sin sesión (únicamente `anon_key`) | SELECT en `cuentos`, `aulas` y `profiles` | 0 registros retornados en todas las tablas | Acceso anónimo bloqueado por RLS (0 registros) | **PASÓ** | `cuentos=0, aulas=0, profiles=0` |
| **SMK-07** | **Limpieza y preservación del esquema** | Casos SMK-01 a SMK-06 finalizados exitosamente | Eliminación específica de IDs generados para el smoke test vía `service_role` | Fixtures temporales eliminados; esquema y tablas intactas | Fixtures eliminados con éxito vía `service_role` | **PASÓ** | Eliminados UIDs doc=`6d81a2a8...`, est1=`8e233c36...`, est2=`7e91154b...` |

---

## 5. Verificación de Limpieza y Preservación del Esquema

Tras la ejecución del caso SMK-07, se auditó la base de datos local para constatar que no quedaron registros huérfanos y que el esquema se conservó íntegro:

```sql
SELECT 'profiles' as t, count(*) FROM public.profiles 
UNION ALL SELECT 'aulas', count(*) FROM public.aulas 
UNION ALL SELECT 'aula_estudiantes', count(*) FROM public.aula_estudiantes 
UNION ALL SELECT 'cuentos', count(*) FROM public.cuentos 
UNION ALL SELECT 'escenas', count(*) FROM public.escenas 
UNION ALL SELECT 'decisiones_narrativas', count(*) FROM public.decisiones_narrativas;
```

**Resultado de la auditoría post-limpieza:**
```text
profiles              | count: 0
aulas                 | count: 0
aula_estudiantes      | count: 0
cuentos               | count: 0
escenas               | count: 0
decisiones_narrativas | count: 0
```
- ✅ Todos los datos ficticios generados por el smoke test fueron eliminados.
- ✅ Todas las tablas, índices, vistas, funciones y políticas RLS permanecen intactas en la base local.
- ✅ El proyecto remoto `wdehfetiazgukfgnngfi` registró **0 alteraciones**.

---

## 6. Limitaciones Conocidas y Alcance de las Pruebas

1. **Servicios de Inteligencia Artificial:** El smoke test no evalúa generación de texto por Gemini ni generación de imágenes por Pollinations, pues su alcance está deliberadamente restringido a autenticación, integridad referencial y políticas RLS de PostgreSQL.
2. **Entorno Local vs. Producción:** El smoke test corre en contenedores Docker locales en Windows. Las latencias de red y cuotas de PostgREST de Supabase Cloud no forman parte de esta prueba funcional.
3. **Almacenamiento de Archivos:** Las imágenes en este smoke test no usan Supabase Storage (en el prototipo actual de Cuentos Mágicos se emplean URLs directas y Data URIs Base64).
