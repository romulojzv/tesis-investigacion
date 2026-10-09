-- ============================================================================
-- MIGRACIÓN LOCAL: QUIZ DE COMPRENSIÓN LECTORA
-- Tablas: public.quiz_intentos y public.quiz_respuestas
-- RLS estricto para estudiantes y docentes (sin permisos de escritura directa en cliente)
-- ============================================================================

-- 1. TABLA: QUIZ_INTENTOS
CREATE TABLE IF NOT EXISTS public.quiz_intentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuento_id TEXT NOT NULL REFERENCES public.cuentos(id) ON DELETE CASCADE,
    estudiante_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    aula_id UUID NULL REFERENCES public.aulas(id) ON DELETE SET NULL,
    estado TEXT NOT NULL DEFAULT 'en_progreso' CHECK (estado IN ('en_progreso', 'completado')),
    puntaje SMALLINT NULL CHECK (puntaje IS NULL OR (puntaje BETWEEN 0 AND 5)),
    total_preguntas SMALLINT NOT NULL DEFAULT 5 CHECK (total_preguntas = 5),
    porcentaje NUMERIC NULL CHECK (porcentaje IS NULL OR (porcentaje >= 0 AND porcentaje <= 100)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_quiz_intentos_cuento_estudiante UNIQUE (cuento_id, estudiante_id)
);

-- 2. TABLA: QUIZ_RESPUESTAS
CREATE TABLE IF NOT EXISTS public.quiz_respuestas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intento_id UUID NOT NULL REFERENCES public.quiz_intentos(id) ON DELETE CASCADE,
    numero_pregunta SMALLINT NOT NULL CHECK (numero_pregunta BETWEEN 1 AND 5),
    pregunta TEXT NOT NULL,
    opciones JSONB NOT NULL CHECK (jsonb_typeof(opciones) = 'array' AND jsonb_array_length(opciones) = 4),
    indice_correcto SMALLINT NOT NULL CHECK (indice_correcto BETWEEN 0 AND 3),
    indice_seleccionado SMALLINT NULL CHECK (indice_seleccionado IS NULL OR (indice_seleccionado BETWEEN 0 AND 3)),
    es_correcta BOOLEAN NULL,
    explicacion TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_quiz_respuestas_intento_pregunta UNIQUE (intento_id, numero_pregunta)
);

-- 3. ÍNDICES DE RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_quiz_intentos_estudiante_id ON public.quiz_intentos(estudiante_id);
CREATE INDEX IF NOT EXISTS idx_quiz_intentos_aula_id ON public.quiz_intentos(aula_id);
CREATE INDEX IF NOT EXISTS idx_quiz_intentos_cuento_id ON public.quiz_intentos(cuento_id);
CREATE INDEX IF NOT EXISTS idx_quiz_intentos_completed_at ON public.quiz_intentos(completed_at);
CREATE INDEX IF NOT EXISTS idx_quiz_respuestas_intento_id ON public.quiz_respuestas(intento_id);

-- 4. PERMISOS Y PRIVILEGIOS
REVOKE ALL ON TABLE public.quiz_intentos FROM anon;
REVOKE ALL ON TABLE public.quiz_respuestas FROM anon;

GRANT SELECT ON TABLE public.quiz_intentos TO authenticated;
GRANT SELECT ON TABLE public.quiz_respuestas TO authenticated;

GRANT ALL ON TABLE public.quiz_intentos TO service_role;
GRANT ALL ON TABLE public.quiz_respuestas TO service_role;

-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.quiz_intentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_respuestas ENABLE ROW LEVEL SECURITY;

-- POLÍTICAS: QUIZ_INTENTOS
DROP POLICY IF EXISTS "quiz_intentos_select_policy" ON public.quiz_intentos;
DROP POLICY IF EXISTS "quiz_intentos_select_estudiante" ON public.quiz_intentos;
CREATE POLICY "quiz_intentos_select_estudiante" ON public.quiz_intentos
FOR SELECT USING (
    estudiante_id = auth.uid()
);

DROP POLICY IF EXISTS "quiz_intentos_select_docente" ON public.quiz_intentos;
CREATE POLICY "quiz_intentos_select_docente" ON public.quiz_intentos
FOR SELECT USING (
    app_private.es_docente() AND (
        (aula_id IS NOT NULL AND app_private.es_docente_de_aula(aula_id))
        OR app_private.es_docente_de_estudiante(estudiante_id)
    )
);

-- POLÍTICAS: QUIZ_RESPUESTAS
DROP POLICY IF EXISTS "quiz_respuestas_select_policy" ON public.quiz_respuestas;
DROP POLICY IF EXISTS "quiz_respuestas_select_estudiante" ON public.quiz_respuestas;
CREATE POLICY "quiz_respuestas_select_estudiante" ON public.quiz_respuestas
FOR SELECT USING (
    -- Estudiante: solo puede consultar sus respuestas cuando el intento esté completado
    EXISTS (
        SELECT 1 FROM public.quiz_intentos qi
        WHERE qi.id = public.quiz_respuestas.intento_id
          AND qi.estudiante_id = auth.uid()
          AND qi.estado = 'completado'
    )
);

DROP POLICY IF EXISTS "quiz_respuestas_select_docente" ON public.quiz_respuestas;
CREATE POLICY "quiz_respuestas_select_docente" ON public.quiz_respuestas
FOR SELECT USING (
    -- Docente: puede consultar respuestas de estudiantes de sus aulas
    app_private.es_docente() AND EXISTS (
        SELECT 1 FROM public.quiz_intentos qi
        WHERE qi.id = public.quiz_respuestas.intento_id
          AND (
              (qi.aula_id IS NOT NULL AND app_private.es_docente_de_aula(qi.aula_id))
              OR app_private.es_docente_de_estudiante(qi.estudiante_id)
          )
    )
);

