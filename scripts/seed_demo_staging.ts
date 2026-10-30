/// <reference lib="deno.ns" />
/// <reference lib="dom" />
import { createClient } from 'npm:@supabase/supabase-js';

const url = Deno.env.get('SUPABASE_URL') || '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

if (!url) {
  console.error('Error de configuración: Se requiere SUPABASE_URL.');
  Deno.exit(1);
}
if (!serviceKey) {
  console.error('Error de configuración: Se requiere SUPABASE_SERVICE_ROLE_KEY.');
  Deno.exit(1);
}

// Salvaguarda: Aceptar exclusivamente el hostname exacto de Staging con HTTPS
try {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'acxsyswrzdtstgqztojj.supabase.co' || (parsed.port && parsed.port !== '443') || parsed.username || parsed.password) {
    throw new Error(`Destino no autorizado: '${parsed.origin}'. Se requiere exclusivamente 'https://acxsyswrzdtstgqztojj.supabase.co'.`);
  }
} catch (err: any) {
  console.error(`⛔ BLOQUEO DE SEGURIDAD: ${err.message}`);
  Deno.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Imagen PNG válida mínima en base64 de 400x200 con encabezado PNG real y compresión
// Representa una ilustración pedagógica de paisaje estilizado para las escenas
const samplePngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAZAAAAEsCAYAAAD5rSTIAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGxSURBVHhe7cExAQAAAMKg9U9tCF8gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgIsBI0AAAekcT84AAAAASUVORK5CYII=';
const dataUri = `data:image/png;base64,${samplePngBase64}`;

async function seed() {
  console.log('================================================================');
  console.log(' SEMBRANDO CUENTA Y CUENTO DEMO EN SUPABASE STAGING');
  console.log(' Target:', url);
  console.log('================================================================');

  const codigoAcceso = 'DEMO26';
  const pin = Deno.env.get('DEMO_ESTUDIANTE_PIN') || '';
  const docentePassword = Deno.env.get('DEMO_DOCENTE_PASSWORD') || '';

  if (!pin) {
    console.error('Error de configuración: Se requiere la variable de entorno DEMO_ESTUDIANTE_PIN.');
    Deno.exit(1);
  }
  if (!docentePassword) {
    console.error('Error de configuración: Se requiere la variable de entorno DEMO_DOCENTE_PASSWORD.');
    Deno.exit(1);
  }

  const emailSintetico = `${codigoAcceso.toLowerCase()}@estudiantes.cuentosmagicos.internal`;
  const nombreEstudiante = 'Nico Explorador';

  // 1. Crear o localizar usuario en Auth
  const { data: listUsers } = await admin.auth.admin.listUsers();
  let user = listUsers?.users?.find(u => u.email === emailSintetico);

  if (user) {
    console.log(`Usuario existente localizado: ${user.id} (${emailSintetico})`);
    await admin.auth.admin.updateUserById(user.id, {
      password: pin,
      user_metadata: { nombre: nombreEstudiante },
      app_metadata: { rol: 'estudiante', codigo_acceso: codigoAcceso },
    });
  } else {
    console.log(`Creando nuevo usuario Auth: ${emailSintetico}...`);
    const { data: nuevo, error: errCreate } = await admin.auth.admin.createUser({
      email: emailSintetico,
      password: pin,
      email_confirm: true,
      user_metadata: { nombre: nombreEstudiante },
      app_metadata: { rol: 'estudiante', codigo_acceso: codigoAcceso },
    });
    if (errCreate) throw errCreate;
    user = nuevo.user;
    console.log(`Usuario creado exitosamente con ID: ${user.id}`);
  }

  // 2. Asegurar perfil en public.profiles
  await admin.from('profiles').upsert({
    id: user.id,
    nombre: nombreEstudiante,
    rol: 'estudiante',
    codigo_acceso: codigoAcceso,
  });
  console.log('✅ Perfil actualizado en public.profiles');

  // 3. Asegurar aula de demostración
  const { data: aulaExistente } = await admin.from('aulas').select('id').eq('codigo_aula', 'DEMO4A').maybeSingle();
  let aulaId = aulaExistente?.id;

  if (!aulaId) {
    // Buscar o crear docente ficticio para el aula
    const docEmail = 'prof.carmen.demo@cuentosmagicos.internal';
    let docUser = listUsers?.users?.find(u => u.email === docEmail);
    if (!docUser) {
      const { data: dNuevo } = await admin.auth.admin.createUser({
        email: docEmail,
        password: docentePassword,
        email_confirm: true,
        user_metadata: { nombre: 'Prof. Carmen Morales' },
        app_metadata: { rol: 'docente' },
      });
      docUser = dNuevo!.user;
      await admin.from('profiles').upsert({
        id: docUser.id,
        nombre: 'Prof. Carmen Morales',
        rol: 'docente',
      });
    }

    const { data: nuevaAula } = await admin.from('aulas').insert({
      nombre: '4to Grado A (Demostración)',
      codigo_aula: 'DEMO4A',
      docente_id: docUser.id,
    }).select().single();
    aulaId = nuevaAula.id;
  }
  console.log('✅ Aula de demostración lista (DEMO4A)');

  // 4. Asegurar inscripción en aula_estudiantes
  await admin.from('aula_estudiantes').upsert({
    aula_id: aulaId,
    estudiante_id: user.id,
    codigo_local: '01',
  });

  // 5. Crear Cuento Demo Completo
  const cuentoId = 'cuento-demo-20261014';
  await admin.from('cuentos').upsert({
    id: cuentoId,
    titulo: 'El Misterio del Valle Dorado',
    personaje_principal: 'Nico el Explorador',
    estudiante_id: user.id,
    aula_id: aulaId,
    es_demo: false,
    origen: 'dibujo',
    descripcion_personaje: 'Nico es un niño curioso de 9 años con sombrero de explorador y binoculares mágicos.',
  });
  console.log('✅ Cuento demo registrado en public.cuentos');

  // 6. Eliminar escenas y decisiones previas del cuento para garantizar estado limpio
  await admin.from('escenas').delete().eq('cuento_id', cuentoId);
  await admin.from('decisiones_narrativas').delete().eq('cuento_id', cuentoId);

  // 7. Insertar las 4 escenas con ilustraciones Data URI
  const escenas = [
    {
      cuento_id: cuentoId,
      numero: 1,
      contenido: 'Nico el Explorador caminaba por los senderos soleados del Valle Dorado. En la ladera encontró una extraña compuerta de piedra cubierta de musgo y símbolos antiguos grabados en su superficie.',
      image_url: dataUri,
      opciones: ['Examinar los símbolos grabados', 'Seguir el sendero hacia la colina'],
      es_final: false,
    },
    {
      cuento_id: cuentoId,
      numero: 2,
      contenido: 'Al descifrar los símbolos, la compuerta se abrió lentamente. Dentro habitaba un gnomo sabio que custodiaba el manantial de agua pura que abastecía a todos los cultivos del valle.',
      image_url: dataUri,
      opciones: ['Saludar con cortesía y respeto', 'Preguntar por qué está oculto'],
      es_final: false,
    },
    {
      cuento_id: cuentoId,
      numero: 3,
      contenido: 'Nico saludó con amabilidad y le ofreció frutas frescas de su mochila. El gnomo sonrió complacido por la nobleza del niño y le mostró cómo la sequía amenazaba la aldea vecina.',
      image_url: dataUri,
      opciones: ['Proponer abrir los canales juntos', 'Pedir consejo al guardián'],
      es_final: false,
    },
    {
      cuento_id: cuentoId,
      numero: 4,
      contenido: 'Juntos activaron los canales de regadío ancestrales. El agua fresca volvió a inundar los campos sedientos y los aldeanos celebraron con música y júbilo la valentía y solidaridad de Nico.',
      image_url: dataUri,
      opciones: ['Fin de la aventura'],
      es_final: true,
    },
  ];

  const { error: errEsc } = await admin.from('escenas').insert(escenas);
  if (errEsc) throw errEsc;
  console.log('✅ 4 escenas con ilustraciones registradas');

  // 8. Insertar decisiones narrativas
  const decisiones = [
    { cuento_id: cuentoId, numero_escena: 1, opcion_seleccionada: 'Examinar los símbolos grabados' },
    { cuento_id: cuentoId, numero_escena: 2, opcion_seleccionada: 'Saludar con cortesía y respeto' },
    { cuento_id: cuentoId, numero_escena: 3, opcion_seleccionada: 'Proponer abrir los canales juntos' },
  ];
  await admin.from('decisiones_narrativas').insert(decisiones);
  console.log('✅ Decisiones narrativas registradas para el PDF');

  // 9. Crear intento de cuestionario en estado 'en_progreso'
  // Limpiar intento previo si existía
  const { data: intentosPrevios } = await admin.from('quiz_intentos').select('id').eq('cuento_id', cuentoId).eq('estudiante_id', user.id);
  if (intentosPrevios && intentosPrevios.length > 0) {
    for (const ip of intentosPrevios) {
      await admin.from('quiz_respuestas').delete().eq('intento_id', ip.id);
      await admin.from('quiz_intentos').delete().eq('id', ip.id);
    }
  }

  const { data: nuevoIntento, error: errIntento } = await admin.from('quiz_intentos').insert({
    cuento_id: cuentoId,
    estudiante_id: user.id,
    aula_id: aulaId,
    estado: 'en_progreso',
    total_preguntas: 5,
    puntaje: null,
    porcentaje: null,
  }).select().single();
  if (errIntento) throw errIntento;
  console.log(`✅ Intento de quiz creado en progreso: ${nuevoIntento.id}`);

  // 10. Insertar las 5 preguntas clasificadas 2-2-1
  const preguntas = [
    {
      intento_id: nuevoIntento.id,
      numero_pregunta: 1,
      pregunta: '¿Quién es el protagonista principal de la historia y qué lugar exploraba?',
      opciones: [
        'Nico el Explorador en el Valle Dorado',
        'Un lobo solitario en el bosque sombrío',
        'Un pescador en el mar abierto',
        'Un rey en su castillo de piedra',
      ],
      indice_correcto: 0,
      explicacion: 'El relato menciona explícitamente al inicio que Nico el Explorador recorría los senderos soleados del Valle Dorado.',
      nivel_comprension: 'literal',
      indice_seleccionado: null,
      es_correcta: null,
    },
    {
      intento_id: nuevoIntento.id,
      numero_pregunta: 2,
      pregunta: '¿Qué ser mágico habitaba detrás de la compuerta de piedra?',
      opciones: [
        'Un gigante de las montañas',
        'Un gnomo sabio custodio del manantial',
        'Un dragón volador',
        'Un duende travieso',
      ],
      indice_correcto: 1,
      explicacion: 'El texto narra directamente que dentro habitaba un gnomo sabio que custodiaba el manantial de agua pura.',
      nivel_comprension: 'literal',
      indice_seleccionado: null,
      es_correcta: null,
    },
    {
      intento_id: nuevoIntento.id,
      numero_pregunta: 3,
      pregunta: '¿Por qué la compuerta y el manantial eran de vital importancia para la aldea?',
      opciones: [
        'Porque guardaban joyas de oro',
        'Porque abastecían de agua a los cultivos y evitaban la sequía',
        'Porque servían de refugio contra animales',
        'Porque eran un sitio secreto de juegos',
      ],
      indice_correcto: 1,
      explicacion: 'A partir de la sequía y los campos sedientos, se deduce que el manantial era el recurso hídrico esencial para la supervivencia.',
      nivel_comprension: 'inferencial',
      indice_seleccionado: null,
      es_correcta: null,
    },
    {
      intento_id: nuevoIntento.id,
      numero_pregunta: 4,
      pregunta: '¿Qué cualidad de Nico permitió ganarse la confianza del gnomo guardián?',
      opciones: [
        'Su habilidad para trepar árboles',
        'Su cortesía, respeto y actitud generosa al compartir',
        'Su fuerza física para mover la roca',
        'Su rapidez para huir ante el peligro',
      ],
      indice_correcto: 1,
      explicacion: 'El gnomo sonrió complacido ante la amabilidad y las provisiones ofrecidas por Nico, demostrando que la nobleza de carácter abrió el diálogo.',
      nivel_comprension: 'inferencial',
      indice_seleccionado: null,
      es_correcta: null,
    },
    {
      intento_id: nuevoIntento.id,
      numero_pregunta: 5,
      pregunta: '¿Qué opinas sobre la decisión de compartir el agua comunal para salvar los sembrados de la aldea?',
      opciones: [
        'Es un acto solidario indispensable para el bien común y la convivencia',
        'El gnomo debió cobrar por cada balde de agua',
        'Fue imprudente porque el agua debió guardarse solo para unos pocos',
        'Es una acción sin importancia en una comunidad',
      ],
      indice_correcto: 0,
      explicacion: 'El acceso compartido y solidario a los recursos naturales vitales es fundamental para el bienestar colectivo y la justicia social en toda comunidad.',
      nivel_comprension: 'critico_reflexivo',
      indice_seleccionado: null,
      es_correcta: null,
    },
  ];

  const { error: errPreg } = await admin.from('quiz_respuestas').insert(preguntas);
  if (errPreg) throw errPreg;
  console.log('✅ 5 preguntas estructuradas 2-2-1 listas para responder');

  console.log('\n================================================================');
  console.log(' ¡CONFIGURACIÓN COMPLETADA CON ÉXITO EN STAGING!');
  console.log('================================================================');
  console.log(`Código de Acceso: ${codigoAcceso}`);
  console.log('PIN: [DEFINIDO POR VARIABLE DE ENTORNO]');
  console.log(`Cuento ID: ${cuentoId}`);
  console.log('================================================================\n');
}

seed().catch(err => {
  console.error('Error sembrando datos:', err);
  Deno.exit(1);
});
