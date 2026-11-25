import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/currency_formatter.dart';

class IncomeSection extends StatelessWidget {
  const IncomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AppProvider>().summaryData;
    final auth = context.watch<AuthProvider>();
    final canReadIncome = auth.canReadHomeSummary;
    final double income = (summary?['pendapatan_hari_ini'] ?? 0).toDouble();
    final FontWeight incomeWeight =
        defaultTargetPlatform == TargetPlatform.android
        ? AppFont.w800
        : AppFont.w900;

    return Center(
      child: Column(
        children: [
          const Text(
            'Pendapatan Hari Ini',
            style: TextStyle(
              color: Colors.white,
              fontWeight: AppFont.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canReadIncome
                ? CurrencyFormatter.formatToRupiah(income)
                : 'Rp ...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: incomeWeight,
              letterSpacing: 0.5,
            ),
          ),
          if (!canReadIncome) ...[
            const SizedBox(height: 6),
            Text(
              'Akses ringkasan dibatasi',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: AppFont.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
