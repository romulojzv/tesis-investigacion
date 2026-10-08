import 'dart:ui';

/// Mapea colores de la paleta infantil a nombres legibles en español.
String? nombreColorEspanol(Color color) {
  final valor = color.toARGB32();
  if (valor == 0xFF000000) return 'negro';
  if (valor == 0xFFF44336) return 'rojo';
  if (valor == 0xFFFF9800) return 'naranja';
  if (valor == 0xFFFFEB3B) return 'amarillo';
  if (valor == 0xFF4CAF50) return 'verde';
  if (valor == 0xFF2196F3) return 'azul';
  if (valor == 0xFF9C27B0) return 'morado';
  if (valor == 0xFF795548) return 'marrón';
  if (valor == 0xFFE91E63) return 'rosado';
  if (valor == 0xFF00BCD4) return 'celeste';
  if (valor == 0xFFFFC107) return 'amarillo dorado';
  if (valor == 0xFF8BC34A) return 'verde claro';

  // Detección aproximada si no coincide exactamente
  final r = (valor >> 16) & 0xFF;
  final g = (valor >> 8) & 0xFF;
  final b = valor & 0xFF;

  if (r < 40 && g < 40 && b < 40) return 'negro';
  if (r > 200 && g < 70 && b < 70) return 'rojo';
  if (r > 200 && g > 150 && b < 80) return 'amarillo';
  if (r < 80 && g > 150 && b < 80) return 'verde';
  if (r < 80 && g < 150 && b > 200) return 'azul';
  if (r > 150 && g < 80 && b > 150) return 'morado';
  if (r > 200 && g > 100 && b > 150) return 'rosado';
  return null;
}

/// Genera una descripción visual canónica estable y estructurada para un personaje
/// creado desde el flujo de dibujo, garantizando que nunca sea nula ni vacía.
String derivarDescripcionVisualBase({
  required String nombrePersonaje,
  Set<Color>? coloresUtilizados,
}) {
  final nombreLimpio = nombrePersonaje.trim();
  final nombreLower = nombreLimpio.toLowerCase();

  String rasgosBase;

  // Detección de tipo o naturaleza visual del personaje (cuando el nombre contiene pistas explícitas)
  // 1. Personas / Niños / Héroes
  if (nombreLower.contains('niño') ||
      nombreLower.contains('niña') ||
      nombreLower.contains('princesa') ||
      nombreLower.contains('principe') ||
      nombreLower.contains('príncipe') ||
      nombreLower.contains('superhéroe') ||
      nombreLower.contains('superheroe') ||
      nombreLower.contains('caballero') ||
      nombreLower.contains('pirata') ||
      nombreLower.contains('astronauta') ||
      nombreLower.contains('mago') ||
      nombreLower.contains('hada')) {
    rasgosBase =
        'personaje humanoide infantil llamado $nombreLimpio, proporciones amigables, expresión alegre y vestimenta sencilla';
    // 2. Animales comunes
  } else if (nombreLower.contains('pollito') || nombreLower.contains('pollo')) {
    rasgosBase = 'personaje tipo pollito, cuerpo amarillo, cabeza roja/rosada, pico amarillo y patas negras';
  } else if (nombreLower.contains('conejito') ||
      nombreLower.contains('conejo')) {
    rasgosBase = 'personaje tipo conejito, orejas largas erguidas, cuerpo suave, nariz rosada y cola redonda';
  } else if (nombreLower.contains('gatito') ||
      nombreLower.contains('gato') ||
      nombreLower.contains('misi')) {
    rasgosBase = 'personaje tipo gatito, orejas triangulares alertas, bigotes finos, ojos curiosos y cola suave';
  } else if (nombreLower.contains('perrito') ||
      nombreLower.contains('perro') ||
      nombreLower.contains('bobby')) {
    rasgosBase = 'personaje tipo perrito, orejas caídas simpáticas, cuerpo alegre, hocico redondeado y cola juguetona';
  } else if (nombreLower.contains('patito') || nombreLower.contains('pato')) {
    rasgosBase = 'personaje tipo patito, plumaje tierno, cabeza redondeada, pico naranja ancho y patitas palmeadas';
  } else if (nombreLower.contains('osito') || nombreLower.contains('oso')) {
    rasgosBase = 'personaje tipo osito, cuerpo redondeado y tierno, orejas circulares y expresión amable';
    // 3. Criaturas fantásticas
  } else if (nombreLower.contains('dinosaurio') ||
      nombreLower.contains('dino')) {
    rasgosBase = 'personaje tipo dinosaurio pequeño infantil, cresta suave en el lomo, silueta amigable y patitas cortas';
  } else if (nombreLower.contains('dragon') || nombreLower.contains('dragón')) {
    rasgosBase = 'personaje tipo dragón infantil fantástico, alitas pequeñas, escamas coloridas y mirada noble';
  } else if (nombreLower.contains('monstruo') ||
      nombreLower.contains('monstruito')) {
    rasgosBase = 'personaje tipo criatura fantástica amistosa, silueta divertida, ojos simpáticos y carácter tierno';
  } else if (nombreLower.contains('unicornio')) {
    rasgosBase = 'personaje tipo unicornio mágico infantil, cuerno en espiral, crin colorida y expresión dulce';
    // 4. Robots y tecnología
  } else if (nombreLower.contains('robot')) {
    rasgosBase = 'personaje tipo robot simpático, cuerpo geométrico redondeado, botones de colores y antena alegre';
    // 5. Vehículos
  } else if (nombreLower.contains('coche') ||
      nombreLower.contains('auto') ||
      nombreLower.contains('carro') ||
      nombreLower.contains('camión') ||
      nombreLower.contains('camion') ||
      nombreLower.contains('avion') ||
      nombreLower.contains('avión') ||
      nombreLower.contains('cohete') ||
      nombreLower.contains('tren') ||
      nombreLower.contains('barco')) {
    rasgosBase = 'personaje tipo vehículo con personalidad amigable, ruedas o alas redondeadas, ventanas expresivas y diseño infantil';
    // 6. Objetos o plantas personificados
  } else if (nombreLower.contains('árbol') ||
      nombreLower.contains('arbol') ||
      nombreLower.contains('flor') ||
      nombreLower.contains('estrella') ||
      nombreLower.contains('sol') ||
      nombreLower.contains('luna')) {
    rasgosBase = 'personaje tipo elemento natural u objeto personificado, rostro tierno y expresivo integrado en su forma';
    // 7. FALLBACK NEUTRAL Y GENERAL (Sin asumir especie sin evidencia)
  } else {
    rasgosBase =
        'personaje diseñado por el estudiante llamado $nombreLimpio, basado fielmente en su dibujo original, conservando su forma, silueta, estructura, colores y detalles distintivos';
  }

  // Integración de colores utilizados en el dibujo
  final nombresColores = <String>[];
  if (coloresUtilizados != null && coloresUtilizados.isNotEmpty) {
    for (final col in coloresUtilizados) {
      final nom = nombreColorEspanol(col);
      if (nom != null && !nombresColores.contains(nom)) {
        nombresColores.add(nom);
      }
    }
  }

  if (nombresColores.isNotEmpty) {
    return '$rasgosBase, con trazos y colores base en ${nombresColores.join(', ')}, estilo ilustración infantil cálida.';
  }

  return '$rasgosBase, estilo ilustración infantil cálida.';
}
