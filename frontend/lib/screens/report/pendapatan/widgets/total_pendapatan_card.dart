import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TotalPendapatanCard extends StatelessWidget {
  final double totalPendapatan;
  final double percentageChange;
  final String periodLabel;
  final int totalTransaksi;

  const TotalPendapatanCard({
    super.key,
    required this.totalPendapatan,
    required this.percentageChange,
    required this.periodLabel,
    this.totalTransaksi = 0,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppPalette.primary, AppPalette.primaryWarm],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -15,
                child: Opacity(
                  opacity: 0.1,
                  child: const Icon(
                    Icons.wallet_rounded,
                    size: 140,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Pendapatan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: AppFont.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatter.format(totalPendapatan),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: AppFont.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        if (totalTransaksi > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$totalTransaksi',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: AppFont.w900,
                                    color: AppPalette.primary,
                                  ),
                                ),
                                const Text(
                                  'Transaksi',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: AppFont.w700,
                                    color: AppPalette.primary,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
