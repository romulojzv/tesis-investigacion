-- RF-22 y RF-26: niveles declarados y respuesta por pregunta con bloqueo e idempotencia.
ALTER TABLE public.quiz_respuestas
  ADD COLUMN IF NOT EXISTS nivel_comprension TEXT NOT NULL DEFAULT 'sin_clasificar';

ALTER TABLE public.quiz_respuestas
  DROP CONSTRAINT IF EXISTS chk_quiz_nivel_comprension;

ALTER TABLE public.quiz_respuestas
  ADD CONSTRAINT chk_quiz_nivel_comprension
  CHECK (nivel_comprension IN ('literal', 'inferencial', 'critico_reflexivo', 'sin_clasificar'));

CREATE OR REPLACE FUNCTION public.responder_pregunta_segura(
  p_intento_id UUID,
  p_numero SMALLINT,
  p_indice SMALLINT,
  p_estudiante_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, pg_temp AS $$
DECLARE
  intento public.quiz_intentos%ROWTYPE;
  pregunta public.quiz_respuestas%ROWTYPE;
  puntuacion INT;
  finalizado BOOLEAN := FALSE;
BEGIN
  IF p_numero NOT BETWEEN 1 AND 5 OR p_indice NOT BETWEEN 0 AND 3 THEN
    RAISE EXCEPTION 'Pregunta o alternativa inválida' USING ERRCODE='22023';
  END IF;

  -- Serializar respuestas concurrentes del mismo intento; la identidad viene de JWT verificado en Edge.
  SELECT * INTO intento FROM public.quiz_intentos WHERE id = p_intento_id FOR UPDATE;
  IF NOT FOUND OR intento.estudiante_id <> p_estudiante_id THEN
    RAISE EXCEPTION 'Intento no autorizado' USING ERRCODE='42501';
  END IF;

  -- Defensa en profundidad: si hay contexto de usuario activo, verificar coincidencia con auth.uid()
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_estudiante_id THEN
    RAISE EXCEPTION 'Intento no autorizado' USING ERRCODE='42501';
  END IF;

  SELECT * INTO pregunta FROM public.quiz_respuestas
    WHERE intento_id = p_intento_id AND numero_pregunta = p_numero FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pregunta inexistente' USING ERRCODE='22023';
  END IF;

  IF pregunta.indice_seleccionado IS NOT NULL THEN
    IF pregunta.indice_seleccionado <> p_indice THEN
      RAISE EXCEPTION 'Respuesta ya confirmada y no modificable' USING ERRCODE='22023';
    END IF;
  ELSE
    IF intento.estado <> 'en_progreso' THEN
      RAISE EXCEPTION 'Intento ya cerrado' USING ERRCODE='22023';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.quiz_respuestas r
      WHERE r.intento_id = p_intento_id
        AND r.numero_pregunta < p_numero
        AND r.indice_seleccionado IS NULL
    ) THEN
      RAISE EXCEPTION 'Debe responder las preguntas anteriores' USING ERRCODE='22023';
    END IF;

    UPDATE public.quiz_respuestas
      SET indice_seleccionado = p_indice,
          es_correcta = (p_indice = pregunta.indice_correcto)
      WHERE id = pregunta.id;
  END IF;

  SELECT COUNT(*) FILTER (WHERE es_correcta IS TRUE)
    INTO puntuacion
    FROM public.quiz_respuestas
    WHERE intento_id = p_intento_id;

  -- Finalizar únicamente al completar las cinco selecciones.
  IF NOT EXISTS (
    SELECT 1 FROM public.quiz_respuestas
    WHERE intento_id = p_intento_id AND indice_seleccionado IS NULL
  ) THEN
    UPDATE public.quiz_intentos
      SET estado = 'completado',
          puntaje = puntuacion,
          porcentaje = ROUND(puntuacion * 100.0 / 5),
          completed_at = COALESCE(completed_at, NOW())
      WHERE id = p_intento_id AND estado = 'en_progreso';
    finalizado := TRUE;
  ELSE
    finalizado := (intento.estado = 'completado');
  END IF;

  RETURN jsonb_build_object(
    'numero', pregunta.numero_pregunta,
    'pregunta', pregunta.pregunta,
    'opciones', pregunta.opciones,
    'indiceSeleccionado', p_indice,
    'indiceCorrecto', pregunta.indice_correcto,
    'esCorrecta', (p_indice = pregunta.indice_correcto),
    'explicacion', pregunta.explicacion,
    'nivelComprension', pregunta.nivel_comprension,
    'quizFinalizado', finalizado
  );
END; $$;

REVOKE ALL ON FUNCTION public.responder_pregunta_segura(UUID, SMALLINT, SMALLINT, UUID)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.responder_pregunta_segura(UUID, SMALLINT, SMALLINT, UUID)
  TO service_role;
