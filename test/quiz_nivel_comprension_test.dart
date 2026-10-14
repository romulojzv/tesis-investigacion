import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_investigacion/models/quiz_question.dart';
import 'package:tesis_investigacion/models/quiz_result.dart';

void main() {
  group('RF-22: Modelos y dimensiones de comprensión lectora', () {
    test('QuizQuestion expone nivel explicito desde camelCase y snake_case', () {
      final p1 = QuizQuestion.fromJson({
        'numero': 1,
        'pregunta': '¿Quién acompañaba al protagonista?',
        'opciones': ['Un perro', 'Un gato', 'Un pájaro', 'Un ratón'],
        'nivelComprension': 'literal',
      });
      expect(p1.nivelComprension, 'literal');
      expect(p1.toJson()['nivelComprension'], 'literal');

      final p2 = QuizQuestion.fromJson({
        'numero': 3,
        'pregunta': '¿Por qué decidieron refugiarse?',
        'opciones': ['Venía lluvia', 'Se hizo de noche', 'Tenían miedo', 'Había monstruos'],
        'nivel_comprension': 'inferencial',
      });
      expect(p2.nivelComprension, 'inferencial');
    });

    test('QuizQuestion conserva compatibilidad con registros historicos sin clasificar', () {
      final pAntigua = QuizQuestion.fromJson({
        'numero': 1,
        'pregunta': 'Pregunta antigua',
        'opciones': ['A', 'B', 'C', 'D'],
      });
      expect(pAntigua.nivelComprension, 'sin_clasificar');
    });

    test('QuizQuestionResult incluye dimension, explicacion y serializacion completa', () {
      final r = QuizQuestionResult.fromJson({
        'numero_pregunta': 5,
        'pregunta': '¿Qué decisión fue más adecuada y por qué?',
        'opciones': ['Opción A', 'Opción B', 'Opción C', 'Opción D'],
        'indice_seleccionado': 2,
        'indice_correcto': 2,
        'es_correcta': true,
        'explicacion': 'Demuestra reflexión crítica sobre el dilema del cuento.',
        'nivel_comprension': 'critico_reflexivo',
      });

      expect(r.numero, 5);
      expect(r.nivelComprension, 'critico_reflexivo');
      expect(r.esCorrecta, true);
      expect(r.opcionSeleccionadaTexto, 'Opción C');
      expect(r.opcionCorrectaTexto, 'Opción C');
      expect(r.toJson()['nivelComprension'], 'critico_reflexivo');
      expect(r.toJson()['nivel_comprension'], 'critico_reflexivo');
    });

    test('QuizQuestionResult maneja respuestas incorrectas y revela opcion esperada', () {
      final r = QuizQuestionResult.fromJson({
        'numero': 2,
        'pregunta': '¿Dónde vivía el protagonista?',
        'opciones': ['En un valle', 'En un barco', 'En una torre', 'En una cueva'],
        'indiceSeleccionado': 0,
        'indiceCorrecto': 3,
        'esCorrecta': false,
        'explicacion': 'La historia describe que su hogar estaba dentro de una cueva.',
        'nivelComprension': 'literal',
      });

      expect(r.esCorrecta, false);
      expect(r.opcionSeleccionadaTexto, 'En un valle');
      expect(r.opcionCorrectaTexto, 'En una cueva');
      expect(r.nivelComprension, 'literal');
    });
  });
}
