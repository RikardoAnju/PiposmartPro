import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Groups integer Rupiah digits while keeping the caret near the edited digit.
class RupiahThousandsInputFormatter extends TextInputFormatter {
  RupiahThousandsInputFormatter({this.maxValue = 999999999});

  final int maxValue;
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  static String format(int value) =>
      NumberFormat.decimalPattern('id_ID').format(value);

  static double? parse(String input) =>
      double.tryParse(input.replaceAll(RegExp(r'[^0-9]'), ''));

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final amount = int.tryParse(digits);
    if (amount == null || amount > maxValue) return oldValue;

    final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCaret = newValue.text
        .substring(0, caret)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final formatted = _formatter.format(amount);
    var formattedCaret = 0;
    var seenDigits = 0;
    while (formattedCaret < formatted.length &&
        seenDigits < digitsBeforeCaret) {
      if (RegExp(r'[0-9]').hasMatch(formatted[formattedCaret])) seenDigits++;
      formattedCaret++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedCaret),
    );
  }
}
