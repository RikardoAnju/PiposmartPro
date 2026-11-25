// lib/shared/widgets/currency_formatter.dart
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatToRupiah(dynamic value) {
    if (value == null) return 'Rp 0';

    int amount;
    if (value is String) {
      amount = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    } else if (value is int) {
      amount = value;
    } else if (value is double) {
      amount = value.toInt();
    } else {
      return 'Rp 0';
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }

  static String formatInputToRupiah(String input) {
    if (input.isEmpty) return '';

    String digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    int value = int.parse(digitsOnly);

    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value);
  }

  static String formatNumberToInput(dynamic value) {
    if (value == null) return '';

    int amount;
    if (value is String) {
      amount = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    } else if (value is int) {
      amount = value;
    } else if (value is double) {
      amount = value.toInt();
    } else {
      return '';
    }

    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(amount);
  }

  /// Convert string Rupiah ke int (untuk dikirim ke API)
  /// "10.000" → 10000
  static int parseRupiahToInt(String rupiahString) {
    String digitsOnly = rupiahString.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  /// Convert string Rupiah ke double
  static double parseRupiahToDouble(String rupiahString) {
    String digitsOnly = rupiahString.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digitsOnly) ?? 0.0;
  }

  /// Format ringkas (untuk summary / card)
  /// 1.200.000 → Rp 1.2jt
  static String formatCompact(dynamic value) {
    if (value == null) return 'Rp 0';

    int amount;
    if (value is String) {
      amount = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    } else if (value is int) {
      amount = value;
    } else if (value is double) {
      amount = value.toInt();
    } else {
      return 'Rp 0';
    }

    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    }

    return 'Rp $amount';
  }
}
