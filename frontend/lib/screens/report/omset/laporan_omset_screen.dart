import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/omset_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/omset/omset_detail_page.dart';
import 'package:ayocucinew/screens/report/omset/omset_skeleton.dart';
import 'package:ayocucinew/screens/report/omset/widgets/omset_tile.dart';
import 'package:ayocucinew/screens/report/omset/widgets/total_omset_card.dart';
import 'package:ayocucinew/screens/report/omset/widgets/omset_filter_sheet.dart';
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

class LaporanOmsetScreen extends StatefulWidget {
  final String token;
  const LaporanOmsetScreen({super.key, required this.token});

  @override
  State<LaporanOmsetScreen> createState() => _LaporanOmsetScreenState();
}

class _LaporanOmsetScreenState extends State<LaporanOmsetScreen> {
  static const Color kPrimary = AppPalette.primary;

  late OmsetFilter _activeFilter;
  final ScrollController _scrollController = ScrollController();
  bool _isExporting = false;

  // Laporan Omset TIDAK pernah diproteksi add-on di server (endpoint
  // /finance/report-omset hanya butuh izin read_omset, bukan RequireAddon).
  // Karena itu layar ini tidak boleh menampilkan status "add-on terkunci" —
  // dulu menyebabkan pesan add-on keliru muncul di Laporan Omset.
  bool _isAddonLockedMessage(String? message) => false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _activeFilter = OmsetFilter(
      filterBerdasarkan: 'Minggu Ini',
      bulan: now.month,
      tahun: now.year,
      tanggalMulai: now.subtract(const Duration(days: 6)),
      tanggalSelesai: now,
    );

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        context.read<LaporanProvider>().loadMoreOmsetReport(widget.token);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().canReadReportAction('read_omset')) {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await context.read<LaporanProvider>().fetchOmsetReport(
      widget.token,
      startDate: _activeFilter.startDate,
      endDate: _activeFilter.endDate,
      statusPembayaran: _activeFilter.statusPembayaran,
    );
  }

  Future<void> _onRefresh() => _fetchData();

  double _calcTotalOmset(List items) {
    final header = context.read<LaporanProvider>().omsetHeader;
    return (header['total_omset'] as num?)?.toDouble() ?? 0.0;
  }

  int _calcTotalTransaksi(List items) {
    final header = context.read<LaporanProvider>().omsetHeader;
    return (header['total_transaksi'] as num?)?.toInt() ?? 0;
  }

  Future<void> _showOmsetDetail(dynamic item, String dateLabel) async {
    final String formattedDate = item.tanggal.toString().split('T')[0];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OmsetDetailPage(
          dateLabel: dateLabel,
          date: formattedDate,
          token: widget.token,
          statusPembayaran: _activeFilter.statusPembayaran,
        ),
      ),
    );
  }

  String _parseDateLabel(String tanggal) {
    try {
      final d = tanggal.substring(0, 10);
      final parsed = DateTime(
        int.parse(d.substring(0, 4)),
        int.parse(d.substring(5, 7)),
        int.parse(d.substring(8, 10)),
      );
      return DateFormat('d MMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return tanggal;
    }
  }

  Future<void> _showCalendarPopup() async {
    final result = await showModalBottomSheet<OmsetFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OmsetFilterSheet(initialFilter: _activeFilter),
    );

    if (result != null) {
      setState(() {
        _activeFilter = result;
      });
      _fetchData();
    }
  }

  String? _getActiveDateLabel() {
    if (_activeFilter.tanggalMulai == null ||
        _activeFilter.tanggalSelesai == null) {
      if (_activeFilter.filterBerdasarkan == 'Tahunan') {
        return 'Tahun ${_activeFilter.tahun}';
      }
      return null;
    }
    final s = DateFormat(
      'd MMM yyyy',
      'id_ID',
    ).format(_activeFilter.tanggalMulai!);
    final e = DateFormat(
      'd MMM yyyy',
      'id_ID',
    ).format(_activeFilter.tanggalSelesai!);
    return s == e ? s : '$s s/d $e';
  }

  String get _exportPeriodLabel {
    switch (_activeFilter.filterBerdasarkan) {
      case 'Minggu Ini':
        return 'Minggu Ini';
      case 'Custom':
        return 'Custom';
      case 'Tahunan':
        return 'Tahun ${_activeFilter.tahun}';
      default:
        return DateFormat(
          'MMMM yyyy',
          'id_ID',
        ).format(DateTime(_activeFilter.tahun, _activeFilter.bulan));
    }
  }

  Future<void> _showExportSheet() async {
    final items = context.read<LaporanProvider>().omsetReport;
    if (items.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data penjualan untuk diunduh',
        isError: true,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan penjualan dengan branding AyoCuci.',
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
    List items,
    double totalOmset,
    int totalTransaksi,
    String periodLabel,
    String filterLabel,
    Uint8List? logoBytes,
  ) {
    return ReportPdfDocument(
      title: 'Laporan Penjualan',
      subtitle:
          'Ringkasan penjualan per periode berdasarkan transaksi yang tercatat di aplikasi.',
      periodLabel: periodLabel,
      rangeLabel: ReportExportBuilder.formatDateRange(
        _activeFilter.startDate,
        _activeFilter.endDate,
      ),
      filterLabel: filterLabel,
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(totalOmset),
      primaryCaption: 'Total penjualan periode ini',
      metrics: [
        ReportPdfMetric(
          title: 'Total Transaksi',
          value: '$totalTransaksi transaksi',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Rata-rata Harian',
          value: ReportExportBuilder.formatRupiah(
            items.isEmpty ? 0 : totalOmset / items.length,
          ),
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
        ReportPdfMetric(
          title: 'Filter Pembayaran',
          value: filterLabel,
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Detail Penjualan',
          subtitle:
              'Rekap penjualan harian yang tampil pada layar laporan penjualan.',
          headers: const ['Tanggal', 'Jumlah Transaksi', 'Total Penjualan'],
          rows: items
              .map(
                (item) => [
                  _parseDateLabel(item.tanggal),
                  '${item.jumlahTransaksi}',
                  ReportExportBuilder.formatRupiah(item.totalOmset),
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
      while (provider.hasMoreOmsetReport) {
        await provider.loadMoreOmsetReport(widget.token);
      }
      final items = provider.omsetReport;
      final totalOmset = _calcTotalOmset(items);
      final totalTransaksi = _calcTotalTransaksi(items);
      final logoBytes = await ReportExportService.loadLogoBytes();
      final periodLabel = _exportPeriodLabel;
      final filterLabel =
          _activeFilter.statusPembayaran?.trim().isNotEmpty == true
          ? _activeFilter.statusPembayaran!
          : 'Semua Status';

      final document = _buildExportDocument(
        items,
        totalOmset,
        totalTransaksi,
        periodLabel,
        filterLabel,
        logoBytes,
      );

      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_omset_${ReportExportBuilder.formatFileDate(_activeFilter.startDate)}_sd_${ReportExportBuilder.formatFileDate(_activeFilter.endDate)}.pdf',
        shareTitle: 'Laporan Penjualan $periodLabel',
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
    final periodLabel = _exportPeriodLabel;
    final filterLabel =
        _activeFilter.statusPembayaran?.trim().isNotEmpty == true
        ? _activeFilter.statusPembayaran!
        : 'Semua Status';

    setState(() => _isExporting = true);
    try {
      while (provider.hasMoreOmsetReport) {
        await provider.loadMoreOmsetReport(widget.token);
      }
      final items = provider.omsetReport;
      final totalOmset = _calcTotalOmset(items);
      final totalTransaksi = _calcTotalTransaksi(items);
      final document = _buildExportDocument(
        items,
        totalOmset,
        totalTransaksi,
        periodLabel,
        filterLabel,
        null,
      );
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_omset_${ReportExportBuilder.formatFileDate(_activeFilter.startDate)}_sd_${ReportExportBuilder.formatFileDate(_activeFilter.endDate)}.xlsx',
        shareTitle: 'Laporan Penjualan $periodLabel',
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

  String? get activeDateLabelForExport => _getActiveDateLabel();

  @override
  Widget build(BuildContext context) {
    final activeDateLabel = _getActiveDateLabel();
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_omset',
    );

    return Consumer<LaporanProvider>(
      builder: (context, provider, _) {
        final items = provider.omsetReport;
        if (_isAddonLockedMessage(provider.errorMessage)) {
          return SafeArea(
            child: AddonLockedPlaceholder(
              title: 'Laporan penjualan belum aktif',
              message:
                  'Aktifkan add-on untuk melihat nilai penjualan dan tren pemasukan.',
              features: const [
                'Nilai penjualan',
                'Tren pemasukan',
                'Ringkasan per periode',
              ],
              onActionTap: () => Navigator.pushNamed(context, '/aktivasi-akun'),
            ),
          );
        }

        return AppScaffold(
          backgroundColor: const Color(0xFFFBFBFB),
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
              'Laporan Penjualan',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
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
                      icon: Icons.payments_outlined,
                      title: 'Laporan Penjualan Terkunci',
                      message:
                          'Akun ini belum punya izin untuk melihat data penjualan.',
                      compact: true,
                    ),
                  ),
                )
              : _isAddonLockedMessage(provider.errorMessage)
              ? SafeArea(
                  child: AddonLockedPlaceholder(
                    title: 'Laporan penjualan belum aktif',
                    message:
                        'Aktifkan add-on untuk melihat nilai penjualan dan tren pemasukan.',
                    features: const [
                      'Nilai penjualan',
                      'Tren pemasukan',
                      'Ringkasan per periode',
                    ],
                    onActionTap: () =>
                        Navigator.pushNamed(context, '/aktivasi-akun'),
                  ),
                )
              : RefreshIndicator(
                  color: kPrimary,
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // TotalOmsetCard moved into sticky header
                      SliverPersistentHeader(
                        key: ValueKey(activeDateLabel != null),
                        pinned: true,
                        delegate: _StickyHeaderDelegate(
                          child: (shrinkOffset) => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBFBFB),
                              boxShadow: [
                                if (shrinkOffset > 10)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TotalOmsetCard(
                                  totalOmset: _calcTotalOmset(items),
                                  totalTransaksi: _calcTotalTransaksi(items),
                                  dateLabel:
                                      activeDateLabel ??
                                      (_activeFilter.filterBerdasarkan ==
                                              'Tahunan'
                                          ? 'Tahun ${_activeFilter.tahun}'
                                          : '${['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'][(_activeFilter.bulan - 1).clamp(0, 11)]} ${_activeFilter.tahun}'),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text(
                                      'Detail Penjualan',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (_activeFilter.statusPembayaran !=
                                        null) ...[
                                      const SizedBox(width: 8),
                                      _StatusBadge(
                                        status: _activeFilter.statusPembayaran!,
                                      ),
                                    ],
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: activeDateLabel != null
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
                                              color: activeDateLabel != null
                                                  ? kPrimary
                                                  : Colors.black54,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Filter',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: activeDateLabel != null
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
                          maxHeight: 235,
                          minHeight: 235,
                        ),
                      ),
                      if (provider.isLoading && items.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: OmsetTileSkeleton(),
                              ),
                              childCount: 5,
                            ),
                          ),
                        )
                      else if (provider.errorMessage != null && items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildError(provider.errorMessage!),
                        )
                      else if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmpty(),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) {
                              final todayStr = DateFormat(
                                'yyyy-MM-dd',
                              ).format(DateTime.now());
                              final bool isTodayMissing = !items.any(
                                (item) => item.tanggal == todayStr,
                              );

                              if (!isTodayMissing) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
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
                                          color: kPrimary.withValues(
                                            alpha: 0.1,
                                          ),
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
                                              'Belum ada transaksi hari ini',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              'Data penjualan akan muncul setelah pesanan masuk.',
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = items[index];
                              final dateLabel = _parseDateLabel(item.tanggal);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OmsetTile(
                                  item: item,
                                  onLihatDetail: () =>
                                      _showOmsetDetail(item, dateLabel),
                                ),
                              );
                            }, childCount: items.length),
                          ),
                        ),
                        if (provider.isLoadingMore)
                          const SliverToBoxAdapter(
                            child: ReportLoadMoreTileSkeleton(),
                          ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const EmptyStateWidget.laporan(
      title: 'Belum ada data penjualan',
      message: 'Coba ubah periode atau filter',
    );
  }

  Widget _buildError(String message) {
    return ReportErrorView(message: message, onRetry: _fetchData);
  }
}

// ════════════════════════════════════════════════
// Custom Calendar Popup
// ════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLunas = status.toLowerCase() == 'lunas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isLunas ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLunas ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      ),
      child: Text(
        isLunas ? 'Lunas' : 'Belum Lunas',
        style: TextStyle(
          fontSize: 11,
          color: isLunas ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      ),
    );
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
  ) {
    return SizedBox.expand(child: child(shrinkOffset));
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
