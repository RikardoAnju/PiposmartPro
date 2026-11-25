import 'package:flutter/material.dart';

class PaymentIconHelper {
  PaymentIconHelper._();

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'qris':
        return Icons.qr_code_2_outlined;
      case 'transfer':
        return Icons.account_balance_outlined;
      case 'e-wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  static IconData getFallbackIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return Icons.account_balance_wallet;
      case 'transfer':
        return Icons.account_balance;
      case 'e-wallet':
        return Icons.phone_android;
      case 'qris':
        return Icons.qr_code_scanner;
      default:
        return Icons.payment;
    }
  }
}
