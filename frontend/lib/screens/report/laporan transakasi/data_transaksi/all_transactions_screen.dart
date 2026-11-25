import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'dart:typed_data';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/all_transactions_skeleton.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/widgets/filter_transaksi_page.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/widgets/transaction_summary_modal.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'widgets/transaction_card.dart';
import 'widgets/transaction_date_header.dart';
import 'widgets/transaction_empty_state.dart';
import 'widgets/transaction_ringkasan_bar.dart';
import 'widgets/transaction_summary_row.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AllTransactionsScreen extends StatefulWidget {
  final String? initialStatus;
  final TransaksiFilter initialFilter;
  final bool autoPickStatusFromFilteredResult;

  const AllTransactionsScreen({
    super.key,
    this.initialStatus,
    this.initialFilter = const TransaksiFilter(),
    this.autoPickStatusFromFilteredResult = false,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _searchQuery = '';
  TransaksiFilter _filter = const TransaksiFilter();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isExporting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _filter = widget.initialFilter;
    if (widget.initialStatus != null && widget.initialStatus!.isNotEmpty) {
      _filter = _filter.copyWith(statusPesanan: [widget.initialStatus!]);
    }

    final now = DateTime.now();
    if (_filter.filterBerdasarkan == 'Custom' &&
        _filter.startDate != null &&
        _filter.endDate != null) {
      _startDate = _filter.startDate!;
      _endDate = _filter.endDate!;
    } else if (_filter.filterBerdasarkan == 'Minggu Ini') {
      _endDate = DateTime(now.year, now.month, now.day);
      _startDate = _endDate.subtract(const Duration(days: 6));
    } else if (_filter.filterBerdasarkan == 'Tahunan') {
      final tahun = _filter.tahun ?? now.year;
      _startDate = DateTime(tahun, 1, 1);
      _endDate = DateTime(tahun, 12, 31);
    } else {
      final bulan = _filter.bulan ?? now.month;
      final tahun = _filter.tahun ?? now.year;
      _startDate = DateTime(tahun, bulan, 1);
      _endDate = DateTime(tahun, bulan + 1, 0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().canReadReportAction(
        'read_transaction',
      )) {
        _fetchTransactions();
      }
    });
  }

  Future<void> _fetchTransactions() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    final dateFormat = DateFormat('yyyy-MM-dd');

    // Kirim filter status ke server agar pagination + agregat (header) benar.
    // "DP" tidak didukung server (bukan status pembayaran sebenarnya, melainkan
    // Belum Lunas + ada DP), jadi status itu tetap difilter sisi-klien.
    final bool hasPaymentFilter = _filter.statusPembayaran.isNotEmpty;
    // DP tersimpan sebagai "Belum Lunas" + nominal DP. Karena itu kombinasi
    // status pembayaran disaring di aplikasi setelah seluruh halaman dimuat.
    const String? serverStatusPembayaran = null;

    await context.read<LaporanProvider>().fetchAllTransactions(
      token,
      startDate: dateFormat.format(_startDate),
      endDate: dateFormat.format(_endDate),
      statusOrder: _filter.statusPesanan.isEmpty
          ? null
          : _filter.statusPesanan.join(','),
      statusPembayaran: serverStatusPembayaran,
      customerId: _filter.customerId,
    );

    // Metode pembayaran dan kategori DP disaring di aplikasi. Muat seluruh
    // halaman agar daftar, total, dan export tetap memakai dataset yang sama.
    if (_filter.metodePembayaran.isNotEmpty || hasPaymentFilter) {
      await _loadRemainingTransactions();
    }

    if (!mounted) return;
  }

  Future<void> _loadRemainingTransactions() async {
    final provider = context.read<LaporanProvider>();
    while (provider.hasMoreTransactions) {
      final previousCount = provider.allTransactions.length;
      await provider.loadMoreAllTransactions();
      if (provider.allTransactions.length == previousCount) break;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final provider = context.read<LaporanProvider>();
    // Jangan muat-lebih saat ada pencarian/filter lokal aktif; hasil server
    // sudah difilter, tapi pencarian teks di sini murni sisi-klien.
    if (_searchQuery.isNotEmpty) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300 &&
        provider.hasMoreTransactions &&
        !provider.isLoadingMore &&
        !provider.isLoading) {
      provider.loadMoreAllTransactions();
    }
  }

  Future<void> _openFilter() async {
    final transactions = context.read<LaporanProvider>().allTransactions;
    final uniqueMethods = transactions
        .map((t) => t.metodePembayaran)
        .where((m) => m != null && m.isNotEmpty)
        .map((m) => _displayMethodLabel(m!))
        .toSet()
        .toList();
    uniqueMethods.sort();

    final result = await Navigator.push<TransaksiFilter>(
      context,
      MaterialPageRoute(
        builder: (_) => FilterTransaksiPage(
          initialFilter: _filter,
          availableMethods: uniqueMethods,
        ),
      ),
    );

    if (result != null) {
      setState(() => _filter = result);
      await _applyFilterAndFetch(result);
    }
  }

  Future<void> _applyFilterAndFetch(TransaksiFilter filter) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    DateTime start;
    DateTime end;

    if (filter.filterBerdasarkan == 'Custom' &&
        filter.startDate != null &&
        filter.endDate != null) {
      start = filter.startDate!;
      end = filter.endDate!;
    } else if (filter.filterBerdasarkan == 'Minggu Ini') {
      final today = DateTime.now();
      end = DateTime(today.year, today.month, today.day);
      start = end.subtract(const Duration(days: 6));
    } else if (filter.filterBerdasarkan == 'Tahunan') {
      final tahun = filter.tahun ?? DateTime.now().year;
      start = DateTime(tahun, 1, 1);
      end = DateTime(tahun, 12, 31);
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

    await _fetchTransactions();
  }

  List<OmsetDetail> _filterTransactionsForSummary(
    List<OmsetDetail> transactions,
  ) {
    if (_searchQuery.isEmpty && !_filter.hasActiveFilter) {
      return transactions;
    }
    return transactions.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.nomorNota.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.namaPelanggan.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesBayar = true;
      if (_filter.statusPembayaran.isNotEmpty) {
        matchesBayar = _filter.statusPembayaran.any((status) {
          if (status.toLowerCase() == 'dp') {
            return item.statusPembayaran.toLowerCase() == 'belum lunas' &&
                item.dpAmount > 0;
          }
          if (status.toLowerCase() == 'belum lunas') {
            return item.statusPembayaran.toLowerCase() == 'belum lunas' &&
                item.dpAmount <= 0;
          }
          return item.statusPembayaran.toLowerCase() == status.toLowerCase();
        });
      }

      final itemMetode = (item.metodePembayaran ?? '').toLowerCase();
      final itemDisplay = _displayMethodLabel(itemMetode).toLowerCase();

      final matchesMetode =
          _filter.metodePembayaran.isEmpty ||
          _filter.metodePembayaran.any((method) {
            final filterMetode = method.toLowerCase();
            return itemMetode.contains(filterMetode) ||
                (itemMetode.isNotEmpty && filterMetode.contains(itemMetode)) ||
                itemDisplay.contains(filterMetode) ||
                (itemDisplay.isNotEmpty && filterMetode.contains(itemDisplay));
          });

      return matchesSearch && matchesBayar && matchesMetode;
    }).toList();
  }

  List<OmsetDetail> _filterTransactions(List<OmsetDetail> transactions) {
    final forSummary = _filterTransactionsForSummary(transactions);

    if (_filter.statusPesanan.isEmpty) return forSummary;

    return forSummary.where((item) {
      final s = item.statusOrder.toLowerCase();
      return _filter.statusPesanan.any((status) {
        final target = status.toLowerCase();
        if (target == 'antrian') return s.contains('antrian');
        if (target == 'proses') return s.contains('proses');
        if (target == 'siap ambil') {
          return s.contains('siap') && s.contains('ambil');
        }
        if (target == 'selesai') return s.contains('selesai');
        if (target == 'batal') return s.contains('batal');
        return false;
      });
    }).toList();
  }

  Map<String, List<OmsetDetail>> _groupTransactionsByDate(
    List<OmsetDetail> transactions,
  ) {
    final map = <String, List<OmsetDetail>>{};
    final formatter = DateFormat('d MMMM yyyy', 'id_ID');

    for (final t in transactions) {
      final key = _formatDate(t, formatter);
      map.putIfAbsent(key, () => []).add(t);
    }

    return map;
  }

  String _formatDate(OmsetDetail t, DateFormat formatter) {
    try {
      final parsed = parseReportDate(t.tanggal);
      if (parsed == null) {
        return t.tanggalMasuk.isNotEmpty ? t.tanggalMasuk : '-';
      }
      return formatter.format(parsed);
    } catch (_) {
      return t.tanggalMasuk.isNotEmpty ? t.tanggalMasuk : '-';
    }
  }

  double _totalRevenue(List<OmsetDetail> transactions) {
    return transactions.fold(0, (sum, t) {
      if (t.statusOrder.toLowerCase() == 'batal') {
        return sum;
      }
      return sum + t.totalHarga;
    });
  }

  bool _isCanceled(OmsetDetail item) {
    return item.statusOrder.toLowerCase().contains('batal');
  }

  bool _isUnpaid(OmsetDetail item) {
    return item.statusPembayaran.toLowerCase().contains('belum');
  }

  double _outstandingAmount(OmsetDetail item) {
    if (!_isUnpaid(item) || _isCanceled(item)) return 0;
    if (item.sisaBayar > 0) return item.sisaBayar;
    final remaining = item.totalHarga - item.dpAmount;
    return remaining > 0 ? remaining : item.totalHarga;
  }

  double _totalGrossSales(List<OmsetDetail> transactions) {
    return transactions.fold(0, (sum, item) {
      if (_isCanceled(item)) return sum;
      final gross = item.totalKotor > 0 ? item.totalKotor : item.totalHarga;
      return sum + gross;
    });
  }

  double _totalDiscount(List<OmsetDetail> transactions) {
    return transactions.fold(0, (sum, item) {
      if (_isCanceled(item)) return sum;
      return sum + item.potonganDiskon;
    });
  }

  double _receivedAmount(OmsetDetail item) {
    if (_isCanceled(item)) return 0;
    final paid = item.totalHarga - _outstandingAmount(item);
    if (paid > 0) return paid;
    return item.dpAmount > 0 ? item.dpAmount : 0;
  }

  double _totalReceived(List<OmsetDetail> transactions) {
    return transactions.fold(0, (sum, item) => sum + _receivedAmount(item));
  }

  double _totalDeliveryRevenue(List<OmsetDetail> transactions) {
    return transactions.fold(0, (sum, item) {
      if (_isCanceled(item)) return sum;
      return sum + (item.jemputBiaya ?? 0) + (item.antarBiaya ?? 0);
    });
  }

  List<List<String>> _pairSummaryRows(
    List<List<String>> left,
    List<List<String>> right,
  ) {
    final maxRows = left.length > right.length ? left.length : right.length;
    return List.generate(maxRows, (index) {
      final leftRow = index < left.length ? left[index] : const ['', ''];
      final rightRow = index < right.length ? right[index] : const ['', ''];
      return [leftRow[0], leftRow[1], rightRow[0], rightRow[1]];
    });
  }

  String _paymentMethodLabel(OmsetDetail item) {
    final method = item.metodePembayaran?.trim();
    if (method == null || method.isEmpty) return '-';
    return _displayMethodLabel(method);
  }

  String _paymentStatusLabel(OmsetDetail item) {
    final status = item.statusPembayaran.trim();
    if (status.toLowerCase() == 'lunas') return 'Lunas';
    if (_receivedAmount(item) > 0 && _outstandingAmount(item) > 0) {
      return 'DP';
    }
    return status.isEmpty ? 'Belum Lunas' : status;
  }

  String _paymentDateLabel(OmsetDetail item) {
    if (item.tanggalPembayaran.trim().isNotEmpty &&
        item.tanggalPembayaran.trim() != '-') {
      return ReportExportBuilder.formatShortTableDate(item.tanggalPembayaran);
    }
    if (item.statusPembayaran.toLowerCase() == 'lunas') {
      return ReportExportBuilder.formatShortTableDate(item.tanggalMasuk);
    }
    return '-';
  }

  String _activeFilterLabel() {
    List<String> active = [];
    if (_filter.statusPesanan.isNotEmpty) {
      active.add('Pesanan: ${_filter.statusPesanan.join(', ')}');
    }
    if (_filter.statusPembayaran.isNotEmpty) {
      active.add('Pembayaran: ${_filter.statusPembayaran.join(', ')}');
    }
    if (_filter.metodePembayaran.isNotEmpty) {
      active.add('Metode: ${_filter.metodePembayaran.join(', ')}');
    }
    if (_filter.filterBerdasarkan != 'Bulanan') {
      active.add('Rentang: ${_filter.filterBerdasarkan}');
    }
    if (active.isEmpty) return 'Tidak ada filter tambahan yang aktif.';
    return active.join(' • ');
  }

  String _exportPeriodLabel() {
    switch (_filter.filterBerdasarkan) {
      case 'Custom':
        return 'Custom';
      case 'Tahunan':
        return 'Tahun ${_startDate.year}';
      default:
        return DateFormat('MMMM yyyy', 'id_ID').format(_startDate);
    }
  }

  String _slimActiveFilterLabel() {
    List<String> active = [_summaryPeriodLabel()];
    if (_filter.statusPesanan.isNotEmpty) {
      active.add(_filter.statusPesanan.join(', '));
    }
    if (_filter.statusPembayaran.isNotEmpty) {
      active.add(_filter.statusPembayaran.join(', '));
    }
    if (_filter.metodePembayaran.isNotEmpty) {
      active.add(_filter.metodePembayaran.join(', '));
    }
    return active.join(' • ');
  }

  String _summaryPeriodLabel() {
    String fmt(DateTime dt) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month';
    }

    switch (_filter.filterBerdasarkan) {
      case 'Tahunan':
        return 'Tahun ${_startDate.year}';
      case 'Bulanan':
        return DateFormat('MMM yyyy', 'id_ID').format(_startDate);
      case 'Minggu Ini':
      case 'Custom':
      default:
        return '${fmt(_startDate)} - ${fmt(_endDate)}';
    }
  }

  String _displayMethodLabel(String raw) {
    final normalized = raw.trim().toLowerCase();

    if (normalized.contains('tunai') || normalized.contains('cash')) {
      return 'Tunai';
    }
    if (normalized.contains('bca')) return 'BCA';
    if (normalized.contains('bri')) return 'BRI';
    if (normalized.contains('bni')) return 'BNI';
    if (normalized.contains('mandiri')) return 'Mandiri';
    if (normalized.contains('permata')) return 'Permata';
    if (normalized.contains('cimb')) return 'CIMB';
    if (normalized.contains('gopay') || normalized.contains('go pay')) {
      return 'GoPay';
    }
    if (normalized.contains('shopeepay') || normalized.contains('shopee pay')) {
      return 'ShopeePay';
    }
    if (normalized.contains('ovo')) return 'OVO';
    if (normalized.contains('dana')) return 'DANA';
    if (normalized.contains('linkaja') || normalized.contains('link aja')) {
      return 'LinkAja';
    }
    if (normalized.contains('qris')) return 'QRIS';
    if (normalized.contains('transfer')) return 'Transfer';
    if (normalized.contains('ewallet') || normalized.contains('e-wallet')) {
      return 'E-Wallet';
    }

    final compact = raw
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\btransfer\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bcash\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bewallet\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\be-wallet\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return compact.isEmpty ? raw : compact;
  }

  Future<void> _showExportSheet(List<OmsetDetail> items) async {
    if (items.isEmpty && !context.read<LaporanProvider>().hasMoreTransactions) {
      CustomToast.show(
        context,
        message: 'Belum ada data transaksi untuk diunduh',
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
            'Download laporan transaksi sesuai tab dan filter yang sedang aktif.',
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

  ReportPdfDocument _buildExportDocument(
    List<OmsetDetail> items,
    Uint8List? logoBytes,
  ) {
    final totalSales = _totalRevenue(items);
    final totalGross = _totalGrossSales(items);
    final unpaidItems = items.where(_isUnpaid).toList();
    final totalUnpaid = unpaidItems.fold<double>(
      0,
      (sum, item) => sum + _outstandingAmount(item),
    );
    final totalReceived = _totalReceived(items);
    final totalDiscount = _totalDiscount(items);
    final totalDeliveryRevenue = _totalDeliveryRevenue(items);
    final summaryRows = _pairSummaryRows(
      [
        [
          'Penjualan Setelah Diskon',
          ReportExportBuilder.formatRupiah(totalSales),
        ],
        ['Total Penjualan', ReportExportBuilder.formatRupiah(totalGross)],
        ['Total Diskon', ReportExportBuilder.formatRupiah(totalDiscount)],
      ],
      [
        ['Uang Diterima', ReportExportBuilder.formatRupiah(totalReceived)],
        ['Sisa Tagihan', ReportExportBuilder.formatRupiah(totalUnpaid)],
        [
          'Pendapatan Antar/Jemput',
          ReportExportBuilder.formatRupiah(totalDeliveryRevenue),
        ],
        ['Total Transaksi Belum Lunas', '${unpaidItems.length} transaksi'],
      ],
    );

    return ReportPdfDocument(
      title: 'Semua Data Transaksi',
      subtitle:
          'Ringkasan transaksi berdasarkan status, pencarian, dan filter aktif pada laporan transaksi.',
      periodLabel: _exportPeriodLabel(),
      rangeLabel: ReportExportBuilder.formatDateRange(_startDate, _endDate),
      filterLabel: _activeFilterLabel(),
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: ReportExportBuilder.formatRupiah(totalSales),
      primaryCaption: 'Penjualan tercatat pada tab aktif',
      metrics: [
        ReportPdfMetric(
          title: 'Jumlah Transaksi',
          value: '${items.length} transaksi',
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Uang Diterima',
          value: ReportExportBuilder.formatRupiah(totalReceived),
          background: PdfColor.fromHex('#F5F8FF'),
          accent: PdfColor.fromHex('#3B82F6'),
        ),
        ReportPdfMetric(
          title: 'Sisa Tagihan',
          value: ReportExportBuilder.formatRupiah(totalUnpaid),
          background: PdfColor.fromHex('#FFF7ED'),
          accent: PdfColor.fromHex('#F97316'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'List Laporan Penjualan',
          subtitle:
              '${unpaidItems.length} transaksi belum lunas dari ${items.length} transaksi.',
          headers: const ['Daftar', 'Total', 'Daftar', 'Total'],
          rows: summaryRows,
        ),
        ReportPdfTable(
          title: 'Detail Transaksi',
          subtitle: 'Data transaksi yang tampil pada daftar aktif.',
          headers: const [
            'Nota',
            'Tgl Transaksi',
            'Tgl Bayar',
            'Pelanggan',
            'Pesanan',
            'Bayar',
            'Metode',
            'Dibayar',
            'Sisa',
            'Total',
          ],
          rows: items
              .map(
                (item) => [
                  item.nomorNota,
                  ReportExportBuilder.formatShortTableDate(item.tanggalMasuk),
                  _paymentDateLabel(item),
                  ReportExportBuilder.sanitizeText(
                    item.namaPelanggan,
                    fallback: 'Tanpa Nama',
                  ),
                  item.statusOrder,
                  _paymentStatusLabel(item),
                  _paymentMethodLabel(item),
                  ReportExportBuilder.formatRupiah(item.dpAmount),
                  ReportExportBuilder.formatRupiah(_outstandingAmount(item)),
                  ReportExportBuilder.formatRupiah(item.totalHarga),
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  String _statusTitleLabel() => _filter.statusPesanan.isEmpty
      ? 'Semua Status'
      : _filter.statusPesanan.join(', ');

  String _statusFileLabel() =>
      (_filter.statusPesanan.isEmpty
              ? 'semua_status'
              : _filter.statusPesanan.join('_'))
          .toLowerCase()
          .replaceAll(' ', '_');

  Future<List<OmsetDetail>> _allFilteredTransactionsForExport() async {
    final provider = context.read<LaporanProvider>();
    await _loadRemainingTransactions();
    return _filterTransactions(provider.allTransactions);
  }

  Future<void> _exportPdf(List<OmsetDetail> _) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final items = await _allFilteredTransactionsForExport();
      if (items.isEmpty) {
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Tidak ada transaksi sesuai filter aktif',
            isError: true,
          );
        }
        return;
      }
      final logoBytes = await ReportExportService.loadLogoBytes();
      final document = _buildExportDocument(items, logoBytes);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'laporan_transaksi_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}_${_statusFileLabel()}${_filter.customerName != null ? '_${_filter.customerName!.toLowerCase().replaceAll(' ', '_')}' : ''}.pdf',
        shareTitle:
            'Laporan Transaksi ${_statusTitleLabel()}${_filter.customerName != null ? ' - ${_filter.customerName!}' : ''}',
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

  Future<void> _exportExcel(List<OmsetDetail> _) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final items = await _allFilteredTransactionsForExport();
      if (items.isEmpty) {
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Tidak ada transaksi sesuai filter aktif',
            isError: true,
          );
        }
        return;
      }
      final document = _buildExportDocument(items, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'laporan_transaksi_${ReportExportBuilder.formatFileDate(_startDate)}_sd_${ReportExportBuilder.formatFileDate(_endDate)}_${_statusFileLabel()}${_filter.customerName != null ? '_${_filter.customerName!.toLowerCase().replaceAll(' ', '_')}' : ''}.xlsx',
        shareTitle:
            'Laporan Transaksi ${_statusTitleLabel()}${_filter.customerName != null ? ' - ${_filter.customerName!}' : ''}',
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
      'read_transaction',
    );
    return Consumer<LaporanProvider>(
      builder: (context, provider, _) {
        final transactions = provider.allTransactions;
        final filtered = _filterTransactions(transactions);
        final grouped = _groupTransactionsByDate(filtered);

        // Pakai agregat dari server (mencakup SELURUH data terfilter, bukan
        // hanya halaman yang sudah dimuat). Status order & status pembayaran
        // sudah difilter server, jadi header-nya akurat. Hanya jatuh ke hitung
        // lokal bila ada filter yang MURNI sisi-klien: pencarian teks, metode
        // pembayaran, atau status "DP" (yang tidak didukung server).
        final header = provider.allTransactionsHeader;
        final bool hasClientOnlyFilter =
            _filter.metodePembayaran.isNotEmpty ||
            _filter.statusPembayaran.isNotEmpty;
        final bool useLocalTotals =
            header == null || _searchQuery.isNotEmpty || hasClientOnlyFilter;
        final totalTransactions = useLocalTotals
            ? filtered.length
            : header.totalTransaksi;
        final totalRevenue = useLocalTotals
            ? _totalRevenue(filtered)
            : header.totalPendapatan;

        return AppScaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _buildAppBar(filtered),
          body: !canRead
              ? const SafeArea(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: 12),
                    child: ReportAccessPlaceholder(
                      icon: Icons.receipt_long_outlined,
                      title: 'Laporan Transaksi Terkunci',
                      message:
                          'Akun ini belum punya izin untuk melihat data transaksi.',
                      compact: true,
                    ),
                  ),
                )
              : Column(
                  children: [
                    TransactionSummaryRow(
                      totalTransactions: totalTransactions,
                      totalRevenue: totalRevenue,
                      footerLabel: _slimActiveFilterLabel(),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppSearchField(
                              height: 40,
                              onChanged: (q) =>
                                  setState(() => _searchQuery = q),
                              hintText: 'Cari nota atau pelanggan',
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _openFilter,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _filter.hasActiveFilter
                                      ? AppPalette.primary
                                      : Colors.black12,
                                ),
                                boxShadow: AppShadows.cardSoft,
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: _filter.hasActiveFilter
                                    ? const Color(0xFFE53935)
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildContent(provider, grouped)),
                  ],
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: TransactionRingkasanBar(
                onTap: () {
                  TransactionSummaryModal.show(
                    context,
                    transactions: filtered,
                    startDate: _startDate,
                    endDate: _endDate,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<OmsetDetail> filteredItems) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Semua Data Transaksi',
        style: TextStyle(color: Colors.black87, fontSize: 16),
      ),
      actions: [
        IconButton(
          onPressed: _isExporting
              ? null
              : () => _showExportSheet(filteredItems),
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
    );
  }

  Widget _buildContent(
    LaporanProvider provider,
    Map<String, List<OmsetDetail>> grouped,
  ) {
    if (provider.isLoading) {
      return const AllTransactionsSkeleton();
    }

    if (provider.errorMessage != null) {
      return _ErrorState(
        message: provider.errorMessage!,
        onRetry: _fetchTransactions,
      );
    }

    if (grouped.isEmpty) {
      return const TransactionEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFFE53935),
      onRefresh: _fetchTransactions,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          for (final entry in grouped.entries) ...[
            TransactionDateHeader(label: entry.key),
            for (final trx in entry.value)
              TransactionCard(item: trx, onDetail: _fetchTransactions),
          ],
          if (provider.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ),
        ],
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
