import 'package:intl/intl.dart';

String formatCompactQuantity(
  num value, {
  int maxDecimalDigits = 2,
  String locale = 'id_ID',
}) {
  final formatter = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDecimalDigits;
  return formatter.format(value);
}
