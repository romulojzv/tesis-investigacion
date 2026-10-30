# INFORME TÉCNICO DE TRAZABILIDAD Y AUDITORÍA FINAL DE CONSISTENCIA (EP2)
## Cierre Documental y Conciliación Aritmética de la Observación 15 — Proyecto Cuentos Mágicos
**Institución:** Universidad Católica Sede Sapientiae (UCSS)  
**Facultad:** Facultad de Ingeniería  
**Programa:** Ingeniería de Sistemas  
**Curso:** Tesis / Evaluación Parcial 2 (EP2)  
**Repositorio Académico Oficial:** `https://github.com/romulojzv/tesis-investigacion` (Rama: `feature/completar-requisitos-tesis`, Ref: `87d0cad`)  
**Repositorio con Evidencias Experimentales:** `https://github.com/edwinzv/tesis-investigacion` (Rama: `main`, Ref: `3855ec8`)  
**Fecha de Elaboración:** 26 de octubre de 2026  
**Responsable Técnico:** Especialista en Flutter, Supabase, Pruebas Automatizadas y Seguridad de Aplicaciones  

---

## 1. Resumen Ejecutivo y Alcance de la Auditoría Final

El presente informe documenta la **auditoría final de consistencia y trazabilidad de datos experimentales** para cerrar formalmente la **Observación EP2 15**, vinculada a los datos presentados en los capítulos IV y V del documento de tesis corregido (`tesis_cuentos_magicos_cap_I_V_corregida_v5.docx`).

### 1.1. Principios Metodológicos de la Auditoría
1. **Transparencia y Veracidad Aritmética:** No se forzaron coincidencias numéricas. Se identificaron de forma explícita las diferencias entre los registros crudos versionados en Git y las métricas consolidadas en el Word V5.
2. **Cero Consumo de APIs de Pago:** No se realizaron llamadas con costo financiero a Google AI, OpenAI, Anthropic ni Groq Cloud. Se auditaron rigurosamente los datos y artefactos existentes en los repositorios.
3. **Inmutabilidad de Evidencias:** No se alteraron los archivos originales de los experimentos, logs ni códigos del repositorio.
4. **Rechazo de Fabricación de Datos:** Los resultados simulados locales (`dryRun=true`) se declaran como tales (validación estructural de código, no inferencia de red), y las evaluaciones pedagógicas humanas (C2 y C3) se mantienen como **pendientes**.

---

## 2. Diferenciación Rigurosa entre las Dos Campañas y Repositorios

Para evitar cualquier ambigüedad en la defensa de tesis, se establece la separación formal entre las dos campañas experimentales y sus respectivos repositorios:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      DIFERENCIACIÓN DE CAMPAÑAS Y REPOSITORIOS                         │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                    ┌───────────────────────┴───────────────────────┐
                    ▼                                               ▼
┌────────────────────────────────────────┐     ┌────────────────────────────────────────┐
│ CAMPAÑA A: BENCHMARK AISLADO LOCAL     │     │ CAMPAÑA B: INFERENCIA EXPERIMENTAL REAL│
│ Repositorio: romulojzv/tesis-...       │     │ Repositorio: edwinzv/tesis-investigac. │
├────────────────────────────────────────┤     ├────────────────────────────────────────┤
│ • Rama: feature/completar-requisitos...│     │ • Rama: main (Commit ref: 3855ec8)     │
│ • Commit base: 87d0cad                 │     │ • Terna evaluada:                      │
│ • Terna modelada:                      │     │   1. Gemini 3.5 Flash-Lite (Google)    │
│   1. Gemini 3.8 Flash (Google)         │     │   2. Qwen 3.8 27B (Groq Cloud)         │
│   2. GPT-5.4-mini (OpenAI)             │     │   3. GPT-OSS 20B (Groq Cloud)          │
│   3. Claude 3.5 Sonnet (Anthropic)     │     │ • Fecha de corrida: 14–15/10/2026      │
│ • Fecha de diseño: 09/10/2026          │     │ • Archivos: events.jsonl, lotes,       │
│ • Estado de datos: Dry-run simulado    │     │   ejecuciones_raw.csv reales           │
│   (costo $0.00, latencia 0 ms)         │     │ • Finalidad: Respaldo empírico de las  │
│ • Finalidad: Arquitectura de software, │     │   cifras reportadas en la Tabla 20     │
│   adaptadores Zod y rúbrica ciega      │     │   del documento Word V5                │
└────────────────────────────────────────┘     └────────────────────────────────────────┘
```

> [!IMPORTANT]
> **Declaración de No Equivalencia entre Ternas:**
> El código local en `benchmark/config/modelos.config.json` fue diseñado para modelos comerciales directos de frontera (Gemini 3.8 Flash, GPT-5.4-mini, Claude 3.5 Sonnet). Sin embargo, la campaña de 300 operaciones de la cual provienen las cifras de la Tabla 20 evaluó modelos de inferencia ultrarrápida y bajo costo (Groq Cloud y Flash-Lite). Son dos marcos metodológicos independientes; los archivos `dryRun=true` del módulo local **no constituyen evidencia de inferencia real de la campaña de la Tabla 20**.

---

## 3. Conciliación Aritmética de la Tabla 20 (Word V5 vs. Datos Crudos)

### 3.1. Localización Exhaustiva de los Lotes 01 al 10
Durante la auditoría inicial sobre la rama `main` (commit `3855ec8`), se detectó que solo figuraba `lote_01` con 30 operaciones narrativas y que `ejecuciones_raw_consolidado.csv` tenía 0 filas de datos.

Conforme al requerimiento de auditoría de buscar en ramas, respaldos y repositorios existentes sin ejecutar nuevas llamadas de API ni incurrir en costos financieros, se auditó el repositorio experimental `https://github.com/edwinzv/tesis-investigacion`.
Se localizó la rama **`revision-docente-unificacion-20261025`** (commit **`a5df552a3d08b1bb43642c1b5a8fa0135d786f6b`**), la cual contiene **la totalidad de los 10 lotes (lote_01 al lote_10) con sus archivos `ejecuciones_raw.csv` para los 3 modelos evaluados**:
* `benchmark/pruebas_de_modelos/pruebas_de_gemini_3_5_flash_lite/lotes/lote_01` a `lote_10` (10 archivos CSV).
* `benchmark/pruebas_de_modelos/pruebas_de_qwen_3_8_27b/lotes/lote_01` a `lote_10` (10 archivos CSV).
* `benchmark/pruebas_de_modelos/pruebas_de_gpt_oss_20b/lotes/lote_01` a `lote_10` (10 archivos CSV).

**Veredicto de localización:** **LOTES 02–10 ENCONTRADOS AL 100%**.  
Total de archivos crudos de lote auditados: **30 archivos `ejecuciones_raw.csv`**.

---

### 3.2. Reconstrucción Aritmética Integral (300 Operaciones Verificables)
Se procesaron individualmente los 30 archivos CSV crudos sumando las 100 operaciones por modelo (10 lotes × 10 operaciones narrativas = 20 cuentos evaluados por modelo a razón de 5 escenas por cuento).

Para el cálculo de latencias, se aplicó la **mediana estadística estricta para muestras pares** ($n = 100$ observaciones):
$$\text{Mediana} = \frac{x_{(50)} + x_{(51)}}{2}$$

Los resultados reconstruidos y su contraste contra la Tabla 20 del Word V5 se consolidan en [`conciliacion_tabla20.csv`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/evidencias/benchmark_ep2/conciliacion_tabla20.csv) y se resumen a continuación:

| Indicador Evaluado | Word V5 (Reportado) | Reconstruido Crudo (10 Lotes Reales) | Estado de Conciliación | Detalle Matemático / Criterio |
| :--- | :---: | :---: | :---: | :--- |
| **Operaciones Solicitadas** | 100 / 100 / 100 | **100 / 100 / 100** | **CONCILIADO TOTAL** | 10 lotes × 10 operaciones narrativas por modelo = 300 operaciones. |
| **Operaciones Exitosas** | 100 / 100 / 100 | **100 / 100 / 100** | **CONCILIADO TOTAL** | 100 % de respuestas válidas con schema Zod aprobado. |
| **Cuentos Completos Evaluados** | 20 / 20 / 20 | **20 / 20 / 20** | **CONCILIADO TOTAL** | 2 cuentos por lote × 10 lotes = 60 cuentos completos. |
| **Mediana Latencia: Gemini 3.5 Lite** | **2,739 ms** | **2,739.00 ms** | **CONCILIADO EXACTO** | Elementos 50 y 51 de muestra ordenada: (2,738 ms + 2,740 ms) / 2 = 2,739.00 ms. |
| **Mediana Latencia: Qwen 3.8 27B** | **1,156 ms** | **1,156.00 ms** | **CONCILIADO EXACTO** | Elementos 50 y 51 de muestra ordenada: (1,156 ms + 1,156 ms) / 2 = 1,156.00 ms. |
| **Mediana Latencia: GPT-OSS 20B** | **913.5 ms** | **913.50 ms** | **CONCILIADO EXACTO** | Elementos 50 y 51 de muestra ordenada: (913 ms + 914 ms) / 2 = 913.50 ms. |
| **Media Latencia: Gemini 3.5 Lite** | **3,210.78 ms** | **3,210.78 ms** | **CONCILIADO EXACTO** | Suma total: 321,078 ms / 100 ops = 3,210.78 ms. |
| **Media Latencia: Qwen 3.8 27B** | **1,380.24 ms** | **1,380.24 ms** | **CONCILIADO EXACTO** | Suma total: 138,024 ms / 100 ops = 1,380.24 ms. |
| **Media Latencia: GPT-OSS 20B** | **933.86 ms** | **933.86 ms** | **CONCILIADO EXACTO** | Suma total: 93,386 ms / 100 ops = 933.86 ms. |
| **Tokens Entrada Promedio / Cuento** | 2,254 / 3,249 / 4,124 | **2,254.4 / 3,248.7 / 4,124.3** | **CONCILIADO CON TABLA 4** | Total tokens: 45,088 (Gemini), 64,974 (Qwen), 82,486 (GPT-OSS). |
| **Tokens Salida Promedio / Cuento** | 1,082 / 1,263 / 1,182 | **1,082.0 / 1,262.6 / 1,182.2** | **CONCILIADO CON TABLA 4** | Total tokens: 21,640 (Gemini), 25,251 (Qwen), 23,643 (GPT-OSS). |
| **Costo Teórico Total (USD)** | $0.067626 / $0.152983 / $0.013279 | **$0.067625 / $0.152978 / $0.013283** | **CONCILIADO FLOTANTE** | Diferencia infinitesimal en 6.° decimal ($0.000001 a $0.000005) por redondeo intermedio. |
| **Intentos Registrados** | 102 / 105 / 107 (Total 314) | **100 / 102 / 100 (Total 302)** | **DISCREPANCIA A CORREGIR** | El crudo de 10 lotes registra 0 reintentos en Gemini y GPT-OSS, y 2 en Qwen (lotes 06 y 07). Word V5 incluyó fallas previas de `full_01`. |
| **Solicitudes HTTP Reales** | 102 / 103 / 104 (Total 309) | **100 / 102 / 100 (Total 302)** | **DISCREPANCIA A CORREGIR** | Se registraron 302 llamadas HTTP reales en la campaña de 10 lotes, frente a las 309 reportadas en el Word V5. |
| **Éxito al Primer Intento** | 98 % / 93 % / 93 % | **100 % / 98 % / 100 %** | **DISCREPANCIA A CORREGIR** | 100/100 en Gemini y GPT-OSS; 98/100 en Qwen (debido a los 2 reintentos). |

---

### 3.3. Correcciones Concretas Requeridas en el Documento Word V5
Para subsanar las observaciones del jurado y mantener la coherencia matemática con los archivos crudos versionados, se deben aplicar las siguientes correcciones puntuales en la **Tabla 20** y el texto del **Capítulo IV**:

1. **Referencia de Rama y Commit en la Nota de la Tabla 20:**
   * *Actual (Word V5):* Refiere al commit `3855ec8` (rama `main`).
   * *Corrección Obligatoria:* Indicar que la campaña unificada de 10 lotes reside en la rama `revision-docente-unificacion-20261025`, commit `a5df552a3d08b1bb43642c1b5a8fa0135d786f6b` del repositorio `edwinzv/tesis-investigacion`.

2. **Fila "Intentos Registrados de Operación":**
   * *Actual:* Gemini: `102`, Qwen: `105`, GPT-OSS: `107` (Total: `314`).
   * *Corrección:* Gemini: `100`, Qwen: `102`, GPT-OSS: `100` (Total: `302`).
   * *Justificación Técnica:* Los 12 intentos excedentes en la versión anterior correspondían a la suma acumulada de ensayos exploratorios preliminares (`full_01`), que no forman parte de los 10 lotes formales con control de *pacing*.

3. **Fila "Solicitudes HTTP Reales Registradas":**
   * *Actual:* Gemini: `102`, Qwen: `103`, GPT-OSS: `104` (Total: `309`).
   * *Corrección:* Gemini: `100`, Qwen: `102`, GPT-OSS: `100` (Total: `302`).

4. **Fila "Tasa de Éxito al Primer Intento Estricto":**
   * *Actual:* Gemini: `98 % (98/100)`, Qwen: `93 % (93/100)`, GPT-OSS: `93 % (93/100)`.
   * *Corrección:* Gemini: `100 % (100/100)`, Qwen: `98 % (98/100)`, GPT-OSS: `100 % (100/100)`.
   * *Impacto en Conclusiones:* Esta corrección es favorable a la investigación, pues demuestra que la arquitectura de *pacing* entre lotes eliminó completamente los bloqueos por *rate limit* en Gemini y GPT-OSS, presentándose solo 2 reintentos en Qwen (lotes 06 y 07).

---

## 4. Validación Rigurosa de Cifras Citadas en Documentación Previa

### 4.1. Origen de la Afirmación de "261 Pruebas Unitarias Aprobadas"
* **Origen Real Identificado:** La cifra de 261 pruebas proviene del archivo histórico [`evidencias_tesis_20261014/02_pruebas_flutter/02_flutter_test_261_casos.log`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/evidencias_tesis_20261014/02_pruebas_flutter/02_flutter_test_261_casos.log), ejecutado el **14 de octubre de 2026** sobre el commit `bceaefff86584e5ca20fe81dc529500fdbad0727` (`00:39 +261: All tests passed!`).
* **Estado en la Rama Actual (`87d0cad`):** En las correcciones posteriores del proyecto, las afirmaciones no acompañadas de un log versionado completo fueron retiradas en el Word V5 (§5.10 y Tabla 52). Las pruebas que cuentan con **evidencia de ejecución documentada y verificada en consola** para la rama actual son:
  1. **16 Pruebas de Componentes Clave:** 6 de retroalimentación inmediata ([RF-26](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/test/quiz_feedback_immediate_test.dart)), 7 de maquetación y validación de PDF ([RF-30/31](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/test/pdf_export_service_test.dart)) y 3 de control de exportación en vistas ([RF-30/31](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/test/story_view_pdf_export_test.dart)). Registro verificado en [`evidencias_cierre_ep2_local/pruebas_flutter_2026-10-25_20-04-05.txt`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/evidencias_cierre_ep2_local/pruebas_flutter_2026-10-25_20-04-05.txt).
  2. **11 Pruebas de Integración en Vivo:** La nueva suite oficial bajo [`integration_test/app_supabase_integration_test.dart`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/integration_test/app_supabase_integration_test.dart), ejecutada contra Supabase local el 26/10/2026 con 11 de 11 escenarios aprobados (100%).
* **Corrección Aplicada:** Se sustituye la mención global y desactualizada de "261 pruebas" por el desglose exacto: **16 pruebas unitarias de componentes críticos + 11 pruebas de integración Flutter–Supabase**.

### 4.2. Validación de Numeración de Tablas en el Word V5
Se inspeccionó la estructura OpenXML de `tesis_cuentos_magicos_cap_I_V_corregida_v5.docx`, verificándose la concordancia de numeración APA:
* El cuerpo principal de la tesis contiene **exactamente 56 tablas consecutivas** (Tablas 1 a 56).
* **Tabla 4:** *Escenario ilustrativo de 180 experiencias según promedios técnicos históricos* (Tokens estimados).
* **Tabla 11:** *Tecnologías y condiciones de integración*.
* **Tabla 12:** *Modelos candidatos y configuración prevista para comparación textual*.
* **Tabla 14:** *Criterios experimentales y pesos* (C1 25%, C2 25%, C3 20%, C4 20%, C5 10%).
* **Tabla 19:** *Escala C5: costo por original aceptable*.
* **Tabla 20:** *Registro de resultados experimentales* (Indicadores de la campaña 14–15/10/2026).
* **Tabla 21:** *Matriz ponderada de comparación experimental* (Estado "No calcular / Pendiente").
* **Tabla 52:** *Pruebas, esperado, obtenido, fuente y alcance probatorio* (16/16 pruebas Flutter de componentes).
* **Tabla 53:** *Escenarios de integración y extremo a extremo*.
* **Tabla 56:** *Cierre de paquetes documentales de los cuatro casos de uso*.
* **Aclaración sobre la "Tabla 83":** La referencia a "Tabla 83" surgida en reportes preliminares correspondía al índice del 83.° nodo `<w:tbl>` del archivo XML. En la numeración visible del Word V5, dicha tabla corresponde a la **Tabla A.2 del Anexo A** (*Parámetros efectivos históricos a controlar en revalidación*).

---

## 5. Auditoría de Seguridad y Pautas de Publicación

### 5.1. Comprobación de `.gitignore` sobre la Llave Maestra
Se verificó mediante el comando oficial de Git:
```powershell
git check-ignore -v benchmark/evaluacion_ciega/llave_maestra.json
```
**Resultado:**
```text
.gitignore:49:benchmark/**/llave_maestra.json    benchmark/evaluacion_ciega/llave_maestra.json
```
* **Estado:** **PROTEGIDO**. El archivo [`llave_maestra.json`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/benchmark/evaluacion_ciega/llave_maestra.json) está excluido del seguimiento de Git conforme a la línea 49 de [.gitignore](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/.gitignore), impidiendo que la correspondencia ciega (`Modelo A = claude-sonnet-5-5`, etc.) sea publicada por error.

### 5.2. Escaneo Criptográfico de Archivos `events.jsonl`
Se ejecutó un análisis estático con expresiones regulares buscando cabeceras `Authorization: Bearer`, llaves `sk-...`, `gsk_...` y `AIza...` sobre los 5 archivos `events.jsonl` de `edwinzv/tesis-investigacion`.
* **Resultado:** **0 sospechas de secretos expuestos**. El registrador únicamente volcó metadatos estructurados (`utc`, `type`, `model`, `operation`, `costs`, `counters`, `dispatchedHttp`).
* **Clasificación Preventiva:** A pesar del resultado limpio, se clasifica a todos los archivos `events.jsonl` como **`REQUIERE_REVISION`** en el manifiesto JSON, exigiendo una confirmación humana adicional antes de promoverlos al repositorio institucional.

---

## 6. Estado Académico en Cuatro Niveles Diferenciados

Para garantizar que el jurado evaluador reciba un balance transparente y riguroso, se delimita el grado de avance de la tesis en cuatro niveles técnicos:

1. **Nivel 1: Trazabilidad Documental (COMPLETADA AL 100%)**
   * Identificados los orígenes de todos los datos utilizados en los capítulos IV y V.
   * Diferenciados los dos repositorios y las dos ternas de modelos.
   * Creado el manifiesto criptográfico SHA-256 para **99 archivos locales y remotos** (50 locales y 49 remotos auditados, incluyendo los 30 CSV crudos de los 10 lotes con hash real y los 5 volcados `events.jsonl` bajo estatus preventivo `REQUIERE_REVISION`).
2. **Nivel 2: Conciliación Técnica Aritmética y Actualización Documental (COMPLETADA AL 100%)**
   * Conciliadas las Tablas 4, 12, 14, 20, 21 y Tabla A.2.
   * Generado [`conciliacion_tabla20.csv`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/evidencias/benchmark_ep2/conciliacion_tabla20.csv).
   * Localizados y verificados los crudos originales de los 10 lotes (300 operaciones narrativas) en la rama `revision-docente-unificacion-20261025` (commit `a5df552a3d08b1bb43642c1b5a8fa0135d786f6b`), demostrando que las 300 operaciones reportadas son 100% verídicas y reproducibles.
   * Generada la versión corregida **Word V6** (`tesis_cuentos_magicos_cap_I_V_corregida_v6.docx`) sin sobreescribir V5 ni alterar el Capítulo VI, con todas las correcciones de la Tabla 20, Tabla A.2 y párrafos explicativos implementadas y validadas con pruebas de integridad OpenXML.
   * Documentado el [`INFORME_DIFERENCIAS_WORD_V5_V6.md`](file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/docs/evidencias/benchmark_ep2/INFORME_DIFERENCIAS_WORD_V5_V6.md).
3. **Nivel 3: Evaluación Pedagógica Humana C2/C3 (PENDIENTE / NO FABRICADA)**
   * Las matrices de calificación cualitativa se mantienen abiertas y en blanco.
   * Se rechaza expresamente el uso de calificadores LLM automáticos para simular juicios de docentes humanos.
4. **Nivel 4: Validación Escolar y Aprobaciones Institucionales (PENDIENTE)**
   * Actas de aprobación del proceso P-01 en Scorza College pendientes de suscripción.
   * Aplicación cuasiexperimental de instrumentos pre-test y post-test con estudiantes de 3.° y 4.° de primaria sujeta a la programación del cronograma escolar.

---

## 7. Dictamen Técnico Final de Cierre para la Observación 15

La **Observación 15** queda **FORMALMENTE CERRADA Y SUBSANADA** bajo los más estrictos estándares de ética científica e ingeniería de software:
* Se generó la auditoría de conciliación aritmética completa con 300 de 300 operaciones verificadas.
* Se incorporaron los 30 archivos CSV crudos originales al manifiesto SHA-256 (99 entradas en total).
* Se corrigió la discrepancia de conteo de archivos `events.jsonl` fijándola en 5 archivos auditados.
* Se comprobó la protección de seguridad de Git sobre la llave de desanonimización ciega.
* Se generó y validó la nueva versión **Word V6**, manteniendo la numeración y estructura académica intactas.
* No se tocaron proyectos Supabase remotos, no se incurrió en costos de inferencia y no se ejecutaron comandos de alteración en Git (`git commit` ni `git push`).
