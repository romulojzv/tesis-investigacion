import 'dart:typed_data';

/// Estados posibles para el proceso de ilustración de una escena
enum EstadoGeneracionImagen { sinImagen, generando, completada, error }

/// Parámetros estructurados para solicitar la ilustración de una escena
class SolicitudImagenEscena {
  final String cuentoId;
  final int numeroEscena;
  final String contenidoEscena;
  final String nombreProtagonista;
  final String? descripcionPersonaje;
  final String? escenario;
  final Uint8List? referenciaVisualBytes;
  final Uint8List? referenciaAnteriorBytes;
  final String estiloVisual;
  final bool esModoDibujo;

  const SolicitudImagenEscena({
    required this.cuentoId,
    required this.numeroEscena,
    required this.contenidoEscena,
    required this.nombreProtagonista,
    this.descripcionPersonaje,
    this.escenario,
    this.referenciaVisualBytes,
    this.referenciaAnteriorBytes,
    this.estiloVisual = 'Ilustración infantil cálida y colorida para libro de cuentos de primaria, estilo acuarela digital limpia, sin texto escrito dentro de la imagen',
    this.esModoDibujo = false,
  });

  /// Construye un prompt detallado optimizado para generadores de imágenes
  String construirPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('Estilo artístico: $estiloVisual.');

    // 1. CHARACTER IDENTITY — PRESERVE
    buffer.writeln(
      '1. IDENTIDAD DEL PROTAGONISTA (PRESERVAR): Protagonista: $nombreProtagonista.',
    );
    if (descripcionPersonaje != null &&
        descripcionPersonaje!.trim().isNotEmpty) {
      buffer.writeln(
        'Rasgos base permanentes del protagonista: ${descripcionPersonaje!.trim()}. '
        'Mantener estrictamente al mismo protagonista en todas las ilustraciones: '
        'misma especie o forma base, mismo tipo o naturaleza visual, silueta, '
        'rasgos principales y paleta de color característica. '
        'NO transformar al protagonista en una criatura u objeto diferente.',
      );
    } else {
      buffer.writeln(
        'Preservar la identidad visual del protagonista en todas las escenas.',
      );
    }

    // 2. CURRENT SCENE — MUST DEPICT
    buffer.writeln(
      '2. ESCENA ACTUAL (REPRESENTAR OBLIGATORIAMENTE ESTA ACCIÓN Y ENTORNO): '
      'La ilustración DEBE representar específicamente lo que sucede en la escena actual: '
      '${contenidoEscena.trim()}. '
      '${(escenario != null && escenario!.trim().isNotEmpty) ? 'Entorno y escenario específico: ${escenario!.trim()}. ' : ''}'
      'Representar con claridad los elementos visuales clave mencionados en el texto (lugares, objetos, acciones, gestos).',
    );

    // 3. COMPOSITION — MUST CHANGE WHEN STORY CHANGES
    buffer.writeln(
      '3. COMPOSICIÓN Y ENCUADRE DINÁMICO (CAMBIAR SEGÚN LA HISTORIA): '
      'Crear una nueva composición, encuadre y ángulo de cámara acorde a la acción de esta escena. '
      'Adaptar la pose, orientación y posición del protagonista a la acción descrita. '
      'Evitar estrictamente repetir la misma pose, mismo encuadre o mismo fondo de la escena anterior '
      'cuando la historia ha cambiado.',
    );

    // 4. PREVIOUS IMAGE — IDENTITY REFERENCE ONLY
    buffer.writeln(
      '4. USO DE REFERENCIA VISUAL PREVIA (SOLO PARA IDENTIDAD): '
      'The previous image is a CHARACTER IDENTITY reference only. '
      'Do not copy its pose, camera angle, background, scenery, or composition. '
      'Create a genuinely new illustration that depicts the CURRENT scene text. '
      'If the previous image conflicts with the current narrative, follow the current narrative while preserving only the protagonist\'s identity. '
      'Expressly AVOID: same pose, same camera framing, same background, same composition across scenes.',
    );

    if (esModoDibujo) {
      buffer.writeln(
        'Transformación suave de dibujo infantil: '
        'Transforma suavemente este dibujo infantil en un personaje ilustrado de cuento. '
        'Hazlo visualmente más limpio y legible, pero conserva fielmente la identidad, silueta, '
        'estructura principal, colores dominantes, especie, tipo o naturaleza visual del sujeto '
        '(persona, animal, criatura fantástica, robot, vehículo, juguete, objeto o planta) '
        'y detalles distintivos definidos por el niño. '
        'El resultado debe sentirse como una versión ilustrada y cuidada de SU MISMO dibujo y concepto original, '
        'no como un rediseño profesional diferente. '
        'Permitido: limpiar líneas y trazos, suavizar bordes, completar pequeños huecos, suavizar trazos, '
        'dar profundidad, mejorar ligeramente proporciones, hacer que sea visualmente legible como '
        'ilustración de cuento y añadir iluminación, texturas e integración propia del escenario. '
        'Reglas negativas de dibujo: NO rediseñar completamente el personaje ni reinterpretar qué es, '
        'NO cambiar de especie o tipo de criatura (si dibuja un vehículo no convertirlo en animal/persona; '
        'si dibuja un robot no humanizarlo innecesariamente; si dibuja una persona no convertirla en animal; '
        'si dibuja una criatura inventada no forzarla a una especie conocida; si dibuja un objeto con cara mantenerlo), '
        'NO hacerlo humanoide si no lo era, '
        'NO agregar ropa o accesorios importantes inexistentes, '
        'NO sustituir sus colores principales ni su paleta dominante sin necesidad, '
        'NO eliminar detalles distintivos ni partes dibujadas por el niño, '
        'NO convertir todos los dibujos en un personaje infantil genérico, '
        'y NO perfeccionar tanto el dibujo que deje de parecer creación del niño o deje de reconocerse.',
      );
    }
    buffer.writeln(
      'Reglas de seguridad infantil: Ilustración apropiada para público infantil de primaria. '
      'Se permiten elementos de fantasía, aventura y acción con tratamiento visual no gráfico '
      'cuando estén presentes en el dibujo original o sean pertinentes para la historia. '
      'NO añadir armas, armaduras, elementos de combate ni otros accesorios importantes que el niño no haya dibujado '
      'o que no sean necesarios para la escena. Los elementos benignos de fantasía ya presentes '
      'no deben convertirse automáticamente en juguetes. '
      'PROHIBIDO estrictamente: contenido sexual o sexualizado, desnudez explícita, violencia gráfica, '
      'sangre o gore, tortura, drogas representadas de forma explícita, odio explícito, terror extremo o contenido claramente adulto. '
      'Si existiera algún elemento realmente inapropiado, neutralizar únicamente esa parte manteniendo el concepto benigno original.',
    );
    buffer.writeln(
      'Reglas de consistencia: Mantener estrictamente al mismo protagonista en todas las ilustraciones: '
      'misma especie o forma base, mismo tipo o naturaleza visual, mismos rasgos principales, silueta y paleta de color característica. '
      'Cualquier cambio de ropa o accesorio es puramente temporal para esta escena; los rasgos base permanecen. '
      'Solo cambiar pose, expresión, acción y entorno según la escena lo requiera. '
      'El personaje NO debe transformarse en una criatura distinta en cada escena. '
      'NO buscar realismo; priorizar consistencia infantil, ternura y continuidad visual. '
      'NO incluir palabras, letras, títulos, globos de diálogo ni números dentro de la ilustración. '
      'Enfoque claro y accesible para niños de primaria.',
    );
    return buffer.toString().trim();
  }
}

/// Excepción específica para errores de autenticación/autorización (HTTP 401 y 403)
/// al solicitar la generación de imágenes, indicando que la solicitud NO debe
/// reintentarse automáticamente ni consumir llamadas adicionales a Pollinations.
class ImageAuthException extends StateError {
  final int statusCode;

  ImageAuthException({required this.statusCode, required String message})
    : super(message);

  @override
  String toString() =>
      'ImageAuthException(status: $statusCode, message: $message)';
}

/// Contrato abstracto para servicios de generación de imágenes de escenas
abstract class ImageService {
  /// Genera o recupera la URL de la ilustración para una escena dada.
  /// Si el proveedor aún no está configurado o falla la llamada, arroja una excepción.
  Future<String> generarIlustracionEscena(SolicitudImagenEscena solicitud);
}
