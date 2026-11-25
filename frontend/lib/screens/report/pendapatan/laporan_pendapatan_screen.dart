import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:typed_data';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/pendapatan/laporan_pendapatan_skeleton.dart';
import 'package:ayocucinew/screens/report/pendapatan/laporan_pendapatan_detail_screen.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'package:ayocucinew/core/utils/payment_icon_helper.dart';
import 'package:ayocucinew/core/utils/payment_name_helper.dart';
import 'widgets/total_pendapatan_card.dart';
import 'widgets/pendapatan_filter_sheet.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LaporanPendapatanScreen extends StatefulWidget {
  const LaporanPendapatanScreen({super.key});

  @override
  State<LaporanPendapatanScreen> createState() =>
      _LaporanPendapatanScreenState();
}

class _LaporanPendapatanScreenState extends State<LaporanPendapatanScreen> {
  static const Color kPrimary = AppPalette.primary; // AyoCuci Orange
  static const Color kBg = Color(0xFFF8F9FA);

  PendapatanFilter _activeFilter = PendapatanFilter(
    filterBerdasarkan: 'Minggu Ini',
    startDate: DateTime.now().subtract(const Duration(days: 6)),
    endDate: DateTime.now(),
  );
  DateTime _selectedMonth = DateTime.now().subtract(const Duration(days: 6));
  final ScrollController _scrollController = ScrollController();
  bool _isExporting = false;

  final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 240) {
        context.read<LaporanProvider>().loadMoreIncomeReport();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().canReadReportAction('read_pendapatan')) {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _startDate {
    if (_activeFilter.filterBerdasarkan == 'Minggu Ini') {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().subtract(const Duration(days: 6)));
    }
    if (_activeFilter.filterBerdasarkan == 'Custom' &&
        _activeFilter.startDate != null) {
      return DateFormat('yyyy-MM-dd').format(_activeFilter.startDate!);
    }
    if (_activeFilter.filterBerdasarkan == 'Tahunan' &&
        _activeFilter.tahun != null) {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_activeFilter.tahun!, 1, 1));
    }
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
  }

  String get _endDate {
    if (_activeFilter.filterBerdasarkan == 'Minggu Ini') {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    if (_activeFilter.filterBerdasarkan == 'Custom' &&
        _activeFilter.endDate != null) {
      return DateFormat('yyyy-MM-dd').format(_activeFilter.endDate!);
    }
    if (_activeFilter.filterBerdasarkan == 'Tahunan' &&
        _activeFilter.tahun != null) {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_activeFilter.tahun!, 12, 31));
    }
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));
  }

  bool get _isFilterActive =>
      _activeFilter.metodePembayaran != null ||
      _activeFilter.filterBerdasarkan != 'Bulanan';

  String get _periodLabel {
    switch (_activeFilter.filterBerdasarkan) {
      case 'Minggu Ini':
        final fmt = DateFormat('d MMM', 'id_ID');
        final start = DateTime.now().subtract(const Duration(days: 6));
        final end = DateTime.now();
        return '${fmt.format(start)} s/d ${DateFormat('d MMM yyyy', 'id_ID').format(end)}';
      case 'Tahunan':
        final tahun = _activeFilter.tahun ?? _selectedMonth.year;
        return 'Tahun $tahun';
      case 'Custom':
        if (_activeFilter.startDate != null && _activeFilter.endDate != null) {
          final fmt = DateFormat('dd MMM yyyy', 'id_ID');
          return '${fmt.format(_activeFilter.startDate!)} s/d ${fmt.format(_activeFilter.endDate!)}';
        }
        return 'Custom';
      default:
        return DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
    }
  }

  String get _exportPeriodLabel {
    switch (_activeFilter.filterBerdasarkan) {
      case 'Minggu Ini':
        return 'Minggu Ini';
      case 'Tahunan':
        return 'Tahun ${_activeFilter.tahun ?? _selectedMonth.year}';
      case 'Custom':
        return 'Custom';
      default:
        return DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
    }
  }

  Future<void> _fetchData() async {
    final token = context.read<AuthProvider>().token ?? '';
    await context.read<LaporanProvider>().fetchIncomeReport(
      token,
      startDate: _startDate,
      endDate: _endDate,
      metodePembayaran: _activeFilter.metodePembayaran,
    );
  }

  Future<void> _showFilter() async {
    final result = await showModalBottomSheet<PendapatanFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PendapatanFilterSheet(initialFilter: _activeFilter),
    );

    if (result != null) {
      setState(() {
        _activeFilter = result;
        if (result.filterBerdasarkan == 'Bulanan' &&
            result.bulan != null &&
            result.tahun != null) {
          _selectedMonth = DateTime(result.tahun!, result.bulan!);
        } else if (result.filterBerdasarkan == 'Tahunan' &&
            result.tahun != null) {
          _selectedMonth = DateTime(result.tahun!, 1);
        }
      });
      _fetchData();
    }
  }

  Future<void> _showExportSheet() async {
    final provider = context.read<LaporanProvider>();
    if (provider.incomeReport.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data pendapatan untuk diunduh',
        isError: true,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan pendapatan dengan branding AyoCuci.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportIncomePdf();
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportIncomeExcel();
        },
      ),
    );
  }

  ReportPdfDocument _buildExportDocument(
    LaporanProvider provider,
    Uint8List? logoBytes,
  ) {
    return ReportPdfDocument(
      title: 'Laporan Pendapatan',
      subtitle:
          'Ringkasan uang masuk berdasarkan periode dan metode pembayaran yang sedang aktif.',
      periodLabel: _exportPeriodLabel,
      rangeLabel: ReportExportBuilder.formatDateRange(_startDate, _endDate),
      filterLabel: _activeFilter.metodePembayaran?.trim().isNotEmpty == true
          ? _activeFilter.metodePembayaran!
          : 'Semua Metode',
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(provider.totalIncome),
      primaryCaption: 'Total pendapatan periode ini',
      metrics: [
        ReportPdfMetric(
          title: 'Hari Dengan Data',
          value: '${provider.incomeTotalDays} hari',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Rata-rata Harian',
          value: ReportExportBuilder.formatRupiah(
            provider.incomeTotalDays == 0
                ? 0
                : provider.totalIncome / provider.incomeTotalDays,
          ),
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
        ReportPdfMetric(
          title: 'Mode Laporan',
          value: _activeFilter.metodePembayaran?.trim().isNotEmpty == true
              ? _activeFilter.metodePembayaran!
              : 'Semua Metode',
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Detail Uang Masuk',
          subtitle:
              'Breakdown harian dan metode pembayaran yang tampil di aplikasi.',
          headers: const [
            'Tanggal',
            'Metode Pembayaran',
            'Nominal Metode',
            'Total Harian',
          ],
          rows: provider.incomeReport.expand((report) {
            final formattedDate = _dayLabel(report.tanggal);
            if (report.breakdown.isEmpty) {
              return [
                [
                  ReportExportBuilder.formatTableDate(formattedDate),
                  '-',
                  ReportExportBuilder.formatRupiah(0),
                  ReportExportBuilder.formatRupiah(report.totalHarian),
                ],
              ];
            }
            return report.breakdown.map(
              (item) => [
                ReportExportBuilder.formatTableDate(formattedDate),
                item.nama,
                ReportExportBuilder.formatRupiah(item.nominal),
                ReportExportBuilder.formatRupiah(report.totalHarian),
              ],
            );
          }).toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportIncomePdf() async {
    if (_isExporting) return;
    final provider = context.read<LaporanProvider>();

    setState(() => _isExporting = true);

    try {
      await _loadAllIncomePages(provider);
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(provider, logoBytes);

      if (!mounted) return;

      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_pendapatan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.pdf',
        shareTitle: 'Laporan Pendapatan $_periodLabel',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal export laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportIncomeExcel() async {
    if (_isExporting) return;
    final provider = context.read<LaporanProvider>();
    setState(() => _isExporting = true);
    try {
      await _loadAllIncomePages(provider);
      final document = _buildExportDocument(provider, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_pendapatan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.xlsx',
        shareTitle: 'Laporan Pendapatan $_periodLabel',
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

  Future<void> _loadAllIncomePages(LaporanProvider provider) async {
    while (provider.hasMoreIncomeReport) {
      await provider.loadMoreIncomeReport();
    }
  }

  String _dayLabel(String tanggal) {
    try {
      final dt = parseReportDate(tanggal);
      if (dt == null) return tanggal;
      return DateFormat('EEE, dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return tanggal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_pendapatan',
    );
    final provider = context.watch<LaporanProvider>();
    final incomeReport = provider.incomeReport;

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
        ),
        title: const Text(
          'Laporan Pendapatan',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isExporting ? null : _showExportSheet,
            icon: _isExporting
                ? const ReportExportIconSkeleton()
                : Image.asset(
                    'assets/icons/ic_download.webp',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
          ),
        ],
      ),
      body: !canRead
          ? const SafeArea(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 12),
                child: ReportAccessPlaceholder(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Laporan Pendapatan Terkunci',
                  message:
                      'Akun ini belum punya izin untuk melihat data pendapatan.',
                  compact: true,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: kPrimary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      minHeight: 225,
                      maxHeight: 225,
                      child: (shrinkOffset) => Container(
                        color: kBg,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TotalPendapatanCard(
                              totalPendapatan: provider.totalIncome,
                              percentageChange: 0,
                              periodLabel: _periodLabel,
                              totalTransaksi:
                                  0, // Transaction count not available in model yet
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Detail Uang Masuk',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: AppFont.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                _buildFilterButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (provider.isLoading && incomeReport.isEmpty)
                    const SliverFillRemaining(
                      child: LaporanPendapatanSkeleton(),
                    )
                  else if (!provider.isLoading && incomeReport.isEmpty)
                    const SliverFillRemaining(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateWidget.laporan(
                          title: 'Belum ada data pendapatan',
                          message: 'Coba ubah periode atau filter',
                          imageWidth: 170,
                        ),
                      ),
                    )
                  else ...[
                    // "No Data Today" Notice
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final todayStr = DateFormat(
                            'yyyy-MM-dd',
                          ).format(DateTime.now());
                          final bool isTodayMissing = !incomeReport.any(
                            (item) => item.tanggal.startsWith(todayStr),
                          );

                          if (!isTodayMissing) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.04),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: kPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Belum ada pendapatan hari ini',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: AppFont.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Data akan muncul setelah pembayaran tercatat pada periode ini.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: AppFont.w600,
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final report = incomeReport[index];
                          return _buildDayTile(report);
                        }, childCount: incomeReport.length),
                      ),
                    ),
                    if (provider.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                          child: Column(
                            children: [
                              ReportLoadMoreTileSkeleton(),
                              ReportLoadMoreTileSkeleton(),
                            ],
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _showFilter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isFilterActive
                ? kPrimary
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 14,
              color: _isFilterActive ? kPrimary : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              'Filter',
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w800,
                color: _isFilterActive ? kPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTile(IncomeReport report) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bool isToday = report.tanggal.startsWith(todayStr);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isToday
            ? Border.all(color: kPrimary.withValues(alpha: 0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isToday ? 0.08 : 0.03),
            blurRadius: isToday ? 15 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isToday)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'HARI INI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: AppFont.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              childrenPadding: EdgeInsets.zero,
              title: Text(
                _dayLabel(report.tanggal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w800,
                  color: Colors.black87,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt.format(report.totalHarian),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w900,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.black26,
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, color: Color(0xFFF1F1F1)),
                ...report.breakdown.map((item) {
                  final isLast = item == report.breakdown.last;
                  return _buildBreakdownItem(report.tanggal, item, isLast);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String dateStr,
    IncomeBreakdown item,
    bool isLast,
  ) {
    final kategori = _detectKategori(item.nama);
    final displayName = _resolveDisplayName(item.nama, kategori);
    final assetPath = _resolveAsset(item.nama, kategori);

    // Parse the date part (yyyy-MM-dd)
    final datePart = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final token = context.read<AuthProvider>().token ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LaporanPendapatanDetailScreen(
                metodeNama: item.nama,
                startDate: datePart,
                endDate: datePart,
                token: token,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        assetPath,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          PaymentIconHelper.getFallbackIcon(kategori),
                          size: 16,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _fmt.format(item.nominal),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Divider(height: 1, color: Color(0xFFF8F8F8)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _detectKategori(String nama) {
    final n = nama.toLowerCase();
    if (n.contains('qris')) {
      return 'QRIS';
    }
    if (n.contains('transfer') ||
        n.contains('bank') ||
        n.contains('bca') ||
        n.contains('bni') ||
        n.contains('bri')) {
      return 'Transfer';
    }
    if (n.contains('gopay') || n.contains('ovo') || n.contains('dana')) {
      return 'E-Wallet';
    }
    return 'Cash';
  }

  String _resolveDisplayName(String nama, String kategori) {
    switch (kategori) {
      case 'Transfer':
        return PaymentNameHelper.getBankDisplayName(nama);
      case 'E-Wallet':
        return PaymentNameHelper.getEwalletDisplayName(nama);
      default:
        return PaymentNameHelper.getCategoryDisplayName(nama);
    }
  }

  String _resolveAsset(String nama, String kategori) {
    String? path;
    if (kategori == 'Transfer') {
      path = PaymentAssetUtil.getBankLogo(nama);
    } else if (kategori == 'E-Wallet') {
      path = PaymentAssetUtil.getEwalletLogo(nama);
    }
    return path ?? PaymentAssetUtil.getCategoryImage(kategori);
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget Function(double shrinkOffset) child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child(shrinkOffset);

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.minHeight != minHeight ||
      oldDelegate.maxHeight != maxHeight ||
      oldDelegate.child != child;
}
