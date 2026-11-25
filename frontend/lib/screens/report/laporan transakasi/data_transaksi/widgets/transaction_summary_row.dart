import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionSummaryRow extends StatelessWidget {
  final int totalTransactions;
  final double totalRevenue;
  final String footerLabel;

  const TransactionSummaryRow({
    super.key,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.footerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        width: double.infinity,
        height: 144,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.primary, AppPalette.primaryWarm],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                right: -18,
                bottom: -12,
                child: Opacity(
                  opacity: 0.12,
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 150,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: _TransactionBadge(totalTransactions: totalTransactions),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Penjualan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currencyFormatter.format(totalRevenue),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: AppFont.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
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
                          Flexible(
                            child: Text(
                              footerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: AppFont.w700,
                              ),
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

class _TransactionBadge extends StatelessWidget {
  final int totalTransactions;

  const _TransactionBadge({required this.totalTransactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalTransactions',
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 18,
              fontWeight: AppFont.w900,
            ),
          ),
          const Text(
            'Transaksi',
            style: TextStyle(
              color: AppPalette.primary,
              fontSize: 8,
              fontWeight: AppFont.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
