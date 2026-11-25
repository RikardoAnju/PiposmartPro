import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import 'widgets/report_header_card.dart';
import 'widgets/summary_grid_section.dart';
import 'widgets/finance_chart_card.dart';
import 'widgets/menu_report_tile.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _chartMonth = DateTime.now();
  bool _isChartExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final provider = context.read<ReportProvider>();
      provider.fetchOutletProfile();
      if (auth.canReadDailyReportSummary || auth.canReadAnyReport) {
        provider.fetchSummary(isDashboard: true);
      }
      if (auth.canReadFinanceOverview) {
        provider.fetchChartData();
      }
    });
  }

  Future<void> _refreshReport(ReportProvider provider) async {
    final auth = context.read<AuthProvider>();
    final futures = <Future<void>>[
      provider.fetchSummary(isDashboard: true, forceRefresh: true),
    ];
    if (auth.canReadFinanceOverview) {
      final start = DateTime(_chartMonth.year, _chartMonth.month, 1);
      final end = DateTime(_chartMonth.year, _chartMonth.month + 1, 0);
      futures.add(
        provider.fetchChartData(start: start, end: end, forceRefresh: true),
      );
    }
    await Future.wait(futures);
  }

  Future<void> _selectChartMonth() async {
    var draft = _chartMonth;
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final now = DateTime.now();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pilih Bulan Grafik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: draft.year > now.year - 2
                            ? () => setSheetState(
                                () => draft = DateTime(
                                  draft.year - 1,
                                  draft.month,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${draft.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: draft.year < now.year
                            ? () => setSheetState(
                                () => draft = DateTime(
                                  draft.year + 1,
                                  draft.month,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.55,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final disabled =
                          draft.year == now.year && month > now.month;
                      final active = draft.month == month;
                      return InkWell(
                        onTap: disabled
                            ? null
                            : () => setSheetState(
                                () => draft = DateTime(draft.year, month),
                              ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? AppPalette.primary
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            DateFormat(
                              'MMM',
                              'id_ID',
                            ).format(DateTime(2024, month)),
                            style: TextStyle(
                              color: disabled
                                  ? Colors.grey.shade300
                                  : active
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 11,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetContext, draft),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(fontWeight: AppFont.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _chartMonth = selected);
    final start = DateTime(selected.year, selected.month, 1);
    final end = DateTime(selected.year, selected.month + 1, 0);
    await context.read<ReportProvider>().fetchChartData(
      start: start,
      end: end,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String todayLabel = DateFormat(
      'EEEE, d MMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    return AppScaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.chevron_left, color: Colors.black87, size: 28),
            ),
          ),
        ),
        title: const AppAssetImage(
          'assets/icons/ic_logo.webp',
          width: 126,
          height: 36,
          fit: BoxFit.contain,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          final auth = context.watch<AuthProvider>();
          if (provider.isLoading && provider.dashboardSummary == null) {
            return const ReportDashboardSkeleton();
          }

          return RefreshIndicator(
            color: AppPalette.danger,
            onRefresh: () => _refreshReport(provider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReportHeaderCard(),
                  const SizedBox(height: 20),
                  SummaryGridSection(
                    summary: provider.dashboardSummary,
                    dateLabel: todayLabel,
                  ),
                  if (auth.canReadFinanceOverview) ...[
                    const SizedBox(height: 16),
                    BusinessTrendCard(
                      data: provider.chartData,
                      isLoading: provider.isChartLoading,
                      isExpanded: _isChartExpanded,
                      periodLabel: DateFormat(
                        'MMM yy',
                        'id_ID',
                      ).format(_chartMonth),
                      onToggle: () =>
                          setState(() => _isChartExpanded = !_isChartExpanded),
                      onFilterTap: _selectChartMonth,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Laporan Usaha',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFont.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MenuReportTile(
                    title: "Laporan Keuangan",
                    subtitle: "Laporan Penjualan, Pendapatan, dan Pengeluaran",
                    image: const AppAssetImage(
                      'assets/laporan/ic_laporan_keuangan.webp',
                      width: 32,
                      height: 32,
                    ),
                    isLocked: !auth.canReadFinanceOverview,
                    onTap: () =>
                        Navigator.pushNamed(context, '/finance-report'),
                  ),
                  MenuReportTile(
                    title: "Laporan Transaksi",
                    subtitle: "Semua data transaksi",
                    image: const AppAssetImage(
                      'assets/laporan/ic_laporan_transaksi.webp',
                      width: 32,
                      height: 32,
                    ),
                    isExpandable: true,
                    isLocked:
                        !auth.canReadReportAction('read_transaction') &&
                        !auth.canReadReportAction('read_service_summary'),
                    children: [
                      SubMenuTile(
                        title: "Semua Data Transaksi",
                        icon: Icons.list_alt_rounded,
                        isLocked: !auth.canReadReportAction('read_transaction'),
                        onTap: () =>
                            Navigator.pushNamed(context, '/all-transactions'),
                      ),
                      SubMenuTile(
                        title: "Ringkasan Transaksi Per Layanan",
                        icon: Icons.category_outlined,
                        isLocked: !auth.canReadReportAction(
                          'read_service_summary',
                        ),
                        onTap: () =>
                            Navigator.pushNamed(context, '/service-report'),
                      ),
                    ],
                  ),
                  MenuReportTile(
                    title: "Laporan Pelanggan",
                    subtitle: "Detail pelanggan dan analisa pertumbuhan",
                    image: const AppAssetImage(
                      'assets/laporan/ic_laporan_pelanggan.webp',
                      width: 32,
                      height: 32,
                    ),
                    isExpandable: true,
                    isLocked: !auth.canReadReportAction('read_customer'),
                    children: [
                      SubMenuTile(
                        title: "Detail Laporan Pelanggan",
                        icon: Icons.person_search_outlined,
                        isLocked: !auth.canReadReportAction('read_customer'),
                        onTap: () =>
                            Navigator.pushNamed(context, '/customer-growth'),
                      ),
                      SubMenuTile(
                        title: "Analisa Pertumbuhan Pelanggan",
                        icon: Icons.show_chart_rounded,
                        isLocked: !auth.canReadReportAction('read_customer'),
                        onTap: () =>
                            Navigator.pushNamed(context, '/customer-summary'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
