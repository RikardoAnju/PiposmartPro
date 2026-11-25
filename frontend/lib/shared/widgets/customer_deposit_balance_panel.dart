import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_font.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/customer_model.dart';

class CustomerDepositBalancePanel extends StatelessWidget {
  const CustomerDepositBalancePanel({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final showKg = customer.depositKg > 0;
    const accent = AppPalette.primary;
    final rupiah = NumberFormat.decimalPattern(
      'id_ID',
    ).format(customer.depositRupiah);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EF), Color(0xFFFFF8F3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE2D7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Deposit',
                  style: TextStyle(color: AppPalette.muted, fontSize: 10),
                ),
                const SizedBox(height: 1),
                Text(
                  'Rp $rupiah',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ],
            ),
          ),
          if (showKg) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 30,
              color: accent.withValues(alpha: 0.16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Kiloan',
                    style: TextStyle(color: AppPalette.muted, fontSize: 10),
                  ),
                  Text(
                    '${formatCompactQuantity(customer.depositKg)} Kg',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
