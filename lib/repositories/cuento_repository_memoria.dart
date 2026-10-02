import '../models/cuento.dart';
import 'cuento_repository.dart';

class CuentoRepositoryMemoria implements CuentoRepository {
  final Map<String, Cuento> _cuentos = {};

  @override
  Future<void> guardarCuento(Cuento cuento) async {
    _cuentos[cuento.id] = cuento;
  }

  @override
  Future<Cuento?> obtenerCuento(String id) async {
    return _cuentos[id];
  }
}