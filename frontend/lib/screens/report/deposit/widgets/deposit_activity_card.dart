import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/deposit_report_model.dart';

class DepositActivityCard extends StatelessWidget {
  final DepositReportEntry entry;
  final VoidCallback? onTap;

  const DepositActivityCard({super.key, required this.entry, this.onTap});

  static final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final type = entry.activityType.toUpperCase();
    final isTopUp = type == 'TOP_UP';
    final isRefund = type == 'REFUND';
    final isUsageReversal = type == 'USAGE_REVERSAL';
    final isCorrection = type == 'CORRECTION';
    final positive =
        isTopUp || isUsageReversal || (isCorrection && entry.amount >= 0);
    final color = positive ? AppPalette.success : AppPalette.danger;
    final label = isCorrection
        ? 'Koreksi Deposit'
        : isTopUp
        ? 'Top Up Deposit'
        : isRefund
        ? 'Pengembalian Deposit'
        : isUsageReversal
        ? 'Pembatalan Pemakaian'
        : 'Pemakaian Deposit';
    final prefix = positive
        ? '+'
        : isCorrection && entry.amount < 0
        ? ''
        : '-';
    final amount = entry.depositType.toUpperCase() == 'KG'
        ? '$prefix${formatCompactQuantity(entry.amount)} Kg'
        : '$prefix${_money.format(entry.amount)}';
    final balanceAfter = entry.depositType.toUpperCase() == 'KG'
        ? '${formatCompactQuantity(entry.balanceAfter)} Kg'
        : _money.format(entry.balanceAfter);
    final depositTypeLabel = entry.depositType.toUpperCase() == 'KG'
        ? 'Kiloan'
        : 'Rupiah';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEEF1F3)),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: .1),
                      child: Icon(
                        isCorrection
                            ? Icons.edit_note_rounded
                            : isTopUp
                            ? Icons.add_rounded
                            : isRefund
                            ? Icons.replay_rounded
                            : isUsageReversal
                            ? Icons.undo_rounded
                            : Icons.shopping_bag_outlined,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.ink,
                                    fontSize: 14,
                                    fontWeight: AppFont.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                amount,
                                maxLines: 1,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: AppFont.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$label • $depositTypeLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.muted,
                              fontSize: 11,
                              fontWeight: AppFont.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.createdAt == null
                                ? 'Waktu tidak tersedia'
                                : DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                    'id_ID',
                                  ).format(entry.createdAt!),
                            style: const TextStyle(
                              color: AppPalette.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _infoValue(
                          Icons.account_balance_wallet_outlined,
                          'Saldo setelah',
                          balanceAfter,
                        ),
                      ),
                      if (isTopUp && entry.paidAmount > 0) ...[
                        Container(
                          width: 1,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: const Color(0xFFE4E9EC),
                        ),
                        Expanded(
                          child: _infoValue(
                            Icons.payments_outlined,
                            'Kas diterima',
                            _money.format(entry.paidAmount),
                          ),
                        ),
                      ],
                      if (isTopUp && entry.discountAmount > 0) ...[
                        Container(
                          width: 1,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: const Color(0xFFE4E9EC),
                        ),
                        Expanded(
                          child: _infoValue(
                            Icons.local_offer_outlined,
                            'Diskon',
                            _money.format(entry.discountAmount),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoValue(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, size: 14, color: AppPalette.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 9,
                fontWeight: AppFont.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 10,
                fontWeight: AppFont.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
