import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/piutang/laporan_piutang_skeleton.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/screens/report/piutang/widgets/piutang_filter_sheet.dart';
import 'package:ayocucinew/screens/status/detail/constants/app_colors.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'widgets/piutang_summary_card.dart';
import 'widgets/piutang_search_bar.dart';
import 'widgets/piutang_tab_bar.dart';
import 'widgets/piutang_tile.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LaporanPiutangScreen extends StatefulWidget {
  final String token;

  const LaporanPiutangScreen({super.key, required this.token});

  @override
  State<LaporanPiutangScreen> createState() => _LaporanPiutangScreenState();
}

class _LaporanPiutangScreenState extends State<LaporanPiutangScreen> {
  static const Color kPrimary = AppColors.primary;
  static const Color kBg = AppColors.background;

  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  final DateTime _endDate = DateTime.now();
  PiutangTab _activeTab = PiutangTab.jatuhTempo;
  late PiutangFilter _activeFilter = PiutangFilter(
    filterBerdasarkan: 'Minggu Ini',
    tanggalMulai: DateTime.now().subtract(const Duration(days: 6)),
    tanggalSelesai: DateTime.now(),
  );
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isExporting = false;
  bool _lastCanAccessAddon = false;
  bool _isSwitchingTab = false;
  final Map<PiutangTab, List<PiutangReport>> _tabCache = {};

  bool _isAddonLockedMessage(String? message) {
    final normalized = (message ?? '').toLowerCase();
    return normalized.contains('memerlukan add-on aktif') ||
        normalized.contains('fitur ini memerlukan add-on aktif') ||
        normalized.contains('silakan lakukan aktivasi terlebih dahulu');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 240) {
        context.read<LaporanProvider>().loadMorePiutang();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canRead = context.read<AuthProvider>().canReadReportAction(
      'read_debt',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_DEBT',
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _toDateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _fetchData({bool switchingTab = false}) async {
    final provider = context.read<LaporanProvider>();

    final startDate = _activeFilter.tanggalMulai != null
        ? _toDateStr(_activeFilter.tanggalMulai!)
        : _toDateStr(_startDate);
    final endDate = _activeFilter.tanggalSelesai != null
        ? _toDateStr(_activeFilter.tanggalSelesai!)
        : _toDateStr(_endDate);

    await provider.fetchPiutangReport(
      widget.token,
      startDate: startDate,
      endDate: endDate,
      search:
          _activeFilter.namaPelanggan ??
          (_searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim()),
      status: _activeTab == PiutangTab.jatuhTempo
          ? 'jatuh_tempo'
          : 'belum_jatuh_tempo',
      showInitialLoading: !switchingTab,
    );

    if (!mounted) return;
    if (provider.errorMessage == null) {
      _tabCache[_activeTab] = List<PiutangReport>.from(provider.piutangReport);
    }
    if (switchingTab) {
      setState(() => _isSwitchingTab = false);
    }
  }

  Future<void> _changeTab(PiutangTab tab) async {
    if (tab == _activeTab || _isSwitchingTab) return;
    setState(() {
      _activeTab = tab;
      _isSwitchingTab = true;
    });
    await _fetchData(switchingTab: true);
  }

  bool _isJatuhTempo(PiutangReport e) => e.isJatuhTempo;

  double _totalJatuhTempo(List<PiutangReport> items) =>
      items.where(_isJatuhTempo).fold(0.0, (s, e) => s + e.sisaPiutang);

  double _totalBelumJatuhTempo(List<PiutangReport> items) => items
      .where((e) => !_isJatuhTempo(e))
      .fold(0.0, (s, e) => s + e.sisaPiutang);

  // ✅ FIX 1: Hitung pelanggan UNIK, bukan jumlah transaksi
  int _jumlahJatuhTempo(List<PiutangReport> items) => items
      .where(_isJatuhTempo)
      .map((e) => e.namaPelanggan.trim())
      .toSet()
      .length;

  int _jumlahBelumJatuhTempo(List<PiutangReport> items) => items
      .where((e) => !_isJatuhTempo(e))
      .map((e) => e.namaPelanggan.trim())
      .toSet()
      .length;

  List<PiutangReport> _filteredItems(List<PiutangReport> items) {
    return items.where((item) {
      final matchTab = _activeTab == PiutangTab.jatuhTempo
          ? _isJatuhTempo(item)
          : !_isJatuhTempo(item);
      final matchPelanggan =
          _activeFilter.namaPelanggan == null ||
          item.namaPelanggan.trim() == _activeFilter.namaPelanggan;
      final hasSisa = item.sisaPiutang > 0;
      return matchTab && matchPelanggan && hasSisa;
    }).toList();
  }

  // ✅ FIX 2: Method khusus untuk summary card (tidak filter by tab)
  List<PiutangReport> _filteredForSummary(List<PiutangReport> items) {
    return items.where((item) {
      final matchPelanggan =
          _activeFilter.namaPelanggan == null ||
          item.namaPelanggan.trim() == _activeFilter.namaPelanggan;
      final hasSisa = item.sisaPiutang > 0;
      return matchPelanggan && hasSisa;
    }).toList();
  }

  List<String> _pelangganList(List<PiutangReport> items) =>
      items.map((e) => e.namaPelanggan.trim()).toSet().toList();

  bool get _hasActiveFilter =>
      _activeFilter.namaPelanggan != null ||
      _activeFilter.tanggalMulai != null ||
      _activeFilter.tanggalSelesai != null;

  void _openFilterPage(List<PiutangReport> allItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PiutangFilterSheet(
        initialFilter: _activeFilter,
        pelangganList: _pelangganList(allItems),
        onApply: (filter) {
          setState(() {
            _activeFilter = filter;
            _tabCache.clear();
          });
          _fetchData();
        },
      ),
    );
  }

  Future<void> _showExportSheet(List<PiutangReport> items) async {
    if (items.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data piutang untuk diunduh',
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
            'Download laporan piutang pelanggan dengan branding AyoCuci.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf(items);
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel(items);
        },
      ),
    );
  }

  Future<List<PiutangReport>> _allVisiblePiutangForExport() async {
    final provider = context.read<LaporanProvider>();
    while (provider.hasMorePiutang) {
      await provider.loadMorePiutang();
    }
    return _filteredItems(provider.piutangReport);
  }

  ReportPdfDocument _buildExportDocument(
    List<PiutangReport> items,
    Uint8List? logoBytes,
  ) {
    final totalPiutang = items.fold<double>(
      0,
      (sum, item) => sum + item.sisaPiutang,
    );

    ReportPdfTable buildTable(List<PiutangReport> rows) {
      return ReportPdfTable(
        title: 'Detail Piutang Pelanggan',
        subtitle: 'Status piutang pelanggan pada periode aktif.',
        headers: const [
          'Pelanggan',
          'Nota',
          'Piutang',
          'Masuk',
          'Estimasi',
          'Sisa Piutang',
        ],
        rows: rows
            .map(
              (item) => [
                ReportExportBuilder.sanitizeText(
                  item.namaPelanggan,
                  fallback: 'Tanpa Nama',
                ),
                item.nomorNota,
                _isJatuhTempo(item) ? 'Tempo' : 'Aktif',
                ReportExportBuilder.formatTableDate(item.tanggalMasuk),
                ReportExportBuilder.formatTableDate(item.tanggalEstimasi),
                ReportExportBuilder.formatRupiah(item.sisaPiutang),
              ],
            )
            .toList(),
      );
    }

    return ReportPdfDocument(
      title: 'Laporan Piutang Pelanggan',
      subtitle:
          'Ringkasan sisa tagihan pelanggan berdasarkan periode, mencakup piutang jatuh tempo dan belum jatuh tempo.',
      periodLabel: _activeFilter.filterBerdasarkan,
      rangeLabel: ReportExportBuilder.formatDateRange(
        _activeFilter.tanggalMulai ?? _startDate,
        _activeFilter.tanggalSelesai ?? _endDate,
      ),
      filterLabel: _activeFilter.namaPelanggan ?? 'Semua Status Piutang',
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(totalPiutang),
      primaryCaption: 'Total sisa piutang semua status',
      metrics: [
        ReportPdfMetric(
          title: 'Jumlah Pelanggan',
          value:
              '${items.map((e) => e.namaPelanggan.trim()).toSet().length} pelanggan',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Jumlah Transaksi',
          value: '${items.length} transaksi',
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
        ReportPdfMetric(
          title: 'Jatuh Tempo',
          value: ReportExportBuilder.formatRupiah(_totalJatuhTempo(items)),
          background: PdfColor.fromHex('#FFF7ED'),
          accent: PdfColor.fromHex('#F97316'),
        ),
        ReportPdfMetric(
          title: 'Belum Jatuh Tempo',
          value: ReportExportBuilder.formatRupiah(_totalBelumJatuhTempo(items)),
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
      ],
      tables: [buildTable(items)],
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf(List<PiutangReport> items) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      items = await _allVisiblePiutangForExport();
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(items, logoBytes);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_piutang_${ReportExportBuilder.formatFileDate(_activeFilter.tanggalMulai ?? _startDate)}_sd_${ReportExportBuilder.formatFileDate(_activeFilter.tanggalSelesai ?? _endDate)}.pdf',
        shareTitle: 'Laporan Piutang Pelanggan',
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

  Future<void> _exportExcel(List<PiutangReport> items) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      items = await _allVisiblePiutangForExport();
      final document = _buildExportDocument(items, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_piutang_${ReportExportBuilder.formatFileDate(_activeFilter.tanggalMulai ?? _startDate)}_sd_${ReportExportBuilder.formatFileDate(_activeFilter.tanggalSelesai ?? _endDate)}.xlsx',
        shareTitle: 'Laporan Piutang Pelanggan',
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
      'read_debt',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_DEBT',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
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
          'Laporan Piutang Pelanggan',
          style: TextStyle(color: Colors.black87, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          Consumer<LaporanProvider>(
            builder: (context, provider, _) {
              final items = _filteredForSummary(provider.piutangReport);
              return IconButton(
                onPressed: _isExporting ? null : () => _showExportSheet(items),
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
                  title: 'Laporan Piutang Terkunci',
                  message:
                      'Akun ini belum punya izin untuk melihat data piutang pelanggan.',
                  compact: true,
                ),
              ),
            )
          : !canAccessAddonFeature
          ? SafeArea(
              child: AddonLockedPlaceholder(
                title: 'Laporan piutang belum aktif',
                message:
                    'Aktifkan add-on untuk melihat piutang pelanggan dalam satu layar.',
                features: const [
                  'Tagihan aktif',
                  'Saldo outstanding',
                  'Status pembayaran',
                ],
                onActionTap: _openAddonActivation,
              ),
            )
          : Consumer<LaporanProvider>(
              builder: (context, provider, _) {
                if (_isAddonLockedMessage(provider.errorMessage)) {
                  return SafeArea(
                    child: AddonLockedPlaceholder(
                      title: 'Laporan piutang belum aktif',
                      message:
                          'Aktifkan add-on untuk melihat piutang pelanggan dalam satu layar.',
                      features: const [
                        'Tagihan aktif',
                        'Saldo outstanding',
                        'Status pembayaran',
                      ],
                      onActionTap: _openAddonActivation,
                    ),
                  );
                }
                final allItems = _isSwitchingTab
                    ? (_tabCache[_activeTab] ?? const <PiutangReport>[])
                    : provider.piutangReport;
                final summary = provider.piutangSummary;

                final summaryItems = _filteredForSummary(allItems);
                final items = _filteredItems(allItems);

                if (provider.isLoading) {
                  return const LaporanPiutangSkeleton();
                }

                if (provider.errorMessage != null) {
                  return _buildError(provider.errorMessage!);
                }

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        minHeight: _hasActiveFilter ? 340 : 305,
                        maxHeight: _hasActiveFilter ? 340 : 305,
                        child: (shrinkOffset) => Container(
                          color: kBg,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            children: [
                              PiutangSummaryCard(
                                jatuhTempo:
                                    summary?.totalJatuhTempo ??
                                    _totalJatuhTempo(summaryItems),
                                jumlahPelangganJatuhTempo:
                                    summary?.countJatuhTempo ??
                                    _jumlahJatuhTempo(summaryItems),
                                belumJatuhTempo:
                                    summary?.totalBelumJatuhTempo ??
                                    _totalBelumJatuhTempo(summaryItems),
                                jumlahPelangganBelumJatuhTempo:
                                    summary?.countBelumJatuhTempo ??
                                    _jumlahBelumJatuhTempo(summaryItems),
                              ),

                              if (_hasActiveFilter) ...[
                                const SizedBox(height: 8),
                                _buildActiveFilterInfo(),
                              ],

                              const SizedBox(height: 12),

                              PiutangSearchBar(
                                controller: _searchController,
                                onChanged: (v) {
                                  setState(() {
                                    _tabCache.clear();
                                  });
                                  Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () {
                                      if (_searchController.text == v) {
                                        _fetchData();
                                      }
                                    },
                                  );
                                },
                                onFilterTap: () => _openFilterPage(allItems),
                                hasActiveFilter: _hasActiveFilter,
                              ),

                              const SizedBox(height: 12),

                              PiutangTabBar(
                                activeTab: _activeTab,
                                onTabChanged: _changeTab,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Detail Piutang Pelanggan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${_activeTab == PiutangTab.jatuhTempo ? (summary?.countJatuhTempo ?? items.length) : (summary?.countBelumJatuhTempo ?? items.length)} pelanggan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
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

                    if (_isSwitchingTab && items.isEmpty)
                      const ReportTransactionSliverSkeleton(
                        itemCount: 3,
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 42),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 42),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            if (items.isEmpty) {
                              return _buildEmpty();
                            }

                            final item = items[index];
                            return PiutangTile(item: item);
                          }, childCount: items.isEmpty ? 1 : items.length),
                        ),
                      ),
                    if (provider.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: ReportLoadMoreTileSkeleton(),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildActiveFilterInfo() {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final mulai = _activeFilter.tanggalMulai;
    final selesai = _activeFilter.tanggalSelesai;
    final pelanggan = _activeFilter.namaPelanggan;

    String label = '';
    if (mulai != null && selesai != null) {
      label = '${fmt.format(mulai)} s/d ${fmt.format(selesai)}';
    } else if (pelanggan != null) {
      label = 'Filter: $pelanggan';
    } else {
      label = 'Filter Aktif';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 14, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: kPrimary),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(
                () => _activeFilter = PiutangFilter(
                  tanggalMulai: DateTime.now().subtract(
                    const Duration(days: 6),
                  ),
                  tanggalSelesai: DateTime.now(),
                ),
              );
              _fetchData();
            },
            child: const Icon(Icons.close_rounded, size: 14, color: kPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: EmptyStateWidget.laporan(
        title: 'Tidak ada data piutang',
        message: 'Coba ubah tanggal atau filter',
        imageWidth: 170,
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
      old.minHeight != minHeight ||
      old.maxHeight != maxHeight ||
      old.child != child;
}
