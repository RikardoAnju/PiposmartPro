import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutBalanceCard extends StatelessWidget {
  final String balance;

  const PayoutBalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.referralHeroGradient,
          stops: AppPalette.referralHeroStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pencairan Saldo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: AppFont.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih bonus referral yang ingin dicairkan,\nlalu tentukan rekening tujuan.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class PayoutAvailableBalanceCard extends StatelessWidget {
  final String balance;

  const PayoutAvailableBalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'Rp',
                style: TextStyle(
                  color: AppPalette.primary,
                  fontWeight: AppFont.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Saldo Tersedia',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                balance,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: AppFont.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
