import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface AuthEstudianteResult {
  ok: boolean;
  userId?: string;
  userClient?: SupabaseClient;
  response?: Response;
}

/**
 * Valida que la solicitud HTTP contenga un JWT válido perteneciente a un usuario
 * con rol 'estudiante' en public.profiles.
 * 
 * Respuestas:
 * - 401: Falta encabezado Authorization, token vacío o JWT inválido/expirado.
 * - 403: Usuario autenticado sin perfil o con rol distinto a 'estudiante' (p. ej. 'docente').
 * - ok: true si el estudiante es legítimo y está autenticado.
 */
export async function validarEstudianteAutenticado(
  req: Request,
  corsHeaders: Record<string, string>,
): Promise<AuthEstudianteResult> {
  const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' };

  // 1. Obtener encabezado Authorization
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'No autorizado. Se requiere token Bearer en el encabezado.' }),
        { status: 401, headers: jsonHeaders },
      ),
    };
  }

  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'Token de autorización vacío.' }),
        { status: 401, headers: jsonHeaders },
      ),
    };
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('Error de configuración: falta variable SUPABASE_URL o claves en el entorno.');
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'Error interno en la configuración del servidor.' }),
        { status: 500, headers: jsonHeaders },
      ),
    };
  }

  // 2. Crear cliente en el contexto del usuario (enviando su JWT para que RLS actúe normalmente)
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 3. Validar token contra Supabase Auth
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData?.user) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'Sesión no válida o expirada. Por favor inicie sesión nuevamente.' }),
        { status: 401, headers: jsonHeaders },
      ),
    };
  }

  const userId = userData.user.id;

  // 4. Consultar profile bajo RLS del usuario autenticado
  const { data: profile, error: profError } = await userClient
    .from('profiles')
    .select('id, rol')
    .eq('id', userId)
    .maybeSingle();

  if (profError || !profile) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'Acceso denegado. Perfil de usuario no encontrado o sin permisos.' }),
        { status: 403, headers: jsonHeaders },
      ),
    };
  }

  if (profile.rol !== 'estudiante') {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: 'Acceso denegado. Función reservada exclusivamente para estudiantes.' }),
        { status: 403, headers: jsonHeaders },
      ),
    };
  }

  return { ok: true, userId, userClient };
}
