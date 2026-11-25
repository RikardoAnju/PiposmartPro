import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionRingkasanBar extends StatelessWidget {
  final VoidCallback? onTap;

  const TransactionRingkasanBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.75,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: AppPalette.primary.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
          'Lihat Ringkasan Transaksi',
          style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
        ),
      ),
    );
  }
}
