import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PaymentColors {
  PaymentColors._();

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'qris':
        return AppPalette.danger;
      case 'transfer':
        return const Color(0xFF2196F3);
      case 'e-wallet':
        return AppPalette.warning;
      default:
        return Colors.grey;
    }
  }

  static Color getBackgroundColor(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return const Color(0xFFE8F5E9);
      case 'transfer':
        return const Color(0xFFE3F2FD);
      case 'e-wallet':
        return const Color(0xFFF3E5F5);
      case 'qris':
        return const Color(0xFFFFF3E0);
      default:
        return Colors.grey.shade100;
    }
  }
}
