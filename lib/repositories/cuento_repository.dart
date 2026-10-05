import '../models/cuento.dart';

abstract class CuentoRepository {
  Future<void> guardarCuento(Cuento cuento);

  Future<Cuento?> obtenerCuento(String id);
}
