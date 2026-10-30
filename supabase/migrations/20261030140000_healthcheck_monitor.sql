-- ==============================================================================
-- MIGRACIÓN CANDIDATA: ENDPOINT SEGURO DE HEALTHCHECK PARA MONITOREO
-- Archivo: supabase/migrations/20261030140000_healthcheck_monitor.sql
-- Objetivo: Permitir que el monitor externo verifique que PostgreSQL está activo
--           respondiendo HTTP 200 OK sin exponer información escolar ni usar service_role.
-- ==============================================================================

-- 1. Tabla pública inocua de salud (1 sola fila garantizada por CHECK (id = 1))
CREATE TABLE IF NOT EXISTS public.healthcheck (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    status TEXT NOT NULL DEFAULT 'ok',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Insertar la fila única si no existe
INSERT INTO public.healthcheck (id, status)
VALUES (1, 'ok')
ON CONFLICT (id) DO UPDATE SET updated_at = timezone('utc'::text, now());

-- 2. Activar Row Level Security
ALTER TABLE public.healthcheck ENABLE ROW LEVEL SECURITY;

-- 3. Permisos mínimos: Solo SELECT a anon y authenticated
REVOKE ALL ON TABLE public.healthcheck FROM PUBLIC;
GRANT SELECT ON TABLE public.healthcheck TO anon, authenticated;

-- 4. Política de lectura pública e inocua
DROP POLICY IF EXISTS "healthcheck_read_policy" ON public.healthcheck;
CREATE POLICY "healthcheck_read_policy" ON public.healthcheck
FOR SELECT USING (true);
