import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TukarSaldoInfoCard extends StatelessWidget {
  final String saldo;
  final String conversionInfo;

  const TukarSaldoInfoCard({
    super.key,
    required this.saldo,
    required this.conversionInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Saldo tersedia
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/icons/ic_dollar.webp',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Saldo Tersedia',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    saldo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Conversion info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(width: 8),
              Text(
                conversionInfo,
                style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
