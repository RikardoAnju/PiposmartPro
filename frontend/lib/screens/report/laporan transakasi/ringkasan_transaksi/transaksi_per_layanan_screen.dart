import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/widgets/filter_transaksi_page.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/ringkasan_transaksi/transaksi_per_layanan_skeleton.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'dart:typed_data';
import 'widgets/layanan_summary_header.dart';
import 'widgets/layanan_table_header.dart';
import 'widgets/layanan_table_row.dart';
import 'widgets/layanan_insight_card.dart';
import 'widgets/layanan_empty_state.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransaksiPerLayananScreen extends StatefulWidget {
  const TransaksiPerLayananScreen({super.key});

  @override
  State<TransaksiPerLayananScreen> createState() =>
      _TransaksiPerLayananScreenState();
}

class _TransaksiPerLayananScreenState extends State<TransaksiPerLayananScreen> {
  TransaksiFilter _filter = TransaksiFilter(
    filterBerdasarkan: 'Minggu Ini',
    startDate: DateTime.now().subtract(const Duration(days: 6)),
    endDate: DateTime.now(),
  );
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isExporting = false;
  bool _lastCanAccessAddon = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 6));
    _endDate = DateTime.now();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 240) {
        context.read<LaporanProvider>().loadMoreTransaksiPerLayanan();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canRead = context.read<AuthProvider>().canReadReportAction(
      'read_service_summary',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_SERVICE_SUMMARY',
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

  Future<void> _fetchData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    final fmt = DateFormat('yyyy-MM-dd');

    await context.read<LaporanProvider>().fetchTransaksiPerLayanan(
      token,
      startDate: fmt.format(_startDate),
      endDate: fmt.format(_endDate),
    );
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TransaksiFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayananPeriodFilterSheet(initialFilter: _filter),
    );

    if (result != null) {
      setState(() => _filter = result);
      await _applyFilter(result);
    }
  }

  Future<void> _applyFilter(TransaksiFilter filter) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    final fmt = DateFormat('yyyy-MM-dd');
    DateTime start;
    DateTime end;

    if (filter.filterBerdasarkan == 'Custom' &&
        filter.startDate != null &&
        filter.endDate != null) {
      start = filter.startDate!;
      end = filter.endDate!;
    } else if (filter.filterBerdasarkan == 'Tahunan') {
      final tahun = filter.tahun ?? DateTime.now().year;
      start = DateTime(tahun, 1, 1);
      end = DateTime(tahun, 12, 31);
    } else if (filter.filterBerdasarkan == 'Minggu Ini') {
      start = DateTime.now().subtract(const Duration(days: 6));
      end = DateTime.now();
    } else {
      final bulan = filter.bulan ?? DateTime.now().month;
      final tahun = filter.tahun ?? DateTime.now().year;
      start = DateTime(tahun, bulan, 1);
      end = DateTime(tahun, bulan + 1, 0);
    }

    setState(() {
      _startDate = start;
      _endDate = end;
    });

    await context.read<LaporanProvider>().fetchTransaksiPerLayanan(
      token,
      startDate: fmt.format(start),
      endDate: fmt.format(end),
    );
  }

  String get _dateLabel {
    final fmt = DateFormat('MMM yyyy', 'id_ID');

    if (_startDate.month == _endDate.month &&
        _startDate.year == _endDate.year) {
      return fmt.format(_startDate);
    }

    return '${DateFormat('d MMM', 'id_ID').format(_startDate)} s/d '
        '${DateFormat('d MMM yyyy', 'id_ID').format(_endDate)}';
  }

  String get _exportPeriodLabel {
    switch (_filter.filterBerdasarkan) {
      case 'Minggu Ini':
        return 'Minggu Ini';
      case 'Custom':
        return 'Custom';
      case 'Tahunan':
        return 'Tahun ${_startDate.year}';
      default:
        return DateFormat('MMMM yyyy', 'id_ID').format(_startDate);
    }
  }

  Map<String, double> _calculateTotalQuantity(
    List<TransaksiLayananItem> items,
  ) {
    double totalKg = 0;
    double totalPcs = 0;
    double totalM = 0;
    double totalKoin = 0;

    for (final item in items) {
      final rawQty = item.totalQty.trim().toLowerCase();

      final match = RegExp(
        r'([\d.,]+)\s*([a-z]+)',
        caseSensitive: false,
      ).firstMatch(rawQty);
      if (match == null) continue;

      final valueText = match.group(1)?.replaceAll(',', '.') ?? '0';
      final unit = (match.group(2) ?? '').trim();
      final value = double.tryParse(valueText) ?? 0.0;

      if (unit.contains('kg')) {
        totalKg += value;
      } else if (unit.contains('pc')) {
        totalPcs += value;
      } else if (unit.contains('koin')) {
        totalKoin += value;
      } else if (unit.contains('m') && !unit.contains('km')) {
        totalM += value;
      }
    }

    return {
      'kg': double.parse(totalKg.toStringAsFixed(2)),
      'pcs': double.parse(totalPcs.toStringAsFixed(0)),
      'm': double.parse(totalM.toStringAsFixed(2)),
      'koin': double.parse(totalKoin.toStringAsFixed(0)),
    };
  }

  TransaksiPerLayananHeader _buildHeader(
    LaporanProvider provider,
    List<TransaksiLayananItem> items,
  ) {
    final providerHeader = provider.transaksiPerLayananHeader;

    if (providerHeader != null) return providerHeader;

    final totalQty = _calculateTotalQuantity(items);

    return TransaksiPerLayananHeader(
      totalLayanan: items.length,
      totalPesanan: items.fold(0, (sum, e) => sum + e.totalPesanan),
      totalHarga: items.fold(0.0, (sum, e) => sum + e.totalHarga),
      totalQuantity: totalQty,
    );
  }

  List<TransaksiLayananItem> _buildRankedItems(
    List<TransaksiLayananItem> items,
  ) {
    final ranked = List<TransaksiLayananItem>.from(items);
    ranked.sort((a, b) {
      final compareRevenue = b.totalHarga.compareTo(a.totalHarga);
      if (compareRevenue != 0) return compareRevenue;
      return b.totalPesanan.compareTo(a.totalPesanan);
    });
    return ranked;
  }

  String _buildInsightText(
    List<TransaksiLayananItem> items,
    TransaksiPerLayananHeader header,
  ) {
    if (items.isEmpty) {
      return 'Belum ada transaksi layanan pada periode ini.';
    }

    final topRevenue = items.first;
    final topOrder = items.reduce(
      (a, b) => a.totalPesanan >= b.totalPesanan ? a : b,
    );
    final contribution = header.totalHarga > 0
        ? (topRevenue.totalHarga / header.totalHarga) * 100
        : 0;

    if (topRevenue.namaLayanan == topOrder.namaLayanan) {
      return 'Layanan ${topRevenue.namaLayanan} menjadi kontributor utama dengan ${topOrder.totalPesanan} pesanan '
          'dan sekitar ${contribution.toStringAsFixed(0)}% dari total penjualan periode ini.';
    }

    return 'Penjualan terbesar datang dari ${topRevenue.namaLayanan}, sementara volume pesanan tertinggi ada pada '
        '${topOrder.namaLayanan}. Ini menandakan layanan populer dan layanan bernilai tinggi belum tentu sama.';
  }

  Future<void> _showExportSheet(
    List<TransaksiLayananItem> items,
    TransaksiPerLayananHeader header,
  ) async {
    if (items.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada data layanan untuk diunduh',
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
            'Download laporan transaksi per layanan dengan branding AyoCuci.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf(items, header);
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel(items, header);
        },
      ),
    );
  }

  ReportPdfDocument _buildExportDocument(
    List<TransaksiLayananItem> items,
    TransaksiPerLayananHeader header,
    Uint8List? logoBytes,
  ) {
    return ReportPdfDocument(
      title: 'Transaksi Per Layanan',
      subtitle:
          'Analisa performa layanan berdasarkan jumlah pesanan, kuantitas, dan kontribusi penjualan.',
      periodLabel: _exportPeriodLabel,
      rangeLabel: ReportExportBuilder.formatDateRange(_startDate, _endDate),
      filterLabel: _filter.filterBerdasarkan,
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(header.totalHarga),
      primaryCaption: 'Total penjualan layanan periode ini',
      metrics: [
        ReportPdfMetric(
          title: 'Total Layanan',
          value: '${header.totalLayanan} layanan',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Total Pesanan',
          value: '${header.totalPesanan} pesanan',
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
        ReportPdfMetric(
          title: 'Total Quantity',
          value: header.totalQuantityText,
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Tabel Layanan',
          subtitle: 'Urut dari kontribusi penjualan terbesar.',
          headers: const ['Layanan', 'Kategori', 'Pesanan', 'Qty', 'Harga'],
          rows: items
              .map(
                (item) => [
                  item.namaLayanan,
                  item.subLabel,
                  '${item.totalPesanan}',
                  item.totalQty,
                  ReportExportBuilder.formatRupiah(item.totalHarga),
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf(
    List<TransaksiLayananItem> items,
    TransaksiPerLayananHeader header,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final provider = context.read<LaporanProvider>();
      while (provider.hasMoreTransaksiPerLayanan) {
        await provider.loadMoreTransaksiPerLayanan();
      }
      final exportItems = _buildRankedItems(provider.transaksiPerLayanan);
      final exportHeader = _buildHeader(provider, exportItems);
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(
        exportItems,
        exportHeader,
        logoBytes,
      );
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'transaksi_per_layanan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.pdf',
        shareTitle: 'Transaksi Per Layanan $_dateLabel',
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
    List<TransaksiLayananItem> items,
    TransaksiPerLayananHeader header,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final provider = context.read<LaporanProvider>();
      while (provider.hasMoreTransaksiPerLayanan) {
        await provider.loadMoreTransaksiPerLayanan();
      }
      final exportItems = _buildRankedItems(provider.transaksiPerLayanan);
      final exportHeader = _buildHeader(provider, exportItems);
      final document = _buildExportDocument(exportItems, exportHeader, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'transaksi_per_layanan_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}.xlsx',
        shareTitle: 'Transaksi Per Layanan $_dateLabel',
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
      'read_service_summary',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_SERVICE_SUMMARY',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );
    return Consumer<LaporanProvider>(
      builder: (context, provider, _) {
        final rankedItems = _buildRankedItems(provider.transaksiPerLayanan);
        final header = _buildHeader(provider, rankedItems);

        return AppScaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(),
          body: !canRead
              ? const SafeArea(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: 12),
                    child: ReportAccessPlaceholder(
                      icon: Icons.category_outlined,
                      title: 'Transaksi Per Layanan Terkunci',
                      message:
                          'Akun ini belum punya izin untuk melihat ringkasan transaksi per layanan.',
                      compact: true,
                    ),
                  ),
                )
              : !canAccessAddonFeature
              ? SafeArea(
                  child: AddonLockedPlaceholder(
                    title: 'Ringkasan per layanan belum aktif',
                    message:
                        'Aktifkan add-on untuk melihat ringkasan transaksi per layanan.',
                    features: const [
                      'Ranking layanan',
                      'Jumlah transaksi',
                      'Nilai penjualan per layanan',
                    ],
                    onActionTap: _openAddonActivation,
                  ),
                )
              : _buildBody(provider, header, rankedItems),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Transaksi Per Layanan',
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: AppFont.w800,
          fontSize: 17,
        ),
      ),
      actions: [
        Consumer<LaporanProvider>(
          builder: (context, provider, _) {
            final items = _buildRankedItems(provider.transaksiPerLayanan);
            final header = _buildHeader(provider, items);

            return IconButton(
              onPressed: _isExporting
                  ? null
                  : () => _showExportSheet(items, header),
              icon: _isExporting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: ReportExportIconSkeleton(),
                    )
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
    );
  }

  Widget _buildBody(
    LaporanProvider provider,
    TransaksiPerLayananHeader header,
    List<TransaksiLayananItem> items,
  ) {
    if (provider.isLoading) {
      return const TransaksiPerLayananSkeleton();
    }
    if (provider.errorMessage != null) {
      return _ErrorState(message: provider.errorMessage!, onRetry: _fetchData);
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayananSummaryHeader(
              header: header,
              dateLabel: _dateLabel,
              filterLabel: _filter.filterBerdasarkan,
              isCustomPeriod: _filter.filterBerdasarkan != 'Bulanan',
              onPeriodTap: _openFilter,
            ),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const LayananEmptyState()
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tabel Layanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w900,
                            color: Color(0xFF211816),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Urut dari kontribusi penjualan terbesar.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8D807A),
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${header.totalLayanan} layanan',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: AppFont.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const LayananTableHeader(),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, i) =>
                          LayananTableRow(item: items[i], isEven: i.isEven),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayananInsightCard(insightText: _buildInsightText(items, header)),
              if (provider.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ReportLoadMoreTileSkeleton(),
                      ReportLoadMoreTileSkeleton(),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ReportErrorView(message: message, onRetry: onRetry);
  }
}

class _LayananPeriodFilterSheet extends StatefulWidget {
  final TransaksiFilter initialFilter;

  const _LayananPeriodFilterSheet({required this.initialFilter});

  @override
  State<_LayananPeriodFilterSheet> createState() =>
      _LayananPeriodFilterSheetState();
}

class _LayananPeriodFilterSheetState extends State<_LayananPeriodFilterSheet> {
  static const Color kPrimary = AppPalette.primary;

  late String _filterBerdasarkan;
  int? _bulan;
  int? _tahun;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _filterOptions = const [
    'Minggu Ini',
    'Bulanan',
    'Tahunan',
    'Custom',
  ];
  final List<String> _bulanNames = const [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  List<int> get _yearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(3, (index) => currentYear - index);
  }

  int _safeYear(int? year) {
    final years = _yearOptions;
    return years.contains(year) ? year! : years.first;
  }

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  @override
  void initState() {
    super.initState();
    _filterBerdasarkan = widget.initialFilter.filterBerdasarkan;
    _bulan = widget.initialFilter.bulan ?? DateTime.now().month;
    _tahun = _safeYear(widget.initialFilter.tahun);
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
  }

  bool get _canApply =>
      _filterBerdasarkan != 'Custom' ||
      (_startDate != null && _endDate != null);

  void _reset() {
    setState(() {
      _filterBerdasarkan = 'Bulanan';
      _bulan = DateTime.now().month;
      _tahun = _safeYear(null);
      _startDate = null;
      _endDate = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      TransaksiFilter(
        filterBerdasarkan: _filterBerdasarkan,
        bulan: _bulan,
        tahun: _tahun,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(
        isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
        isStart ? firstDate : (_startDate ?? firstDate),
        now,
      ),
      firstDate: isStart ? firstDate : (_startDate ?? firstDate),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D7D1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Periode',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: AppFont.w900,
                              color: Color(0xFF221816),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Atur rentang waktu untuk analisa layanan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D807A),
                              fontWeight: AppFont.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: kPrimary,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildModeSelector(),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _filterBerdasarkan == 'Bulanan'
                      ? _buildBulananPicker()
                      : _filterBerdasarkan == 'Tahunan'
                      ? _buildTahunanPicker()
                      : _buildCustomPicker(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canApply ? _apply : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      disabledBackgroundColor: const Color(0xFFF2D2CA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _filterBerdasarkan == 'Custom' && !_canApply
                          ? 'Lengkapi rentang tanggal'
                          : 'Terapkan Periode',
                      style: const TextStyle(fontWeight: AppFont.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final activeIndex = _filterOptions
        .indexOf(_filterBerdasarkan)
        .clamp(0, _filterOptions.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / _filterOptions.length;

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
                children: _filterOptions.map((option) {
                  final isActive = _filterBerdasarkan == option;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _filterBerdasarkan = option),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.w800,
                            color: isActive
                                ? kPrimary
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
            onChanged: (val) => setState(() => _bulan = val),
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
            onChanged: (val) => setState(() => _tahun = val),
          ),
        ),
      ],
    );
  }

  Widget _buildTahunanPicker() {
    return _buildDropdown<int>(
      value: _tahun,
      hint: 'Tahun',
      items: _yearOptions
          .map(
            (year) =>
                DropdownMenuItem(value: year, child: Text(year.toString())),
          )
          .toList(),
      onChanged: (val) => setState(() => _tahun = val),
    );
  }

  Widget _buildCustomPicker() {
    return Row(
      children: [
        Expanded(
          child: _DateTile(
            label: 'Tanggal Mulai',
            value: _startDate,
            onTap: () => _pickDate(isStart: true),
            onClear: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateTile(
            label: 'Tanggal Selesai',
            value: _endDate,
            onTap: () => _pickDate(isStart: false),
            onClear: null,
          ),
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
          borderSide: const BorderSide(color: kPrimary),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
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
              color: AppPalette.primary,
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
                      fontWeight: AppFont.w700,
                      color: Color(0xFF8A7D77),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: AppFont.w800,
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
