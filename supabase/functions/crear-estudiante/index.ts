import '@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const jsonHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json',
};

Deno.serve(async (req: Request) => {
  // 1. Manejo de pre-vuelo CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 2. Restricción estricta de método HTTP
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Método no permitido. Solo se acepta POST.' }),
      { status: 405, headers: jsonHeaders },
    );
  }

  try {
    // 3. Autenticación del Docente mediante Bearer JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'No autorizado. Se requiere token Bearer en el encabezado.' }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Token de autorización vacío.' }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('[crear-estudiante] Error de configuración: faltan variables SUPABASE_URL o SERVICE_ROLE_KEY.');
      return new Response(
        JSON.stringify({ error: 'Error interno en la configuración del servidor.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Validar token contra Supabase Auth
    const { data: userData, error: userAuthError } = await supabaseAdmin.auth.getUser(token);
    if (userAuthError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: 'Sesión no válida o expirada. Por favor inicie sesión nuevamente.' }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const docenteUser = userData.user;

    // 4. Comprobar rol 'docente' en public.profiles
    const { data: docenteProfile, error: profError } = await supabaseAdmin
      .from('profiles')
      .select('id, nombre, rol')
      .eq('id', docenteUser.id)
      .maybeSingle();

    if (profError || !docenteProfile || docenteProfile.rol !== 'docente') {
      return new Response(
        JSON.stringify({ error: 'Acceso denegado. Se requiere rol docente para registrar estudiantes.' }),
        { status: 403, headers: jsonHeaders },
      );
    }

    // 5. Parseo y validación de entrada
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return new Response(
        JSON.stringify({ error: 'Cuerpo de solicitud inválido o JSON mal formado.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const rawNombre = body.nombre?.toString().trim() ?? '';
    const rawAulaId = body.aulaId?.toString().trim() ?? '';
    const rawCodigoLocal = body.codigoLocal?.toString().trim() ?? '';

    // Validación: nombre
    if (rawNombre.length < 2 || rawNombre.length > 80) {
      return new Response(
        JSON.stringify({ error: 'El nombre del estudiante debe tener entre 2 y 80 caracteres.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // Validación: aulaId (formato UUID)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!rawAulaId || !uuidRegex.test(rawAulaId)) {
      return new Response(
        JSON.stringify({ error: 'El aulaId proporcionado no tiene un formato UUID válido.' }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // Validación: codigoLocal (alfanumérico y guiones, 1 a 20 caracteres)
    const codigoLocalRegex = /^[A-Za-z0-9_-]{1,20}$/;
    if (!rawCodigoLocal || !codigoLocalRegex.test(rawCodigoLocal)) {
      return new Response(
        JSON.stringify({
          error: 'El código local debe ser alfanumérico (letras, números o guiones) y tener entre 1 y 20 caracteres.',
        }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // 6. Validar propiedad del aula
    const { data: aula, error: aulaError } = await supabaseAdmin
      .from('aulas')
      .select('id, nombre, codigo_aula, docente_id')
      .eq('id', rawAulaId)
      .eq('docente_id', docenteUser.id)
      .maybeSingle();

    if (aulaError || !aula) {
      return new Response(
        JSON.stringify({ error: 'El aula indicada no existe o no pertenece al docente autenticado.' }),
        { status: 403, headers: jsonHeaders },
      );
    }

    // 7. Validar disponibilidad de codigoLocal en el aula
    const { data: matriculaExistente } = await supabaseAdmin
      .from('aula_estudiantes')
      .select('estudiante_id')
      .eq('aula_id', rawAulaId)
      .eq('codigo_local', rawCodigoLocal)
      .maybeSingle();

    if (matriculaExistente) {
      return new Response(
        JSON.stringify({
          error: `El código local '${rawCodigoLocal}' ya se encuentra asignado a otro estudiante en esta aula.`,
        }),
        { status: 409, headers: jsonHeaders },
      );
    }

    // 8. Generar codigo_acceso globalmente único y verificar colisiones
    const codigoAcceso = `${aula.codigo_aula}-${rawCodigoLocal}`.toUpperCase();

    const { data: perfilExistente } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('codigo_acceso', codigoAcceso)
      .maybeSingle();

    if (perfilExistente) {
      return new Response(
        JSON.stringify({
          error: `Colisión de código de acceso global '${codigoAcceso}'. Modifique el código local para evitar duplicados.`,
        }),
        { status: 409, headers: jsonHeaders },
      );
    }

    // 9. Generar PIN criptográfico de 6 dígitos con Web Crypto (rango 100000 - 999999)
    const randomBuffer = new Uint32Array(1);
    crypto.getRandomValues(randomBuffer);
    const pin = (100000 + (randomBuffer[0] % 900000)).toString();

    // 10. Construir email técnico sintético determinista
    const emailSintetico = `${codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;

    // 11. Creación en Supabase Auth mediante Admin API
    const { data: nuevoAuthUser, error: createAuthError } = await supabaseAdmin.auth.admin.createUser({
      email: emailSintetico,
      password: pin,
      email_confirm: true,
      app_metadata: {
        rol: 'estudiante',
        codigo_acceso: codigoAcceso,
      },
      user_metadata: {
        nombre: rawNombre,
      },
    });

    if (createAuthError || !nuevoAuthUser?.user) {
      console.error('[crear-estudiante] Error al registrar usuario en Auth:', createAuthError?.message);
      return new Response(
        JSON.stringify({ error: 'No se pudo crear la cuenta del estudiante en el servicio de autenticación.' }),
        { status: 500, headers: jsonHeaders },
      );
    }

    const nuevoEstudianteId = nuevoAuthUser.user.id;

    // 12. Matrícula en public.aula_estudiantes con ROLLBACK COMPENSATORIO
    try {
      const { error: enrollError } = await supabaseAdmin
        .from('aula_estudiantes')
        .insert({
          aula_id: rawAulaId,
          estudiante_id: nuevoEstudianteId,
          codigo_local: rawCodigoLocal,
        });

      if (enrollError) {
        console.error(
          '[crear-estudiante] Error al insertar matrícula. Ejecutando rollback compensatorio...',
          enrollError.message,
        );
        // Rollback: Eliminar usuario de Auth para no dejar cuentas huérfanas
        await supabaseAdmin.auth.admin.deleteUser(nuevoEstudianteId);

        return new Response(
          JSON.stringify({
            error: 'No se pudo registrar la matrícula del estudiante. La cuenta fue cancelada para mantener consistencia.',
          }),
          { status: 500, headers: jsonHeaders },
        );
      }
    } catch (enrollCatchErr) {
      console.error('[crear-estudiante] Excepción inesperada en matrícula. Ejecutando rollback...', enrollCatchErr);
      await supabaseAdmin.auth.admin.deleteUser(nuevoEstudianteId);

      return new Response(
        JSON.stringify({
          error: 'Error inesperado durante la matrícula escolar. Se aplicó reversión automática.',
        }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // 13. Registro seguro (sin credenciales ni PIN en logs)
    console.log('[crear-estudiante] Estudiante registrado exitosamente:', {
      estudianteId: nuevoEstudianteId,
      codigoAcceso,
      aulaId: rawAulaId,
      docenteId: docenteUser.id,
    });

    // 14. Respuesta exitosa (PIN retornado UNA SOLA VEZ)
    return new Response(
      JSON.stringify({
        success: true,
        estudianteId: nuevoEstudianteId,
        nombre: rawNombre,
        codigoAcceso: codigoAcceso,
        pin: pin,
      }),
      { status: 201, headers: jsonHeaders },
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error('[crear-estudiante] Error no controlado:', errorMsg);

    return new Response(
      JSON.stringify({ error: 'Error interno no controlado al procesar la solicitud.' }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
