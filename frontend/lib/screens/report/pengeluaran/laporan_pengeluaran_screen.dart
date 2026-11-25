import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/pengeluaran/analisa_laporan_skeleton.dart';
import 'package:ayocucinew/screens/report/pengeluaran/pengeluaran_detail_page.dart';
import 'package:ayocucinew/screens/report/pengeluaran/widgets/detail_pengeluaran_tile.dart';
import 'package:ayocucinew/screens/report/pengeluaran/widgets/total_pengeluaran_card.dart';
import 'package:ayocucinew/screens/report/pengeluaran/widgets/pengeluaran_filter_sheet.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AnalisaLaporanScreen extends StatefulWidget {
  final String token;

  const AnalisaLaporanScreen({super.key, required this.token});

  @override
  State<AnalisaLaporanScreen> createState() => _AnalisaLaporanScreenState();
}

class _AnalisaLaporanScreenState extends State<AnalisaLaporanScreen> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFFBFBFB);

  late PengeluaranFilter _currentFilter;
  final ScrollController _scrollController = ScrollController();
  bool _isExporting = false;

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
    _currentFilter = PengeluaranFilter(
      filterBerdasarkan: 'Minggu Ini',
      tanggalMulai: now.subtract(const Duration(days: 6)),
      tanggalSelesai: now,
      bulan: now.month,
      tahun: now.year,
    );

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        context.read<LaporanProvider>().loadMoreExpenseReport(widget.token);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().canReadReportAction(
        'read_pengeluaran',
      )) {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  DateTimeRange get _currentDateRange {
    if (_currentFilter.filterBerdasarkan == 'Custom' ||
        _currentFilter.filterBerdasarkan == 'Minggu Ini') {
      final start =
          _currentFilter.tanggalMulai ??
          DateTime.now().subtract(const Duration(days: 6));
      final end = _currentFilter.tanggalSelesai ?? DateTime.now();
      return DateTimeRange(start: start, end: end);
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (_currentFilter.filterBerdasarkan == 'Harian') {
        return DateTimeRange(start: today, end: today);
      } else if (_currentFilter.filterBerdasarkan == 'Tahunan') {
        final yearEnd = DateTime(_currentFilter.tahun, 12, 31);
        return DateTimeRange(
          start: DateTime(_currentFilter.tahun, 1, 1),
          end: yearEnd.isAfter(today) ? today : yearEnd,
        );
      } else {
        return DateTimeRange(
          start: DateTime(_currentFilter.tahun, _currentFilter.bulan, 1),
          end:
              today.month == _currentFilter.bulan &&
                  today.year == _currentFilter.tahun
              ? today
              : DateTime(_currentFilter.tahun, _currentFilter.bulan + 1, 0),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    final dateRange = _currentDateRange;

    await context.read<LaporanProvider>().fetchExpenseAnalisa(
      widget.token,
      startDate: _formatDate(dateRange.start),
      endDate: _formatDate(dateRange.end),
    );
  }

  void _navigateToDetail(ExpenseAnalisa item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PengeluaranDetailPage(
          tanggal: item.tanggalRaw,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _showCalendarPopup() async {
    final result = await showModalBottomSheet<PengeluaranFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          PengeluaranFilterSheet(initialFilter: _currentFilter),
    );

    if (result != null) {
      setState(() {
        _currentFilter = result;
      });
      _fetchData();
    }
  }

  String get _filterLabel {
    if ((_currentFilter.filterBerdasarkan == 'Custom' ||
            _currentFilter.filterBerdasarkan == 'Minggu Ini') &&
        _currentFilter.tanggalMulai != null) {
      final fmt = DateFormat('dd MMM yyyy', 'id_ID');
      return '${fmt.format(_currentFilter.tanggalMulai!)} s/d ${fmt.format(_currentFilter.tanggalSelesai ?? _currentFilter.tanggalMulai!)}';
    }

    switch (_currentFilter.filterBerdasarkan) {
      case 'Harian':
        return DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());
      case 'Bulanan':
        return DateFormat(
          'MMMM yyyy',
          'id_ID',
        ).format(DateTime(_currentFilter.tahun, _currentFilter.bulan));
      default:
        return 'Custom';
    }
  }

  String get _exportPeriodLabel {
    switch (_currentFilter.filterBerdasarkan) {
      case 'Harian':
        return 'Harian';
      case 'Minggu Ini':
        return 'Minggu Ini';
      case 'Custom':
        return 'Custom';
      case 'Bulanan':
        return DateFormat(
          'MMMM yyyy',
          'id_ID',
        ).format(DateTime(_currentFilter.tahun, _currentFilter.bulan));
      default:
        return _currentFilter.filterBerdasarkan;
    }
  }

  String? _getActiveDateRangeLabel() {
    if (_currentFilter.tanggalMulai == null ||
        _currentFilter.tanggalSelesai == null) {
      return null;
    }
    final s = DateFormat(
      'd MMM yyyy',
      'id_ID',
    ).format(_currentFilter.tanggalMulai!);
    final e = DateFormat(
      'd MMM yyyy',
      'id_ID',
    ).format(_currentFilter.tanggalSelesai!);
    return s == e ? s : '$s s/d $e';
  }

  bool get _hasActiveFilter =>
      _currentFilter.filterBerdasarkan == 'Custom' &&
      _currentFilter.tanggalMulai != null;

  Future<void> _showExportSheet() async {
    final items = context.read<LaporanProvider>().expenseAnalisa;
    if (items.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data pengeluaran untuk diunduh',
        isError: true,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan pengeluaran dengan branding AyoCuci.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf();
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel();
        },
      ),
    );
  }

  ReportPdfDocument _buildExportDocument(
    LaporanProvider provider,
    Uint8List? logoBytes,
    List<ExpenseDetail> detailItems,
  ) {
    final summary = provider.expenseSummary;
    final analisaItems = provider.expenseAnalisa;
    return ReportPdfDocument(
      title: 'Laporan Pengeluaran',
      subtitle:
          'Ringkasan pengeluaran operasional per periode berdasarkan transaksi yang tercatat.',
      periodLabel: _exportPeriodLabel,
      rangeLabel: ReportExportBuilder.formatDateRange(
        _currentDateRange.start,
        _currentDateRange.end,
      ),
      filterLabel: _hasActiveFilter ? 'Periode Kustom' : 'Periode Default',
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(
        summary?.totalExpense ?? 0,
      ),
      primaryCaption: 'Total pengeluaran periode ini',
      metrics: [
        ReportPdfMetric(
          title: 'Total Transaksi',
          value: '${summary?.totalTransaksi ?? 0} transaksi',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Hari Dengan Data',
          value: '${analisaItems.length} hari',
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Detail Pengeluaran Operasional',
          subtitle: 'Rincian seluruh transaksi pengeluaran operasional.',
          headers: const ['Tanggal', 'Nama Pengeluaran', 'Kategori', 'Nominal'],
          rows: detailItems
              .map(
                (item) => [
                  ReportExportBuilder.formatTableDate(item.tanggal),
                  item.nama,
                  item.kategoriNama,
                  ReportExportBuilder.formatRupiah(item.jumlah),
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    final provider = context.read<LaporanProvider>();
    setState(() => _isExporting = true);

    try {
      final dateRange = _currentDateRange;
      final detailItems = await provider.fetchAllExpenseDetails(
        widget.token,
        startDate: _formatDate(dateRange.start),
        endDate: _formatDate(dateRange.end),
      );
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(provider, logoBytes, detailItems);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_pengeluaran_${ReportExportBuilder.formatFileDate(_currentFilter.tanggalMulai ?? DateTime(_currentFilter.tahun, _currentFilter.bulan, 1))}_sd_${ReportExportBuilder.formatFileDate(_currentFilter.tanggalSelesai ?? DateTime(_currentFilter.tahun, _currentFilter.bulan + 1, 0))}.pdf',
        shareTitle: 'Laporan Pengeluaran $_filterLabel',
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

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    final provider = context.read<LaporanProvider>();
    setState(() => _isExporting = true);
    try {
      final dateRange = _currentDateRange;
      final detailItems = await provider.fetchAllExpenseDetails(
        widget.token,
        startDate: _formatDate(dateRange.start),
        endDate: _formatDate(dateRange.end),
      );
      final document = _buildExportDocument(provider, null, detailItems);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_pengeluaran_${ReportExportBuilder.formatFileDate(_currentFilter.tanggalMulai ?? DateTime(_currentFilter.tahun, _currentFilter.bulan, 1))}_sd_${ReportExportBuilder.formatFileDate(_currentFilter.tanggalSelesai ?? DateTime(_currentFilter.tahun, _currentFilter.bulan + 1, 0))}.xlsx',
        shareTitle: 'Laporan Pengeluaran $_filterLabel',
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
    final activeRangeLabel = _getActiveDateRangeLabel();
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_pengeluaran',
    );

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laporan Pengeluaran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,

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
                  icon: Icons.shopping_bag_outlined,
                  title: 'Laporan Pengeluaran Terkunci',
                  message:
                      'Akun ini belum punya izin untuk melihat data pengeluaran.',
                  compact: true,
                ),
              ),
            )
          : Consumer<LaporanProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.expenseAnalisa.isEmpty) {
                  return const AnalisaLaporanSkeleton();
                }
                if (_isAddonLockedMessage(provider.errorMessage)) {
                  return SafeArea(
                    child: AddonLockedPlaceholder(
                      title: 'Laporan pengeluaran belum aktif',
                      message:
                          'Aktifkan add-on untuk melihat biaya operasional dan ringkasan pengeluaran.',
                      features: const [
                        'Biaya operasional',
                        'Ringkasan pengeluaran',
                        'Analisa per kategori',
                      ],
                      onActionTap: () =>
                          Navigator.pushNamed(context, '/aktivasi-akun'),
                    ),
                  );
                }
                if (provider.errorMessage != null &&
                    provider.expenseAnalisa.isEmpty) {
                  return _buildError(provider.errorMessage!);
                }

                final expenseList = provider.expenseAnalisa;
                final summary = provider.expenseSummary;
                final harianList = expenseList
                    .map(PengeluaranHarian.fromExpenseAnalisa)
                    .toList();

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        minHeight: 235,
                        maxHeight: 235,
                        child: (shrinkOffset) => Container(
                          color: kBg,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TotalPengeluaranCard(
                                totalPengeluaran: summary?.totalExpense ?? 0,
                                totalTransaksi: summary?.totalTransaksi ?? 0,
                                dateLabel: activeRangeLabel ?? _filterLabel,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    'Detail Pengeluaran',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _showCalendarPopup,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _hasActiveFilter
                                              ? kPrimary
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
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
                                            color: _hasActiveFilter
                                                ? kPrimary
                                                : Colors.black54,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Filter',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _hasActiveFilter
                                                  ? kPrimary
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (harianList.isEmpty)
                      const SliverFillRemaining(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: EmptyStateWidget.laporan(
                            title: 'Belum ada data pengeluaran',
                            message: 'Belum ada data yang dapat ditampilkan',
                            imageWidth: 170,
                          ),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Builder(
                          builder: (context) {
                            final todayStr = DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now());
                            final bool isTodayMissing = !harianList.any(
                              (item) => item.tanggalRaw == todayStr,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
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
                                            'Belum ada pengeluaran hari ini',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'Data akan muncul secara otomatis setelah transaksi dicatat.',
                                            style: TextStyle(
                                              fontSize: 10,
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = harianList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DetailPengeluaranTile(
                                jumlahPengeluaran: item.jumlahPengeluaran,
                                tanggal: item.tanggal,
                                tanggalRaw: item.tanggalRaw,
                                totalJumlah: item.totalJumlah,
                                onLihatDetail: () => _navigateToDetail(
                                  expenseList[harianList.indexOf(item)],
                                ),
                              ),
                            );
                          }, childCount: harianList.length),
                        ),
                      ),
                      if (provider.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: ReportLoadMoreTileSkeleton(),
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildError(String message) {
    return ReportErrorView(message: message, onRetry: _fetchData);
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double shrinkOffset) child;
  final double minHeight;
  final double maxHeight;

  _StickyHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child(shrinkOffset));

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      maxHeight != old.maxHeight ||
      minHeight != old.minHeight ||
      child != old.child;
}
