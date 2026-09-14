import 'package:intl/intl.dart';

final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dateTime = DateFormat("d MMM · h:mm a", 'es');

String formatCop(num value) => _cop.format(value);

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());
