import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/report_model.dart';
import '../../../providers/auth_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/trend_label.dart';

class SummaryGridSection extends StatelessWidget {
  final SummaryReport? summary;
  final String dateLabel;

  const SummaryGridSection({super.key, this.summary, required this.dateLabel});

  static const _primary = AppPalette.primary;
  static const _ink = Color(0xFF262338);
  static const _muted = Color(0xFF9A96A8);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canReadSummary = auth.canReadDailyReportSummary;
    final currency = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    final totalOrder = summary?.totalTransaksi ?? 0;
    final averageOrder = totalOrder == 0
        ? 0
        : (summary?.totalOmset ?? 0) / totalOrder;

    final items = [
      _MetricData(
        title: 'Total Penjualan',
        value: canReadSummary
            ? currency.format(summary?.totalOmset ?? 0)
            : '∗∗∗∗∗∗',
        trend: summary?.omsetTrend ?? 0,
        icon: Icons.payments_rounded,
        isLocked: !canReadSummary,
      ),
      _MetricData(
        title: 'Pendapatan',
        value: canReadSummary
            ? currency.format(summary?.totalIncome ?? 0)
            : '∗∗∗∗∗∗',
        trend: summary?.incomeTrend ?? 0,
        icon: Icons.account_balance_wallet_rounded,
        isLocked: !canReadSummary,
      ),
      _MetricData(
        title: 'Rata-rata Order',
        value: canReadSummary ? currency.format(averageOrder) : '∗∗∗∗∗∗',
        trend: 0,
        icon: Icons.bar_chart_rounded,
        isLocked: !canReadSummary,
        showTrend: false,
      ),
      _MetricData(
        title: 'Pengeluaran',
        value: canReadSummary
            ? currency.format(summary?.totalExpense ?? 0)
            : '∗∗∗∗∗∗',
        trend: summary?.expenseTrend ?? 0,
        icon: Icons.shopping_cart_rounded,
        isLocked: !canReadSummary,
        isNegativeTrendGood: true,
      ),
      _MetricData(
        title: 'Total Transaksi',
        value: canReadSummary ? '${summary?.totalTransaksi ?? 0}' : '∗∗∗',
        trend: summary?.transaksiTrend ?? 0,
        icon: Icons.insert_chart_rounded,
        isLocked: !canReadSummary,
      ),
      _MetricData(
        title: 'Pesanan Diambil',
        value: canReadSummary ? '${summary?.pesananDiambil ?? 0}' : '∗∗∗',
        trend: summary?.pesananTrend ?? 0,
        icon: Icons.task_alt_rounded,
        isLocked: !canReadSummary,
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Ringkasan Hari Ini',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: AppFont.w900,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: AppFont.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Perubahan dibandingkan periode sebelumnya',
            style: TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: AppFont.w500,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ProfitSummaryCard(
          value: canReadSummary
              ? currency.format(summary?.profitLoss ?? 0)
              : '∗∗∗∗∗∗',
          trend: summary?.profitLossTrend ?? 0,
          isLocked: !canReadSummary,
          isNegative: (summary?.profitLoss ?? 0) < 0,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.36,
          ),
          itemBuilder: (context, index) => _MetricCard(data: items[index]),
        ),
        // _buildInfoFooter(),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isPositive = data.trend >= 0;
    final isGoodTrend = data.isNegativeTrendGood ? !isPositive : isPositive;
    final trendColor = isGoodTrend
        ? const Color(0xFF16A34A)
        : SummaryGridSection._primary;
    final trendText = formatTrendLabel(data.trend);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -14,
            child: Icon(
              data.icon,
              size: 58,
              color: SummaryGridSection._primary.withValues(alpha: 0.045),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppPalette.primaryBorder.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      data.icon,
                      size: 14,
                      color: SummaryGridSection._primary,
                    ),
                  ),
                  const Spacer(),
                  if (!data.isLocked && data.showTrend)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.095),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: trendColor.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        trendText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 7.6,
                          color: trendColor,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SummaryGridSection._muted,
                  fontSize: 9.2,
                  fontWeight: AppFont.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: SummaryGridSection._primary,
                        fontSize: 17.5,
                        fontWeight: AppFont.w900,
                        letterSpacing: 0,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitSummaryCard extends StatelessWidget {
  final String value;
  final double trend;
  final bool isLocked;
  final bool isNegative;

  const _ProfitSummaryCard({
    required this.value,
    required this.trend,
    required this.isLocked,
    required this.isNegative,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = isNegative
        ? AppPalette.danger
        : SummaryGridSection._primary;
    final trendColor = trend < 0 ? AppPalette.danger : const Color(0xFF16A34A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: SummaryGridSection._primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laba/Rugi Kas',
                  style: TextStyle(
                    color: SummaryGridSection._muted,
                    fontSize: 10,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 20,
                    fontWeight: AppFont.w900,
                  ),
                ),
              ],
            ),
          ),
          if (!isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.095),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: trendColor.withValues(alpha: 0.08)),
              ),
              child: Text(
                formatTrendLabel(trend, decimalDigits: 0),
                style: TextStyle(
                  color: trendColor,
                  fontSize: 9,
                  fontWeight: AppFont.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final double trend;
  final IconData icon;
  final bool isLocked;
  final bool isNegativeTrendGood;
  final bool showTrend;

  const _MetricData({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    this.isLocked = false,
    this.isNegativeTrendGood = false,
    this.showTrend = true,
  });
}
