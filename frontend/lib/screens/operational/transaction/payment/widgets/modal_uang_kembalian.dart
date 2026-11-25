import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ChangeMoneyModal extends StatelessWidget {
  final double cashReceived;
  final double totalAmount;
  final VoidCallback onConfirm;

  const ChangeMoneyModal({
    super.key,
    required this.cashReceived,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final changeAmount = cashReceived - totalAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with gradient background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppPalette.danger.withValues(alpha: 0.3),
                    AppPalette.danger.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppPalette.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    size: 40,
                    color: Colors.white,
                    weight: 700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Change amount text
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: AppFont.w600,
                  color: Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Kembalian : '),
                  TextSpan(
                    text: currencyFormatter.format(changeAmount),
                    style: const TextStyle(
                      fontWeight: AppFont.w700,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // OK Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onConfirm(); // Panggil onConfirm dulu
                  Navigator.of(
                    context,
                  ).pop(true); // Baru tutup dialog dengan return true
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppPalette.primaryBorderStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'OKE',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFont.w600,
                    color: AppPalette.danger,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
