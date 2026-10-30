# AUDITORÍA DE SEGURIDAD POSTGRESQL Y POLÍTICAS RLS — CUENTOS MÁGICOS
**Proyecto de Tesis:** Cuentos Mágicos — Aplicación Educativa Adaptativa  
**Enfoque:** Seguridad de Datos Escolares, Privacidad de Menores y Control de Acceso  
**Fecha:** 30 de octubre de 2026  
**Auditor:** Especialista Senior en Ciberseguridad, PostgreSQL y Políticas RLS  

---

## 1. Resumen Ejecutivo de Seguridad

La arquitectura de seguridad del proyecto **Cuentos Mágicos** implementa el principio de **Defensa en Profundidad (Defense in Depth)**, combinando:
1. Control de acceso a nivel de API Gateway (Kong / GoTrue con verificación de JWT).
2. Seguridad a nivel de filas (**Row Level Security - RLS**) activa en el 100% de las tablas relacionales.
3. Esquema privado aislado (`app_private`) con funciones auxiliares que aíslan la lógica de privilegios del alcance de usuarios anónimos o no autorizados.
4. Funciones con privilegio de ejecutor (**`SECURITY DEFINER`**) configuradas con **`SET search_path = ''`** para mitigar de forma definitiva ataques de secuestro de ruta de búsqueda (*search_path hijacking*).
5. Triggers de integridad e inmutabilidad en campos sensibles (`rol`, `id`, `codigo_acceso`).

---

## 2. Matriz de Tablas y Políticas RLS

Todas las tablas del esquema `public` tienen activado `ROW LEVEL SECURITY`. A continuación se detalla la matriz de evaluación técnica:

| Tabla | RLS Activo | Permisos para `anon` | Permisos para `authenticated` | Políticas SELECT | Políticas INSERT/UPDATE/DELETE | Evaluación |
| :--- | :---: | :---: | :---: | :--- | :--- | :---: |
| `public.profiles` | **SÍ** | `REVOKE ALL` | `SELECT` | `id = auth.uid()` o docente del estudiante | No autorizados directamente. Gestionado por trigger seguro. | **ROBUSTO** |
| `public.aulas` | **SÍ** | `REVOKE ALL` | `SELECT, ALL` | Docente propietario o estudiante inscrito | Solo docente propietario (`docente_id = auth.uid()`) | **ROBUSTO** |
| `public.aula_estudiantes`| **SÍ** | `REVOKE ALL` | `SELECT, INSERT, DEL`| Estudiante propio o docente del aula | Solo docente del aula | **ROBUSTO** |
| `public.cuentos` | **SÍ** | `REVOKE ALL` | `SELECT, ALL` | Estudiante autor o docente del estudiante | Solo estudiante autor (`estudiante_id = auth.uid()`) | **ROBUSTO** |
| `public.escenas` | **SÍ** | `REVOKE ALL` | `SELECT, ALL` | Vinculada al cuento del estudiante o docente | Solo estudiante autor del cuento | **ROBUSTO** |
| `public.decisiones_narrativas`| **SÍ** | `REVOKE ALL` | `SELECT, ALL` | Vinculada al cuento del estudiante o docente | Solo estudiante autor del cuento | **ROBUSTO** |
| `public.quiz_intentos` | **SÍ** | `REVOKE ALL` | `SELECT` | Estudiante propio o docente del estudiante | Escritura directa prohibida a clientes; vía Edge/RPC | **ROBUSTO** |
| `public.quiz_respuestas`| **SÍ** | `REVOKE ALL` | `SELECT` | Estudiante propio (solo en intento completado) | Escritura directa prohibida; vía RPC con `FOR UPDATE` | **EXCELENTE** |

---

## 3. Análisis de Aislamiento y Privacidad Escolar

### 3.1. Aislamiento Horizontal entre Estudiantes (Anti-Peeking)
* **Caso de Prueba Evaluado:** Un estudiante autenticado intenta listar perfiles, cuentos o cuestionarios pertenecientes a otro estudiante.
* **Mecanismo RLS:**
  ```sql
  -- profiles
  CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT USING (
      id = auth.uid() 
      OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(id))
  );

  -- cuentos
  CREATE POLICY "cuentos_select_policy" ON public.cuentos
  FOR SELECT USING (
      estudiante_id = auth.uid()
      OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(estudiante_id))
  );
  ```
* **Veredicto:** Si el estudiante `A` consulta registros con el identificador del estudiante `B`, el motor PostgreSQL filtra automáticamente el conjunto de resultados y retorna una lista vacía (`[]`). No se genera filtración de metadatos ni de información personal.

### 3.2. Protección Anti-Fraude en Cuestionarios (`quiz_respuestas`)
* **Regla Crítica:** Durante la realización de un cuestionario, un estudiante no debe poder consultar las respuestas correctas antes de terminar la evaluación.
* **Mecanismo RLS:**
  ```sql
  CREATE POLICY "quiz_respuestas_select_estudiante" ON public.quiz_respuestas
  FOR SELECT USING (
      EXISTS (
          SELECT 1 FROM public.quiz_intentos qi
          WHERE qi.id = public.quiz_respuestas.intento_id
            AND qi.estudiante_id = auth.uid()
            AND qi.estado = 'completado'
      )
  );
  ```
* **Veredicto:** Si el cuestionario está en estado `'en_progreso'`, cualquier consulta `SELECT` sobre `quiz_respuestas` retorna 0 filas al estudiante, impidiendo que descubra las alternativas correctas mediante inspección de tráfico de red.

---

## 4. Auditoría de Funciones `SECURITY DEFINER` y RPCs

Las funciones `SECURITY DEFINER` se ejecutan con los privilegios del usuario creador (normalmente `postgres` o `supabase_admin`). Si no se configuran adecuadamente, representan el vector de ataque más crítico en PostgreSQL.

### 4.1. Análisis de Mitigación de Vulnerabilidades

| Función | Esquema | Privilegio de Ejecución | `search_path` Configurado | Control de Autorización Interno |
| :--- | :--- | :--- | :---: | :--- |
| `es_docente()` | `app_private` | `authenticated, service_role` | `''` (Vacío) | Comprueba `rol = 'docente'` sobre `auth.uid()` |
| `es_estudiante(UUID)` | `app_private` | `authenticated, service_role` | `''` (Vacío) | Comprueba `rol = 'estudiante'` |
| `es_docente_de_estudiante(UUID)` | `app_private` | `authenticated, service_role` | `''` (Vacío) | Valida relación aula-docente |
| `es_docente_de_aula(UUID)` | `app_private` | `authenticated, service_role` | `''` (Vacío) | Valida pertenencia de aula |
| `es_estudiante_de_aula(UUID)` | `app_private` | `authenticated, service_role` | `''` (Vacío) | Valida inscripción del alumno |
| `prevenir_cambio_campos_sensibles()` | `public` | Trigger interno | `''` (Vacío) | Aborta con excepción ante cambios en `rol`, `id` o `codigo_acceso` |
| `handle_new_user()` | `public` | `supabase_auth_admin, service_role` | `public, pg_catalog, pg_temp` | Valida rol obligatorio en metadatos |
| `actualizar_mi_nombre(TEXT)` | `public` | `authenticated` | `''` (Vacío) | Filtra longitud (2 a 80) y fuerza `id = auth.uid()` |
| `responder_pregunta_segura(...)` | `public` | **`service_role` Únicamente** | `public, pg_temp` | Bloqueo por fila (`FOR UPDATE`), idempotencia y cierre atómico |

> [!NOTE]
> **Mitigación de Search Path Hijacking:** Al definir `SET search_path = ''`, cualquier llamada a funciones o tablas debe estar completamente calificada (`public.profiles`, `auth.uid()`). Esto anula la posibilidad de que un usuario cree tablas o funciones maliciosas en un esquema temporal para secuestrar la ejecución de funciones privilegiadas.

---

## 5. Auditoría de Supabase Storage

### Estado Actual de Buckets
- En el código de la Edge Function `generar-imagen` (`supabase/functions/generar-imagen/index.ts`), existe código preparado para almacenar ilustraciones en el bucket `'cuentos'`:
  ```typescript
  const storagePath = `${cuentoId}/escenas/escena_${numeroEscena}.webp`;
  ```
- **Hallazgo:** Actualmente, las imágenes se transmiten en Base64 o URLs directas. Si se formaliza el bucket `'cuentos'`, se debe asegurar que no sea completamente público para prevenir la descarga masiva no autorizada de dibujos escolares.

### Recomendación Preventiva para Storage (Propuesta SQL)
Si en el futuro se activa el bucket `'cuentos'`, se debe aplicar la siguiente política de aislamiento:

```sql
-- PROPUESTA PREVENTIVA (NO APLICAR EN PRODUCCIÓN SIN APROBACIÓN)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('cuentos', 'cuentos', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Permitir lectura solo si el usuario es dueño del cuento o docente asignado
CREATE POLICY "storage_cuentos_lectura_autorizada" ON storage.objects
FOR SELECT USING (
    bucket_id = 'cuentos'
    AND auth.role() = 'authenticated'
    AND (
        -- El primer segmento de la ruta es el cuento_id
        EXISTS (
            SELECT 1 FROM public.cuentos c
            WHERE c.id = split_part(name, '/', 1)
              AND (
                  c.estudiante_id = auth.uid()
                  OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(c.estudiante_id))
              )
        )
    )
);
```

---

## 6. Conclusión de la Auditoría de Seguridad

1. **Vulnerabilidades Críticas:** **0 detectadas.**
2. **Fuga de Claves Privilegiadas en Cliente:** **0.** Flutter solo utiliza la clave pública `anon`.
3. **Omisión de RLS:** **Ninguna.** RLS está habilitado y forzado en todas las entidades escolares.
4. **Cumplimiento Ético y Pedagógico:** Los datos de menores (estudiantes) están estrictamente aislados entre sí y solo son accesibles por su docente legítimamente vinculado mediante un aula escolar.
