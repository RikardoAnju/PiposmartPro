import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/report_export_builder.dart';
import '../../../core/utils/report_export_service.dart';
import '../../../shared/widgets/report_download_sheet.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../report/widgets/report_error_view.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../data/models/customer_deposit_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/customer_deposit_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import 'package:intl/intl.dart';
import '../../status/detail/detail_orderan_sereen.dart';
import '../../report/deposit/deposit_period_filter_sheet.dart';
import 'widgets/customer_deposit_receipt_share.dart';
import 'customer_deposit_adjustment_screen.dart';

class CustomerDepositHistoryScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDepositHistoryScreen({super.key, required this.customer});

  @override
  State<CustomerDepositHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<CustomerDepositHistoryScreen> {
  int selectedTab = 0;
  static const tabs = [
    'Semua',
    'Top Up',
    'Pemakaian',
    'Koreksi',
    'Pengembalian',
  ];
  final _searchController = TextEditingController();
  String _query = '';
  DateTime _start = DateTime.now().subtract(const Duration(days: 6));
  DateTime _end = DateTime.now();
  bool _isExporting = false;
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppPageBar(
        title: 'Riwayat ${widget.customer.name}',
        exportTooltip: 'Export riwayat',
        onExport: _showExportSheet,
        isExporting: _isExporting,
      ),
      body: Consumer<CustomerDepositProvider>(
        builder: (context, provider, child) {
          if (provider.loading && !provider.hasLoaded) {
            return const _DepositHistorySkeleton();
          }
          if (provider.errorMessage != null && provider.ledger.isEmpty) {
            return ReportErrorView(
              message: provider.errorMessage!,
              onRetry: _fetchHistory,
              color: AppPalette.primary,
            );
          }
          final entries = provider.ledger
              .where(_matchesPeriod)
              .where(_matchesTab)
              .where(_matchesQuery)
              .toList();
          return Column(
            children: [
              if (provider.loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppPalette.primary,
                  backgroundColor: AppPalette.primaryPale,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SizedBox(width: double.infinity, child: _periodButton()),
              ),
              _buildTabs(provider.ledger.where(_matchesPeriod).toList()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _query = value);
                    _loadRemainingHistory();
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari aktivitas atau petugas',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE4E9EE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE4E9EE)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? _buildEmptyState(provider)
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          MediaQuery.viewPaddingOf(context).bottom + 32,
                        ),
                        itemCount:
                            entries.length + (provider.hasMoreLedger ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == entries.length) {
                            return _loadMoreButton(provider);
                          }
                          return _entryTile(entries[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesPeriod(CustomerDepositLedgerEntry entry) {
    final date = entry.createdAt?.toLocal();
    if (date == null) return false;
    final start = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day, 23, 59, 59, 999);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  Widget _periodButton() => OutlinedButton.icon(
    onPressed: _pickPeriod,
    icon: const Icon(Icons.calendar_today_outlined, size: 16),
    label: Text(
      '${DateFormat('d MMM yyyy', 'id_ID').format(_start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_end)}',
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppPalette.ink,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4E9EE)),
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Future<void> _pickPeriod() async {
    final range = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DepositPeriodFilterSheet(
        initialRange: DateTimeRange(start: _start, end: _end),
      ),
    );
    if (range == null) return;
    setState(() {
      _start = range.start;
      _end = range.end;
    });
    await _fetchHistory();
  }

  Future<void> _fetchHistory({bool append = false}) =>
      context.read<CustomerDepositProvider>().fetchLedger(
        widget.customer.id,
        start: _start,
        end: _end,
        append: append,
      );

  Widget _buildEmptyState(CustomerDepositProvider provider) {
    final lastActivity = provider.lastActivityAt?.toLocal();
    final hasActiveSearchOrTab = _query.trim().isNotEmpty || selectedTab != 0;
    if (lastActivity == null ||
        hasActiveSearchOrTab ||
        !_isDefaultSevenDayRange) {
      return const EmptyStateWidget.laporan(
        title: 'Belum ada aktivitas deposit',
        message: 'Coba ubah periode, pencarian, atau filter aktivitas.',
      );
    }

    return EmptyStateWidget.laporan(
      title: 'Tidak ada aktivitas dalam 7 hari terakhir',
      message:
          'Aktivitas terakhir ${DateFormat('d MMM yyyy', 'id_ID').format(lastActivity)}.',
      actionLabel: 'Tampilkan aktivitas terakhir',
      onAction: () async {
        setState(() {
          _start = DateTime(
            lastActivity.year,
            lastActivity.month,
            lastActivity.day,
          );
          _end = _start;
        });
        await _fetchHistory();
      },
    );
  }

  Widget _loadMoreButton(CustomerDepositProvider provider) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 20),
    child: OutlinedButton(
      onPressed: provider.loading ? null : () => _fetchHistory(append: true),
      child: Text(provider.loading ? 'Memuat...' : 'Muat lebih banyak'),
    ),
  );

  bool get _isDefaultSevenDayRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day);
    return start == today.subtract(const Duration(days: 6)) && end == today;
  }

  Future<void> _loadRemainingHistory() async {
    final provider = context.read<CustomerDepositProvider>();
    if (provider.loading) return;
    while (mounted && provider.hasMoreLedger) {
      await _fetchHistory(append: true);
    }
  }

  Future<void> _showExportSheet() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ReportDownloadSheet(
      isExporting: _isExporting,
      description:
          'Download mutasi ${widget.customer.name} sesuai periode dan filter aktif.',
      onExportPdf: () {
        Navigator.pop(sheetContext);
        _export(pdf: true);
      },
      onExportExcel: () {
        Navigator.pop(sheetContext);
        _export(pdf: false);
      },
    ),
  );

  Future<void> _export({required bool pdf}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final allRows = await context
          .read<CustomerDepositProvider>()
          .fetchAllLedger(widget.customer.id, start: _start, end: _end);
      final rows = allRows
          .where(_matchesPeriod)
          .where(_matchesTab)
          .where(_matchesQuery)
          .toList();
      final logo = pdf ? await ReportExportService.loadLogoBytes() : null;
      if (!mounted) return;
      final doc = _buildExportDocument(rows, logo);
      final safeName = ReportExportBuilder.sanitizeText(
        widget.customer.name,
      ).replaceAll(' ', '_').toLowerCase();
      final extension = pdf ? 'pdf' : 'xlsx';
      final fileName =
          'riwayat_deposit_${safeName}_${ReportExportBuilder.formatFileDate(_start)}_sd_${ReportExportBuilder.formatFileDate(_end)}.$extension';
      if (pdf) {
        await ReportExportService.exportPdf(
          context: context,
          document: doc,
          fileName: fileName,
          shareTitle: 'Riwayat Deposit ${widget.customer.name}',
        );
      } else {
        await ReportExportService.exportExcel(
          context: context,
          document: doc,
          fileName: fileName,
          shareTitle: 'Riwayat Deposit ${widget.customer.name}',
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  ReportPdfDocument _buildExportDocument(
    List<CustomerDepositLedgerEntry> rows,
    Uint8List? logo,
  ) {
    double total(String activity, String type) {
      final result = rows.where((e) => e.depositType == type).fold<double>(0, (
        sum,
        e,
      ) {
        if (activity == 'TOP_UP') {
          if (e.entryType == 'TOP_UP' || e.entryType == 'CORRECTION') {
            return sum + e.amount;
          }
          if (e.entryType == 'REFUND') return sum - e.amount;
        }
        if (activity == 'USAGE') {
          if (e.entryType == 'USAGE') return sum + e.amount;
          if (e.entryType == 'USAGE_REVERSAL') return sum - e.amount;
        }
        return sum;
      });
      return result < 0 ? 0 : result;
    }

    String activityLabel(String value) => value == 'CORRECTION'
        ? 'Koreksi Deposit'
        : value == 'TOP_UP'
        ? 'Top Up Deposit'
        : value == 'REFUND'
        ? 'Pengembalian Deposit'
        : value == 'USAGE_REVERSAL'
        ? 'Pembatalan Pemakaian'
        : 'Pemakaian Deposit';
    String typeLabel(String value) => value == 'KG' ? 'Kiloan' : 'Rupiah';
    String amount(CustomerDepositLedgerEntry e) => e.depositType == 'KG'
        ? '${formatCompactQuantity(e.amount)} Kg'
        : _money.format(e.amount);
    String balance(CustomerDepositLedgerEntry e) => e.depositType == 'KG'
        ? '${formatCompactQuantity(e.balanceAfter)} Kg'
        : _money.format(e.balanceAfter);

    return ReportPdfDocument(
      title: 'Riwayat Deposit ${widget.customer.name}',
      subtitle: 'Mutasi deposit pelanggan sesuai periode dan filter aktif.',
      periodLabel: 'Periode Riwayat Deposit',
      rangeLabel: ReportExportBuilder.formatDateRange(_start, _end),
      filterLabel: selectedTab == 0 ? 'Semua aktivitas' : tabs[selectedTab],
      primaryValue: '${rows.length} Aktivitas',
      primaryCaption: 'Total mutasi dalam periode',
      metrics: [
        ReportPdfMetric(
          title: 'Top Up Rupiah',
          value: _money.format(total('TOP_UP', 'RUPIAH')),
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
        ReportPdfMetric(
          title: 'Top Up Kiloan',
          value: '${formatCompactQuantity(total('TOP_UP', 'KG'))} Kg',
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
        ReportPdfMetric(
          title: 'Pemakaian Rupiah',
          value: _money.format(total('USAGE', 'RUPIAH')),
          background: PdfColor.fromHex('#FFF0ED'),
          accent: PdfColor.fromHex('#FF6B4A'),
        ),
        ReportPdfMetric(
          title: 'Pemakaian Kiloan',
          value: '${formatCompactQuantity(total('USAGE', 'KG'))} Kg',
          background: PdfColor.fromHex('#FFF0ED'),
          accent: PdfColor.fromHex('#FF6B4A'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Mutasi Deposit',
          subtitle: 'Pelanggan: ${widget.customer.name}',
          headers: const [
            'Waktu',
            'Aktivitas',
            'Jenis',
            'Nilai',
            'Saldo Setelah',
            'Petugas',
          ],
          rows: rows
              .map(
                (e) => [
                  e.createdAt == null
                      ? '-'
                      : DateFormat(
                          'dd MMM yyyy HH:mm',
                          'id_ID',
                        ).format(e.createdAt!.toLocal()),
                  activityLabel(e.entryType),
                  typeLabel(e.depositType),
                  amount(e),
                  balance(e),
                  e.createdByName.trim().isEmpty ? 'Sistem' : e.createdByName,
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logo,
    );
  }

  bool _matchesTab(CustomerDepositLedgerEntry entry) {
    if (selectedTab == 0) return true;
    if (selectedTab == 1) {
      return entry.entryType == 'TOP_UP';
    }
    if (selectedTab == 2) return entry.entryType == 'USAGE';
    if (selectedTab == 3) return entry.entryType == 'CORRECTION';
    return entry.entryType == 'REFUND';
  }

  bool _matchesQuery(CustomerDepositLedgerEntry entry) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final activity = entry.entryType == 'CORRECTION'
        ? 'koreksi deposit'
        : entry.entryType == 'TOP_UP'
        ? 'top up deposit'
        : entry.entryType == 'REFUND'
        ? 'pengembalian deposit'
        : entry.entryType == 'USAGE_REVERSAL'
        ? 'pembatalan pemakaian'
        : 'pemakaian deposit';
    return activity.contains(query) ||
        entry.depositType.toLowerCase().contains(query) ||
        entry.createdByName.toLowerCase().contains(query);
  }

  Widget _buildTabs(
    List<CustomerDepositLedgerEntry> ledger,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: List.generate(tabs.length, (index) {
        final count = index == 0
            ? ledger.length
            : ledger.where((entry) {
                return index == 1
                    ? entry.entryType == 'TOP_UP'
                    : index == 2
                    ? entry.entryType == 'USAGE'
                    : index == 3
                    ? entry.entryType == 'CORRECTION'
                    : entry.entryType == 'REFUND';
              }).length;
        final selected = selectedTab == index;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('${tabs[index]}  $count'),
            selected: selected,
            onSelected: (_) {
              setState(() => selectedTab = index);
              _loadRemainingHistory();
            },
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppPalette.ink,
              fontSize: 12,
              fontWeight: AppFont.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            backgroundColor: Colors.white,
            selectedColor: AppPalette.primary,
            side: BorderSide(
              color: selected ? AppPalette.primary : const Color(0xFFE1E7ED),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      }),
    ),
  );

  Widget _entryTile(CustomerDepositLedgerEntry entry) {
    final isTopUp = entry.entryType == 'TOP_UP';
    final isRefund = entry.entryType == 'REFUND';
    final isUsageReversal = entry.entryType == 'USAGE_REVERSAL';
    final isCorrection = entry.entryType == 'CORRECTION';
    final title = isCorrection
        ? 'Koreksi Deposit'
        : isTopUp
        ? 'Top Up Deposit'
        : isRefund
        ? 'Pengembalian Deposit'
        : isUsageReversal
        ? 'Pembatalan Pemakaian'
        : 'Pemakaian Deposit';
    final icon = isCorrection
        ? Icons.edit_note_rounded
        : isTopUp
        ? Icons.north_east_rounded
        : isRefund
        ? Icons.replay_rounded
        : isUsageReversal
        ? Icons.undo_rounded
        : Icons.receipt_long_rounded;
    final balanceDelta = isTopUp
        ? entry.amount.abs()
        : isCorrection
        ? entry.amount
        : isUsageReversal
        ? entry.amount.abs()
        : -entry.amount.abs();
    final positive = balanceDelta > 0;
    final signedAmount = balanceDelta > 0
        ? '+${_formatAmount(balanceDelta, entry.depositType)}'
        : balanceDelta < 0
        ? '-${_formatAmount(balanceDelta.abs(), entry.depositType)}'
        : _formatAmount(0, entry.depositType);
    final cash = entry.paidAmount;
    final cashLabel = cash > 0
        ? 'Uang diterima ${_formatAmount(cash, 'RUPIAH')}'
        : cash < 0
        ? 'Uang dikembalikan ${_formatAmount(cash.abs(), 'RUPIAH')}'
        : 'Tidak ada perpindahan uang';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () => _openDetailPage(entry),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: positive
                        ? const Color(0xFFEAF9F0)
                        : const Color(0xFFFFEDEF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: positive
                        ? const Color(0xFF22B35B)
                        : const Color(0xFFFF1E2D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppPalette.ink,
                          fontSize: 14,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (entry.createdAt != null)
                        Text(
                          '${entry.depositType == 'KG' ? 'Deposit Kg' : 'Deposit Rupiah'} • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(entry.createdAt!.toLocal())}',
                          style: const TextStyle(
                            color: Color(0xFF9AA4AE),
                            fontSize: 10,
                          ),
                        ),
                      if (entry.createdByName.isNotEmpty)
                        Text(
                          'Oleh ${entry.createdByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        cashLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cash > 0
                              ? AppPalette.success
                              : cash < 0
                              ? AppPalette.danger
                              : AppPalette.muted,
                          fontSize: 10,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  signedAmount,
                  style: TextStyle(
                    color: positive
                        ? const Color(0xFF00A844)
                        : const Color(0xFFFF1525),
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount, String type) {
    if (type.toUpperCase() == 'KG') {
      return '${formatCompactQuantity(amount)} Kg';
    }
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _openDetailPage(CustomerDepositLedgerEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDepositDetailScreen(
          customer: widget.customer,
          entry: entry,
        ),
      ),
    );
    if (mounted) {
      await _fetchHistory();
    }
  }

  // Legacy dialog retained for backward compatibility; history now opens the
  // dedicated detail screen through _openDetailPage.
  // ignore: unused_element
  void _showDetail(CustomerDepositLedgerEntry entry) {
    final isTopUp = entry.entryType == 'TOP_UP';
    final isRefund = entry.entryType == 'REFUND';
    final isUsageReversal = entry.entryType == 'USAGE_REVERSAL';
    final isCorrection = entry.entryType == 'CORRECTION';
    final title = isCorrection
        ? 'Detail Koreksi'
        : isTopUp
        ? 'Detail Top Up'
        : isRefund
        ? 'Detail Pengembalian'
        : isUsageReversal
        ? 'Detail Pembatalan Pemakaian'
        : 'Detail Pemakaian';
    final statusTitle = isTopUp
        ? 'Top Up Deposit Berhasil'
        : isRefund
        ? 'Pengembalian Deposit'
        : 'Pemakaian Deposit Berhasil';
    final icon = entry.entryType == 'CORRECTION'
        ? Icons.edit_note_rounded
        : isTopUp
        ? Icons.check_rounded
        : isRefund
        ? Icons.replay_rounded
        : Icons.receipt_long_rounded;
    final iconColor = isTopUp || isRefund
        ? const Color(0xFF27A957)
        : const Color(0xFFFF2635);
    final deltaPrefix = isTopUp || isRefund ? '+' : '-';
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppPalette.ink,
                          fontSize: 16,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isTopUp || isRefund
                        ? const Color(0xFFE7F7EC)
                        : const Color(0xFFFFEAED),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 27),
                ),
                const SizedBox(height: 12),
                Text(
                  statusTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 15,
                    fontWeight: AppFont.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.createdAt == null
                      ? '-'
                      : DateFormat(
                          'dd MMMM yyyy, HH:mm',
                          'id_ID',
                        ).format(entry.createdAt!.toLocal()),
                  style: const TextStyle(
                    color: Color(0xFF7F8992),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'DETAIL TRANSAKSI',
                          style: TextStyle(
                            color: Color(0xFF566982),
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailLine('Pelanggan', widget.customer.name),
                      _detailLine(
                        'No. Transaksi',
                        entry.referenceId.isEmpty ? '-' : entry.referenceId,
                      ),
                      _detailLine('Jenis Deposit', entry.depositType),
                      _detailLine(
                        'Metode Pembayaran',
                        entry.paymentMethod.isEmpty
                            ? 'Manual'
                            : entry.paymentMethod,
                      ),
                      const Divider(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isRefund
                              ? 'SALDO DIKEMBALIKAN'
                              : isTopUp
                              ? 'SALDO DITAMBAHKAN'
                              : 'SALDO DIGUNAKAN',
                          style: const TextStyle(
                            color: Color(0xFF566982),
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailLine(
                        entry.depositType,
                        '$deltaPrefix${_formatAmount(entry.amount, entry.depositType)}',
                        valueColor: iconColor,
                      ),
                      const Divider(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isRefund
                              ? 'SALDO SETELAH PENGEMBALIAN'
                              : isTopUp
                              ? 'SALDO SETELAH TOP UP'
                              : 'SALDO SETELAH PEMAKAIAN',
                          style: const TextStyle(
                            color: Color(0xFF566982),
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailLine(
                        entry.depositType,
                        _formatAmount(entry.balanceAfter, entry.depositType),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Kembali',
                      style: TextStyle(fontSize: 12, fontWeight: AppFont.w600),
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

  Widget _detailLine(
    String label,
    String value, {
    Color valueColor = AppPalette.ink,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF806F6C), fontSize: 10),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DepositHistorySkeleton extends StatelessWidget {
  const _DepositHistorySkeleton();

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: const [
        AppSkeletonBox(height: 46, radius: 12),
        SizedBox(height: 12),
        Row(
          children: [
            AppSkeletonBox(width: 84, height: 34, radius: 17),
            SizedBox(width: 8),
            AppSkeletonBox(width: 84, height: 34, radius: 17),
            SizedBox(width: 8),
            AppSkeletonBox(width: 96, height: 34, radius: 17),
          ],
        ),
        SizedBox(height: 12),
        AppSkeletonBox(height: 48, radius: 12),
        SizedBox(height: 18),
        AppSkeletonBox(height: 92, radius: 16),
        SizedBox(height: 10),
        AppSkeletonBox(height: 92, radius: 16),
        SizedBox(height: 10),
        AppSkeletonBox(height: 92, radius: 16),
      ],
    ),
  );
}

class CustomerDepositDetailScreen extends StatefulWidget {
  final Customer customer;
  final CustomerDepositLedgerEntry entry;

  const CustomerDepositDetailScreen({
    super.key,
    required this.customer,
    required this.entry,
  });

  @override
  State<CustomerDepositDetailScreen> createState() =>
      _CustomerDepositDetailScreenState();
}

class _CustomerDepositDetailScreenState
    extends State<CustomerDepositDetailScreen> {
  Customer get customer => widget.customer;
  CustomerDepositLedgerEntry get entry => widget.entry;
  Future<Map<String, dynamic>>? _adjustmentState;

  @override
  void initState() {
    super.initState();
    if (entry.entryType == 'TOP_UP' && entry.referenceId.isNotEmpty) {
      _adjustmentState = context
          .read<CustomerDepositProvider>()
          .adjustmentState(customer.id, entry.referenceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTopUp = entry.entryType == 'TOP_UP';
    final adjustmentState = _adjustmentState;
    final isRefund = entry.entryType == 'REFUND';
    final isUsageReversal = entry.entryType == 'USAGE_REVERSAL';
    final isCorrection = entry.entryType == 'CORRECTION';
    final title = isCorrection
        ? 'Detail Koreksi'
        : isTopUp
        ? 'Detail Top Up'
        : isRefund
        ? 'Detail Pengembalian'
        : isUsageReversal
        ? 'Detail Pembatalan Pemakaian'
        : 'Detail Pemakaian';
    final balanceDelta = _balanceDelta;
    final cashDelta = entry.paidAmount;
    final color = balanceDelta > 0
        ? AppPalette.success
        : balanceDelta < 0
        ? AppPalette.danger
        : AppPalette.muted;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppPageBar(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        children: [
          _buildTransactionHero(title, balanceDelta),
          const SizedBox(height: 14),
          _buildCashCard(cashDelta),
          const SizedBox(height: 14),
          _buildTransactionSummary(context, color),
          if (adjustmentState != null)
            FutureBuilder<Map<String, dynamic>>(
              future: adjustmentState,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _adjustmentLoadError();
                }
                final state = snapshot.data;
                if (state == null) return const SizedBox.shrink();
                return _buildTopUpTimeline(state);
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTopUp &&
                  entry.referenceId.isNotEmpty &&
                  context.watch<AuthProvider>().isOwnerOrAdmin) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerDepositAdjustmentScreen(
                            customer: customer,
                            topupId: entry.referenceId,
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('KOREKSI / REFUND'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (isTopUp) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      Map<String, dynamic> state;
                      try {
                        state = await context
                            .read<CustomerDepositProvider>()
                            .adjustmentState(customer.id, entry.referenceId);
                      } catch (_) {
                        if (!context.mounted) return;
                        CustomToast.show(
                          context,
                          message:
                              'Status koreksi belum dapat diperiksa. Coba lagi.',
                          isError: true,
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      await CustomerDepositReceiptShare.send(
                        context: context,
                        customerName: customer.name,
                        customerPhone: customer.phone,
                        title: 'TOP UP DEPOSIT',
                        amount: _signedAmount(balanceDelta),
                        depositType: entry.depositType == 'KG'
                            ? 'Deposit Kg'
                            : 'Deposit Rupiah',
                        createdAt: entry.createdAt == null
                            ? '-'
                            : DateFormat(
                                'dd MMM yyyy, HH:mm',
                                'id_ID',
                              ).format(entry.createdAt!.toLocal()),
                        balanceAfter: _amount(entry.balanceAfter),
                        cashAmount: _cash(entry.paidAmount),
                        paymentMethod: entry.paymentMethod,
                        createdBy: entry.createdByName.trim().isEmpty
                            ? 'Sistem'
                            : entry.createdByName,
                        note: entry.note,
                        adjustmentNote: _shareAdjustmentSummary(state),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const Text(
                      'KIRIM KE WHATSAPP',
                      style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.ink,
                    side: const BorderSide(color: Color(0xFFD9E2EA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: const Text(
                    'Kembali',
                    style: TextStyle(fontSize: 14, fontWeight: AppFont.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _balanceDelta {
    if (entry.entryType == 'TOP_UP') return entry.amount.abs();
    if (entry.entryType == 'CORRECTION') return entry.amount;
    if (entry.entryType == 'USAGE_REVERSAL') return entry.amount.abs();
    return -entry.amount.abs();
  }

  String _signedAmount(double value) => value > 0
      ? '+${_amount(value)}'
      : value < 0
      ? '-${_amount(value.abs())}'
      : _amount(0);

  String _signedCash(double value) => value > 0
      ? '+${_cash(value)}'
      : value < 0
      ? '-${_cash(value.abs())}'
      : _cash(0);

  Widget _buildTransactionHero(String title, double balanceDelta) {
    final isTopUp = entry.entryType == 'TOP_UP';
    final isRefund = entry.entryType == 'REFUND';
    final isUsageReversal = entry.entryType == 'USAGE_REVERSAL';
    final icon = entry.entryType == 'CORRECTION'
        ? Icons.edit_note_rounded
        : isTopUp
        ? Icons.account_balance_wallet_outlined
        : isRefund
        ? Icons.settings_backup_restore_rounded
        : isUsageReversal
        ? Icons.undo_rounded
        : Icons.shopping_bag_outlined;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppPalette.primaryWarm.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .22)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: AppFont.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            balanceDelta > 0
                ? 'Saldo deposit bertambah'
                : balanceDelta < 0
                ? 'Saldo deposit berkurang'
                : 'Saldo deposit tidak berubah',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 7),
          Text(
            _signedAmount(balanceDelta),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: AppFont.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCard(double cashDelta) {
    final isTopUp = entry.entryType == 'TOP_UP';
    final isUsage = entry.entryType == 'USAGE';
    final cashTitle = cashDelta > 0
        ? 'Uang diterima'
        : cashDelta < 0
        ? 'Uang dikembalikan'
        : 'Tidak ada perpindahan uang';
    final cashColor = cashDelta > 0
        ? AppPalette.success
        : cashDelta < 0
        ? AppPalette.danger
        : AppPalette.muted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'UANG PADA TRANSAKSI INI',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 11,
              fontWeight: AppFont.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cashColor.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  cashDelta > 0
                      ? Icons.south_west_rounded
                      : cashDelta < 0
                      ? Icons.north_east_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: cashColor,
                  size: 23,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cashTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 14,
                  fontWeight: AppFont.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _signedCash(cashDelta),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cashColor,
                  fontSize: 22,
                  fontWeight: AppFont.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
          if (cashDelta != 0 && entry.paymentMethod.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _line('Metode pembayaran', entry.paymentMethod.trim()),
          ],
          if (isUsage) ...[
            const SizedBox(height: 8),
            const Text(
              'Pemakaian ini menggunakan saldo deposit. Pembayaran lain, bila ada, tercatat di pesanan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else if (cashDelta == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Mutasi saldo ini tidak disertai uang masuk atau keluar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (isTopUp && entry.discountAmount > 0) ...[
            const Divider(height: 20),
            _line('Diskon program deposit', _cash(entry.discountAmount)),
          ],
        ],
      ),
    );
  }

  Widget _adjustmentLoadError() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat penyesuaian belum dapat dimuat',
            style: TextStyle(color: AppPalette.ink, fontWeight: AppFont.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Rincian top up awal tetap dapat dilihat di atas.',
            style: TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
          TextButton(
            onPressed: () => setState(() {
              _adjustmentState = context
                  .read<CustomerDepositProvider>()
                  .adjustmentState(customer.id, entry.referenceId);
            }),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _buildTopUpTimeline(Map<String, dynamic> state) {
    final currentValue = (state['current_value'] as num?)?.toDouble();
    final currentPaid = (state['current_paid'] as num?)?.toDouble();
    final eventMaps = (state['events'] as List?) ?? const [];
    final events = eventMaps
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final adjustmentCount =
        (state['adjustment_count'] as num?)?.toInt() ?? events.length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adjustmentCount > 0 &&
              currentValue != null &&
              currentPaid != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOP UP INI SUDAH DISESUAIKAN',
                    style: TextStyle(
                      color: AppPalette.primaryDeep,
                      fontSize: 12,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _line(
                    'Nilai top up setelah penyesuaian',
                    _amount(currentValue),
                  ),
                  _line('Total uang bersih rangkaian ini', _cash(currentPaid)),
                  const SizedBox(height: 6),
                  const Text(
                    'Angka di atas adalah hasil top up awal beserta koreksi/refund terkait, bukan saldo dompet pelanggan saat ini.',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            decoration: AppDecorations.card(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RIWAYAT TOP UP INI',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 12,
                    fontWeight: AppFont.w700,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perubahan deposit dan uang aktual dicatat terpisah pada tiap peristiwa.',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _timelineEvent(
                  title: 'Top up awal',
                  date: entry.createdAt,
                  actor: entry.createdByName,
                  balanceDelta: entry.amount.abs(),
                  cashDelta: entry.paidAmount,
                  method: entry.paymentMethod,
                  note: entry.note,
                ),
                for (final event in events) ...[
                  const Divider(height: 16),
                  _timelineEvent(
                    title: event['kind'] == 'REFUND' ? 'Refund' : 'Koreksi',
                    date: DateTime.tryParse('${event['created_at'] ?? ''}'),
                    actor: '${event['created_by_name'] ?? ''}',
                    balanceDelta:
                        (event['value_delta'] as num?)?.toDouble() ?? 0,
                    cashDelta: (event['cash_delta'] as num?)?.toDouble() ?? 0,
                    method: '${event['payment_method'] ?? ''}',
                    note: '${event['note'] ?? ''}',
                  ),
                ],
                if (adjustmentCount > 0 && events.isEmpty) ...[
                  const Divider(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Rincian penyesuaian belum tersedia. Lihat riwayat deposit pelanggan.',
                      style: TextStyle(color: AppPalette.muted, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineEvent({
    required String title,
    required DateTime? date,
    required String actor,
    required double balanceDelta,
    required double cashDelta,
    required String method,
    required String note,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 14,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _dateText(date),
          style: const TextStyle(color: AppPalette.muted, fontSize: 11),
        ),
        if (actor.trim().isNotEmpty)
          Text(
            'Oleh ${actor.trim()}',
            style: const TextStyle(color: AppPalette.muted, fontSize: 11),
          ),
        const SizedBox(height: 8),
        _line(
          _depositMovementLabel(balanceDelta),
          _signedAmount(balanceDelta),
          valueColor: balanceDelta > 0
              ? AppPalette.success
              : balanceDelta < 0
              ? AppPalette.danger
              : AppPalette.muted,
        ),
        _line(
          _cashMovementLabel(cashDelta),
          _signedCash(cashDelta),
          valueColor: cashDelta > 0
              ? AppPalette.success
              : cashDelta < 0
              ? AppPalette.danger
              : AppPalette.muted,
        ),
        if (cashDelta != 0 && method.trim().isNotEmpty)
          _line('Metode pembayaran', method.trim()),
        if (note.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Catatan: ${note.trim()}',
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
      ],
    ),
  );

  String _dateText(DateTime? value) => value == null
      ? '-'
      : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value.toLocal());

  String _depositMovementLabel(double value) {
    if (value > 0) return 'Deposit ditambahkan';
    if (value < 0) return 'Deposit dikurangi';
    return 'Deposit tidak berubah';
  }

  String _cashMovementLabel(double value) {
    if (value > 0) return 'Uang diterima';
    if (value < 0) return 'Uang dikembalikan';
    return 'Tidak ada perpindahan uang';
  }

  String _shareAdjustmentSummary(Map<String, dynamic> state) {
    final count = (state['adjustment_count'] as num?)?.toInt() ?? 0;
    if (count == 0) return '';
    final currentValue = (state['current_value'] as num?)?.toDouble();
    final currentPaid = (state['current_paid'] as num?)?.toDouble();
    final lines = <String>[
      'Bukti ini mencatat top up awal, sebelum penyesuaian berikutnya.',
      if (currentValue != null)
        'Nilai top up setelah penyesuaian: ${_amount(currentValue)}',
      if (currentPaid != null)
        'Total uang bersih rangkaian top up ini: ${_cash(currentPaid)}',
    ];
    final events = (state['events'] as List?) ?? const [];
    for (final raw in events.whereType<Map>()) {
      final event = Map<String, dynamic>.from(raw);
      final balance = (event['value_delta'] as num?)?.toDouble() ?? 0;
      final cash = (event['cash_delta'] as num?)?.toDouble() ?? 0;
      final label = event['kind'] == 'REFUND' ? 'Refund' : 'Koreksi';
      final method = '${event['payment_method'] ?? ''}'.trim();
      lines.add(
        '$label (${_dateText(DateTime.tryParse('${event['created_at'] ?? ''}'))}): saldo ${_signedAmount(balance)}, kas ${_signedCash(cash)}${cash != 0 && method.isNotEmpty ? ' via $method' : ''}',
      );
    }
    return lines.join('\n');
  }

  Widget _buildTransactionSummary(BuildContext context, Color color) {
    final actor = entry.createdByName.trim().isEmpty
        ? 'Sistem'
        : entry.createdByName;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'RINCIAN TRANSAKSI',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: AppFont.w700,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _line('Pelanggan', customer.name),
          _line('Dibuat oleh', actor),
          _line(
            'Jenis saldo',
            entry.depositType == 'KG' ? 'Deposit Kg' : 'Deposit Rupiah',
          ),
          _line(
            'Waktu',
            entry.createdAt == null
                ? '-'
                : DateFormat(
                    'dd MMM yyyy, HH:mm',
                    'id_ID',
                  ).format(entry.createdAt!.toLocal()),
          ),
          const Divider(height: 18),
          _line('Saldo sebelum', _amount(entry.balanceBefore)),
          _line(
            'Saldo sesudah',
            _amount(entry.balanceAfter),
            valueColor: AppPalette.primaryDeep,
            emphasize: true,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saldo ini adalah kondisi pada waktu transaksi, bukan saldo pelanggan saat ini.',
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
          if (entry.note.trim().isNotEmpty) _noteBlock(entry.note.trim()),
          if (entry.entryType == 'USAGE' &&
              entry.referenceId.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _relatedOrderButton(context),
          ],
        ],
      ),
    );
  }

  Widget _relatedOrderButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DetailPesananScreen(transactionId: entry.referenceId),
            ),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Lihat Pesanan Terkait'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.primary,
            side: const BorderSide(color: AppPalette.primary),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontSize: 13, fontWeight: AppFont.w700),
          ),
        ),
      ),
    );
  }

  Widget _noteBlock(String note) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8, bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE8EDF0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan',
          style: TextStyle(
            color: Color(0xFF806F6C),
            fontSize: 14,
            fontWeight: AppFont.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 14,
            fontWeight: AppFont.w600,
            height: 1.35,
          ),
        ),
      ],
    ),
  );

  Widget _line(
    String label,
    String value, {
    Color valueColor = AppPalette.ink,
    bool emphasize = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 16.5;
      final stack = largeText || constraints.maxWidth < 300;
      const labelStyle = TextStyle(
        color: Color(0xFF806F6C),
        fontSize: 14,
        fontWeight: AppFont.w500,
        height: 1.3,
      );
      final valueStyle = TextStyle(
        color: valueColor,
        fontSize: emphasize ? 16 : 14,
        fontWeight: emphasize ? AppFont.w700 : AppFont.w600,
        height: 1.3,
      );
      if (stack) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              Text(value, style: valueStyle),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(label, style: labelStyle)),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: Text(value, textAlign: TextAlign.right, style: valueStyle),
            ),
          ],
        ),
      );
    },
  );

  String _amount(double value) => entry.depositType.toUpperCase() == 'KG'
      ? '${formatCompactQuantity(value)} Kg'
      : NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp',
          decimalDigits: 0,
        ).format(value);

  String _cash(double value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  ).format(value);
}
