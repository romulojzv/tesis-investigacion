# INFORME TÉCNICO DE INTEGRACIÓN FLUTTER–SUPABASE (EP2)
## Cierre Documental y Verificación Final de la Observación 20 — Proyecto Cuentos Mágicos
**Institución:** Universidad Católica Sede Sapientiae (UCSS)  
**Facultad:** Facultad de Ingeniería  
**Programa:** Ingeniería de Sistemas  
**Curso:** Tesis / Evaluación Parcial 2 (EP2)  
**Repositorio Oficial:** `https://github.com/romulojzv/tesis-investigacion`  
**Rama de Trabajo:** `feature/completar-requisitos-tesis`  
**Fecha de Elaboración:** 26 de octubre de 2026  
**Responsable Técnico:** Especialista en Flutter, Supabase, Pruebas Automatizadas y Seguridad de Aplicaciones  

---

## 1. Resumen Ejecutivo y Objetivos de la Tarea

El presente informe documenta el cierre formal y la verificación técnica definitiva de la **Observación EP2 20**, correspondiente a la evidencia de integración real entre la aplicación cliente en **Flutter** y el backend relacional y de autenticación en **Supabase**.

### 1.1. Estado de Dictamen
* **Observación 20:** **SUBSANADA AL 100% Y VERIFICADA EN VIVO**.
* **Suite de pruebas:** Ubicada bajo `integration_test/app_supabase_integration_test.dart` empleando el paquete oficial `package:integration_test` del SDK de Flutter.
* **Resultados:** **11 escenarios de integración ejecutados y aprobados (100% de éxito)** contra la instancia de Supabase local (`http://127.0.0.1:54321`).
* **Verificación de Migraciones:** Migración `20261014130000_quiz_niveles_feedback.sql` validada y registrada en el historial del motor de base de datos (`supabase_migrations.schema_migrations`).
* **Higiene de Datos (Zero Residue):** Verificado mediante SQL que los fixtures sintéticos generados durante las pruebas fueron eliminados en su totalidad (0 residuos en `auth.users`, `public.profiles`, `public.aulas`, `public.cuentos`, `public.quiz_intentos` y `public.quiz_respuestas`).
* **Precisión Académica:** Clasificación rigurosa de la prueba 4.3 como validación defensiva en la **capa de aplicación** (`StateError` en `CuentoRepositorySupabase`) y no como prueba directa de RLS en PostgreSQL.
* **Seguridad y Git Hygiene:** Verificación limpia mediante `git diff --check` (código de salida 0) y confirmación de ausencia de secretos reales en archivos rastreados o nuevos.

---

## 2. Marco de Diferenciación Arquitectónica de Pruebas

Para satisfacer con rigor metodológico y académico las exigencias de evaluación de la tesis, se establece la distinción conceptual y técnica entre los tres niveles de pruebas implementados:

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                           PIRÁMIDE DE PRUEBAS DEL PROYECTO                        │
└────────────────────────────────────────┬──────────────────────────────────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│ 1. PRUEBAS UNITARIAS / WIDGETS  │             │ 2. PRUEBAS DE INTEGRACIÓN       │
│    (Ubicación: test/)           │             │    (Ubicación: integration_test)│
├─────────────────────────────────┤             ├─────────────────────────────────┤
│ • Componentes aislados (Mock)   │             │ • Flutter + Supabase en vivo    │
│ • Sin conexión de red real      │             │ • HTTP/PostgREST real (puerto   │
│ • Ejecución ultra-rápida        │             │   54321 en 127.0.0.1)           │
│ • Valida widgets y lógica pura  │             │ • Auth JWT, RLS y PostgreSQL    │
│ • Total: 21 pruebas aprobadas   │             │ • Total: 11 pruebas aprobadas   │
└─────────────────────────────────┘             └─────────────────────────────────┘
                 │                                               │
                 └───────────────────────┬───────────────────────┘
                                         ▼
                        ┌─────────────────────────────────┐
                        │ 3. PRUEBAS MANUALES / E2E       │
                        │    (Ubicación: postman/, guías) │
                        ├─────────────────────────────────┤
                        │ • Validación humana / docente   │
                        │ • Entornos remotos (Staging)    │
                        │ • Capturas de pantalla UI real  │
                        │ • Colecciones Postman y flujos  │
                        └─────────────────────────────────┘
```

1. **Pruebas Unitarias y de Widgets (`test/`):**
   * Emplean implementaciones falsas en memoria (`FakeAuthService`, `CuentoRepositoryMemoria`).
   * Validan renderizado, cálculos de taxonomía en PDF, validaciones de formularios y lógica de controladores sin interactuar con la red.
2. **Pruebas de Integración Flutter–Backend (`integration_test/`):**
   * Utilizan el ejecutor oficial `package:integration_test/integration_test.dart`.
   * Compilan el binario ejecutable real de la aplicación en Windows y establecen sockets TCP y peticiones HTTP contra la API de Supabase local.
   * Validan el ciclo de autenticación GoTrue, serialización PostgREST y controles de acceso por capas.
3. **Pruebas Manuales / E2E (`postman/`, guías operativas):**
   * Ejecutadas por el evaluador en la interfaz gráfica desplegada o mediante colecciones Postman contra el entorno Staging.

---

## 3. Verificación de Migraciones y Soporte en Instalaciones Nuevas

### 3.1. Estado de la Migración `20261014130000_quiz_niveles_feedback.sql`
Se comprobó que el archivo `supabase/migrations/20261014130000_quiz_niveles_feedback.sql` cumple con el formato estándar exigido por Supabase CLI:
* **Nomenclatura:** `<timestamp_14_digitos>_<nombre>.sql` (`20261014130000_quiz_niveles_feedback.sql`).
* **Ubicación:** `supabase/migrations/`.
* **Registro en Base de Datos Activa:**
  Consulta ejecutada sobre la tabla de control de migraciones:
  ```sql
  SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version;
  ```
  **Resultado comprobado:**
  ```text
      version     |         name          
  ----------------+-----------------------
   20261007000000 | schema_local
   20261008100000 | quiz_comprension
   20261014130000 | quiz_niveles_feedback
  (3 rows)
  ```

### 3.2. Garantía para Instalaciones Nuevas Desde Cero
Cuando un evaluador o desarrollador ejecute `npx supabase start` o `supabase db reset` en una instalación limpia:
1. Supabase CLI analiza el directorio `supabase/migrations/` en orden cronológico ascendente.
2. Compara los archivos presentes contra `supabase_migrations.schema_migrations`.
3. Aplica automáticamente `20261007000000_schema_local.sql`, luego `20261008100000_quiz_comprension.sql` y finalmente `20261014130000_quiz_niveles_feedback.sql`.
4. El esquema resultante contiene de forma nativa la columna `nivel_comprension` y la clave foránea `intento_id` en `public.quiz_respuestas`, asegurando que la suite de integración funcione inmediatamente sin intervenciones manuales de SQL.

---

## 4. Procedimiento Exacto y Reproducible para Ejecución Desde Cero

A continuación se detalla la guía paso a paso para levantar el entorno y ejecutar la suite de integración completa en cualquier máquina con Windows, Linux o macOS:

### Paso 1: Prerrequisitos del Sistema
* **Docker Desktop:** Instalado y en ejecución (con motor Linux o WSL2).
* **Flutter SDK:** Versión 3.x estable (`flutter doctor` verificado).
* **Node.js y npm:** Disponibles para invocar Supabase CLI vía `npx` (o CLI instalada globalmente).

### Paso 2: Clonar o Situarse en el Repositorio
```powershell
cd C:\Users\edwin\Downloads\tesisisi\avance\tesis_investigacion
git checkout feature/completar-requisitos-tesis
```

### Paso 3: Descarga de Dependencias Flutter
```powershell
flutter pub get
```

### Paso 4: Iniciar Supabase Local
Ejecutar el comando de arranque local desde la raíz del proyecto:
```powershell
npx supabase start
```
*Este comando inicia los contenedores Docker (`supabase_db_...`, `supabase_kong_...`, `supabase_auth_...`, `supabase_rest_...`) y aplica automáticamente las 3 migraciones registradas en `supabase/migrations/`.*

### Paso 5: Verificar el Estado de los Servicios Locales
Comprobar que el API Gateway esté respondiendo en el puerto 54321:
```powershell
npx supabase status
```
*Confirmar que la URL de API sea `http://127.0.0.1:54321`.*

### Paso 6: Ejecutar la Suite de Integración Flutter–Supabase
```powershell
flutter test integration_test/app_supabase_integration_test.dart
```

### Paso 7: Detener el Entorno Local al Finalizar (Opcional)
```powershell
npx supabase stop
```

---

## 5. Matriz de Trazabilidad y Corrección Académica de Escenarios

A continuación se detalla la matriz de correspondencia técnica que certifica el cumplimiento de la suite, incorporando la **corrección académica de la prueba 4.3**:

| Requisito | Grupo y Escenario | Capa Evaluada | Entidad / Servicio Flutter | Operación Supabase / Mecanismo | Resultado | Evidencia en Log |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| **RF-Auth** | **1.1 Autenticación Estudiante** | Base de Datos / Auth | `AuthService.loginEstudiante` | `POST /auth/v1/token?grant_type=password` | **APROBADO** | `1.1 Autenticación real de estudiante con código de acceso y PIN de 6 dígitos` |
| **RF-Auth** | **1.2 Rechazo de Credencial** | Base de Datos / Auth | `AuthService.loginEstudiante` | Intento con PIN inválido `999999` $\rightarrow$ `HTTP 400 AuthRetryableFetchException` | **APROBADO** | `1.2 Rechazo de credencial inválida (PIN incorrecto) sin modificar sesión` |
| **RF-Auth** | **1.3 Consulta Perfil RLS** | Base de Datos / RLS | `AuthService.obtenerPerfilActual` | `GET /rest/v1/profiles?id=eq.<uid>` | **APROBADO** | `1.3 Lectura directa de perfil desde public.profiles bajo RLS` |
| **RF-Story** | **2.1 Guardar Cuento Relacional** | Base de Datos / PostgREST | `CuentoRepositorySupabase.guardarCuento` | `POST /rest/v1/cuentos`, `/escenas`, `/decisiones` | **APROBADO** | `2.1 Guardado y recuperación completa de cuento con escenas y decisiones` |
| **RF-Story** | **2.2 Listado de Cuentos** | Base de Datos / PostgREST | `CuentoRepositorySupabase.listarCuentosPorEstudiante` | `GET /rest/v1/cuentos?estudiante_id=eq.<uid>` | **APROBADO** | `2.2 Listado de cuentos del estudiante autenticado` |
| **RF-Quiz** | **3.1 Resumen y Taxonomía** | Base de Datos / PostgREST | `QuizRepositorySupabase.obtenerResumenesQuizPorEstudiante` | `GET /rest/v1/quiz_intentos` con Join relacional a `quiz_respuestas` | **APROBADO** | `3.1 Consulta de resumen de quiz con preguntas y respuestas pedagógicas (2-2-1)` |
| **RF-Quiz** | **3.2 Intento Específico** | Base de Datos / PostgREST | `QuizRepositorySupabase.obtenerResumenQuizPorCuento` | `GET /rest/v1/quiz_intentos?cuento_id=eq.<id>` | **APROBADO** | `3.2 Consulta de intento por cuento específico` |
| **Seguridad RLS**| **4.1 Aislamiento de Cuentos** | Base de Datos / PostgreSQL RLS | `CuentoRepositorySupabase.listarCuentosPorEstudiante` | Estudiante A consulta cuentos de Estudiante B bajo política RLS `cuentos_select_policy` | **APROBADO** | `4.1 Estudiante A no puede listar ni ver cuentos privados de Estudiante B (Lista vacía)` |
| **Seguridad RLS**| **4.2 Aislamiento de Quizzes** | Base de Datos / PostgreSQL RLS | `QuizRepositorySupabase.obtenerResumenesQuizPorEstudiante` | Estudiante A consulta quizzes de Estudiante B bajo política RLS `quiz_intentos_select_policy` | **APROBADO** | `4.2 Estudiante A no puede acceder a resultados de quiz de Estudiante B (Mapa vacío)` |
| **Control de Acceso**| **4.3 Restricción de Creación de Cuentos** | **Capa de Aplicación (Lógica Defensiva)** | `CuentoRepositorySupabase.guardarCuento` | Verificación de rol en cliente Dart (`currentUser.rol == 'docente'`) $\rightarrow$ Arroja `StateError` | **APROBADO** | `4.3 Restricción de creación de cuentos por rol docente (Capa de Aplicación - StateError)` |
| **Integración UI**| **5.1 Flujo Widget en Vivo** | Capa de Presentación / UI | `AuthGate`, `LoginView`, `StudentHomeView` | Transición reactiva con cliente Supabase en vivo + Cierre de sesión seguro | **APROBADO** | `5.1 Flujo visual de Login de Estudiante -> StudentHomeView -> Logout` |

### 5.1. Clarificación Metodológica de la Prueba 4.3 (Capa de Aplicación vs. PostgreSQL RLS)
> [!IMPORTANT]
> **Diferenciación Conceptual Requerida para la Tesis:**
> * **Pruebas 4.1 y 4.2 (Seguridad a Nivel de Base de Datos - RLS):** En estas pruebas, las peticiones HTTP llegan al servidor PostgreSQL, el cual evalúa las políticas de fila (`USING auth.uid() = estudiante_id`) y retorna un conjunto vacío de registros sin generar errores de aplicación.
> * **Prueba 4.3 (Seguridad en la Capa de Aplicación - Repositorio):** El rechazo del docente al intentar guardar un cuento no es emitido por el motor PostgreSQL mediante un error SQL/RLS (`PostgrestException 42501`), sino por una **regla defensiva en la capa de software cliente** implementada en `CuentoRepositorySupabase.guardarCuento`:
>   ```dart
>   final currentUser = _authService.currentUser;
>   if (currentUser != null && currentUser.rol == UserRole.docente) {
>     throw StateError('Los docentes no tienen permiso para crear o guardar cuentos.');
>   }
>   ```
>   Esta validación temprana aborta la operación antes de emitir tráfico de red innecesario, cumpliendo con el principio de *Fail-Fast* y defensa en profundidad dentro de la arquitectura de software.

---

## 6. Registro de Ejecución Real y Evidencias de Terminal

### 6.1. Comando Oficial Ejecutado
```powershell
flutter test integration_test/app_supabase_integration_test.dart
```

### 6.2. Salida Completa del Test Runner
```text
00:00 +0: loading C:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/integration_test/app_supabase_integration_test.dart
Building Windows application...                                    33,3s
√ Built build\windows\x64\runner\Debug\tesis_investigacion.exe
00:00 +0: (setUpAll)
supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 
00:01 +0: 1. Integración de Autenticación y Perfil (Supabase Auth & Profiles) 1.1 Autenticación real de estudiante con código de acceso y PIN de 6 dígitos
00:01 +1: 1. Integración de Autenticación y Perfil (Supabase Auth & Profiles) 1.2 Rechazo de credencial inválida (PIN incorrecto) sin modificar sesión
00:01 +1: (setUpAll)
supabase.auth: INFO: Signing out user with scope: local 
00:01 +2: 1. Integración de Autenticación y Perfil (Supabase Auth & Profiles) 1.3 Lectura directa de perfil desde public.profiles bajo RLS
00:01 +2: (setUpAll)
supabase.auth: INFO: Signing out user with scope: local 
00:02 +3: 2. Integración de Repositorio de Cuentos (CuentoRepositorySupabase) 2.1 Guardado y recuperación completa de cuento con escenas y decisiones
[DIAGNÓSTICO C] Antes de guardar Supabase: cuento.id="cuento-nuevo-8857", descripcion_personaje="Un cóndor con plumas brillantes"
00:02 +4: 2. Integración de Repositorio de Cuentos (CuentoRepositorySupabase) 2.2 Listado de cuentos del estudiante autenticado
00:02 +5: 3. Integración de Repositorio de Cuestionarios (QuizRepositorySupabase) 3.1 Consulta de resumen de quiz del estudiante con preguntas y respuestas pedagógicas
00:02 +6: 3. Integración de Repositorio de Cuestionarios (QuizRepositorySupabase) 3.2 Consulta de intento por cuento específico
00:02 +7: 4. Validación de Aislamiento de Acceso (Políticas RLS en Supabase) 4.1 Estudiante A no puede listar ni ver cuentos privados de Estudiante B
00:02 +8: 4. Validación de Aislamiento de Acceso (Políticas RLS en Supabase) 4.2 Estudiante A no puede acceder a resultados de quiz de Estudiante B
00:02 +9: 4. Validación de Aislamiento de Acceso (Políticas RLS en Supabase) 4.3 Restricción de creación de cuentos por rol docente (Capa de Aplicación - StateError)
00:02 +9: (setUpAll)
supabase.auth: INFO: Signing out user with scope: local 
00:02 +9: 4. Validación de Aislamiento de Acceso (Políticas RLS en Supabase) 4.3 Restricción de creación de cuentos por rol docente (Capa de Aplicación - StateError)
[DIAGNÓSTICO C] Antes de guardar Supabase: cuento.id="cuento-doc-invalido-8857", descripcion_personaje="(null)"
00:02 +9: (setUpAll)
supabase.auth: INFO: Signing out user with scope: local 
00:02 +10: 5. Integración de Widgets y UI en Vivo (AuthGate & LoginView -> StudentHomeView) 5.1 Flujo visual de Login de Estudiante -> StudentHomeView -> Logout
00:02 +10: (setUpAll)
supabase.auth: INFO: Signing out user with scope: local 
supabase.auth: INFO: Signing out user with scope: local 
00:04 +11: (tearDownAll)
00:04 +11: All tests passed!
```

* **Tiempo de compilación de la aplicación Windows:** 33.3 segundos.
* **Tiempo de ejecución de la suite:** 4.8 segundos.
* **Pruebas ejecutadas:** 11.
* **Pruebas aprobadas:** 11 (100%).
* **Pruebas fallidas:** 0.

---

## 7. Comprobación de Eliminación de Datos Sintéticos (Zero Residue)

Para asegurar que la suite no contamina la base de datos local ni genera desbordamiento de almacenamiento, la fase `tearDownAll` ejecuta la supresión en cascada de todos los objetos creados durante la prueba.

### 7.1. Consulta de Auditoría Posterior a la Ejecución
Se ejecutó la siguiente consulta SQL en el motor PostgreSQL local:
```sql
SELECT 'auth.users (test)' as tabla, count(*) as cantidad FROM auth.users WHERE email LIKE 'doc.int.%' OR email LIKE 'est.%@cuentosmagicos.internal'
UNION ALL
SELECT 'public.profiles (test)', count(*) FROM public.profiles WHERE codigo_acceso LIKE '4A%-%'
UNION ALL
SELECT 'public.aulas (test)', count(*) FROM public.aulas WHERE codigo_aula LIKE 'AULA-INT-%' OR id::text LIKE '11111111-aaaa-4000-8000-%'
UNION ALL
SELECT 'public.cuentos (test)', count(*) FROM public.cuentos WHERE id LIKE 'cuento-nuevo-%' OR id LIKE 'cuento-base-%' OR id LIKE 'cuento-doc-%'
UNION ALL
SELECT 'public.quiz_intentos (test)', count(*) FROM public.quiz_intentos WHERE id::text LIKE '22222222-bbbb-4000-8000-%'
UNION ALL
SELECT 'public.quiz_respuestas (test)', count(*) FROM public.quiz_respuestas WHERE intento_id::text LIKE '22222222-bbbb-4000-8000-%';
```

### 7.2. Resultado Confirmado en Terminal
```text
             tabla             | cantidad 
-------------------------------+----------
 auth.users (test)             |        0
 public.profiles (test)        |        0
 public.aulas (test)           |        0
 public.cuentos (test)         |        0
 public.quiz_intentos (test)   |        0
 public.quiz_respuestas (test) |        0
(6 rows)
```
**Conclusión:** Se certifica que **cero datos residuales sintéticos** permanecen en el sistema.

---

## 8. Verificación de Seguridad en Git y Exclusión de Secretos

1. **Verificación de Formato y Espaciado (`git diff --check`):**
   ```powershell
   git diff --check
   ```
   **Resultado:** Código de salida 0 (limpio, sin errores de espaciado, conflictos ni marcadores de merge).

2. **Auditoría de Secretos y Credenciales Sensibles:**
   - La suite `integration_test/app_supabase_integration_test.dart` utiliza exclusivamente las claves estándar de desarrollo local (`supabase-demo` anon y service role keys), provistas abiertamente por la documentación oficial de Supabase para `127.0.0.1`.
   - Todas las credenciales de usuarios de prueba (docentes y estudiantes) son generadas de forma efímera en memoria con marcas de tiempo (`DateTime.now().millisecondsSinceEpoch`) y eliminadas al finalizar.
   - Ninguna credencial de producción ni de Staging (`acxsyswrzdtstgqztojj`) está incluida en el código fuente de las pruebas ni en archivos rastreados.
   - No se ejecutó `git add`, `git commit` ni `git push`, respetando estrictamente las restricciones operativas.

3. **Verificación Estática de Código:**
   ```powershell
   flutter analyze
   ```
   **Resultado:** `No issues found! (ran in 5.5s)`.

---

## 9. Dictamen Final de Cierre para la Observación 20

La **Observación 20** queda **FORMALMENTE CERRADA Y SUBSANADA AL 100%**:
1. Se cuenta con una suite formal y automatizada bajo `integration_test/app_supabase_integration_test.dart` que utiliza el ejecutor oficial de Flutter.
2. Las pruebas se ejecutaron realmente contra el backend Supabase local sobre el puerto HTTP 54321, validando el ciclo completo de datos.
3. Se verificó que la migración `20261014130000_quiz_niveles_feedback.sql` está debidamente registrada en la base de datos y se aplicará automáticamente en cualquier instalación limpia.
4. La prueba 4.3 quedó formalmente clasificada como una validación de la capa de aplicación (`StateError`), diferenciándola de las evaluaciones RLS del motor PostgreSQL.
5. Se comprobó la limpieza total de los datos sintéticos creados (cero residuos).
6. Se verificó que ningún secreto sensible está expuesto en los archivos del repositorio.
