import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/detail%20laporan/customer_transaction_detail_screen.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

const _ayoOrange = AppPalette.primary;
const _surfaceColor = AppPalette.primaryPale;
const _cardBorderColor = Color(0xFFF4E5DF);

class CustomerDetailReportScreen extends StatefulWidget {
  const CustomerDetailReportScreen({super.key});

  @override
  State<CustomerDetailReportScreen> createState() =>
      _CustomerDetailReportScreenState();
}

class _CustomerDetailReportScreenState
    extends State<CustomerDetailReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int _displayCount = 15;
  static const int _pageSize = 15;
  String _searchQuery = '';
  bool _isExporting = false;
  bool _lastCanAccessAddon = false;
  String _activityStatus = 'active';

  bool _isAddonLockedMessage(String? message) {
    final normalized = (message ?? '').toLowerCase();
    return normalized.contains('memerlukan add-on aktif') ||
        normalized.contains('fitur ini memerlukan add-on aktif') ||
        normalized.contains('silakan lakukan aktivasi terlebih dahulu');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month);
    _endDate = now;
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadMore();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canRead = context.read<AuthProvider>().canReadReportAction(
      'read_customer',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_CUSTOMER_GROWTH',
    );
    final canAccessAddon = hasAddonAccess(context: context, hasAddon: hasAddon);

    if (canRead && canAccessAddon && !_lastCanAccessAddon) {
      _lastCanAccessAddon = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchData();
      });
    } else if (!canAccessAddon) {
      _lastCanAccessAddon = false;
    }
  }

  Future<void> _openAddonActivation() async {
    await Navigator.pushNamed(context, '/aktivasi-akun');
    if (!mounted) return;
    await context.read<AddonProvider>().fetchActiveAddons();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchData() {
    final token = context.read<AuthProvider>().token ?? '';
    context.read<LaporanProvider>().fetchCustomerDetailReport(
      token,
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
    );
    setState(() {
      _displayCount = 15;
    });
  }

  Future<void> _loadMore() async {
    final provider = context.read<LaporanProvider>();
    final allCustomers = _buildSortedCustomers(provider);
    final filtered = _filterCustomers(allCustomers);
    if (_displayCount < filtered.length) {
      setState(() {
        _displayCount += _pageSize;
      });
      return;
    }
    await provider.loadMoreCustomerDetail(_activityStatus);
    if (mounted) setState(() => _displayCount += _pageSize);
  }

  Future<void> _loadAllForLocalSearch() async {
    if (_searchQuery.isEmpty) return;
    final provider = context.read<LaporanProvider>();
    while (provider.customerDetailData(_activityStatus)?.hasMore == true) {
      await provider.loadMoreCustomerDetail(_activityStatus);
    }
  }

  List<TopCustomerItem> _filterCustomers(List<TopCustomerItem> all) {
    if (_searchQuery.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.noHp.contains(_searchQuery),
        )
        .toList();
  }

  List<TopCustomerItem> _buildSortedCustomers(LaporanProvider provider) {
    final data = provider.customerDetailData(_activityStatus);
    final allCustomers = [...?data?.podium, ...?data?.others];
    allCustomers.sort((a, b) {
      final nominalCompare = b.totalNominal.compareTo(a.totalNominal);
      if (nominalCompare != 0) return nominalCompare;
      final orderCompare = b.totalOrder.compareTo(a.totalOrder);
      if (orderCompare != 0) return orderCompare;
      return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
    });
    return allCustomers;
  }

  String _getInitials(String name) {
    final cleanedName = _cleanCustomerName(name);
    final parts = cleanedName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  String _cleanCustomerName(String name) {
    return ReportExportBuilder.sanitizeText(name, fallback: 'Tanpa Nama');
  }

  String _formatPeriod() {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    String fmt(DateTime dt) => '${dt.day} ${bulan[dt.month - 1]} ${dt.year}';
    return '${fmt(_startDate)} s/d ${fmt(_endDate)}';
  }

  String _formatCompactRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  bool get _hasCustomPeriod {
    final now = DateTime.now();
    final defaultStart = DateTime.now().subtract(const Duration(days: 6));
    final defaultEnd = DateTime(now.year, now.month, now.day);
    return _startDate != defaultStart ||
        DateTime(_endDate.year, _endDate.month, _endDate.day) != defaultEnd;
  }

  Future<void> _pickPeriod() async {
    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPeriodFilterSheet(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _startDate = result.start;
      _endDate = result.end;
      _displayCount = 15;
    });
    _fetchData();
  }

  void _goToDetail(TopCustomerItem customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerTransactionDetailScreen(
          customer: customer,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }

  Future<void> _showExportSheet(
    List<TopCustomerItem> filtered,
    int totalOrder,
    double totalNominal,
  ) async {
    if (filtered.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data pelanggan untuk diunduh',
        isError: true,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description:
            'Download ringkasan pelanggan sesuai periode dan pencarian aktif.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf(filtered, totalOrder, totalNominal);
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel(filtered, totalOrder, totalNominal);
        },
      ),
    );
  }

  ReportPdfDocument _buildExportDocument(
    List<TopCustomerItem> filtered,
    int totalOrder,
    double totalNominal,
    Uint8List? logoBytes,
  ) {
    return ReportPdfDocument(
      title: 'Detail Laporan Pelanggan',
      subtitle: 'Daftar pelanggan dan kontribusi transaksi pada periode aktif.',
      periodLabel: _formatPeriod(),
      rangeLabel: ReportExportBuilder.formatDateRange(_startDate, _endDate),
      filterLabel: _searchQuery.trim().isNotEmpty
          ? 'Cari: ${_searchQuery.trim()}'
          : 'Semua Pelanggan',
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: '${filtered.length}',
      primaryCaption: 'Jumlah pelanggan pada daftar aktif',
      metrics: [
        ReportPdfMetric(
          title: 'Total Order',
          value: '$totalOrder order',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Nilai Transaksi',
          value: ReportExportBuilder.formatRupiah(totalNominal),
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Daftar Pelanggan',
          subtitle: 'Urut dari kontribusi transaksi terbesar.',
          headers: const ['Nama', 'No HP', 'Gender', 'Order', 'Total Belanja'],
          rows: filtered
              .map(
                (item) => [
                  ReportExportBuilder.sanitizeText(
                    item.nama,
                    fallback: 'Tanpa Nama',
                  ),
                  item.noHp,
                  item.jenisKelamin,
                  '${item.totalOrder}',
                  ReportExportBuilder.formatRupiah(item.totalNominal),
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf(
    List<TopCustomerItem> filtered,
    int totalOrder,
    double totalNominal,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(
        filtered,
        totalOrder,
        totalNominal,
        logoBytes,
      );
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'detail_laporan_pelanggan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.pdf',
        shareTitle: 'Detail Laporan Pelanggan ${_formatPeriod()}',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal export laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel(
    List<TopCustomerItem> filtered,
    int totalOrder,
    double totalNominal,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final document = _buildExportDocument(
        filtered,
        totalOrder,
        totalNominal,
        null,
      );
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'detail_laporan_pelanggan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.xlsx',
        shareTitle: 'Detail Laporan Pelanggan ${_formatPeriod()}',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal export laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_customer',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_CUSTOMER_GROWTH',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );
    return AppScaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Laporan Pelanggan',
          style: TextStyle(color: Colors.black, fontSize: 17),
        ),
        actions: [
          Consumer<LaporanProvider>(
            builder: (context, provider, _) {
              final allCustomers = _buildSortedCustomers(provider);
              final filtered = _filterCustomers(allCustomers);
              final totalNominal = filtered.fold<double>(
                0,
                (sum, item) => sum + item.totalNominal,
              );
              final totalOrder = filtered.fold<int>(
                0,
                (sum, item) => sum + item.totalOrder,
              );
              return IconButton(
                onPressed: _isExporting
                    ? null
                    : () =>
                          _showExportSheet(filtered, totalOrder, totalNominal),
                icon: _isExporting
                    ? const ReportExportIconSkeleton()
                    : Image.asset(
                        'assets/icons/ic_download.webp',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.download_rounded,
                            size: 22,
                            color: Colors.black87,
                          );
                        },
                      ),
              );
            },
          ),
        ],
      ),
      body: !canRead
          ? const SafeArea(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 12),
                child: ReportAccessPlaceholder(
                  icon: Icons.person_search_outlined,
                  title: 'Detail Laporan Pelanggan Terkunci',
                  message:
                      'Akun ini belum punya izin untuk melihat detail laporan pelanggan.',
                  compact: true,
                ),
              ),
            )
          : !canAccessAddonFeature
          ? SafeArea(
              child: AddonLockedPlaceholder(
                title: 'Detail pelanggan belum aktif',
                message:
                    'Aktifkan add-on untuk membuka daftar pelanggan dan ringkasan transaksinya.',
                features: const [
                  'Daftar pelanggan',
                  'Ringkasan transaksi',
                  'Detail per pelanggan',
                ],
                onActionTap: _openAddonActivation,
              ),
            )
          : Consumer<LaporanProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const ReportCustomerDetailSkeleton();
                }

                if (_isAddonLockedMessage(provider.errorMessage)) {
                  return SafeArea(
                    child: AddonLockedPlaceholder(
                      title: 'Detail pelanggan belum aktif',
                      message:
                          'Aktifkan add-on untuk membuka daftar pelanggan dan ringkasan transaksinya.',
                      features: const [
                        'Daftar pelanggan',
                        'Ringkasan transaksi',
                        'Detail per pelanggan',
                      ],
                      onActionTap: _openAddonActivation,
                    ),
                  );
                }

                if (provider.errorMessage != null) {
                  return ReportErrorView(
                    message: provider.errorMessage!,
                    onRetry: _fetchData,
                    color: _ayoOrange,
                  );
                }

                final allCustomers = _buildSortedCustomers(provider);
                final filtered = _filterCustomers(allCustomers);
                final displayed = filtered.take(_displayCount).toList();
                final serverSummary = provider.customerDetailData(
                  _activityStatus,
                );
                final totalNominal = _searchQuery.isEmpty
                    ? (serverSummary?.totalNominal ?? 0)
                    : filtered.fold<double>(
                        0,
                        (sum, item) => sum + item.totalNominal,
                      );
                final totalOrder = _searchQuery.isEmpty
                    ? (serverSummary?.totalOrder ?? 0)
                    : filtered.fold<int>(
                        0,
                        (sum, item) => sum + item.totalOrder,
                      );
                final totalCustomers = _searchQuery.isEmpty
                    ? (serverSummary?.totalCustomers ?? 0)
                    : filtered.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CustomerSummaryCard(
                            periodLabel: _formatPeriod(),
                            totalCustomers: totalCustomers,
                            totalOrders: totalOrder,
                            totalNominal: _formatCompactRupiah(totalNominal),
                            isFiltered: _searchQuery.isNotEmpty,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _CustomerSearchBar(
                                  controller: _searchController,
                                  query: _searchQuery,
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                      _displayCount = 15;
                                    });
                                    _loadAllForLocalSearch();
                                  },
                                  onClear: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _displayCount = 15;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              _CustomerPeriodFilterButton(
                                isActive: _hasCustomPeriod,
                                onTap: _pickPeriod,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CustomerActivityFilter(
                            value: _activityStatus,
                            onChanged: (value) {
                              if (value == _activityStatus) return;
                              setState(() {
                                _activityStatus = value;
                                _displayCount = 15;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _CustomerListHeader(
                            totalCustomers: totalCustomers,
                            isInactive: _activityStatus == 'inactive',
                          ),
                          if (provider.isLoadingMoreCustomer)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: _ayoOrange,
                        onRefresh: () async => _fetchData(),
                        child: filtered.isEmpty
                            ? ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  24,
                                ),
                                children: [
                                  _CustomerEmptyState(
                                    isInactive: _activityStatus == 'inactive',
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  24,
                                ),
                                itemCount: displayed.length + 1,
                                itemBuilder: (context, index) {
                                  if (index >= displayed.length) {
                                    if (_displayCount < filtered.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: ReportLoadMoreTileSkeleton(),
                                      );
                                    }
                                    return const SizedBox(height: 24);
                                  }

                                  final customer = displayed[index];
                                  return _CustomerCard(
                                    customer: customer,
                                    initials: _getInitials(customer.nama),
                                    displayName: _cleanCustomerName(
                                      customer.nama,
                                    ),
                                    onTap: () => _goToDetail(customer),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  final String periodLabel;
  final int totalCustomers;
  final int totalOrders;
  final String totalNominal;
  final bool isFiltered;

  const _CustomerSummaryCard({
    required this.periodLabel,
    required this.totalCustomers,
    required this.totalOrders,
    required this.totalNominal,
    required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Pelanggan',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCustomers.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _SummaryPill(
                    icon: Icons.calendar_today_rounded,
                    label: 'Periode',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    periodLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  if (isFiltered) ...[
                    const SizedBox(height: 6),
                    const _SummaryPill(
                      icon: Icons.search_rounded,
                      label: 'Hasil Pencarian',
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryMiniMetric(
                  label: 'Total Order',
                  value: '$totalOrders order',
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMiniMetric(
                  label: 'Nilai Transaksi',
                  value: totalNominal,
                  alignEnd: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _SummaryMiniMetric({
    required this.label,
    required this.value,
    this.alignEnd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _CustomerListHeader extends StatelessWidget {
  final int totalCustomers;
  final bool isInactive;

  const _CustomerListHeader({
    required this.totalCustomers,
    required this.isInactive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daftar Pelanggan',
                  style: TextStyle(fontSize: 18, color: Color(0xFF2F2A28)),
                ),
                const SizedBox(height: 3),
                Text(
                  isInactive
                      ? 'Belum melakukan transaksi pada periode ini.'
                      : 'Urut dari kontribusi transaksi terbesar.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF938B86),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalCustomers pelanggan',
              style: const TextStyle(fontSize: 12, color: _ayoOrange),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerEmptyState extends StatelessWidget {
  final bool isInactive;

  const _CustomerEmptyState({required this.isInactive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorderColor),
      ),
      child: EmptyStateWidget.pelanggan(
        title: isInactive
            ? 'Semua pelanggan sudah bertransaksi'
            : 'Belum ada transaksi pelanggan',
        message: isInactive
            ? 'Tidak ada pelanggan yang perlu ditindaklanjuti pada periode ini.'
            : 'Data pelanggan akan muncul setelah ada transaksi pada periode laporan ini.',
        imageWidth: 170,
      ),
    );
  }
}

class _CustomerActivityFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CustomerActivityFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActivityFilterChip(
            label: 'Bertransaksi',
            selected: value == 'active',
            onTap: () => onChanged('active'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActivityFilterChip(
            label: 'Belum Transaksi',
            selected: value == 'inactive',
            onTap: () => onChanged('inactive'),
          ),
        ),
      ],
    );
  }
}

class _ActivityFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppPalette.primary : _cardBorderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6E6662),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CustomerSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      onChanged: onChanged,
      onClear: onClear,
      showClear: query.isNotEmpty,
      hintText: 'Cari pelanggan',
      height: 48,
    );
  }
}

class _CustomerPeriodFilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CustomerPeriodFilterButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? const Color(0xFFFFD3C7) : _cardBorderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 20,
            color: isActive ? _ayoOrange : const Color(0xFFB1A7A1),
          ),
        ),
      ),
    );
  }
}

class _CustomerPeriodFilterSheet extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const _CustomerPeriodFilterSheet({
    required this.initialStartDate,
    required this.initialEndDate,
  });

  @override
  State<_CustomerPeriodFilterSheet> createState() =>
      _CustomerPeriodFilterSheetState();
}

class _CustomerPeriodFilterSheetState
    extends State<_CustomerPeriodFilterSheet> {
  static const List<String> _options = ['Bulanan', 'Tahunan', 'Custom'];
  static const List<String> _bulanNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  late String _mode;
  late int _bulan;
  late int _tahun;
  DateTime? _startDate;
  DateTime? _endDate;

  List<int> get _yearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(3, (index) => currentYear - index);
  }

  int _safeYear(int year) {
    final years = _yearOptions;
    return years.contains(year) ? year : years.first;
  }

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  bool get _canApply =>
      _mode != 'Custom' || (_startDate != null && _endDate != null);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isDefaultMonthly =
        widget.initialStartDate.year == now.year &&
        widget.initialStartDate.month == now.month &&
        widget.initialStartDate.day == 1 &&
        widget.initialEndDate.year == now.year &&
        widget.initialEndDate.month == now.month &&
        widget.initialEndDate.day == now.day;

    final isFullYear =
        widget.initialStartDate.month == 1 &&
        widget.initialStartDate.day == 1 &&
        widget.initialEndDate.month == 12 &&
        widget.initialEndDate.day == 31 &&
        widget.initialStartDate.year == widget.initialEndDate.year;

    _mode = isDefaultMonthly ? 'Bulanan' : (isFullYear ? 'Tahunan' : 'Custom');
    _bulan = widget.initialStartDate.month;
    _tahun = _safeYear(widget.initialStartDate.year);
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  void _reset() {
    final now = DateTime.now();
    setState(() {
      _mode = 'Bulanan';
      _bulan = now.month;
      _tahun = _safeYear(now.year);
      _startDate = DateTime.now().subtract(const Duration(days: 6));
      _endDate = now;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(initial, firstDate, now),
      firstDate: firstDate,
      lastDate: now,
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _ayoOrange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _mode = 'Custom';
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_mode == 'Bulanan') {
      final start = DateTime(_tahun, _bulan, 1);
      final endOfMonth = DateTime(_tahun, _bulan + 1, 0);
      return DateTimeRange(
        start: start,
        end: endOfMonth.isAfter(today) ? today : endOfMonth,
      );
    }

    if (_mode == 'Tahunan') {
      final start = DateTime(_tahun, 1, 1);
      final endOfYear = DateTime(_tahun, 12, 31);
      return DateTimeRange(
        start: start,
        end: endOfYear.isAfter(today) ? today : endOfYear,
      );
    }

    return DateTimeRange(
      start: _startDate ?? today.subtract(const Duration(days: 6)),
      end: _endDate ?? today,
    );
  }

  void _apply() {
    final now = DateTime.now();
    late final DateTime start;
    late final DateTime end;

    if (_mode == 'Bulanan') {
      start = DateTime(_tahun, _bulan, 1);
      final lastDay = DateTime(_tahun, _bulan + 1, 0);
      final today = DateTime(now.year, now.month, now.day);
      end = _tahun == now.year && _bulan == now.month && lastDay.isAfter(today)
          ? today
          : lastDay;
    } else if (_mode == 'Tahunan') {
      start = DateTime(_tahun, 1, 1);
      final lastDay = DateTime(_tahun, 12, 31);
      final today = DateTime(now.year, now.month, now.day);
      end = _tahun == now.year && lastDay.isAfter(today) ? today : lastDay;
    } else {
      if (_startDate == null || _endDate == null) return;
      start = _startDate!;
      end = _endDate!;
    }

    Navigator.pop(context, DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7D9D2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Periode',
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFF241815),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Atur rentang waktu laporan pelanggan.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8D807A),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _reset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 13, color: _ayoOrange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildModeSelector(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_mode),
                  child: _buildPeriodFields(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canApply ? _apply : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ayoOrange,
                    disabledBackgroundColor: const Color(0xFFF2D6CD),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _mode == 'Custom' && !_canApply
                        ? 'Lengkapi rentang tanggal'
                        : 'TERAPKAN FILTER',
                    style: const TextStyle(fontSize: 14, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final activeIndex = _options.indexOf(_mode).clamp(0, _options.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / _options.length;

        return Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2EF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: activeIndex * segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: _options.map((option) {
                  final isActive = _mode == option;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _mode = option),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? _ayoOrange
                                : const Color(0xFF7F736E),
                          ),
                          child: Text(option),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBulananPicker() {
    return Row(
      key: const ValueKey('bulanan'),
      children: [
        Expanded(
          child: _buildDropdown<int>(
            value: _bulan,
            hint: 'Bulan',
            items: List.generate(
              12,
              (i) =>
                  DropdownMenuItem(value: i + 1, child: Text(_bulanNames[i])),
            ),
            onChanged: (val) => setState(() => _bulan = val ?? _bulan),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown<int>(
            value: _tahun,
            hint: 'Tahun',
            items: _yearOptions
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  ),
                )
                .toList(),
            onChanged: (val) =>
                setState(() => _tahun = _safeYear(val ?? _tahun)),
          ),
        ),
      ],
    );
  }

  Widget _buildTahunanPicker() {
    return SizedBox(
      key: const ValueKey('tahunan'),
      child: _buildDropdown<int>(
        value: _tahun,
        hint: 'Tahun',
        items: _yearOptions
            .map(
              (year) =>
                  DropdownMenuItem(value: year, child: Text(year.toString())),
            )
            .toList(),
        onChanged: (val) => setState(() => _tahun = _safeYear(val ?? _tahun)),
      ),
    );
  }

  Widget _buildPeriodFields() {
    Widget? selector;
    if (_mode == 'Bulanan') {
      selector = _buildBulananPicker();
    } else if (_mode == 'Tahunan') {
      selector = _buildTahunanPicker();
    }

    final range = _activeRange;
    return Column(
      children: [
        if (selector != null) ...[selector, const SizedBox(height: 12)],
        Row(
          children: [
            Expanded(
              child: _PeriodDateTile(
                label: 'Tanggal Mulai',
                value: range.start,
                onTap: () => _pickDate(isStart: true),
                onClear: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PeriodDateTile(
                label: 'Tanggal Selesai',
                value: range.end,
                onTap: () => _pickDate(isStart: false),
                onClear: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFFFBF8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0E3DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0E3DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _ayoOrange),
        ),
      ),
    );
  }
}

class _PeriodDateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PeriodDateTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Pilih tanggal'
        : DateFormat('d MMMM yyyy', 'id_ID').format(value!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0E3DD)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: _ayoOrange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8A7D77),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF221816),
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF9E908B),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final TopCustomerItem customer;
  final String initials;
  final String displayName;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.initials,
    required this.displayName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CustomerAvatar(initials: initials),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            color: Color(0xFF2F2A28),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 13,
                              color: Color(0xFFB3A7A1),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                customer.noHp.isNotEmpty
                                    ? customer.noHp
                                    : 'Nomor HP belum tersedia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF948B86),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Belanja',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFFA59C97),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Rp ${_formatRupiah(customer.totalNominal)}',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15,
                              color: _ayoOrange,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFF5ECE8)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.receipt_long_rounded,
                          label: '${customer.totalOrder} order',
                          backgroundColor: const Color(0xFFFFF3EE),
                          iconColor: _ayoOrange,
                          textColor: const Color(0xFF9A5542),
                        ),
                        if (customer.jenisKelamin.isNotEmpty)
                          _InfoChip(
                            icon: customer.jenisKelamin == 'P'
                                ? Icons.female_rounded
                                : Icons.male_rounded,
                            label: customer.jenisKelamin == 'P'
                                ? 'Perempuan'
                                : 'Laki-laki',
                            backgroundColor: customer.jenisKelamin == 'P'
                                ? const Color(0xFFFFF0F4)
                                : const Color(0xFFF1F6FF),
                            iconColor: customer.jenisKelamin == 'P'
                                ? const Color(0xFFE57399)
                                : const Color(0xFF6D9EEB),
                            textColor: const Color(0xFF7E7671),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _ayoOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRupiah(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String initials;

  const _CustomerAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    final display = initials.trim().isEmpty || initials == '?'
        ? null
        : initials;

    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFF0EB), Color(0xFFFFE2D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: display == null
          ? const Icon(Icons.person_rounded, color: _ayoOrange, size: 25)
          : Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(color: _ayoOrange, fontSize: 16),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: textColor)),
        ],
      ),
    );
  }
}
