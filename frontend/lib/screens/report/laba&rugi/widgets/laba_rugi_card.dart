import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LabaRugiCard extends StatelessWidget {
  final String dateLabel;

  const LabaRugiCard({super.key, required this.dateLabel});

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value.abs());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LaporanProvider>();
    final report = provider.profitLossReport;

    if (provider.isLoading) {
      return _buildSkeleton();
    }

    final labaBersih = report?.labaRugi ?? 0;
    final isPositive = labaBersih >= 0;
    final sign = isPositive ? '+' : '-';

    return Container(
      width: double.infinity,
      height: 150, // Standardized height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Icon Decoration
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20), // Standardized padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laba/Rugi Bersih',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13, // Standardized font size
                        fontWeight: AppFont.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$sign${_formatRupiah(labaBersih)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28, // Standardized font size
                          fontWeight: AppFont.w900,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: AppFont.w800,
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
    );
  }

  Widget _buildSkeleton() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(120, 13),
                const SizedBox(height: 4),
                _skeletonBox(180, 28),
              ],
            ),
            _skeletonBox(110, 24),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
