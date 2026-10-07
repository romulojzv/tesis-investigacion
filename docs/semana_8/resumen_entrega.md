# Resumen Ejecutivo de Entrega — Semana 8

**Proyecto:** Cuentos Mágicos  
**Objetivo de la Entrega:** Smoke Test Real en Supabase Local, Manual de Compilación Determinista y Diagramas de Arquitectura Exportados  
**Fecha:** 7 de Octubre de 2026  
**Documento:** `docs/semana_8/resumen_entrega.md`

---

## 1. Relación de Entregables Generados

Todos los documentos, diagramas y scripts han sido consolidados en las rutas normadas:

| Archivo | Tipo | Descripción del Contenido |
| :--- | :--- | :--- |
| [`docs/semana_8/smoke_test.md`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/smoke_test.md) | Documento MD | Matriz de pruebas de humo (7/7 casos PASÓ), diagnóstico de entorno aislado, ejecución real en Supabase Local (Docker) y auditoría de limpieza. |
| [`docs/semana_8/manual_compilacion.md`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/manual_compilacion.md) | Documento MD | Manual determinista paso a paso con versiones reales verificadas de Windows 11, Flutter 3.47.6, Dart 3.13.5, MSVC 14.51, CMake 4.3.1 y Ninja 1.13.2. |
| [`docs/semana_8/diagrama_componentes.mmd`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_componentes.mmd) | Fuente Mermaid | Diagrama Mermaid de componentes basado en la arquitectura en capas real de Flutter Desktop y Supabase. |
| [`docs/semana_8/diagrama_componentes.svg`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_componentes.svg) | Gráfico Vectorial | Exportación vectorial SVG renderizada de componentes. |
| [`docs/semana_8/diagrama_componentes.png`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_componentes.png) | Gráfico Raster | Exportación PNG de alta resolución de componentes. |
| [`docs/semana_8/diagrama_despliegue.mmd`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_despliegue.mmd) | Fuente Mermaid | Diagrama Mermaid de despliegue físico y de red (Flutter Engine Win32, Supabase PostgREST/RLS, Edge Functions, Gemini, Pollinations). |
| [`docs/semana_8/diagrama_despliegue.svg`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_despliegue.svg) | Gráfico Vectorial | Exportación vectorial SVG renderizada de despliegue. |
| [`docs/semana_8/diagrama_despliegue.png`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/diagrama_despliegue.png) | Gráfico Raster | Exportación PNG de alta resolución de despliegue. |
| [`docs/semana_8/resumen_entrega.md`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/semana_8/resumen_entrega.md) | Documento MD | Síntesis ejecutiva y balance de resultados de la Semana 8. |
| [`scripts/smoke_test_isolated.ts`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/scripts/smoke_test_isolated.ts) | Script TypeScript | Suite automatizada de smoke test con salvaguarda determinista anti-remoto y ejecución contra Supabase Local. |
| [`supabase/migrations/20261007000000_schema_local.sql`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/supabase/migrations/20261007000000_schema_local.sql) | Script SQL | Migración reproducible local con todas las tablas, vistas, funciones, triggers y políticas RLS para tests herméticos. |

---

## 2. Puntos Clave Abordados

### A. Diagnóstico, Reproducción de Esquema y Smoke Test en Supabase Local
- **Entorno Local Activo:** Supabase Local se ejecutó sobre Docker Desktop en Windows (PostgreSQL en `127.0.0.1:54322`, API PostgREST en `http://127.0.0.1:54321`, Studio en `http://127.0.0.1:54323`).
- **Inspección de Esquema:** Inicialmente la base de datos local contaba con 0 tablas en `public`. Se elaboró y aplicó la migración `20261007000000_schema_local.sql` mediante `npx.cmd supabase migration up --local`, aprovisionando las 6 tablas esenciales (`profiles`, `aulas`, `aula_estudiantes`, `cuentos`, `escenas`, `decisiones_narrativas`) y la vista `decisiones`.
- **Verificación RLS:** Se auditó que las 6 tablas cuentan con `relrowsecurity = true` activo.
- **Ejecución Real del Smoke Test:** Se ejecutó `npx.cmd tsx scripts/smoke_test_isolated.ts`, completando con éxito los 7 casos:
  * **SMK-01 (PASÓ):** Login de docente y estudiantes sintéticos emitiendo JWT válidos.
  * **SMK-02 (PASÓ):** Lectura autorizada de profiles propios y aulas asignadas.
  * **SMK-03 (PASÓ):** Estudiante autor crea y consulta su propio cuento, escenas y decisiones.
  * **SMK-04 (PASÓ):** Estudiante 2 recibe 0 registros al intentar consultar el cuento de Estudiante 1 (aislamiento RLS estricto).
  * **SMK-05 (PASÓ):** Docente asignado al aula supervisa lectura del cuento pero su intento de UPDATE es bloqueado por RLS.
  * **SMK-06 (PASÓ):** Usuario anónimo sin sesión recibe 0 registros en cuentos, aulas y perfiles.
  * **SMK-07 (PASÓ):** Eliminación controlada de los fixtures sintéticos mediante `service_role`.
- **Auditoría de Limpieza:** Verificación posterior con `count(*) = 0` en todas las tablas, conservando el esquema intacto.
- **Invariante Crítica:** El proyecto remoto `wdehfetiazgukfgnngfi` registró **0 alteraciones**. Cero consumo de cuotas de Gemini o Pollinations.

### B. Corrección Estática en `run_estudiantes_pilot.ts`
- Se tipó el retorno de `invocarCrearEstudiante` con la interfaz `EstudianteCreado`.
- Type-check estricto ejecutado con `npx.cmd tsc --noEmit -p tsconfig.scripts.json`: **0 errores**.

### C. Manual de Compilación Determinista
- Registro fidedigno del toolchain Windows verificado: Windows 11 Pro (Build 26100), Flutter 3.47.6, Dart 3.13.5, MSVC v14.51, CMake 4.3.1, Ninja 1.13.2, Node v24.21.0, Deno 2.9.7 y Supabase CLI 2.119.0.
- Explicación formal de la reproducibilidad binaria en el ecosistema Windows C++/PE.

### D. Diagramas de Arquitectura Exportados
- **Diagrama de Componentes:** Refleja la arquitectura real en capas de la app Desktop, separando controladores, servicios y marcando el módulo de Quiz como **PENDIENTE**. Exportado a SVG y PNG.
- **Diagrama de Despliegue:** Modela la topología de red, ilustrando la entrega de imágenes como Data URI Base64 y documentando el estado de `verify_jwt` en las Edge Functions. Exportado a SVG y PNG.

---

## 3. Estado de Calidad del Código y Binarios

```text
npx.cmd tsc --noEmit -p tsconfig.scripts.json
=> 0 errores (Type-check superado al 100%)

dart format .
=> Formatted 52 files (0 changed) in 0.47 seconds. (100% OK)

flutter analyze
=> No issues found! (ran in 3.0s) (0 errores, 0 advertencias)

flutter test
=> 00:16 +134: All tests passed! (134/134 pruebas exitosas)

flutter build windows --debug
=> √ Built build\windows\x64\runner\Debug\tesis_investigacion.exe (28.5s)
```
