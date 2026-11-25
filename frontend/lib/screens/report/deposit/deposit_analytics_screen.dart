import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/deposit_analytics_provider.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../widgets/report_error_view.dart';

class DepositAnalyticsScreen extends StatelessWidget {
  final Customer? customer;

  const DepositAnalyticsScreen({super.key, this.customer});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => DepositAnalyticsProvider()..fetch(customerId: customer?.id),
    child: _DepositAnalyticsView(customer: customer),
  );
}

enum _AnalyticsPeriod { all, today, week, month, year, custom }

class _DepositAnalyticsView extends StatefulWidget {
  final Customer? customer;

  const _DepositAnalyticsView({required this.customer});

  @override
  State<_DepositAnalyticsView> createState() => _DepositAnalyticsViewState();
}

class _DepositAnalyticsViewState extends State<_DepositAnalyticsView> {
  Customer? get customer => widget.customer;
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  _AnalyticsPeriod _period = _AnalyticsPeriod.all;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final isCustomer = customer != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppPageBar(
        title: 'Analitik Deposit',
        actions: [
          IconButton(
            tooltip: 'Filter periode',
            onPressed: _showPeriodPicker,
            icon: const Icon(Icons.tune_rounded, color: AppPalette.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<DepositAnalyticsProvider>(
        builder: (context, provider, _) {
          final a = provider.analytics;
          if (provider.isLoading && !provider.hasLoaded) {
            return _DepositAnalyticsSkeleton(showCustomerScope: isCustomer);
          }
          if (provider.errorMessage != null && !provider.hasLoaded) {
            return ReportErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.fetch(customerId: customer?.id),
              color: AppPalette.primary,
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 40,
            ),
            children: [
              if (provider.isLoading) ...[
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppPalette.primary,
                  backgroundColor: AppPalette.primaryPale,
                ),
                const SizedBox(height: 12),
              ],
              if (isCustomer) _customerScope(),
              if (isCustomer) const SizedBox(height: 12),
              _balanceHero(a.currentRupiah, a.currentKg),
              const SizedBox(height: 20),
              _periodHeader(),
              const SizedBox(height: 12),
              if (provider.errorMessage != null)
                _error(provider.errorMessage!)
              else ...[
                _cashReceivedSummary(
                  a.totalPaidTopUpRupiah + a.totalPaidTopUpKg,
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Deposit Rupiah',
                  accent: AppPalette.primary,
                  rows: [
                    _MetricRow(
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Nilai deposit diberikan',
                      value: _money.format(a.totalTopUpRupiah),
                      valueColor: AppPalette.primary,
                    ),
                    _MetricRow(
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppPalette.primary,
                      label: 'Kas diterima dari top up',
                      value: _money.format(a.totalPaidTopUpRupiah),
                      valueColor: AppPalette.primary,
                    ),
                    _MetricRow(
                      icon: Icons.local_offer_outlined,
                      color: const Color(0xFFF59E0B),
                      label: 'Diskon program deposit',
                      value: _money.format(a.totalDiscountRupiah),
                      valueColor: const Color(0xFFF59E0B),
                    ),
                    _MetricRow(
                      icon: Icons.shopping_bag_outlined,
                      color: const Color(0xFFFF6B4A),
                      label: 'Deposit sudah digunakan',
                      value: _money.format(a.totalUsageRupiah),
                      valueColor: AppPalette.primary,
                    ),
                    _MetricRow(
                      icon: Icons.replay_rounded,
                      color: const Color(0xFF6D8CFF),
                      label: 'Pengembalian deposit',
                      value: _money.format(a.totalRefundRupiah),
                      valueColor: AppPalette.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Deposit Kiloan',
                  accent: const Color(0xFF0F9D82),
                  rows: [
                    _MetricRow(
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Total top up kiloan',
                      value: '${formatCompactQuantity(a.totalTopUpKg)} Kg',
                      valueColor: const Color(0xFF0F9D82),
                    ),
                    _MetricRow(
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppPalette.primary,
                      label: 'Kas diterima dari top up kiloan',
                      value: _money.format(a.totalPaidTopUpKg),
                      valueColor: const Color(0xFF0F9D82),
                    ),
                    _MetricRow(
                      icon: Icons.local_offer_outlined,
                      color: const Color(0xFFF59E0B),
                      label: 'Diskon program kiloan',
                      value: _money.format(a.totalDiscountKg),
                      valueColor: const Color(0xFFF59E0B),
                    ),
                    _MetricRow(
                      icon: Icons.shopping_bag_outlined,
                      color: const Color(0xFFFF6B4A),
                      label: 'Kiloan sudah digunakan',
                      value: '${formatCompactQuantity(a.totalUsageKg)} Kg',
                      valueColor: const Color(0xFF0F9D82),
                    ),
                    _MetricRow(
                      icon: Icons.replay_rounded,
                      color: const Color(0xFF6D8CFF),
                      label: 'Kiloan dikembalikan',
                      value: '${formatCompactQuantity(a.totalRefundKg)} Kg',
                      valueColor: const Color(0xFF0F9D82),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String get _periodLabel {
    final formatter = DateFormat('dd MMM yyyy', 'id_ID');
    return switch (_period) {
      _AnalyticsPeriod.all => 'Sejak Bergabung',
      _AnalyticsPeriod.today => 'Hari Ini',
      _AnalyticsPeriod.week => '7 Hari Terakhir',
      _AnalyticsPeriod.month => 'Bulan Ini',
      _AnalyticsPeriod.year => 'Tahun Ini',
      _AnalyticsPeriod.custom when _customRange != null =>
        '${formatter.format(_customRange!.start)} – ${formatter.format(_customRange!.end)}',
      _ => 'Custom',
    };
  }

  DateTimeRange? _rangeFor(_AnalyticsPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      _AnalyticsPeriod.all => null,
      _AnalyticsPeriod.today => DateTimeRange(start: today, end: today),
      _AnalyticsPeriod.week => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _AnalyticsPeriod.month => DateTimeRange(
        start: DateTime(today.year, today.month, 1),
        end: today,
      ),
      _AnalyticsPeriod.year => DateTimeRange(
        start: DateTime(today.year, 1, 1),
        end: today,
      ),
      _AnalyticsPeriod.custom => _customRange,
    };
  }

  Future<void> _applyPeriod(_AnalyticsPeriod period) async {
    DateTimeRange? range;
    if (period == _AnalyticsPeriod.custom) {
      final now = DateTime.now();
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5, 1, 1),
        lastDate: now,
        initialDateRange: _customRange,
        helpText: 'Pilih Periode Analitik',
        saveText: 'TERAPKAN',
      );
      if (range == null || !mounted) return;
      _customRange = range;
    } else {
      range = _rangeFor(period);
    }

    setState(() => _period = period);
    await context.read<DepositAnalyticsProvider>().fetch(
      customerId: customer?.id,
      startDate: range?.start,
      endDate: range?.end,
    );
  }

  Future<void> _showPeriodPicker() async {
    final selected = await showModalBottomSheet<_AnalyticsPeriod>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Periode Aktivitas Deposit',
                style: TextStyle(fontSize: 17, fontWeight: AppFont.w700),
              ),
              const SizedBox(height: 12),
              for (final option in _AnalyticsPeriod.values)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (option) {
                    _AnalyticsPeriod.all => 'Sejak Bergabung',
                    _AnalyticsPeriod.today => 'Hari Ini',
                    _AnalyticsPeriod.week => '7 Hari Terakhir',
                    _AnalyticsPeriod.month => 'Bulan Ini',
                    _AnalyticsPeriod.year => 'Tahun Ini',
                    _AnalyticsPeriod.custom => 'Custom',
                  }),
                  trailing: option == _period
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppPalette.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _applyPeriod(selected);
  }

  Widget _periodHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas Deposit — $_periodLabel',
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 18,
                fontWeight: AppFont.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Saldo aktif di atas selalu menampilkan posisi saat ini.',
              style: TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Ubah periode',
        visualDensity: VisualDensity.compact,
        onPressed: _showPeriodPicker,
        icon: const Icon(Icons.calendar_month_rounded),
        color: AppPalette.primary,
      ),
    ],
  );

  Widget _customerScope() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFDDD3)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppPalette.primaryPale,
          child: Icon(Icons.person_rounded, color: AppPalette.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            customer!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: AppFont.w700, fontSize: 16),
          ),
        ),
      ],
    ),
  );

  Widget _balanceHero(double rupiah, double kg) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: AppPalette.brandGradient),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saldo Deposit Aktif',
          style: TextStyle(color: Colors.white, fontWeight: AppFont.w700),
        ),
        const SizedBox(height: 4),
        Text(
          customer == null
              ? 'Akumulasi saldo seluruh pelanggan saat ini'
              : 'Saldo pelanggan saat ini',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .82),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _heroValue('Rupiah', _money.format(rupiah))),
            Container(
              width: 1,
              height: 42,
              color: Colors.white.withValues(alpha: .35),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _heroValue('Kiloan', '${formatCompactQuantity(kg)} Kg'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _heroValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .82),
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: AppFont.w800,
        ),
      ),
    ],
  );

  Widget _cashReceivedSummary(double value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF9F0),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFCDEED9)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.payments_outlined,
            color: Color(0xFF16A765),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total uang diterima',
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 14,
                  fontWeight: AppFont.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Gabungan pembayaran top up Rupiah dan Kiloan',
                style: TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _money.format(value),
          style: const TextStyle(
            color: Color(0xFF16A765),
            fontSize: 16,
            fontWeight: AppFont.w900,
          ),
        ),
      ],
    ),
  );

  Widget _section({
    required String title,
    required Color accent,
    required List<_MetricRow> rows,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: .16)),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
      ],
    ),
  );

  Widget _error(String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message, style: const TextStyle(color: AppPalette.muted)),
  );
}

class _DepositAnalyticsSkeleton extends StatelessWidget {
  final bool showCustomerScope;

  const _DepositAnalyticsSkeleton({required this.showCustomerScope});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: [
        if (showCustomerScope) ...const [
          AppSkeletonBox(height: 46, radius: 14),
          SizedBox(height: 12),
        ],
        const AppSkeletonBox(height: 146, radius: 22),
        const SizedBox(height: 22),
        const AppSkeletonBox(width: 220, height: 20, radius: 8),
        const SizedBox(height: 8),
        const AppSkeletonBox(width: 280, height: 12, radius: 8),
        const SizedBox(height: 14),
        const AppSkeletonBox(height: 252, radius: 18),
        const SizedBox(height: 12),
        const AppSkeletonBox(height: 210, radius: 18),
      ],
    ),
  );
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color valueColor;

  const _MetricRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppPalette.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontWeight: AppFont.w700, color: valueColor),
        ),
      ],
    ),
  );
}
