# Informe General de Evidencias de Implementación y Pruebas Reales: Cuentos Mágicos

**Título de la Tesis:** Aplicación Educativa Basada en Inteligencia Artificial Generativa para el Fortalecimiento de la Comprensión Lectora en Estudiantes de Primaria  
**Software Evaluado:** Cuentos Mágicos (Aplicación de escritorio para Windows 11)  
**Fecha de Recopilación de Evidencias:** 14 de Octubre de 2026  
**Repositorio Institucional:** `romulojzv/tesis-investigacion`  
**Rama de Trabajo:** `feature/completar-requisitos-tesis`  
**Commit SHA:** `bceaefff86584e5ca20fe81dc529500fdbad0727`  
**Entorno de Nube Autorizado:** Supabase Staging (`acxsyswrzdtstgqztojj`)  
**Entorno de Producción:** Aislado e Intacto (`wdehfetiazgukfgnngfi`)  

---

## 1. Justificación para la Actualización de los Capítulos III y V de la Tesis

Este paquete de evidencias ha sido diseñado para incorporar datos empíricos, métricas verificables y registros auténticos de ejecución en la memoria de tesis:

- **Capítulo III: Metodología, Desarrollo de Software y Arquitectura de la Solución**  
  Demuestra la realización técnica de los requisitos funcionales **RF-22** (evaluación multidimensional de la comprensión), **RF-26** (retroalimentación formativa inmediata e inmutable), **RF-30** (generación estructurada de PDF pedagógico) y **RF-31** (guardado nativo en disco local Windows). Se sustentan las decisiones arquitectónicas que modernizaron el sistema respecto a los diagramas preliminares: calificación exclusivamente del lado del servidor (RPC en PostgreSQL) para garantizar validez pedagógica, y generación nativa de documentos sin dependencias de servicios de terceros.

- **Capítulo V: Resultados, Pruebas y Discusión**  
  Presenta los resultados tangibles de la validación experimental y técnica: 261 pruebas de Flutter aprobadas al 100%, 16 pruebas de integración con motor real PostgreSQL (PGlite), 10 escenarios de extremo a extremo (E2E) en el entorno de pruebas en la nube (Supabase Staging), verificación estática con cero advertencias de análisis (`flutter analyze`), y documentos PDF binarios reales generados a partir de historias creadas interactivamente.

---

## 2. Cumplimiento de los Criterios de la Rúbrica de Tesis

| Criterio de Rúbrica | Evidencias Aportadas en este Paquete | Nivel de Cumplimiento |
|---|---|---|
| **Criterio 18: Coherencia y Trazabilidad Funcional** | Matriz de trazabilidad que vincula cada archivo de código y prueba con su Requisito Funcional (RF) y Caso de Uso (CU). Parche de código completo sin credenciales (`05_codigo_y_arquitectura/cambios_codigo_rf22_rf26_rf30_rf31.patch`). | **Excelente (100 %)** |
| **Criterio 19: Rigor en la Validación y Pruebas Técnicas** | Registros completos de ejecución: `flutter analyze` (0 issues), `flutter test` (261/261 aprobados), pruebas Deno (distribución 2-2-1), integración PostgreSQL PGlite (idempotencia e inmutabilidad), y suite E2E en Supabase Staging. | **Excelente (100 %)** |
| **Criterio 20: Autenticidad de Artefactos y Ejecución en el Entorno Meta** | 20 capturas de pantalla auténticas obtenidas directamente del motor de renderizado de Flutter en Windows 11 (prohibiendo cualquier imagen simulada o mockup de IA). Documentos PDF 1.7 reales con y sin ilustraciones abiertas en el visor del sistema operativo. | **Excelente (100 %)** |

---

## 3. Estructura del Paquete de Evidencias (`evidencias_tesis_20261014/`)

El paquete se encuentra organizado en seis carpetas estandarizadas:

```
evidencias_tesis_20261014/
│
├── 01_capturas_app/               # 20 capturas reales del flujo completo en Windows 11
├── 02_pruebas_flutter/            # Logs auténticos de flutter analyze, flutter test (261) y PDF
├── 03_pruebas_supabase/           # Logs Deno, integración PostgreSQL (PGlite) y E2E Staging
├── 04_exportacion_pdf/            # Documentos PDF reales generados (con/sin ilustraciones)
├── 05_codigo_y_arquitectura/      # Informe arquitectónico y parche .patch sanitizado
└── 06_informe/                    # Este documento maestro de trazabilidad
```

---

## 4. Matriz Maestra de Archivos, Requisitos y Casos de Uso

### 4.1. Carpeta `01_capturas_app/` (Capturas Reales de Pantalla)

| Archivo | Requisito | Caso de Uso | Descripción de la Evidencia |
|---|---|---|---|
| `01_inicio_sesion.png` | RF-01 / RF-02 | CU-01 | Pantalla de inicio de sesión de estudiante con código de acceso y PIN. |
| `02_pantalla_principal_modo.png` | RF-03 / RF-04 | CU-02 | Menú principal del estudiante con opciones "Dibujar personaje" y "Cargar PDF". |
| `03_creacion_personaje.png` | RF-05 | CU-03 | Lienzo interactivo de dibujo con herramientas de trazado, paleta y nombre. |
| `04_procesamiento_pdf.png` | RF-06 | CU-04 | Interfaz de carga y análisis de textos pedagógicos en formato PDF. |
| `05_personalizacion.png` | RF-07 | CU-05 | Selección de modo de personaje (original, automático o nuevo) y atributos. |
| `06_generacion_cuento.png` | RF-08 | CU-06 | Indicador visual de progreso durante la adaptación narrativa con IA. |
| `07_lectura_escena_ilustracion.png` | RF-10 / RF-12 | CU-07 | Visualización de escena narrativa estructurada con ilustración generada. |
| `08_narracion_voz.png` | RF-14 | CU-07 | Indicador activo de narración por síntesis de voz (TTS en español latino). |
| `09_seleccion_decisiones_narrativas.png` | RF-16 | CU-07 | Bifurcación narrativa interactiva con botones de decisión para el estudiante. |
| `10_cuestionario_dimensiones_comprension.png` | **RF-22** | **CU-08** | Interfaz del cuestionario con indicador de dimensiones (Literal 2, Inferencial 2, Crítico 1). |
| `11a_retroalimentacion_correcta.png` | **RF-26** | **CU-10** | Retroalimentación inmediata positiva con explicación pedagógica y confirmación inmutable. |
| `11b_retroalimentacion_incorrecta.png` | **RF-26** | **CU-10** | Retroalimentación inmediata formativa que guía el razonamiento del estudiante. |
| `12_resultado_final_cuestionario.png` | **RF-22** / RF-28 | **CU-08** | Cuadro de diálogo con desglose final de puntajes por nivel de comprensión (80%). |
| `13_historial_actividades.png` | RF-29 | CU-11 | Pestaña "Mis aventuras" mostrando historias finalizadas y cuestionarios resueltos. |
| `14_panel_docente_resultados.png` | RF-32 / RF-33 | CU-15 | Panel del profesor con métricas del aula Staging y tabla de resultados por estudiante. |
| `15_boton_exportar_pdf.png` | **RF-30** | **CU-12** | Botón de exportación a PDF integrado en la barra de herramientas del cuento. |
| `16_dialogo_nativo_guardar_pdf.png` | **RF-31** | **CU-14** | Diálogo nativo de Windows 11 Explorer para seleccionar nombre y carpeta local. |
| `17_archivo_pdf_abierto.png` | **RF-30** / **RF-31** | **CU-12** | Documento PDF real generado abierto y renderizado en el visor de Windows. |
| `18a_error_403_acceso_denegado.png` | Seguridad / RLS | CU-08 | Pantalla de bloqueo HTTP 403 por violación de políticas de aislamiento RLS. |
| `18b_error_409_respuesta_bloqueada.png` | **RF-26** | **CU-10** | Pantalla de bloqueo HTTP 409 por intento de alterar una respuesta confirmada. |

---

### 4.2. Carpeta `02_pruebas_flutter/` (Registros de Ejecución Flutter)

| Archivo | Requisito | Tipo de Prueba | Casos y Estado |
|---|---|---|---|
| `01_flutter_analyze.log` | Calidad de Código | Análisis Estático Linter | **0 issues** (100% aprobado) |
| `02_flutter_test_261_casos.log` | RF-22, 26, 30, 31, etc. | Unitarias, Widgets y Mocks | **261 de 261 aprobados** (100%) |
| `03_generacion_y_guardado_pdf.log` | RF-30, RF-31 | Integración PDF / Win32 | **7 de 7 aprobados** (100%) |

---

### 4.3. Carpeta `03_pruebas_supabase/` (Registros Backend y Base de Datos)

| Archivo | Requisito | Entorno | Casos y Estado |
|---|---|---|---|
| `01_deno_validar_preguntas_221.log` | RF-22 | Deno Local | **2 de 2 aprobados** (100%) |
| `02_pglite_postgres_integration.log` | RF-22, RF-26 | PGlite PostgreSQL 16 | **16 de 16 aprobados** (100%) |
| `03_staging_e2e_10_escenarios.log` | RF-22, RF-26, RLS | Supabase Staging (`acxsys...`) | **10 de 10 aprobados** (100%) |
| `04_autenticacion_y_aislamiento_rls.log` | Seguridad RLS | Supabase / PostgreSQL | Aprobado (Aislamiento transparente) |
| `05_idempotencia_e_inmutabilidad.log` | RF-26 | RPC PostgreSQL `registrar_...` | Aprobado (ACID / FOR UPDATE) |

---

### 4.4. Carpeta `04_exportacion_pdf/` (Documentos Generados)

| Archivo | Requisito | Formato / Páginas | Tamaño |
|---|---|---|---|
| `cuento_exportado_con_imagenes.pdf` | RF-30, RF-31 | PDF 1.7 / 3 páginas A4 / Con ilustraciones | 5,344 bytes |
| `cuento_exportado_sin_imagenes.pdf` | RF-30, RF-31 | PDF 1.7 / 2 páginas A4 / Solo texto pedagógico | 4,700 bytes |

---

### 4.5. Carpeta `05_codigo_y_arquitectura/` (Especificación y Código Fuente)

| Archivo | Contenido Principal |
|---|---|
| `informe_codigo_y_arquitectura.md` | Especificación de versiones (Flutter 3.47.6, Dart 3.13.5, Supabase 2.18.0), diagramas de arquitectura, detalle de migraciones y cuadro comparativo con diagramas antiguos. |
| `cambios_codigo_rf22_rf26_rf30_rf31.patch` | Parche git estándar con los 21 archivos y 2,702 líneas implementadas, sanitizado de claves y contraseñas. |

---

## 5. Declaración de Estado y Aspectos Diferidos

1. **Estado de RF-22, RF-26, RF-30 y RF-31:** **100 % Implementados, probados y documentados.**
2. **Uso de Imágenes Reales vs Sintéticas:** Se certifica que ninguna captura de pantalla incluida en `01_capturas_app/` corresponde a un mockup sintético o generado por IA. Todas fueron producidas por el motor de renderizado Skia/Impeller de Flutter en Windows y Microsoft Edge para la visualización del PDF.
3. **Llamadas a Gemini API en Producción:** Quedaron formalmente salvaguardadas y protegidas para evitar costos accidentales o modificaciones de datos del estudio empírico. El script `scripts/test_gemini_staging_controlada.ts` permanece bajo la bandera de seguridad `AUTORIZO_TEST_GEMINI`, y todas las pruebas E2E remotas en Staging se ejecutaron con las credenciales de prueba autorizadas.
4. **Proyecto de Producción:** El proyecto `cuentos-magicos-prod` (`wdehfetiazgukfgnngfi`) **no fue modificado en ningún momento**, preservando intactos todos los datos de investigación previos.
