import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'dart:typed_data';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/core/utils/user_friendly_error.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CustomerTransactionDetailScreen extends StatefulWidget {
  final TopCustomerItem customer;
  final DateTime startDate;
  final DateTime endDate;

  const CustomerTransactionDetailScreen({
    super.key,
    required this.customer,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<CustomerTransactionDetailScreen> createState() =>
      _CustomerTransactionDetailScreenState();
}

class _CustomerTransactionDetailScreenState
    extends State<CustomerTransactionDetailScreen> {
  List<OmsetDetail> _transactions = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions();
    });
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = context.read<AuthProvider>().token ?? '';
      final provider = context.read<LaporanProvider>();

      // Filter berdasarkan ID pelanggan (bukan pencarian nama), agar tidak
      // ikut menarik transaksi pelanggan lain yang namanya mirip.
      // Fallback ke pencarian nama hanya bila ID tidak tersedia (data lama).
      final customerId = widget.customer.id.trim();
      await provider.fetchAllTransactions(
        token,
        startDate: DateFormat('yyyy-MM-dd').format(widget.startDate),
        endDate: DateFormat('yyyy-MM-dd').format(widget.endDate),
        customerId: customerId.isNotEmpty ? customerId : null,
        search: customerId.isEmpty ? widget.customer.nama : null,
      );

      // Muat SELURUH halaman agar daftar & total tidak terpotong di 20 baris.
      while (mounted && provider.hasMoreTransactions) {
        await provider.loadMoreAllTransactions();
      }

      if (!mounted) return;
      setState(() {
        _transactions = provider.allTransactions
            .where((trx) => !_isCancelled(trx.statusOrder))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userFriendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  String _formatRupiah(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  bool _isCancelled(String status) {
    return status.trim().toLowerCase() == 'batal';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return const Color(0xFF4CAF50);
      case 'belum lunas':
      case 'belum_lunas':
        return AppPalette.primary;
      default:
        return AppPalette.warning;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'lunas':
        return const Color(0xFFE8F5E9);
      case 'belum lunas':
      case 'belum_lunas':
        return const Color(0xFFFFF0EB);
      default:
        return const Color(0xFFFFF3E0);
    }
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
    return '${fmt(widget.startDate)} s/d ${fmt(widget.endDate)}';
  }

  Future<void> _showExportSheet() async {
    if (_transactions.isEmpty) {
      CustomToast.show(
        context,
        message: 'Belum ada transaksi untuk diunduh',
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
            'Download riwayat transaksi ${widget.customer.nama} pada periode aktif.',
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

  ReportPdfDocument _buildExportDocument(Uint8List? logoBytes) {
    final totalOrder = _transactions.length;
    final totalNominal = _transactions.fold<double>(
      0,
      (sum, trx) => sum + trx.totalHarga,
    );
    final customer = widget.customer;
    final phone = customer.noHp.isNotEmpty ? customer.noHp : '-';

    return ReportPdfDocument(
      title: 'Transaksi Pelanggan',
      subtitle:
          'Riwayat transaksi ${ReportExportBuilder.sanitizeText(customer.nama, fallback: 'Tanpa Nama')} ($phone).',
      periodLabel: _formatPeriod(),
      rangeLabel: ReportExportBuilder.formatDateRange(
        widget.startDate,
        widget.endDate,
      ),
      filterLabel: ReportExportBuilder.sanitizeText(
        customer.nama,
        fallback: 'Tanpa Nama',
      ),
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: '$totalOrder',
      primaryCaption: 'Jumlah transaksi pada periode aktif',
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
          title: 'Riwayat Transaksi',
          subtitle: 'Daftar transaksi pelanggan pada periode aktif.',
          headers: const [
            'No Nota',
            'Masuk',
            'Est Selesai',
            'Status Bayar',
            'Total',
          ],
          rows: _transactions
              .map(
                (trx) => [
                  trx.nomorNota,
                  trx.tanggalMasuk,
                  trx.tanggalSelesai,
                  trx.statusPembayaran,
                  ReportExportBuilder.formatRupiah(trx.totalHarga),
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  String _exportFileName(String ext) {
    final safeName = ReportExportBuilder.sanitizeText(
      widget.customer.nama,
      fallback: 'pelanggan',
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'transaksi_${safeName}_${ReportExportBuilder.formatFileDate(widget.startDate)}_sd_${ReportExportBuilder.formatFileDate(widget.endDate)}.$ext';
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(logoBytes);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName: _exportFileName('pdf'),
        shareTitle: 'Transaksi ${widget.customer.nama} ${_formatPeriod()}',
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
    setState(() => _isExporting = true);
    try {
      final document = _buildExportDocument(null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName: _exportFileName('xlsx'),
        shareTitle: 'Transaksi ${widget.customer.nama} ${_formatPeriod()}',
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
    final customer = widget.customer;
    final displayTotalOrder = !_isLoading
        ? _transactions.length
        : customer.totalOrder;
    final displayTotalNominal = !_isLoading
        ? _transactions.fold<double>(0, (sum, trx) => sum + trx.totalHarga)
        : customer.totalNominal;

    return AppScaffold(
      backgroundColor: AppPalette.primarySoft,
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
          'Transaksi Pelanggan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          if (!_isLoading && _errorMessage == null && _transactions.isNotEmpty)
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
                          color: Colors.black87,
                        );
                      },
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.primaryWarm],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Text(
                        _getInitials(customer.nama),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w800,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.noHp.isNotEmpty ? customer.noHp : '-',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 82,
                    maxWidth: 104,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$displayTotalOrder Order',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Rp ${_formatRupiah(displayTotalNominal)}',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Riwayat Transaksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFont.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                if (!_isLoading && _transactions.isNotEmpty)
                  Text(
                    '${_transactions.length} transaksi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                      fontWeight: AppFont.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _isLoading
                ? const ReportTransactionListSkeleton()
                : _errorMessage != null
                ? ReportErrorView(
                    message: _errorMessage!,
                    onRetry: _fetchTransactions,
                    color: AppPalette.primary,
                  )
                : _transactions.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada transaksi',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    ),
                  )
                : RefreshIndicator(
                    color: AppPalette.primary,
                    onRefresh: _fetchTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final trx = _transactions[index];
                        return _TransactionCard(
                          trx: trx,
                          statusColor: _statusColor(trx.statusPembayaran),
                          statusBgColor: _statusBgColor(trx.statusPembayaran),
                          formatRupiah: _formatRupiah,
                          onTap: () {
                            final transactionId = trx.id.trim().isNotEmpty
                                ? trx.id
                                : trx.nomorNota;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailPesananScreen(
                                  transactionId: transactionId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final OmsetDetail trx;
  final Color statusColor;
  final Color statusBgColor;
  final String Function(double) formatRupiah;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.trx,
    required this.statusColor,
    required this.statusBgColor,
    required this.formatRupiah,
    required this.onTap,
  });

  bool get _hasDownPayment {
    return trx.statusPembayaran.toLowerCase() == 'belum lunas' &&
        trx.dpAmount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trx.namaPelanggan.isNotEmpty
                            ? trx.namaPelanggan
                            : 'Tanpa Nama',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: AppFont.w800,
                          color: Color(0xFF263340),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Rp ${formatRupiah(trx.totalHarga)}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: AppFont.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (trx.metodePembayaran != null &&
                        trx.metodePembayaran!.trim().isNotEmpty)
                      _SoftBadge(
                        label: trx.metodePembayaran!.toUpperCase(),
                        color: const Color(0xFF3B82F6),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    _SoftBadge(
                      label: trx.statusPembayaran.toUpperCase(),
                      color: statusColor,
                      bgColor: statusBgColor,
                    ),
                    if (_hasDownPayment)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _SoftBadge(
                            label: 'DP',
                            color: Color(0xFF8B5CF6),
                            bgColor: Color(0xFFF3E8FF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rp ${formatRupiah(trx.dpAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: AppFont.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InlineInfo(
                        Icons.access_time_rounded,
                        'Masuk: ${trx.tanggalMasuk}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InlineInfo(
                        Icons.event_available_rounded,
                        'Est: ${trx.tanggalSelesai}',
                      ),
                    ),
                  ],
                ),
                if (trx.catatan.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _InlineInfo(Icons.notes_rounded, trx.catatan, maxLines: 2),
                ],
                const Divider(
                  height: 24,
                  thickness: 0.6,
                  color: Color(0xFFF1E5E0),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trx.nomorNota,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAAA09B),
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Lihat Detail',
                          style: TextStyle(
                            color: Color(0xFFAAA09B),
                            fontSize: 12,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFFAAA09B),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const _InlineInfo(this.icon, this.text, {this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFB9AEA9)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E817B),
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _SoftBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: AppFont.w800),
      ),
    );
  }
}
