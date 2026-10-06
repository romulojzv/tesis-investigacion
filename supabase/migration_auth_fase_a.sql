-- ============================================================================
-- SCRIPT DE MIGRACIÓN: FASE A (PREPARACIÓN AUTH — COMPATIBLE CON APP ACTUAL)
-- ============================================================================

-- 1. EXTENSIONES Y ESQUEMA PRIVADO
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS app_private;

-- 2. TABLA: PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL CHECK (rol IN ('docente', 'estudiante')),
    codigo_acceso TEXT UNIQUE NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. TABLA: AULAS
CREATE TABLE IF NOT EXISTS public.aulas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    codigo_aula TEXT UNIQUE NOT NULL,
    docente_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. TABLA: AULA_ESTUDIANTES
CREATE TABLE IF NOT EXISTS public.aula_estudiantes (
    aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
    estudiante_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    codigo_local TEXT NOT NULL,
    fecha_inscripcion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (aula_id, estudiante_id),
    CONSTRAINT uq_aula_codigo_local UNIQUE (aula_id, codigo_local)
);

-- 5. EVOLUCIÓN ADITIVA: CUENTOS
-- Se agregan columnas como NULLABLE para respetar cuentos existentes
ALTER TABLE public.cuentos 
ADD COLUMN IF NOT EXISTS estudiante_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.cuentos 
ADD COLUMN IF NOT EXISTS aula_id UUID REFERENCES public.aulas(id) ON DELETE SET NULL;

ALTER TABLE public.cuentos 
ADD COLUMN IF NOT EXISTS es_demo BOOLEAN NOT NULL DEFAULT FALSE;

-- Marcar cuentos preexistentes de pruebas como demos históricos
UPDATE public.cuentos 
SET es_demo = TRUE 
WHERE estudiante_id IS NULL AND es_demo IS FALSE;

-- 6. ÍNDICES DE ALTO RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_profiles_rol ON public.profiles(rol);
CREATE INDEX IF NOT EXISTS idx_profiles_codigo_acceso ON public.profiles(codigo_acceso);
CREATE INDEX IF NOT EXISTS idx_aulas_docente_id ON public.aulas(docente_id);
CREATE INDEX IF NOT EXISTS idx_aula_estudiantes_estudiante ON public.aula_estudiantes(estudiante_id);
CREATE INDEX IF NOT EXISTS idx_aula_estudiantes_aula ON public.aula_estudiantes(aula_id);
CREATE INDEX IF NOT EXISTS idx_cuentos_estudiante_id ON public.cuentos(estudiante_id);
CREATE INDEX IF NOT EXISTS idx_cuentos_aula_id ON public.cuentos(aula_id);

-- ============================================================================
-- 7. HELPERS EN SCHEMA PRIVADO (SECURITY DEFINER + search_path='')
-- ============================================================================

-- Comprueba si el usuario autenticado tiene rol 'docente' en profiles
CREATE OR REPLACE FUNCTION app_private.es_docente()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND rol = 'docente'
    );
$$;

-- Comprueba si el usuario indicado tiene rol 'estudiante' en profiles
CREATE OR REPLACE FUNCTION app_private.es_estudiante(p_usuario_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = p_usuario_id 
          AND rol = 'estudiante'
    );
$$;

-- Comprueba si un estudiante pertenece a alguna aula del docente autenticado
CREATE OR REPLACE FUNCTION app_private.es_docente_de_estudiante(p_estudiante_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.aulas a
        JOIN public.aula_estudiantes ae ON a.id = ae.aula_id
        WHERE a.docente_id = auth.uid() 
          AND ae.estudiante_id = p_estudiante_id
    );
$$;

-- Comprueba si el usuario autenticado es docente y dueño del aula específica
CREATE OR REPLACE FUNCTION app_private.es_docente_de_aula(p_aula_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.aulas a
        JOIN public.profiles p ON p.id = a.docente_id
        WHERE a.id = p_aula_id 
          AND a.docente_id = auth.uid()
          AND p.rol = 'docente'
    );
$$;

-- Comprueba si auth.uid() está matriculado como estudiante en el aula específica
CREATE OR REPLACE FUNCTION app_private.es_estudiante_de_aula(p_aula_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.aula_estudiantes ae
        JOIN public.profiles p ON p.id = ae.estudiante_id
        WHERE ae.aula_id = p_aula_id 
          AND ae.estudiante_id = auth.uid()
          AND p.rol = 'estudiante'
    );
$$;

-- ============================================================================
-- 8. TRIGGERS Y RPC DE SEGURIDAD (search_path='')
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prevenir_cambio_campos_sensibles()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.rol IS DISTINCT FROM OLD.rol THEN
        RAISE EXCEPTION 'Operación rechazada: El rol no puede modificarse.';
    END IF;
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Operación rechazada: El ID de usuario no puede modificarse.';
    END IF;
    IF NEW.codigo_acceso IS DISTINCT FROM OLD.codigo_acceso THEN
        RAISE EXCEPTION 'Operación rechazada: El código de acceso de un estudiante es inmutable.';
    END IF;
    
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_prevenir_cambio_campos_sensibles ON public.profiles;
CREATE TRIGGER tr_prevenir_cambio_campos_sensibles
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevenir_cambio_campos_sensibles();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rol TEXT;
    v_codigo_acceso TEXT;
    v_nombre TEXT;
BEGIN
    v_rol := NEW.raw_app_meta_data->>'rol';
    
    IF v_rol IS NULL OR v_rol NOT IN ('docente', 'estudiante') THEN
        RAISE EXCEPTION 'Registro denegado: Usuario sin rol administrativo autorizado en app_metadata.';
    END IF;

    v_codigo_acceso := NEW.raw_app_meta_data->>'codigo_acceso';
    v_nombre := COALESCE(NEW.raw_user_meta_data->>'nombre', 'Usuario');

    INSERT INTO public.profiles (id, nombre, rol, codigo_acceso)
    VALUES (NEW.id, v_nombre, v_rol, v_codigo_acceso);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.actualizar_mi_nombre(nuevo_nombre TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_limpio TEXT;
BEGIN
    v_limpio := TRIM(nuevo_nombre);
    IF v_limpio IS NULL OR LENGTH(v_limpio) < 2 OR LENGTH(v_limpio) > 80 THEN
        RAISE EXCEPTION 'El nombre debe contener entre 2 y 80 caracteres.';
    END IF;

    UPDATE public.profiles
    SET nombre = v_limpio,
        updated_at = timezone('utc'::text, now())
    WHERE id = auth.uid();
END;
$$;

-- ============================================================================
-- 9. PERMISOS Y PRIVILEGIOS DE FASE A
-- ============================================================================

-- Blindaje de esquema privado y funciones helpers
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA app_private TO authenticated, service_role;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA app_private FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.es_docente() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_estudiante(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_docente_de_estudiante(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_docente_de_aula(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_estudiante_de_aula(UUID) TO authenticated, service_role;

-- Blindaje estricto de funciones de triggers
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevenir_cambio_campos_sensibles() FROM PUBLIC, anon, authenticated;

-- RPC de nombre
REVOKE EXECUTE ON FUNCTION public.actualizar_mi_nombre(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_mi_nombre(TEXT) TO authenticated, service_role;

-- Permisos exclusivamente en tablas NUEVAS (profiles, aulas, aula_estudiantes)
REVOKE ALL ON TABLE public.profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;

REVOKE ALL ON TABLE public.aulas FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.aulas TO authenticated;

REVOKE ALL ON TABLE public.aula_estudiantes FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.aula_estudiantes TO authenticated;

-- ============================================================================
-- 10. POLÍTICAS RLS EN TABLAS NUEVAS (ANTI-RECURSIÓN)
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aulas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_estudiantes ENABLE ROW LEVEL SECURITY;

-- PROFILES
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
FOR SELECT USING (
    id = auth.uid() 
    OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(id))
);

-- AULAS
DROP POLICY IF EXISTS "aulas_docente_insert" ON public.aulas;
CREATE POLICY "aulas_docente_insert" ON public.aulas
FOR INSERT WITH CHECK (
    app_private.es_docente() 
    AND docente_id = auth.uid()
);

DROP POLICY IF EXISTS "aulas_docente_manage" ON public.aulas;
CREATE POLICY "aulas_docente_manage" ON public.aulas
FOR UPDATE USING (
    app_private.es_docente_de_aula(id)
);

DROP POLICY IF EXISTS "aulas_docente_delete" ON public.aulas;
CREATE POLICY "aulas_docente_delete" ON public.aulas
FOR DELETE USING (
    app_private.es_docente_de_aula(id)
);

DROP POLICY IF EXISTS "aulas_select" ON public.aulas;
CREATE POLICY "aulas_select" ON public.aulas
FOR SELECT USING (
    app_private.es_docente_de_aula(id)
    OR app_private.es_estudiante_de_aula(id)
);

-- AULA_ESTUDIANTES
DROP POLICY IF EXISTS "aula_estudiantes_docente_insert" ON public.aula_estudiantes;
CREATE POLICY "aula_estudiantes_docente_insert" ON public.aula_estudiantes
FOR INSERT WITH CHECK (
    app_private.es_docente_de_aula(aula_id)
    AND app_private.es_estudiante(estudiante_id)
);

DROP POLICY IF EXISTS "aula_estudiantes_docente_delete" ON public.aula_estudiantes;
CREATE POLICY "aula_estudiantes_docente_delete" ON public.aula_estudiantes
FOR DELETE USING (
    app_private.es_docente_de_aula(aula_id)
);

DROP POLICY IF EXISTS "aula_estudiantes_select" ON public.aula_estudiantes;
CREATE POLICY "aula_estudiantes_select" ON public.aula_estudiantes
FOR SELECT USING (
    estudiante_id = auth.uid()
    OR app_private.es_docente_de_aula(aula_id)
);
