import 'dart:math' as math;

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../data/models/finance_model.dart';
import '../../../data/models/report_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/trend_label.dart';

class FinanceChartCard extends StatelessWidget {
  final List<ChartDataFinance> data;
  final SummaryReport? summary; // Tambahkan summary untuk quick metrics
  final DateTime selectedMonth;
  final VoidCallback onFilterTap;

  const FinanceChartCard({
    super.key,
    required this.data,
    this.summary,
    required this.selectedMonth,
    required this.onFilterTap,
  });

  static const Color colorOmset = Color(0xFFF2994A);
  static const Color colorExpense = AppPalette.danger;
  static const Color colorProfit = Color(0xFF27AE60);
  static const Color colorIncome = Color(0xFF3B82F6);
  static const Color colorBg = Color(0xFFF8F9FB);

  static String formatCompactMoney(num value, {String prefix = 'Rp'}) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    final symbol = prefix.isEmpty ? '' : prefix;

    String formatAmount(double amount, {bool allowDecimal = false}) {
      final hasDecimal = allowDecimal && amount % 1 != 0;
      return NumberFormat.decimalPattern('id_ID').format(
        hasDecimal ? double.parse(amount.toStringAsFixed(1)) : amount.round(),
      );
    }

    if (abs >= 1000000000) {
      final amount = value.abs() / 1000000000;
      return '$sign$symbol${formatAmount(amount, allowDecimal: true)} M';
    }
    if (abs >= 1000000) {
      final amount = value.abs() / 1000000;
      return '$sign$symbol${formatAmount(amount, allowDecimal: true)} jt';
    }
    if (abs >= 1000) {
      final amount = value.abs() / 1000;
      return '$sign$symbol${formatAmount(amount)} rb';
    }
    return '$sign$symbol${NumberFormat.decimalPattern('id_ID').format(abs.round())}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppDecorations.card(
        radius: 28,
        shadow: [
          const BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _buildHeader(),
          ),
          const SizedBox(height: 20),
          if (summary != null) _buildQuickMetrics(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildLegend(),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEF1F5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        size: 18,
                        color: colorProfit,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Tren Harian',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Ketuk titik untuk detail',
                        style: TextStyle(
                          color: AppPalette.muted,
                          fontSize: 9.5,
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 245,
                  child: data.isEmpty
                      ? _buildEmptyState()
                      : CombinedChart(data: data),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Analisa Keuangan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: AppFont.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Performa outlet ${DateFormat('MMMM yyyy', 'id_ID').format(selectedMonth)}",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.4),
                  fontWeight: AppFont.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onFilterTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: colorExpense,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM yy', 'id_ID').format(selectedMonth),
                  style: const TextStyle(
                    color: colorExpense,
                    fontSize: 12,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetrics() {
    double avgOrderValue = 0;
    if (summary!.totalTransaksi > 0) {
      avgOrderValue = summary!.totalOmset / summary!.totalTransaksi;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _ProfitHighlight(
            value: summary!.profitLoss,
            trend: summary!.profitLossTrend,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: "Total Penjualan",
                  value: summary!.totalOmset,
                  trend: summary!.omsetTrend,
                  color: colorOmset,
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: "Pendapatan",
                  value: summary!.totalIncome,
                  trend: summary!.incomeTrend,
                  color: colorIncome,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: "Pengeluaran",
                  value: summary!.totalExpense,
                  trend: summary!.expenseTrend,
                  color: colorExpense,
                  icon: Icons.outbox_rounded,
                  isNegativeTrendGood: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: "Rata-rata Order",
                  value: avgOrderValue,
                  trend: 0,
                  color: const Color(0xFF00A6A6),
                  icon: Icons.shopping_basket_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LegendItem(label: "Laba Bersih", color: colorProfit, isBold: true),
          SizedBox(width: 8),
          _LegendItem(label: "Pendapatan", color: colorIncome),
          SizedBox(width: 8),
          _LegendItem(label: "Penjualan", color: colorOmset),
          SizedBox(width: 8),
          _LegendItem(
            label: "Pengeluaran",
            color: colorExpense,
            isDashed: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget.laporan(
      title: 'Belum ada data',
      message: 'Belum ada data untuk ditampilkan',
      imageWidth: 140,
    );
  }
}

enum FinanceChartSeries { profit, income, sales, expense }

class BusinessTrendCard extends StatefulWidget {
  final List<ChartDataFinance> data;
  final bool isLoading;
  final bool isExpanded;
  final String periodLabel;
  final VoidCallback onToggle;
  final VoidCallback onFilterTap;

  const BusinessTrendCard({
    super.key,
    required this.data,
    required this.isLoading,
    required this.isExpanded,
    required this.periodLabel,
    required this.onToggle,
    required this.onFilterTap,
  });

  @override
  State<BusinessTrendCard> createState() => _BusinessTrendCardState();
}

class _BusinessTrendCardState extends State<BusinessTrendCard> {
  final Set<FinanceChartSeries> _selectedSeries = {
    FinanceChartSeries.profit,
    FinanceChartSeries.income,
    FinanceChartSeries.sales,
    FinanceChartSeries.expense,
  };

  void _toggleSeries(FinanceChartSeries series) {
    setState(() {
      if (_selectedSeries.contains(series)) {
        if (_selectedSeries.length > 1) {
          _selectedSeries.remove(series);
        }
      } else {
        _selectedSeries.add(series);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: 16, shadow: AppShadows.cardSoft),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      size: 18,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Grafik Perkembangan Bisnis',
                      style: TextStyle(
                        color: AppPalette.ink,
                        fontSize: 12,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Tren Harian',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 13,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: widget.onFilterTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: AppPalette.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.periodLabel,
                                style: const TextStyle(
                                  color: AppPalette.primary,
                                  fontSize: 10,
                                  fontWeight: AppFont.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _LegendItem(
                            label: 'Laba/Rugi Kas',
                            color: FinanceChartCard.colorProfit,
                            isBold: true,
                            isSelected: _selectedSeries.contains(
                              FinanceChartSeries.profit,
                            ),
                            onTap: () =>
                                _toggleSeries(FinanceChartSeries.profit),
                          ),
                          const SizedBox(width: 6),
                          _LegendItem(
                            label: 'Pendapatan',
                            color: FinanceChartCard.colorIncome,
                            isSelected: _selectedSeries.contains(
                              FinanceChartSeries.income,
                            ),
                            onTap: () =>
                                _toggleSeries(FinanceChartSeries.income),
                          ),
                          const SizedBox(width: 6),
                          _LegendItem(
                            label: 'Penjualan',
                            color: FinanceChartCard.colorOmset,
                            isSelected: _selectedSeries.contains(
                              FinanceChartSeries.sales,
                            ),
                            onTap: () =>
                                _toggleSeries(FinanceChartSeries.sales),
                          ),
                          const SizedBox(width: 6),
                          _LegendItem(
                            label: 'Pengeluaran',
                            color: FinanceChartCard.colorExpense,
                            isDashed: true,
                            isSelected: _selectedSeries.contains(
                              FinanceChartSeries.expense,
                            ),
                            onTap: () =>
                                _toggleSeries(FinanceChartSeries.expense),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 245,
                    child: widget.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : widget.data.isEmpty
                        ? const EmptyStateWidget.laporan(
                            title: 'Belum ada data',
                            message: 'Belum ada aktivitas pada periode ini',
                            imageWidth: 120,
                          )
                        : CombinedChart(
                            data: widget.data,
                            selectedSeries: _selectedSeries,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final double value;
  final double trend;
  final Color color;
  final IconData icon;
  final bool isNegativeTrendGood;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
    required this.icon,
    this.isNegativeTrendGood = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final bool isGoodTrend = isNegativeTrendGood ? !isPositive : isPositive;
    final bool isNegativeValue = value < 0;
    final Color effectiveColor = isNegativeValue
        ? FinanceChartCard.colorExpense
        : color;

    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: effectiveColor),
              ),
              if (trend != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isGoodTrend ? Colors.green : Colors.red).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formatTrendLabel(trend, decimalDigits: 0),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: AppFont.w700,
                      color: isGoodTrend ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.black.withValues(alpha: 0.4),
              fontWeight: AppFont.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FinanceChartCard.formatCompactMoney(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w900,
              color: effectiveColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitHighlight extends StatelessWidget {
  final double value;
  final double trend;

  const _ProfitHighlight({required this.value, required this.trend});

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final color = isNegative
        ? FinanceChartCard.colorExpense
        : FinanceChartCard.colorProfit;
    final trendIsGood = trend >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_graph_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laba Bersih',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    fontWeight: AppFont.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  FinanceChartCard.formatCompactMoney(value),
                  style: TextStyle(
                    color: color,
                    fontSize: 23,
                    fontWeight: AppFont.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ],
            ),
          ),
          if (trend != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: (trendIsGood ? Colors.green : Colors.red).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formatTrendLabel(trend, decimalDigits: 0),
                style: TextStyle(
                  color: trendIsGood ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: AppFont.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CombinedChart extends StatefulWidget {
  final List<ChartDataFinance> data;
  final Set<FinanceChartSeries> selectedSeries;

  const CombinedChart({
    super.key,
    required this.data,
    this.selectedSeries = const {
      FinanceChartSeries.profit,
      FinanceChartSeries.income,
      FinanceChartSeries.sales,
      FinanceChartSeries.expense,
    },
  });

  @override
  State<CombinedChart> createState() => _CombinedChartState();
}

class _CombinedChartState extends State<CombinedChart> {
  double _niceInterval(double range) {
    if (range <= 0) return 1;
    final rough = range / 4;
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final normalized = rough / magnitude;
    final step = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return step * magnitude;
  }

  List<int> _buildVisibleLabelIndexes() {
    if (widget.data.isEmpty) return const [];
    if (widget.data.length <= 5) {
      return List<int>.generate(widget.data.length, (index) => index);
    }

    final rawIndexes = <int>[
      0,
      (widget.data.length * 0.25).round(),
      (widget.data.length * 0.5).round(),
      (widget.data.length * 0.75).round(),
      widget.data.length - 1,
    ];

    final visibleIndexes = <int>[];
    for (final rawIndex in rawIndexes) {
      final safeIndex = rawIndex.clamp(0, widget.data.length - 1);
      if (!visibleIndexes.contains(safeIndex)) {
        visibleIndexes.add(safeIndex);
      }
    }
    return visibleIndexes;
  }

  @override
  Widget build(BuildContext context) {
    double minY = 0;
    double maxY = 0;
    for (var d in widget.data) {
      final values = <FinanceChartSeries, double>{
        FinanceChartSeries.profit: d.income - d.expense,
        FinanceChartSeries.income: d.income,
        FinanceChartSeries.sales: d.omset,
        FinanceChartSeries.expense: d.expense,
      };
      for (final series in widget.selectedSeries) {
        final value = values[series]!;
        if (value > maxY) maxY = value;
        if (value < minY) minY = value;
      }
    }

    final rawMinY = minY;
    final rawMaxY = maxY == 0 ? 100 : maxY;
    final yInterval = _niceInterval(rawMaxY - rawMinY);
    maxY = (rawMaxY / yInterval).ceil() * yInterval;
    if (maxY == rawMaxY) maxY += yInterval;
    minY = rawMinY < 0 ? (rawMinY / yInterval).floor() * yInterval : 0;
    final periodProfit = widget.data.fold<double>(
      0,
      (total, item) => total + item.income - item.expense,
    );
    final profitLineColor = periodProfit < 0
        ? FinanceChartCard.colorExpense
        : FinanceChartCard.colorProfit;
    final visibleLabelIndexes = _buildVisibleLabelIndexes();
    final activeSeries = FinanceChartSeries.values
        .where(widget.selectedSeries.contains)
        .toList();

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: minY,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (event is FlPanStartEvent || event is FlTapDownEvent) {
              HapticFeedback.selectionClick();
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: Colors.black.withValues(alpha: 0.05),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 8,
                        color: Colors.white,
                        strokeWidth: 4,
                        strokeColor: barData.color ?? Colors.green,
                      ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A1A),
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots.map((s) {
                // Satu tooltip merangkum semua seri yang sedang dipilih.
                if (s.barIndex != 0) return null;

                final d = widget.data[s.spotIndex];
                final fmt = NumberFormat.currency(
                  locale: 'id',
                  symbol: 'Rp',
                  decimalDigits: 0,
                );
                final values = <FinanceChartSeries, double>{
                  FinanceChartSeries.profit: d.income - d.expense,
                  FinanceChartSeries.income: d.income,
                  FinanceChartSeries.sales: d.omset,
                  FinanceChartSeries.expense: d.expense,
                };
                final labels = <FinanceChartSeries, String>{
                  FinanceChartSeries.profit: 'Laba/Rugi Kas',
                  FinanceChartSeries.income: 'Pendapatan',
                  FinanceChartSeries.sales: 'Penjualan',
                  FinanceChartSeries.expense: 'Pengeluaran',
                };
                final colors = <FinanceChartSeries, Color>{
                  FinanceChartSeries.profit: profitLineColor,
                  FinanceChartSeries.income: FinanceChartCard.colorIncome,
                  FinanceChartSeries.sales: FinanceChartCard.colorOmset,
                  FinanceChartSeries.expense: FinanceChartCard.colorExpense,
                };

                return LineTooltipItem(
                  "${DateFormat('d MMMM yyyy').format(parseReportDate(d.date) ?? DateTime.now())}\n",
                  const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: AppFont.w500,
                  ),
                  children: activeSeries.asMap().entries.map((entry) {
                    final series = entry.value;
                    final isLast = entry.key == activeSeries.length - 1;
                    return TextSpan(
                      text:
                          '${labels[series]}: ${fmt.format(values[series])}${isLast ? '' : '\n'}',
                      style: TextStyle(
                        color: colors[series],
                        fontWeight: series == FinanceChartSeries.profit
                            ? AppFont.w900
                            : AppFont.w600,
                        fontSize: series == FinanceChartSeries.profit ? 14 : 11,
                      ),
                    );
                  }).toList(),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= widget.data.length) {
                  return const SizedBox();
                }
                if (!visibleLabelIndexes.contains(idx)) return const SizedBox();
                final date = parseReportDate(widget.data[idx].date);
                if (date == null) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('d MMM', 'id_ID').format(date),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 9,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Text(
                FinanceChartCard.formatCompactMoney(value, prefix: ''),
                style: const TextStyle(
                  color: Color(0xFFD0D0D0),
                  fontWeight: AppFont.w700,
                  fontSize: 9,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black.withValues(alpha: 0.03),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData:
            [
                  // 1. PROFIT LINE (Primary)
                  LineChartBarData(
                    spots: widget.data
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(
                            e.key.toDouble(),
                            e.value.income - e.value.expense,
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: profitLineColor,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: widget.data.length <= 15,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: profitLineColor,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          profitLineColor.withValues(alpha: 0.15),
                          profitLineColor.withValues(alpha: 0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // 2. INCOME LINE (Secondary)
                  LineChartBarData(
                    spots: widget.data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.income))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: FinanceChartCard.colorIncome.withValues(alpha: 0.8),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  // 2. OMSET LINE (Secondary)
                  LineChartBarData(
                    spots: widget.data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.omset))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: FinanceChartCard.colorOmset.withValues(alpha: 0.65),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  // 3. EXPENSE LINE (Dashed)
                  LineChartBarData(
                    spots: widget.data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.expense))
                        .toList(),
                    isCurved: true,
                    color: FinanceChartCard.colorExpense.withValues(
                      alpha: 0.55,
                    ),
                    barWidth: 1.5,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ]
                .asMap()
                .entries
                .where(
                  (entry) => widget.selectedSeries.contains(
                    FinanceChartSeries.values[entry.key],
                  ),
                )
                .map((entry) => entry.value)
                .toList(),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool isBold;
  final bool isDashed;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LegendItem({
    required this.label,
    required this.color,
    this.isBold = false,
    this.isDashed = false,
    this.isSelected = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isBold ? 0.1 : 0.07)
              : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.28)
                : const Color(0xFFE7EAF0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDashed)
              Row(
                children: List.generate(
                  3,
                  (i) => Container(
                    width: 4,
                    height: 2,
                    margin: const EdgeInsets.only(right: 2),
                    color: isSelected ? color : AppPalette.muted,
                  ),
                ),
              )
            else
              Container(
                width: isBold ? 14 : 10,
                height: isBold ? 4 : 2,
                decoration: BoxDecoration(
                  color: isSelected ? color : AppPalette.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isBold ? AppFont.w800 : AppFont.w600,
                color: isSelected
                    ? (isBold ? Colors.black87 : const Color(0xFF686F7D))
                    : AppPalette.muted,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                isSelected ? Icons.check_circle : Icons.add_circle_outline,
                size: 13,
                color: isSelected ? color : AppPalette.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
