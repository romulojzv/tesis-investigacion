# Evidencia Técnica: Código, Arquitectura y Migraciones (Cuentos Mágicos)

**Fecha:** 14 de Octubre de 2026  
**Repositorio:** `romulojzv/tesis-investigacion`  
**Rama activa:** `feature/completar-requisitos-tesis`  
**Commit SHA completo:** `bceaefff86584e5ca20fe81dc529500fdbad0727`  
**Entorno Cloud Autorizado:** Supabase Staging (`acxsyswrzdtstgqztojj`)  

---

## 1. Entorno Tecnológico y Versiones Oficiales

| Componente | Versión Oficial | Propósito en el Sistema |
|---|---|---|
| **Flutter SDK** | `3.47.6` (channel stable) | Framework multiplataforma de interfaz de usuario de escritorio para Windows 11. |
| **Dart SDK** | `3.13.5` | Lenguaje de desarrollo cliente, fuertemente tipado con null safety. |
| **Supabase Flutter Client** | `^2.18.0` (2.18.0) | Conector SDK para autenticación, realtime y llamadas a Edge Functions. |
| **Syncfusion Flutter PDF** | `^35.1.37` (35.1.37) | Motor binario de generación y dibujo vectorial de documentos PDF A4. |
| **Windows File Picker** | `^2.0.0` (2.0.0) | Diálogo Win32 nativo para selección de ruta de guardado local. |
| **Deno Runtime** | `v2.x` (en Edge Functions) | Entorno de ejecución seguro para Edge Functions TypeScript. |
| **PostgreSQL** | `PostgreSQL 16` (Supabase Cloud) | Motor relacional con Row Level Security (RLS) y procedimientos PL/pgSQL. |

---

## 2. Matriz de Trazabilidad: Requisitos, Casos de Uso y Archivos de Código

| Requisito Funcional | Caso de Uso (Tesis) | Descripción Pedagógica / Funcional | Archivos Implementados y Modificados |
|---|---|---|---|
| **RF-22** | **CU-08**: Resolver Cuestionario de Comprensión Lectora | Clasificación taxonómica de 5 preguntas en tres dimensiones de comprensión: Literal (2), Inferencial (2) y Crítico-Reflexiva (1). | - [`lib/models/quiz_question.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/models/quiz_question.dart)<br>- [`lib/views/quiz_view.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/views/quiz_view.dart)<br>- [`supabase/functions/generar-quiz/index.ts`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/supabase/functions/generar-quiz/index.ts)<br>- [`supabase/migrations/20261014130000_quiz_niveles_feedback.sql`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/supabase/migrations/20261014130000_quiz_niveles_feedback.sql) |
| **RF-26** | **CU-10**: Recibir Retroalimentación Formativa Inmediata | Calificación en servidor pregunta a pregunta, retroalimentación explicativa inmediata, bloqueo inmutable de respuestas confirmadas e idempotencia. | - [`lib/services/supabase_quiz_service.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/services/supabase_quiz_service.dart)<br>- [`lib/views/quiz_view.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/views/quiz_view.dart)<br>- [`supabase/functions/responder-pregunta/index.ts`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/supabase/functions/responder-pregunta/index.ts)<br>- RPC `registrar_respuesta_individual_v1` en PostgreSQL |
| **RF-30** | **CU-12**: Exportar Cuento a Documento PDF | Generación en cliente de un documento PDF estructurado en A4 con portada pedagógica, escenas narrativas, ilustraciones integradas y decisiones tomadas. | - [`lib/services/pdf_export_service.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/services/pdf_export_service.dart)<br>- [`lib/views/story_view.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/views/story_view.dart) |
| **RF-31** | **CU-14**: Guardar Archivo PDF Localmente | Invocación del diálogo nativo del Explorador de Windows 11 (`SaveFileDialog`) y persistencia local del archivo binario con manejo de errores y cancelación. | - [`lib/services/pdf_export_service.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/services/pdf_export_service.dart)<br>- [`lib/views/story_view.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/lib/views/story_view.dart) |

---

## 3. Arquitectura del Sistema Actualizada

### 3.1. Arquitectura de Capas en Flutter (Cliente Windows)
```
┌────────────────────────────────────────────────────────┐
│                   CAPA DE PRESENTACIÓN                  │
│  - StoryView (Lectura, TTS, Decisiones, Botón PDF)     │
│  - QuizView (Taxonomía 2-2-1, Feedback Inmediato)       │
│  - TeacherHomeView / StudentHomeView                   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                    CAPA DE SERVICIOS                    │
│  - SupabaseQuizService (generarQuiz, responderPregunta)│
│  - PdfExportService (Syncfusion PDF + FilePicker Win32)│
│  - NarracionService (Flutter TTS)                      │
│  - StoryController (Orquestación narrativa)            │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                  REPOSITORIOS Y MODELOS                │
│  - QuizRepositorySupabase / CuentoRepositorySupabase   │
│  - QuizQuestion, QuizQuestionResult, QuizAttemptSummary│
└───────────────────────────┬────────────────────────────┘
                            │ HTTPS / JWT
```

### 3.2. Arquitectura de Backend (Supabase Staging)
```
                            │ HTTPS / JWT
┌───────────────────────────▼────────────────────────────┐
│                SUPABASE EDGE FUNCTIONS (Deno)          │
│  - generar-quiz (Genera 5 preguntas 2-2-1 con Gemini)  │
│  - responder-pregunta (Valida y confirma por pregunta) │
│  - enviar-quiz (Cierre histórico retrocompatible)      │
└───────────────────────────┬────────────────────────────┘
                            │ SQL / PL/pgSQL
┌───────────────────────────▼────────────────────────────┐
│             BASE DE DATOS POSTGRESQL 16 (CLOUD)        │
│  - public.quiz_intentos (estado, puntaje, porcentaje)  │
│  - public.quiz_respuestas (nivel_comprension, inmutable│
│  - RPC registrar_respuesta_individual_v1 (FOR UPDATE)  │
│  - Políticas Row Level Security (Aislamiento Alumno/Doc)│
└────────────────────────────────────────────────────────┘
```

---

## 4. Migraciones SQL Aplicadas en Supabase Staging

El entorno de pruebas de Staging (`acxsyswrzdtstgqztojj`) tiene desplegadas y verificadas las tres migraciones canónicas:

1. `20261007000000_schema_inicial.sql`:
   - Tablas base `profiles`, `aulas`, `estudiantes_aula`, `cuentos`.
   - Esquemas `auth` y funciones auxiliares `app_private`.
2. `20261008100000_quiz_comprension.sql`:
   - Creación de tablas `public.quiz_intentos` y `public.quiz_respuestas`.
   - Definición de llaves foráneas a `estudiante_id` y `completed_at`.
   - Políticas RLS para alumnos y docentes de aula.
3. `20261014130000_quiz_niveles_feedback.sql`:
   - Agregación de columna `nivel_comprension TEXT CHECK (nivel_comprension IN ('literal', 'inferencial', 'critico_reflexivo'))` en `public.quiz_respuestas`.
   - Agregación de columna `respondida BOOLEAN DEFAULT FALSE` para control de inmutabilidad paso a paso.
   - Creación de la función transaccional `registrar_respuesta_individual_v1(p_intento_id, p_numero, p_indice_seleccionado)` con bloqueo pesimista `FOR UPDATE` para garantizar concurrencia e inmutabilidad.

---

## 5. Edge Functions Desplegadas

Las siguientes tres funciones están activas en `https://acxsyswrzdtstgqztojj.supabase.co/functions/v1/`:

1. `generar-quiz`:
   - Autenticación: Valida JWT de estudiante.
   - Lógica: Consulta el cuento, llama a la IA o genera plantilla de contingencia asegurando estrictamente 2 Literales, 2 Inferenciales y 1 Crítico-Reflexiva.
   - Inserta el intento en `quiz_intentos` y las 5 preguntas en `quiz_respuestas`.
   - Retorno al cliente: Oculta `indice_correcto` y explicaciones pedagógicas (seguridad anti-trampas).
2. `responder-pregunta`:
   - Autenticación: Valida JWT del estudiante propietario del intento.
   - Invocación: Invoca la función RPC `registrar_respuesta_individual_v1`.
   - Retorno: `esCorrecta`, `indiceCorrecto`, `explicacion`, `nivelComprension` y estado actualizado del intento.
   - Manejo de errores: Si la respuesta ya fue confirmada y difiere, responde `HTTP 409 Conflict`.
3. `enviar-quiz`:
   - Autenticación: Valida JWT.
   - Función: Compatibilidad con envíos en bloque heredados, blindado para no alterar preguntas ya confirmadas por `responder-pregunta`.

---

## 6. Diferencias entre el Código Actual y los Diagramas Antiguos de la Tesis

| Aspecto Arquitectónico | Diagrama Antiguo de la Tesis | Código Real Implementado (Octubre 2026) | Justificación de la Evolución |
|---|---|---|---|
| **Calificación del Cuestionario** | El cliente Flutter evaluaba las opciones localmente y enviaba el puntaje total a la base de datos. | La calificación se realiza **exclusivamente en Supabase** (PostgreSQL / Edge Function). El cliente nunca recibe las respuestas correctas antes de responder. | Criterio de seguridad y validez de la evaluación formativa; evita manipulación de calificaciones por parte de los estudiantes. |
| **Flujo de Respuestas** | Envío de todas las 5 respuestas en un solo paquete final (Batch). | Flujo interactivo **pregunta a pregunta con retroalimentación inmediata** (RF-26) y cierre atómico al completar la última. | Principios pedagógicos de retroalimentación inmediata y andamiaje cognitivo para primaria. |
| **Dimensiones de Comprensión** | No se discriminaban los niveles taxonómicos en la base de datos (puntaje global 0 a 5). | Taxonomía explícita **2-2-1** almacenada en `quiz_respuestas.nivel_comprension` y visualizada en el Panel Docente. | Exigencia de RF-22 para evaluar la competencia lectora según el Currículo Nacional de Educación Básica (CNEB). |
| **Generación de PDF** | Previsto inicialmente a través de un servicio externo o renderizado HTML a PDF. | Motor nativo en Dart con **`syncfusion_flutter_pdf`** y persistencia directa mediante **Win32 `windows_file_picker`**. | Operación 100% offline, sin costos de APIs externas, garantizando la privacidad de las historias y dibujos creados por los niños. |

---

## 7. Paquete de Cambios Externo

El archivo con todos los cambios de código fuente sin secretos ni credenciales se encuentra disponible en:
`evidencias_tesis_20261014/05_codigo_y_arquitectura/cambios_codigo_rf22_rf26_rf30_rf31.patch`
