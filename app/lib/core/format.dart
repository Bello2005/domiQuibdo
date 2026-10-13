import 'package:intl/intl.dart';

final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dateTime = DateFormat("d MMM · h:mm a", 'es');

String formatCop(num value) => _cop.format(value);

/// Distancia legible: "80 m" o "1,2 km".
String formatDistance(int meters) =>
    meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());
