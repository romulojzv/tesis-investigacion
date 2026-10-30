# INFORME TÉCNICO DE DIAGNÓSTICO SUPABASE — CUENTOS MÁGICOS
**Proyecto de Tesis:** Cuentos Mágicos — Aplicación Educativa Adaptativa  
**Repositorio:** `romulojzv/tesis-investigacion`  
**Rama de Trabajo:** `feature/completar-requisitos-tesis`  
**Commit Evaluado:** `aa0d4be10be428624003cebf49ca3309ba6efcd7` (con árbol local verificado)  
**Fecha de Diagnóstico:** 30 de octubre de 2026  
**Responsable Técnico:** Especialista Senior en Flutter, Supabase, PostgreSQL y Seguridad  

---

## 1. Resumen Ejecutivo del Diagnóstico

El presente informe detalla el estado operacional, la configuración arquitectónica y los factores de riesgo del backend en **Supabase** correspondiente a la plataforma educativa **Cuentos Mágicos**.

### Diagnóstico Global
1. **Estado del Servicio Remoto:** **ACTIVO Y SALUDABLE (`ACTIVE_HEALTHY`)** en ambas instancias cloud.
2. **Entornos Identificados:**
   - **Producción / Piloto (`wdehfetiazgukfgnngfi`):** Activo, versión PostgreSQL 17.11.0.002. Contiene la base de datos real del estudio piloto (35 escenas, 3 cuentos, 3 intentos de evaluación, 15 respuestas). Intacto y protegido.
   - **Staging / Pruebas Remotas (`acxsyswrzdtstgqztojj`):** Activo, versión PostgreSQL 17.11.0.003. Entorno limpio y autorizado para validaciones en la nube sin comprometer datos reales.
   - **Local CLI (`127.0.0.1:54321`):** Diseñado para pruebas locales automáticas con Docker.
3. **Sincronización de Migraciones:** **100% Alineada.** Las 3 migraciones canónicas del repositorio están aplicadas tanto en Producción como en Staging.
4. **Edge Functions:** 7 funciones activas en Producción; 3 activas en Staging. Todas con verificación obligatoria de JWT (`verify_jwt: true`).
5. **Configuración Cliente Flutter:** Correcta mediante constantes de compilación (`--dart-define`). La aplicación no incluye ni utiliza la clave `service_role`.

---

## 2. Mapa Arquitectónico de Entornos Supabase

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                             ARQUITECTURA DE ENTORNOS CUENTOS MÁGICOS                             │
└────────────────────────────────┬────────────────────────────────┬────────────────────────────────┘
                                 │                                │
                                 ▼                                ▼
┌──────────────────────────────────────────────────┐   ┌──────────────────────────────────────────────────┐
│ 1. PRODUCCIÓN / PILOTO EDUCATIVO                 │   │ 2. STAGING / PRUEBAS CLOUD CONTROLADAS           │
├──────────────────────────────────────────────────┤   ├──────────────────────────────────────────────────┤
│ • Project Ref: wdehfetiazgukfgnngfi             │   │ • Project Ref: acxsyswrzdtstgqztojj             │
│ • Nombre: romulojzv's Project                    │   │ • Nombre: cuentos-magicos-staging                │
│ • Región: AWS us-east-1 (N. Virginia)            │   │ • Región: AWS us-east-1 (N. Virginia)            │
│ • Estado: ACTIVE_HEALTHY                         │   │ • Estado: ACTIVE_HEALTHY                         │
│ • Motor: PostgreSQL 17.11.0.002                  │   │ • Motor: PostgreSQL 17.11.0.003                  │
│ • Rol: Datos reales del piloto experimental      │   │ • Rol: Pruebas remotas, Postman y E2E            │
│ • Regla: CERO ESCRITURAS DE PRUEBA (INTACTO)     │   │ • Regla: Aislado, sin impacto en producción      │
└──────────────────────────────────────────────────┘   └──────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. ENTORNO LOCAL DE DESARROLLO (DOCKER / SUPABASE CLI)                                          │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ • Endpoint: http://127.0.0.1:54321 | Puerto Postgres: 54322                                    │
│ • Motor: Docker Engine / Supabase CLI v2.120.0                                                   │
│ • Rol: Ejecución de integration_test/app_supabase_integration_test.dart (11 pruebas)             │
│ • Regla: Fixtures 100% sintéticos y eliminación total en tearDownAll (Zero Residue)             │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Estado Detallado de Proyectos Remotos

A través de la API de gestión de Supabase CLI autenticada localmente (`npx supabase projects list`), se obtuvieron las siguientes métricas exactas:

| Parámetro | Proyecto Producción / Piloto | Proyecto Staging |
| :--- | :--- | :--- |
| **Project Reference** | `wdehfetiazgukfgnngfi` | `acxsyswrzdtstgqztojj` |
| **Nombre Oficial** | `romulojzv's Project` | `cuentos-magicos-staging` |
| **Organización** | `ixosxloqiyqhclqkttpa` (`tesis`) | `ixosxloqiyqhclqkttpa` (`tesis`) |
| **Región de Despliegue** | `us-east-1` | `us-east-1` |
| **Fecha de Creación** | 2026-10-02 03:40:14 UTC | 2026-10-14 18:37:44 UTC |
| **Estado Operativo** | **`ACTIVE_HEALTHY`** | **`ACTIVE_HEALTHY`** |
| **Host de Base de Datos** | `db.wdehfetiazgukfgnngfi.supabase.co` | `db.acxsyswrzdtstgqztojj.supabase.co` |
| **Versión del Motor** | PostgreSQL 17.11.0.002 | PostgreSQL 17.11.0.003 |
| **Canal de Lanzamiento** | GA (General Availability) | GA (General Availability) |
| **Proyecto Vinculado CLI** | **Sí (`linked: true`)** | No (`linked: false`) |

---

## 4. Estado de Migraciones y Esquema Relacional

La inspección mediante `npx supabase migration list` confirmó la trazabilidad cronológica absoluta:

```text
Local Migration        Remote Migration (Prod)   Remote Migration (Staging)   Estado
--------------------   -----------------------   --------------------------   --------
20261007000000         20261007000000            20261007000000               SINCRONIZADO
20261008100000         20261008100000            20261008100000               SINCRONIZADO
20261014130000         20261014130000            20261014130000               SINCRONIZADO
```

### Contenido de las Migraciones
1. **`20261007000000_schema_local.sql`:**
   - Extensiones `uuid-ossp`, `pgcrypto`.
   - Esquema privado `app_private` para validaciones de rol docente/estudiante.
   - Tablas: `profiles`, `aulas`, `aula_estudiantes`, `cuentos`, `escenas`, `decisiones_narrativas`.
   - Políticas RLS y funciones `SECURITY DEFINER` con `search_path = ''`.
2. **`20261008100000_quiz_comprension.sql`:**
   - Tablas: `quiz_intentos` y `quiz_respuestas`.
   - Control de acceso RLS: estudiantes solo leen sus respuestas al completar el cuestionario.
3. **`20261014130000_quiz_niveles_feedback.sql`:**
   - Dimensiones pedagógicas: columna `nivel_comprension` con restricción de 4 niveles (`literal`, `inferencial`, `critico_reflexivo`, `sin_clasificar`).
   - Función RPC transaccional `responder_pregunta_segura` con control de concurrencia (`FOR UPDATE`) y cierre atómico de intentos.

---

## 5. Inventario de Tablas y Estadísticas Reales de Base de Datos

Mediante la herramienta `npx supabase inspect db table-stats` ejecutada de forma directa contra los motores PostgreSQL remotos, se obtuvieron las métricas físicas reales:

### Proyecto Producción (`wdehfetiazgukfgnngfi`)
| Tabla | Tamaño Tabla | Tamaño Índices | Tamaño Total | Filas Estimadas |
| :--- | :---: | :---: | :---: | :---: |
| `public.escenas` | 15 MB | 32 kB | **15 MB** | 35 |
| `public.cuentos` | 232 kB | 48 kB | **280 kB** | 3 |
| `public.profiles` | 48 kB | 64 kB | **112 kB** | > 0 |
| `public.quiz_intentos` | 16 kB | 96 kB | **112 kB** | 3 |
| `public.quiz_respuestas` | 56 kB | 48 kB | **104 kB** | 15 |
| `public.aula_estudiantes` | 16 kB | 64 kB | **80 kB** | > 0 |
| `public.aulas` | 16 kB | 48 kB | **64 kB** | > 0 |
| `public.decisiones_narrativas` | 32 kB | 16 kB | **48 kB** | 9 |

> [!IMPORTANT]
> Los datos anteriores corresponden a la persistencia real del grupo piloto durante el trabajo de campo de la tesis. Esto confirma que el proyecto `wdehfetiazgukfgnngfi` contiene registros irreemplazables que deben preservarse intactos.

### Proyecto Staging (`acxsyswrzdtstgqztojj`)
| Tabla | Tamaño Total | Filas Estimadas | Estado Operativo |
| :--- | :---: | :---: | :--- |
| `public.profiles` | 80 kB | 0 (post-rotación) | Disponible para pruebas |
| `public.cuentos` | 64 kB | 0 | Disponible para pruebas |
| `public.escenas` | 80 kB | 0 | Disponible para pruebas |
| `public.quiz_intentos` | 112 kB | 0 | Disponible para pruebas |
| `public.quiz_respuestas` | 96 kB | 0 | Disponible para pruebas |
| `public.aulas` | 64 kB | 0 | Disponible para pruebas |

---

## 6. Inventario de Edge Functions

La consulta a la infraestructura serverless (`npx supabase functions list`) reportó:

### Producción (`wdehfetiazgukfgnngfi`)
| Función | Versión | Estado | Verificación JWT | Propósito |
| :--- | :---: | :---: | :---: | :--- |
| `analizar-historia` | v9 | ACTIVE | `verify_jwt: true` | Extracción de entidades y contexto inicial con Gemini |
| `generar-escena` | v9 | ACTIVE | `verify_jwt: true` | Generación de tramas pedagógicas ramificadas |
| `generar-imagen` | v8 | ACTIVE | `verify_jwt: true` | Generación de ilustraciones con Pollinations/Stable Diffusion |
| `crear-estudiante` | v4 | ACTIVE | `verify_jwt: true` | Aprovisionamiento seguro con metadatos administrativos |
| `generar-quiz` | v4 | ACTIVE | `verify_jwt: true` | Construcción de preguntas distribuidas (2-2-1) |
| `enviar-quiz` | v3 | ACTIVE | `verify_jwt: true` | Registro y evaluación de cuestionarios |
| `responder-pregunta` | v1 | ACTIVE | `verify_jwt: true` | Envío secuencial con bloqueo e idempotencia (RF-22/26) |

### Staging (`acxsyswrzdtstgqztojj`)
| Función | Versión | Estado | Verificación JWT | Propósito |
| :--- | :---: | :---: | :---: | :--- |
| `responder-pregunta` | v1 | ACTIVE | `verify_jwt: true` | Validación de respuesta inmediata |
| `enviar-quiz` | v1 | ACTIVE | `verify_jwt: true` | Evaluación general de cuestionario |
| `generar-quiz` | v1 | ACTIVE | `verify_jwt: true` | Generación de preguntas sintéticas |

---

## 7. Configuración de la Aplicación Flutter

Se revisó la inicialización y el consumo de Supabase en `lib/main.dart`:

```dart
// lib/main.dart (Líneas 85-148)
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

await Supabase.initialize(
  url: supabaseUrl,
  publishableKey: supabasePublishableKey,
);
```

### Comprobaciones de Seguridad en Flutter
1. **Inyección en Tiempo de Compilación:** Se realiza exclusivamente mediante `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
2. **Ausencia de Claves Maestras:** Se verificó que ninguna clave `service_role` o secreto institucional está incrustado en el código fuente de Flutter ni en los repositorios de Dart.
3. **Higienización de Sesiones:** La aplicación implementa limpieza proactiva de almacenamiento local (`SharedPreferences`) y `signOut(scope: SignOutScope.local)` al arrancar cuando `FORCE_LOGIN_ON_START=true`, asegurando que no queden sesiones residuales entre diferentes estudiantes.

---

## 8. Diagnóstico de Riesgos y Plan de Acción

| ID Riesgo | Descripción del Riesgo | Severidad | Probabilidad | Medida Preventiva Adoptada |
| :--- | :--- | :---: | :---: | :--- |
| **R-01** | Pausa por inactividad de 7 días en el plan Free de Supabase. | **ALTA** | Media-Alta | Implementar monitor periódico ligero externo (1 consulta diaria SELECT autorizada). |
| **R-02** | Alteración o pérdida de datos reales del piloto escolar. | **CRÍTICA** | Baja (con salvaguardas) | Blindaje estricto de `wdehfetiazgukfgnngfi`: cero escrituras de pruebas en producción. Todo test va a Staging o Local. |
| **R-03** | Consumo accidental de cuotas de APIs de IA pagadas (Gemini). | **MEDIA** | Nula | Pruebas de integración utilizan mocks o endpoints de base de datos sin disparar generación de IA real. |
| **R-04** | Exposición de credenciales en commits públicos. | **ALTA** | Nula | Credenciales resguardadas bajo Windows DPAPI y `.gitignore` verificado. |
