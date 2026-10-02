import 'escena.dart';

class Cuento {
  final String id;
  final String titulo;
  final String personajePrincipal;
  final List<Escena> escenas;

  Cuento({
    required this.id,
    required this.titulo,
    required this.personajePrincipal,
    List<Escena>? escenas,
  }) : escenas = escenas ?? [];

  void agregarEscena(Escena escena) {
    escenas.add(escena);
  }
}