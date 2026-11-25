import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/screens/report/laba&rugi/filter_laporan_labarugi.dart';
import 'package:ayocucinew/screens/report/laba&rugi/laporan_laba_rugi_skeleton.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:ayocucinew/screens/report/pendapatan/laporan_pendapatan_detail_screen.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/core/utils/payment_name_helper.dart';
import 'package:ayocucinew/core/utils/payment_colors.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'widgets/laba_rugi_card.dart';
import 'widgets/laporan_tab_bar.dart';
import 'widgets/transaksi_tile.dart';
import 'widgets/metode_pembayaran_tile.dart';
import 'widgets/pengeluaran_kategori_tile.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LaporanLabaRugiScreen extends StatefulWidget {
  final String token;

  const LaporanLabaRugiScreen({super.key, required this.token});

  @override
  State<LaporanLabaRugiScreen> createState() => _LaporanLabaRugiScreenState();
}

class _LaporanLabaRugiScreenState extends State<LaporanLabaRugiScreen> {
  static const Color _kPrimary = AppPalette.danger;
  static const Color _kBg = Color(0xFFF5F5F5);

  int _selectedTab = 0;

  late DateTime _startDate;
  late DateTime _endDate;

  LaporanRugiFilter _filter = const LaporanRugiFilter();
  bool _isExporting = false;
  bool _lastCanAccessAddon = false;

  bool _isAddonLockedMessage(String? message) {
    final normalized = (message ?? '').toLowerCase();
    return normalized.contains('memerlukan add-on aktif') ||
        normalized.contains('fitur ini memerlukan add-on aktif') ||
        normalized.contains('silakan lakukan aktivasi terlebih dahulu');
  }

  String _fmt(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  String _resolveCategory(String nama) {
    final lower = nama.toLowerCase();

    if (lower.contains('cash')) return 'Cash';
    if (lower.contains('qris')) return 'QRIS';

    if (lower.contains('transfer') ||
        lower.contains('bank') ||
        lower.contains('bca') ||
        lower.contains('bni') ||
        lower.contains('bri') ||
        lower.contains('mandiri') ||
        lower.contains('bsi') ||
        lower.contains('cimb')) {
      return 'Transfer';
    }

    if (lower.contains('wallet') ||
        lower.contains('gopay') ||
        lower.contains('ovo') ||
        lower.contains('dana') ||
        lower.contains('shopee') ||
        lower.contains('linkaja')) {
      return 'E-Wallet';
    }

    return 'Cash';
  }

  @override
  void initState() {
    super.initState();

    _startDate = DateTime.now().subtract(const Duration(days: 6));
    _endDate = DateTime.now();

    _filter = LaporanRugiFilter(
      filterBerdasarkan: 'Minggu Ini',
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canRead = context.read<AuthProvider>().canReadReportAction(
      'read_profit_loss',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_PROFIT_LOSS',
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
    final provider = context.read<LaporanProvider>();
    await provider.fetchAllLabaRugiData(
      widget.token,
      startDate: _fmt(_startDate),
      endDate: _fmt(_endDate),
    );
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<LaporanRugiFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabaRugiFilterSheet(initialFilter: _filter),
    );

    if (result != null) {
      _onFilterApply(result);
    }
  }

  void _onFilterApply(LaporanRugiFilter result) {
    final now = DateTime.now();
    final tahun = result.tahun ?? now.year;
    final bulan = result.bulan ?? now.month;

    late DateTime start;
    late DateTime end;

    if (result.filterBerdasarkan == 'Custom') {
      start = result.startDate ?? DateTime(tahun, bulan, 1);
      end = result.endDate ?? DateTime(tahun, bulan + 1, 0);
    } else if (result.filterBerdasarkan == 'Tahunan') {
      start = DateTime(tahun, 1, 1);
      end = DateTime(tahun, 12, 31);
    } else if (result.filterBerdasarkan == 'Minggu Ini') {
      start = result.startDate ?? now.subtract(const Duration(days: 6));
      end = result.endDate ?? now;
    } else {
      start = DateTime(tahun, bulan, 1);
      end = DateTime(tahun, bulan + 1, 0);
    }

    setState(() {
      _filter = result;
      _startDate = start;
      _endDate = end;
    });

    _fetchData();
  }

  Widget _buildTabContent(LaporanProvider provider) {
    switch (_selectedTab) {
      case 0:
        return _buildDetailPendapatan(provider);
      case 1:
        return _buildMetodePembayaran(provider);
      case 2:
        return _buildDetailPengeluaran(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  String get _periodLabel {
    if (_filter.filterBerdasarkan == 'Custom' ||
        _filter.filterBerdasarkan == 'Minggu Ini') {
      return '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_endDate)}';
    }
    if (_filter.filterBerdasarkan == 'Tahunan') {
      return 'Tahun ${_startDate.year}';
    }
    return DateFormat('MMMM yyyy', 'id_ID').format(_startDate);
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

  String get _tabLabel => switch (_selectedTab) {
    0 => 'Pendapatan',
    1 => 'Pembayaran',
    _ => 'Pengeluaran',
  };

  Future<void> _showExportSheet(LaporanProvider provider) async {
    final report = provider.profitLossReport;
    if (report == null) {
      CustomToast.show(
        context,
        message: 'Belum ada data laba rugi untuk diunduh',
        isError: true,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan laba rugi sesuai tab yang sedang aktif.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf(provider);
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel(provider);
        },
      ),
    );
  }

  List<ReportPdfTable> _buildExportTables(
    LaporanProvider provider,
    ProfitLossReport report,
  ) {
    final metodeList =
        (provider.profitLossDetailMetode.isNotEmpty
                ? provider.profitLossDetailMetode
                : (report.detailMetode).whereType<Map>().map(
                    (e) => ProfitLossDetailMetode.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  ))
            .toList();
    final pengeluaranList =
        (provider.profitLossDetailPengeluaran.isNotEmpty
                ? provider.profitLossDetailPengeluaran
                : (report.detailPengeluaran).whereType<Map>().map(
                    (e) => ProfitLossDetailPengeluaran.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  ))
            .toList();

    return switch (_selectedTab) {
      0 => [
        ReportPdfTable(
          title: 'Ringkasan Laba Rugi Harian',
          subtitle: 'Pendapatan, pengeluaran, dan laba rugi per tanggal.',
          headers: const ['Tanggal', 'Pendapatan', 'Pengeluaran', 'Laba/Rugi'],
          rows: report.detailHarian
              .map<List<String>>(
                (row) => [
                  ReportExportBuilder.formatTableDate(row['date']),
                  ReportExportBuilder.formatRupiah((row['income'] ?? 0) as num),
                  ReportExportBuilder.formatRupiah(
                    (row['expense'] ?? 0) as num,
                  ),
                  ReportExportBuilder.formatRupiah(
                    (row['laba_rugi'] ?? 0) as num,
                  ),
                ],
              )
              .toList(),
        ),
      ],
      1 => [
        ReportPdfTable(
          title: 'Metode Pembayaran',
          subtitle: 'Penerimaan kas laundry dan top up deposit per metode.',
          headers: const ['Metode', 'Nominal'],
          rows: metodeList
              .map(
                (item) => [
                  item.metodeNama,
                  ReportExportBuilder.formatRupiah(item.total),
                ],
              )
              .toList(),
        ),
      ],
      _ => [
        ReportPdfTable(
          title: 'Kategori Pengeluaran',
          subtitle: 'Kontribusi pengeluaran berdasarkan kategori.',
          headers: const ['Kategori', 'Nominal'],
          rows: pengeluaranList
              .map(
                (item) => [
                  item.kategoriNama,
                  ReportExportBuilder.formatRupiah(item.total),
                ],
              )
              .toList(),
        ),
      ],
    };
  }

  ReportPdfDocument _buildExportDocument(
    LaporanProvider provider,
    ProfitLossReport report,
    Uint8List? logoBytes,
  ) {
    return ReportPdfDocument(
      title: 'Laporan Laba & Rugi',
      subtitle:
          'Ringkasan performa keuangan berdasarkan pendapatan, pengeluaran, dan laba rugi pada periode aktif.',
      periodLabel: _exportPeriodLabel,
      rangeLabel: ReportExportBuilder.formatDateRange(_startDate, _endDate),
      filterLabel: _tabLabel,
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(report.labaRugi),
      primaryCaption: 'Laba atau rugi bersih periode ini',
      metrics: [
        ReportPdfMetric(
          title: 'Pendapatan',
          value: ReportExportBuilder.formatRupiah(report.totalPendapatan),
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
        ReportPdfMetric(
          title: 'Pengeluaran',
          value: ReportExportBuilder.formatRupiah(report.totalPengeluaran),
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Total Transaksi',
          value: '${report.totalTransaksi} transaksi',
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
      ],
      tables: _buildExportTables(provider, report),
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf(LaporanProvider provider) async {
    if (_isExporting) return;
    final report = provider.profitLossReport;
    if (report == null) return;

    setState(() => _isExporting = true);
    try {
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(provider, report, logoBytes);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_laba_rugi_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}_${_tabLabel.toLowerCase()}.pdf',
        shareTitle: 'Laporan Laba & Rugi $_tabLabel',
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

  Future<void> _exportExcel(LaporanProvider provider) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final report = provider.profitLossReport;
      if (report == null) {
        throw Exception('Data laba rugi belum tersedia');
      }
      final document = _buildExportDocument(provider, report, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_laba_rugi_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}_${_tabLabel.toLowerCase()}.xlsx',
        shareTitle: 'Laporan Laba & Rugi $_periodLabel',
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

  Widget _buildDetailPendapatan(LaporanProvider provider) {
    final report = provider.profitLossReport;

    if (report != null && report.detailHarian.isNotEmpty) {
      return Column(
        children: report.detailHarian.map((row) {
          final date = row['date']?.toString() ?? '';
          return TransaksiTile(
            row: {
              'tanggal': date,
              'pendapatan': (row['income'] ?? 0).toDouble(),
              'pengeluaran': (row['expense'] ?? 0).toDouble(),
              'labaRugi': (row['laba_rugi'] ?? 0).toDouble(),
              'omset': (row['omset'] ?? 0).toDouble(),
            },
            onTap: date.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LaporanPendapatanDetailScreen(
                        metodeNama: '',
                        startDate: date.split('T').first,
                        endDate: date.split('T').first,
                        token: widget.token,
                      ),
                    ),
                  ),
          );
        }).toList(),
      );
    }

    return const _EmptyCard();
  }

  Widget _buildMetodePembayaran(LaporanProvider provider) {
    final report = provider.profitLossReport;

    final rawMetodeList = (report?.detailMetode ?? [])
        .map((e) => ProfitLossDetailMetode.fromJson(e as Map<String, dynamic>))
        .toList();

    if (rawMetodeList.isEmpty) {
      return const _EmptyCard();
    }

    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in rawMetodeList) {
      final category = _resolveCategory(item.metodeNama);
      final displayNama = category == 'Transfer'
          ? PaymentNameHelper.getBankDisplayName(item.metodeNama)
          : category == 'E-Wallet'
          ? PaymentNameHelper.getEwalletDisplayName(item.metodeNama)
          : (category == 'Cash'
                ? 'Tunai / Cash'
                : PaymentNameHelper.getCategoryDisplayName(item.metodeNama));

      if (grouped.containsKey(displayNama)) {
        grouped[displayNama]!['total'] += item.total;
      } else {
        grouped[displayNama] = {
          'total': item.total,
          'category': category,
          'raw': item.metodeNama,
        };
      }
    }

    final entries = grouped.entries.toList();

    final money = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFDDD1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pendapatan ${money.format(report?.totalKasMasuk ?? 0)} termasuk top up deposit ${money.format(report?.totalTopUpDeposit ?? 0)}. Pemakaian saldo deposit tidak dihitung lagi agar pendapatan tidak tercatat dua kali.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF72564D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: entries.asMap().entries.map((mapEntry) {
              final isLast = mapEntry.key == entries.length - 1;
              final displayNama = mapEntry.value.key;
              final data = mapEntry.value.value;
              final total = data['total'] as double;
              final category = data['category'] as String;
              final raw = data['raw'] as String;

              String? logoAsset;
              if (category == 'Transfer') {
                logoAsset = PaymentAssetUtil.getBankLogo(raw);
              } else if (category == 'E-Wallet') {
                logoAsset = PaymentAssetUtil.getEwalletLogo(raw);
              } else {
                logoAsset = PaymentAssetUtil.getCategoryImage(category);
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LaporanPendapatanDetailScreen(
                        metodeNama: raw,
                        startDate: _fmt(_startDate),
                        endDate: _fmt(_endDate),
                        token: widget.token,
                      ),
                    ),
                  );
                },
                child: MetodePembayaranTile(
                  nama: displayNama,
                  total: total,
                  logoAsset: logoAsset,
                  bgColor: PaymentColors.getBackgroundColor(category),
                  showDivider: !isLast,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPengeluaran(LaporanProvider provider) {
    final report = provider.profitLossReport;

    final pengeluaranList = (report?.detailPengeluaran ?? [])
        .map(
          (e) =>
              ProfitLossDetailPengeluaran.fromJson(e as Map<String, dynamic>),
        )
        .toList();

    if (pengeluaranList.isEmpty) {
      return const _EmptyCard();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: pengeluaranList.asMap().entries.map((entry) {
          final item = entry.value;
          return PengeluaranKategoriTile(
            token: widget.token,
            startDate: _fmt(_startDate),
            endDate: _fmt(_endDate),
            kategoriId: item.kategoriId,
            kategori: item.kategoriNama,
            total: item.total,
            showDivider: entry.key < pengeluaranList.length - 1,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_profit_loss',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_PROFIT_LOSS',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );
    return Consumer<LaporanProvider>(
      builder: (context, provider, _) {
        final report = provider.profitLossReport;

        return AppScaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Laporan Laba & Rugi',
              style: TextStyle(color: Colors.black, fontSize: 15),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: _isExporting
                    ? null
                    : () => _showExportSheet(provider),
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
              ),
            ],
          ),
          body: !canRead
              ? const SafeArea(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: 12),
                    child: ReportAccessPlaceholder(
                      icon: Icons.query_stats_outlined,
                      title: 'Laporan Laba & Rugi Terkunci',
                      message:
                          'Akun ini belum punya izin untuk melihat data laba rugi.',
                      compact: true,
                    ),
                  ),
                )
              : !canAccessAddonFeature
              ? SafeArea(
                  child: AddonLockedPlaceholder(
                    title: 'Laporan laba rugi belum aktif',
                    message:
                        'Aktifkan add-on untuk melihat profit usaha dan performa per periode.',
                    features: const [
                      'Profit periode',
                      'Biaya operasional',
                      'Performa usaha',
                    ],
                    onActionTap: _openAddonActivation,
                  ),
                )
              : _isAddonLockedMessage(provider.errorMessage)
              ? SafeArea(
                  child: AddonLockedPlaceholder(
                    title: 'Laporan laba rugi belum aktif',
                    message:
                        'Aktifkan add-on untuk melihat profit usaha dan performa per periode.',
                    features: const [
                      'Pendapatan usaha',
                      'Biaya operasional',
                      'Analisa profit',
                    ],
                    onActionTap: _openAddonActivation,
                  ),
                )
              : _buildBody(provider, report),
        );
      },
    );
  }

  Widget _buildBody(LaporanProvider provider, ProfitLossReport? report) {
    if (provider.isLoading) {
      return const LaporanLabaRugiSkeleton();
    }

    if (provider.errorMessage != null) {
      return _buildErrorState(provider.errorMessage!);
    }

    final rupiahFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        Container(
          color: _kBg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              LabaRugiCard(dateLabel: _periodLabel),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      label: 'Total Pendapatan',
                      amount: report?.totalPendapatan ?? 0.0,
                      isIncome: true,
                      rupiahFmt: rupiahFmt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      label: 'Total Pengeluaran',
                      amount: report?.totalPengeluaran ?? 0.0,
                      isIncome: false,
                      rupiahFmt: rupiahFmt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ringkasan Laba & Rugi',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  InkWell(
                    onTap: _openFilter,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _filter.hasActiveFilter
                              ? _kPrimary
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
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: _filter.hasActiveFilter
                                ? _kPrimary
                                : Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              color: _filter.hasActiveFilter
                                  ? _kPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LaporanTabBar(
                selectedIndex: _selectedTab,
                onTabChanged: (i) {
                  setState(() => _selectedTab = i);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: _buildTabContent(provider),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double amount,
    required bool isIncome,
    required NumberFormat rupiahFmt,
  }) {
    final color = isIncome ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final bgColor = isIncome
        ? const Color(0xFFEAFBF0)
        : const Color(0xFFFFEFEF);
    final icon = isIncome
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    final prefix = isIncome ? '+ ' : '- ';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.split(' ').last, // Use shorter label
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black26,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix${rupiahFmt.format(amount)}',
              style: TextStyle(fontSize: 16, color: color, height: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return ReportErrorView(
      message: message,
      onRetry: _fetchData,
      color: _kPrimary,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Belum ada data laba rugi',
            style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coba ubah periode atau filter',
            style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 200,
            height: 200,
            child: EmptyStateWidget.laporan(
              title: '',
              message: '',
              imageWidth: 160,
            ),
          ),
        ],
      ),
    );
  }
}
