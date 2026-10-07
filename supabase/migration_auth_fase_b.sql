-- ============================================================================
-- SCRIPT DE MIGRACIÓN: FASE B (CORTE DE SEGURIDAD DEFINITIVO Y AISLAMIENTO)
-- ADVERTENCIA: NO EJECUTAR HASTA QUE FLUTTER AUTH Y SESIONES ESTÉN OPERATIVAS
-- ============================================================================

-- 1. ELIMINACIÓN DE POLICIES TEMPORALES / PROTOTIPO
DROP POLICY IF EXISTS "Lectura temporal de cuentos" ON public.cuentos;
DROP POLICY IF EXISTS "Insercion temporal de cuentos" ON public.cuentos;
DROP POLICY IF EXISTS "Actualizacion temporal de cuentos" ON public.cuentos;

DROP POLICY IF EXISTS "Lectura temporal de escenas" ON public.escenas;
DROP POLICY IF EXISTS "Insercion temporal de escenas" ON public.escenas;
DROP POLICY IF EXISTS "Actualizacion temporal de escenas" ON public.escenas;

DROP POLICY IF EXISTS "Lectura temporal de decisiones" ON public.decisiones_narrativas;
DROP POLICY IF EXISTS "Insercion temporal de decisiones" ON public.decisiones_narrativas;
DROP POLICY IF EXISTS "Actualizacion temporal de decisiones" ON public.decisiones_narrativas;

-- Limpieza preventiva adicional de cualquier otra política legacy en estas tablas
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename IN ('cuentos', 'escenas', 'decisiones_narrativas')
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
        RAISE NOTICE 'Policy eliminada: % en tabla %', r.policyname, r.tablename;
    END LOOP;
END $$;

-- 2. REVOCACIÓN TOTAL DE ACCESO A ANON Y AUTHENTICATED
REVOKE ALL ON TABLE public.cuentos FROM anon;
REVOKE ALL ON TABLE public.cuentos FROM authenticated;

REVOKE ALL ON TABLE public.escenas FROM anon;
REVOKE ALL ON TABLE public.escenas FROM authenticated;

REVOKE ALL ON TABLE public.decisiones_narrativas FROM anon;
REVOKE ALL ON TABLE public.decisiones_narrativas FROM authenticated;

-- 3. CONCESIÓN SELECTIVA A USUARIOS AUTENTICADOS (RLS regulará el acceso)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cuentos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.escenas TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.decisiones_narrativas TO authenticated;

GRANT ALL ON TABLE public.cuentos TO service_role;
GRANT ALL ON TABLE public.escenas TO service_role;
GRANT ALL ON TABLE public.decisiones_narrativas TO service_role;

-- 4. ACTIVACIÓN OBLIGATORIA DE RLS
ALTER TABLE public.cuentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escenas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisiones_narrativas ENABLE ROW LEVEL SECURITY;

-- 5. POLÍTICAS DEFINITIVAS DE CUENTOS
CREATE POLICY "cuentos_select_policy" ON public.cuentos
FOR SELECT USING (
    estudiante_id = auth.uid()
    OR (app_private.es_docente() AND app_private.es_docente_de_estudiante(estudiante_id))
);

CREATE POLICY "cuentos_insert_policy" ON public.cuentos
FOR INSERT WITH CHECK (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
    AND (
        aula_id IS NULL 
        OR app_private.es_estudiante_de_aula(aula_id)
    )
);

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

CREATE POLICY "cuentos_delete_policy" ON public.cuentos
FOR DELETE USING (
    app_private.es_estudiante(auth.uid())
    AND estudiante_id = auth.uid()
);

-- 6. POLÍTICAS DEFINITIVAS DE ESCENAS
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

-- 7. POLÍTICAS DEFINITIVAS DE DECISIONES NARRATIVAS
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
