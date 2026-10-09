// lib/utils/date_formatter.dart

class DateFormatter {
  /// Convierte una fecha (típicamente almacenada en UTC en la base de datos)
  /// a la hora local del sistema y la formatea como 'dd/MM/yyyy HH:mm'.
  ///
  /// No altera el objeto DateTime original ni la persistencia en base de datos.
  static String formatearFechaHoraLocal(DateTime fecha) {
    final local = fecha.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final anio = local.year.toString();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$minuto';
  }
}
