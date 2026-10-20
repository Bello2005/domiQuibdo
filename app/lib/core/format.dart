import 'package:intl/intl.dart';

// Como se escribe en Colombia: "$9.812.700" (el patrón de es_CO pondría el símbolo al final).
final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0, customPattern: '\u00A4#,##0');
final _dateTime = DateFormat("d MMM · h:mm a", 'es');

String formatCop(num value) => _cop.format(value);

/// Distancia legible: "80 m" o "1,2 km".
String formatDistance(int meters) =>
    meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

/// Monto corto para ejes y gráficas: "$1,2 M", "$350 mil", "$900".
String formatCopCompact(num value) {
  final abs = value.abs();
  String trim(double v) =>
      (v >= 10 ? v.round().toString() : v.toStringAsFixed(1)).replaceAll('.', ',').replaceAll(',0', '');
  if (abs >= 1000000) return '\$${trim(value / 1000000)} M';
  if (abs >= 1000) return '\$${(value / 1000).round()} mil';
  return formatCop(value);
}
