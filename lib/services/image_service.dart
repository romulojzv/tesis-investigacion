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
  final String estiloVisual;

  const SolicitudImagenEscena({
    required this.cuentoId,
    required this.numeroEscena,
    required this.contenidoEscena,
    required this.nombreProtagonista,
    this.descripcionPersonaje,
    this.escenario,
    this.referenciaVisualBytes,
    this.estiloVisual = 'Ilustración infantil cálida y colorida para libro de cuentos de primaria, estilo acuarela digital limpia, sin texto escrito dentro de la imagen',
  });

  /// Construye un prompt detallado optimizado para generadores de imágenes
  String construirPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('Estilo artístico: $estiloVisual.');
    buffer.writeln('Protagonista: $nombreProtagonista.');
    if (descripcionPersonaje != null &&
        descripcionPersonaje!.trim().isNotEmpty) {
      buffer.writeln(
        'Rasgos base permanentes del protagonista: ${descripcionPersonaje!.trim()}.',
      );
    }
    if (escenario != null && escenario!.trim().isNotEmpty) {
      buffer.writeln('Entorno y escenario: ${escenario!.trim()}.');
    }
    buffer.writeln('Acción narrativa de la escena: ${contenidoEscena.trim()}.');
    buffer.writeln(
      'Reglas de composición: Mantener estrictamente la apariencia y rasgos base del protagonista en todas las ilustraciones. '
      'Cualquier cambio de ropa o accesorio es puramente temporal por la acción de la escena y no altera sus rasgos base. '
      'NO incluir palabras, letras, títulos, globos de diálogo ni números dentro de la ilustración. '
      'Enfoque claro y accesible para niños de primaria.',
    );
    return buffer.toString().trim();
  }
}

/// Contrato abstracto para servicios de generación de imágenes de escenas
abstract class ImageService {
  /// Genera o recupera la URL de la ilustración para una escena dada.
  /// Si el proveedor aún no está configurado o falla la llamada, arroja una excepción.
  Future<String> generarIlustracionEscena(SolicitudImagenEscena solicitud);
}
