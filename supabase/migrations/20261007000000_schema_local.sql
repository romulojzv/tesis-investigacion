-- ============================================================================
-- ESQUEMA COMPLETO LOCAL PARA PRUEBAS Y SMOKE TEST (SEMANA 8)
-- Base de datos: PostgreSQL 127.0.0.1:54322 (Supabase Local)
-- Cero impacto en proyecto remoto. Fixtures 100% sintéticos.
-- ============================================================================

-- 1. EXTENSIONES Y ESQUEMA PRIVADO
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS app_private;

-- 2. TABLAS BASE DE AUTENTICACIÓN Y ORGANIZACIÓN ESCOLAR
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL CHECK (rol IN ('docente', 'estudiante')),
    codigo_acceso TEXT UNIQUE NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.aulas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    codigo_aula TEXT UNIQUE NOT NULL,
    docente_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.aula_estudiantes (
    aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
    estudiante_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    codigo_local TEXT NOT NULL,
    fecha_inscripcion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (aula_id, estudiante_id),
    CONSTRAINT uq_aula_codigo_local UNIQUE (aula_id, codigo_local)
);

-- 3. TABLAS NARRATIVAS (CUENTOS MÁGICOS)
CREATE TABLE IF NOT EXISTS public.cuentos (
    id TEXT PRIMARY KEY,
    titulo TEXT NOT NULL,
    titulo_original TEXT,
    personaje_principal TEXT NOT NULL,
    personaje_original TEXT,
    es_personaje_nuevo BOOLEAN NOT NULL DEFAULT FALSE,
    origen TEXT NOT NULL DEFAULT 'dibujo',
    texto_fuente TEXT,
    resumen_original TEXT,
    escenario_original TEXT,
    conflicto_principal TEXT,
    final_original TEXT,
    descripcion_personaje TEXT,
    estudiante_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    aula_id UUID REFERENCES public.aulas(id) ON DELETE SET NULL,
    es_demo BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.escenas (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cuento_id TEXT NOT NULL REFERENCES public.cuentos(id) ON DELETE CASCADE,
    numero INT NOT NULL,
    contenido TEXT NOT NULL,
    image_url TEXT,
    opciones JSONB DEFAULT '[]'::jsonb,
    es_final BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_escenas_cuento_numero UNIQUE (cuento_id, numero)
);

CREATE TABLE IF NOT EXISTS public.decisiones_narrativas (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cuento_id TEXT NOT NULL REFERENCES public.cuentos(id) ON DELETE CASCADE,
    numero_escena INT NOT NULL,
    opcion_seleccionada TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_decisiones_cuento_numero UNIQUE (cuento_id, numero_escena)
);

-- Vista de compatibilidad para queries que utilicen 'decisiones'
CREATE OR REPLACE VIEW public.decisiones WITH (security_invoker = on) AS
SELECT * FROM public.decisiones_narrativas;

-- 4. ÍNDICES DE RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_profiles_rol ON public.profiles(rol);
CREATE INDEX IF NOT EXISTS idx_profiles_codigo_acceso ON public.profiles(codigo_acceso);
CREATE INDEX IF NOT EXISTS idx_aulas_docente_id ON public.aulas(docente_id);
CREATE INDEX IF NOT EXISTS idx_aula_estudiantes_estudiante ON public.aula_estudiantes(estudiante_id);
CREATE INDEX IF NOT EXISTS idx_aula_estudiantes_aula ON public.aula_estudiantes(aula_id);
CREATE INDEX IF NOT EXISTS idx_cuentos_estudiante_id ON public.cuentos(estudiante_id);
CREATE INDEX IF NOT EXISTS idx_cuentos_aula_id ON public.cuentos(aula_id);

-- 5. FUNCIONES HELPER EN app_private (SECURITY DEFINER + search_path='')
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

-- 6. TRIGGERS Y RPC DE SEGURIDAD
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
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
    v_rol TEXT;
    v_codigo_acceso TEXT;
    v_nombre TEXT;
BEGIN
    v_rol := NEW.raw_app_meta_data->>'rol';
    
    IF v_rol IS NULL THEN
        RETURN NEW;
    END IF;

    IF v_rol NOT IN ('docente', 'estudiante') THEN
        RAISE EXCEPTION 'Registro denegado: Usuario sin rol administrativo autorizado en app_metadata.';
    END IF;

    v_codigo_acceso := NEW.raw_app_meta_data->>'codigo_acceso';
    v_nombre := COALESCE(NEW.raw_user_meta_data->>'nombre', 'Usuario');

    INSERT INTO public.profiles (id, nombre, rol, codigo_acceso)
    VALUES (NEW.id, v_nombre, v_rol, v_codigo_acceso)
    ON CONFLICT (id) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        rol = EXCLUDED.rol,
        codigo_acceso = COALESCE(EXCLUDED.codigo_acceso, public.profiles.codigo_acceso);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT OR UPDATE ON auth.users
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

-- 7. PERMISOS Y PRIVILEGIOS
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA app_private TO authenticated, service_role;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA app_private FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.es_docente() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_estudiante(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_docente_de_estudiante(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_docente_de_aula(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION app_private.es_estudiante_de_aula(UUID) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin, service_role;
REVOKE EXECUTE ON FUNCTION public.prevenir_cambio_campos_sensibles() FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.actualizar_mi_nombre(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_mi_nombre(TEXT) TO authenticated, service_role;

-- Revocar accesos por defecto a anon
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.aulas FROM anon;
REVOKE ALL ON TABLE public.aula_estudiantes FROM anon;
REVOKE ALL ON TABLE public.cuentos FROM anon;
REVOKE ALL ON TABLE public.escenas FROM anon;
REVOKE ALL ON TABLE public.decisiones_narrativas FROM anon;

-- Concesión a authenticated
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.aulas TO authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.aula_estudiantes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cuentos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.escenas TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.decisiones_narrativas TO authenticated;

-- Concesión a service_role
GRANT ALL ON TABLE public.profiles TO service_role;
GRANT ALL ON TABLE public.aulas TO service_role;
GRANT ALL ON TABLE public.aula_estudiantes TO service_role;
GRANT ALL ON TABLE public.cuentos TO service_role;
GRANT ALL ON TABLE public.escenas TO service_role;
GRANT ALL ON TABLE public.decisiones_narrativas TO service_role;

-- 8. ROW LEVEL SECURITY (RLS) ACTIVO EN TODAS LAS TABLAS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aulas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_estudiantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cuentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escenas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisiones_narrativas ENABLE ROW LEVEL SECURITY;

-- POLÍTICAS: PROFILES
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
FOR SELECT USING (
    id = auth.uid() 
    OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(id))
);

-- POLÍTICAS: AULAS
DROP POLICY IF EXISTS "aulas_docente_insert" ON public.aulas;
CREATE POLICY "aulas_docente_insert" ON public.aulas
FOR INSERT WITH CHECK (
    app_private.es_docente() 
    AND docente_id = auth.uid()
);

DROP POLICY IF EXISTS "aulas_docente_manage" ON public.aulas;
CREATE POLICY "aulas_docente_manage" ON public.aulas
FOR UPDATE USING (
    docente_id = auth.uid() AND app_private.es_docente()
) WITH CHECK (
    docente_id = auth.uid() AND app_private.es_docente()
);

DROP POLICY IF EXISTS "aulas_docente_delete" ON public.aulas;
CREATE POLICY "aulas_docente_delete" ON public.aulas
FOR DELETE USING (
    docente_id = auth.uid() AND app_private.es_docente()
);

DROP POLICY IF EXISTS "aulas_select" ON public.aulas;
CREATE POLICY "aulas_select" ON public.aulas
FOR SELECT USING (
    (docente_id = auth.uid() AND app_private.es_docente())
    OR app_private.es_estudiante_de_aula(id)
);

-- POLÍTICAS: AULA_ESTUDIANTES
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

-- POLÍTICAS: CUENTOS
DROP POLICY IF EXISTS "cuentos_select_policy" ON public.cuentos;
CREATE POLICY "cuentos_select_policy" ON public.cuentos
FOR SELECT USING (
    estudiante_id = auth.uid()
    OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(estudiante_id))
);

DROP POLICY IF EXISTS "cuentos_insert_policy" ON public.cuentos;
CREATE POLICY "cuentos_insert_policy" ON public.cuentos
FOR INSERT WITH CHECK (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
    AND (
        aula_id IS NULL 
        OR app_private.es_estudiante_de_aula(aula_id)
    )
);

DROP POLICY IF EXISTS "cuentos_update_policy" ON public.cuentos;
CREATE POLICY "cuentos_update_policy" ON public.cuentos
FOR UPDATE 
USING (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
)
WITH CHECK (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
    AND (
        aula_id IS NULL 
        OR app_private.es_estudiante_de_aula(aula_id)
    )
);

DROP POLICY IF EXISTS "cuentos_delete_policy" ON public.cuentos;
CREATE POLICY "cuentos_delete_policy" ON public.cuentos
FOR DELETE USING (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
);

-- POLÍTICAS: ESCENAS
DROP POLICY IF EXISTS "escenas_select_policy" ON public.escenas;
CREATE POLICY "escenas_select_policy" ON public.escenas
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.escenas.cuento_id 
          AND (
              c.estudiante_id = auth.uid()
              OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(c.estudiante_id))
          )
    )
);

DROP POLICY IF EXISTS "escenas_modify_policy" ON public.escenas;
CREATE POLICY "escenas_modify_policy" ON public.escenas
FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.escenas.cuento_id AND c.estudiante_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.escenas.cuento_id AND c.estudiante_id = auth.uid()
    )
);

-- POLÍTICAS: DECISIONES NARRATIVAS
DROP POLICY IF EXISTS "decisiones_select_policy" ON public.decisiones_narrativas;
CREATE POLICY "decisiones_select_policy" ON public.decisiones_narrativas
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.decisiones_narrativas.cuento_id 
          AND (
              c.estudiante_id = auth.uid()
              OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(c.estudiante_id))
          )
    )
);

DROP POLICY IF EXISTS "decisiones_modify_policy" ON public.decisiones_narrativas;
CREATE POLICY "decisiones_modify_policy" ON public.decisiones_narrativas
FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.decisiones_narrativas.cuento_id AND c.estudiante_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.cuentos c 
        WHERE c.id = public.decisiones_narrativas.cuento_id AND c.estudiante_id = auth.uid()
    )
);
