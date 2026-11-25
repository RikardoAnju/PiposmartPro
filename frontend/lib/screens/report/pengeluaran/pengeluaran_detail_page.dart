import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:typed_data';

import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:pdf/pdf.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PengeluaranDetailPage extends StatefulWidget {
  final String tanggal;
  final String token;

  const PengeluaranDetailPage({
    super.key,
    required this.tanggal,
    required this.token,
  });

  @override
  State<PengeluaranDetailPage> createState() => _PengeluaranDetailPageState();
}

class _PengeluaranDetailPageState extends State<PengeluaranDetailPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFFBFBFB);

  final Map<String, bool> _expandedMap = {};
  final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  bool _isExporting = false;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  ReportPdfDocument _buildExportDocument(
    LaporanProvider provider,
    Uint8List? logoBytes,
    List<ExpenseDetail> detailItems,
  ) {
    final totalPengeluaran = detailItems.fold(
      0.0,
      (sum, item) => sum + item.jumlah,
    );

    return ReportPdfDocument(
      title: 'Detail Pengeluaran',
      subtitle:
          'Rincian seluruh transaksi pengeluaran operasional pada tanggal ini.',
      periodLabel: _formatTanggalDisplay(widget.tanggal),
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(totalPengeluaran),
      primaryCaption: 'Total pengeluaran pada tanggal ini',
      metrics: [
        ReportPdfMetric(
          title: 'Total Transaksi',
          value: '${detailItems.length} transaksi',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Daftar Pengeluaran',
          headers: const ['Nama Pengeluaran', 'Kategori', 'Nominal'],
          rows: detailItems
              .map(
                (item) => [
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
      final detailItems = await provider.fetchAllExpenseDetails(
        widget.token,
        startDate: widget.tanggal,
        endDate: widget.tanggal,
      );
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(provider, logoBytes, detailItems);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'detail_pengeluaran_${ReportExportBuilder.formatFileDate(widget.tanggal)}.pdf',
        shareTitle:
            'Detail Pengeluaran ${_formatTanggalDisplay(widget.tanggal)}',
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
      final detailItems = await provider.fetchAllExpenseDetails(
        widget.token,
        startDate: widget.tanggal,
        endDate: widget.tanggal,
      );
      final document = _buildExportDocument(provider, null, detailItems);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'detail_pengeluaran_${ReportExportBuilder.formatFileDate(widget.tanggal)}.xlsx',
        shareTitle:
            'Detail Pengeluaran ${_formatTanggalDisplay(widget.tanggal)}',
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

  Future<void> _showExportSheet() async {
    final items = context.read<LaporanProvider>().expenseDetail;
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
        description: 'Download rincian pengeluaran pada tanggal ini.',
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

  Future<void> _fetchData() async {
    _page = 1;
    await _fetchExpenseDetail(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<LaporanProvider>();
      if (!provider.isLoadingMore && provider.hasMoreExpense) {
        _page++;
        _fetchExpenseDetail(page: _page);
      }
    }
  }

  Future<void> _fetchExpenseDetail({int page = 1}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    await context.read<LaporanProvider>().fetchExpenseDetail(
      token,
      startDate: widget.tanggal,
      endDate: widget.tanggal,
      page: page,
    );
  }

  String _formatTanggalDisplay(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dateOnly = raw.split('T').first;
      final parts = dateOnly.split('-');
      if (parts.length != 3) return raw;
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[0]);
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
      return '${day.toString().padLeft(2, '0')} ${bulan[month - 1]} $year';
    } catch (_) {
      return raw;
    }
  }

  Map<String, List<ExpenseDetail>> _groupByKategori(List<ExpenseDetail> list) {
    final Map<String, List<ExpenseDetail>> grouped = {};
    for (final item in list) {
      grouped.putIfAbsent(item.kategoriNama, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
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
          'Detail Pengeluaran',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
            letterSpacing: -0.5,
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
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.download_rounded,
                        size: 22,
                        color: Color(0xFFFF8A00),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<LaporanProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const ReportExpenseDetailSkeleton();
          }

          if (provider.errorMessage != null) {
            return _buildError(provider.errorMessage!);
          }

          final detailList = provider.expenseDetail;
          // Pakai agregat server (seluruh data terfilter) agar total tidak
          // bertambah saat scroll memuat halaman berikutnya. Fallback ke
          // hitung lokal bila header belum tersedia.
          final detailHeader = provider.expenseDetailHeader;
          final totalPengeluaran =
              detailHeader?.totalNominal ??
              detailList.fold<double>(0.0, (sum, item) => sum + item.jumlah);
          final totalTransaksi =
              detailHeader?.totalTransaksi ?? detailList.length;
          final grouped = _groupByKategori(detailList);

          for (final key in grouped.keys) {
            _expandedMap.putIfAbsent(
              key,
              () => false,
            ); // Default collapsed as requested
          }

          return Column(
            children: [
              // FIXED HEADER SECTION
              Container(
                color: kBg,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTotalCard(totalPengeluaran, totalTransaksi),
                    const SizedBox(height: 16),
                    const Text(
                      'Rincian Berdasarkan Kategori',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // SCROLLABLE LIST SECTION
              Expanded(
                child: detailList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateWidget.laporan(
                          title: 'Belum ada data pengeluaran',
                          message: 'Belum ada data yang dapat ditampilkan',
                          imageWidth: 170,
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        child: Column(
                          children: grouped.entries.map((entry) {
                            return _buildKategoriCard(entry.key, entry.value);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(double total, int count) {
    return Container(
      width: double.infinity,
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Opacity(
              opacity: 0.1,
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pengeluaran',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatter.format(total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: AppFont.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              color: AppPalette.primary,
                              fontSize: 18,
                              fontWeight: AppFont.w900,
                            ),
                          ),
                          const Text(
                            'Transaksi',
                            style: TextStyle(
                              color: AppPalette.primary,
                              fontSize: 8,
                              fontWeight: AppFont.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTanggalDisplay(widget.tanggal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriCard(String kategoriNama, List<ExpenseDetail> items) {
    final totalKategori = items.fold(0.0, (sum, item) => sum + item.jumlah);
    final isExpanded = _expandedMap[kategoriNama] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _expandedMap[kategoriNama] = !isExpanded),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        size: 18,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        kategoriNama,
                        style: const TextStyle(
                          fontWeight: AppFont.w900,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      _formatter.format(totalKategori),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: kPrimary,
                        fontWeight: AppFont.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1, color: Color(0xFFF1F1F1)),
              ...items.map((item) {
                final isLast = item == items.last;
                final bool showKeterangan =
                    item.keterangan != null &&
                    item.keterangan!.isNotEmpty &&
                    item.keterangan != item.nama;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nama,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: AppFont.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (showKeterangan)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.keterangan!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontWeight: AppFont.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatter.format(item.jumlah),
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
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return ReportErrorView(message: message, onRetry: _fetchData);
  }
}
