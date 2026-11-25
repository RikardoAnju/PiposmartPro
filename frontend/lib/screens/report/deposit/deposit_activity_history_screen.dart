import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/report_export_builder.dart';
import '../../../core/utils/report_export_service.dart';
import '../../../data/models/customer_deposit_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/deposit_report_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/deposit_report_provider.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/report_download_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../widgets/report_error_view.dart';
import '../../operational/customer/customer_deposit_history_screen.dart';
import 'deposit_period_filter_sheet.dart';
import 'widgets/deposit_activity_card.dart';

class DepositActivityHistoryScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DepositActivityHistoryScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<DepositActivityHistoryScreen> createState() =>
      _DepositActivityHistoryScreenState();
}

class _HistoryFilterResult {
  final String depositType;
  final Customer? customer;
  final DateTimeRange period;

  const _HistoryFilterResult({
    required this.depositType,
    required this.customer,
    required this.period,
  });
}

InputDecoration _historyFilterInputDecoration() => InputDecoration(
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  filled: true,
  fillColor: Colors.white,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.black.withValues(alpha: .08)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
  ),
);

Widget _historyYearPicker(int year, ValueChanged<int> onChanged) =>
    DropdownButtonFormField<int>(
      initialValue: year,
      isExpanded: true,
      decoration: _historyFilterInputDecoration(),
      items: List.generate(4, (index) => DateTime.now().year - index)
          .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
          .toList(),
      onChanged: (value) => onChanged(value ?? year),
    );

Widget _historyDateField({
  required String label,
  required DateTime value,
  required VoidCallback onTap,
}) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(14),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppPalette.primary.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.calendar_month_rounded,
          size: 16,
          color: AppPalette.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: AppFont.w700,
                  color: Color(0xFF9B8E88),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMMM yyyy', 'id_ID').format(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: AppFont.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

class _HistoryFilterSheet extends StatefulWidget {
  final String depositType;
  final Customer? selectedCustomer;
  final List<Customer> customers;
  final DateTimeRange initialPeriod;

  const _HistoryFilterSheet({
    required this.depositType,
    required this.selectedCustomer,
    required this.customers,
    required this.initialPeriod,
  });

  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late String selectedType;
  Customer? customer;
  late DateTimeRange period;
  late DateTime today;
  late DateTime weekStart;
  late String periodMode;
  late int periodMonth;
  late int periodYear;

  @override
  void initState() {
    super.initState();
    selectedType = widget.depositType;
    customer = widget.selectedCustomer;
    period = widget.initialPeriod;
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    weekStart = today.subtract(const Duration(days: 6));
    periodMode = period.start == weekStart && period.end == today
        ? 'Minggu Ini'
        : 'Custom';
    periodMonth = period.start.month;
    periodYear = period.start.year;
  }

  DateTimeRange activePeriod() {
    if (periodMode == 'Bulanan') {
      final start = DateTime(periodYear, periodMonth, 1);
      final end = DateTime(periodYear, periodMonth + 1, 0);
      return DateTimeRange(start: start, end: end.isAfter(today) ? today : end);
    }
    if (periodMode == 'Tahunan') {
      final start = DateTime(periodYear, 1, 1);
      final end = DateTime(periodYear, 12, 31);
      return DateTimeRange(start: start, end: end.isAfter(today) ? today : end);
    }
    if (periodMode == 'Minggu Ini') {
      return DateTimeRange(start: weekStart, end: today);
    }
    return period;
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewPaddingOf(context).bottom + 20,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Laporan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppFont.w900,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            selectedType = '';
                            customer = null;
                            periodMode = 'Minggu Ini';
                            period = DateTimeRange(
                              start: weekStart,
                              end: today,
                            );
                            periodMonth = today.month;
                            periodYear = today.year;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: AppPalette.primary,
                            backgroundColor: AppPalette.primary.withValues(
                              alpha: .08,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: AppFont.w800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Periode Laporan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 54,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const modes = [
                        'Minggu Ini',
                        'Bulanan',
                        'Tahunan',
                        'Custom',
                      ];
                      final selected = modes.indexOf(periodMode).clamp(0, 3);
                      final width = constraints.maxWidth / modes.length;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            left: selected * width,
                            top: 0,
                            bottom: 0,
                            width: width,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Row(
                            children: modes
                                .map(
                                  (mode) => Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() {
                                        final previousPeriod = activePeriod();
                                        periodMode = mode;
                                        if (mode == 'Custom') {
                                          period = previousPeriod;
                                        }
                                      }),
                                      child: Center(
                                        child: Text(
                                          mode,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: AppFont.w900,
                                            color: periodMode == mode
                                                ? AppPalette.primary
                                                : const Color(0xFF999999),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (periodMode == 'Bulanan')
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: periodMonth,
                          isExpanded: true,
                          decoration: _historyFilterInputDecoration(),
                          items:
                              const [
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
                                  ]
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key + 1,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(
                            () => periodMonth = value ?? periodMonth,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _historyYearPicker(periodYear, (value) {
                          setState(() => periodYear = value);
                        }),
                      ),
                    ],
                  )
                else if (periodMode == 'Tahunan')
                  _historyYearPicker(periodYear, (value) {
                    setState(() => periodYear = value);
                  }),
                if (periodMode == 'Bulanan' || periodMode == 'Tahunan')
                  const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _historyDateField(
                        label: 'Tanggal Mulai',
                        value: activePeriod().start,
                        onTap: () async {
                          final selected = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: today,
                            initialDateRange: activePeriod(),
                          );
                          if (selected != null) {
                            setState(() {
                              period = selected;
                              periodMode = 'Custom';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _historyDateField(
                        label: 'Tanggal Selesai',
                        value: activePeriod().end,
                        onTap: () async {
                          final selected = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: today,
                            initialDateRange: activePeriod(),
                          );
                          if (selected != null) {
                            setState(() {
                              period = selected;
                              periodMode = 'Custom';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Jenis saldo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [('Semua', ''), ('Rupiah', 'RUPIAH'), ('Kg', 'KG')]
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.$1),
                          selected: selectedType == item.$2,
                          onSelected: (_) =>
                              setState(() => selectedType = item.$2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pelanggan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selection = await showModalBottomSheet<_CustomerPick>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _CustomerPicker(
                        customers: widget.customers,
                        selectedCustomer: customer,
                      ),
                    );
                    if (selection != null) {
                      setState(() => customer = selection.customer);
                    }
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(
                    customer?.name ?? 'Semua pelanggan',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppPalette.ink,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0xFFE4E9EE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (customer != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => customer = null),
                      child: const Text('Hapus pilihan'),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _HistoryFilterResult(
                        depositType: selectedType,
                        customer: customer,
                        period: activePeriod(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'TERAPKAN FILTER',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w900,
                        color: Colors.white,
                        letterSpacing: .8,
                      ),
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
}

class _CustomerPick {
  final Customer? customer;
  const _CustomerPick(this.customer);
}

class _CustomerPicker extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;

  const _CustomerPicker({
    required this.customers,
    required this.selectedCustomer,
  });

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final customers = widget.customers.where((item) {
      return query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.phone.toLowerCase().contains(query) ||
          item.kode.toLowerCase().contains(query);
    }).toList();
    return Container(
      height: MediaQuery.sizeOf(context).height * .75,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewPaddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 0, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Pelanggan',
                    style: TextStyle(fontSize: 18, fontWeight: AppFont.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black38),
                ),
              ],
            ),
          ),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Cari pelanggan atau nomor WA',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F9FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: customers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final selected = widget.selectedCustomer == null;
                  return _customerTile(
                    title: 'Semua pelanggan',
                    subtitle: 'Tampilkan aktivitas seluruh pelanggan',
                    selected: selected,
                    onTap: () =>
                        Navigator.pop(context, const _CustomerPick(null)),
                  );
                }
                final item = customers[index - 1];
                return _customerTile(
                  title: item.name,
                  subtitle: item.phone.trim().isEmpty
                      ? 'No. WA belum diisi'
                      : item.phone,
                  selected: item.id == widget.selectedCustomer?.id,
                  onTap: () => Navigator.pop(context, _CustomerPick(item)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: selected
          ? AppPalette.primaryPale
          : const Color(0xFFF2F5F7),
      child: Icon(
        title == 'Semua pelanggan'
            ? Icons.people_outline_rounded
            : Icons.person_outline_rounded,
        color: AppPalette.primary,
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: selected ? AppFont.w800 : AppFont.w600,
        color: selected ? AppPalette.primary : AppPalette.ink,
      ),
    ),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: selected
        ? const Icon(Icons.check_circle_rounded, color: AppPalette.primary)
        : null,
  );
}

class _DepositActivityHistoryScreenState
    extends State<DepositActivityHistoryScreen> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('d MMM yyyy', 'id_ID');
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  String _activity = '';
  String _depositType = '';
  String _query = '';
  late DateTime _start;
  late DateTime _end;
  Customer? _selectedCustomer;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _start = widget.startDate;
    _end = widget.endDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool loadMore = false}) =>
      context.read<DepositReportProvider>().fetch(
        startDate: _start,
        endDate: _end,
        activityType: _activity,
        depositType: _depositType,
        customerId: _selectedCustomer?.id,
        loadMore: loadMore,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppPageBar(
        title: 'Riwayat Deposit',
        onExport: _showExportSheet,
        isExporting: _isExporting,
      ),
      body: Consumer<DepositReportProvider>(
        builder: (context, provider, _) {
          final entries = provider.entries.where(_matchesQuery).toList();
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 220 &&
                  !provider.isLoading &&
                  provider.hasMore) {
                _load(loadMore: true);
              }
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewPaddingOf(context).bottom + 116,
              ),
              children: [
                Row(
                  children: [
                    Expanded(child: _periodLabel()),
                    const SizedBox(width: 8),
                    _filterButton(),
                  ],
                ),
                const SizedBox(height: 12),
                if (_depositType.isNotEmpty || _selectedCustomer != null)
                  _activeFilterChips(),
                _searchField(),
                const SizedBox(height: 12),
                _buildTabs(),
                if (provider.isLoading &&
                    provider.hasLoaded &&
                    !provider.isLoadingMore) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppPalette.primary,
                    backgroundColor: AppPalette.primaryPale,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Mutasi Deposit (${entries.length})',
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 16,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (provider.isLoading && !provider.hasLoaded)
                  const _DepositLedgerListSkeleton()
                else if (provider.errorMessage != null && !provider.hasLoaded)
                  ReportErrorView(
                    message: provider.errorMessage!,
                    onRetry: _load,
                    color: AppPalette.primary,
                  )
                else if (entries.isEmpty)
                  const EmptyStateWidget.laporan(
                    title: 'Belum ada aktivitas deposit',
                    message:
                        'Coba ubah periode, pencarian, atau filter aktivitas.',
                  )
                else
                  ...entries.map(
                    (entry) => DepositActivityCard(
                      entry: entry,
                      onTap: () => _openDetail(entry),
                    ),
                  ),
                if (provider.isLoadingMore)
                  const _DepositLedgerLoadMoreSkeleton(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'deposit_summary_fab',
        onPressed: () =>
            _showActivitySummary(context.read<DepositReportProvider>().header),
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.summarize_outlined),
        label: const Text(
          'Ringkasan',
          style: TextStyle(fontWeight: AppFont.w700),
        ),
      ),
    );
  }

  Future<void> _showExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description:
            'Download seluruh mutasi deposit sesuai periode dan filter aktif.',
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
  }

  Future<void> _export({required bool pdf}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final provider = context.read<DepositReportProvider>();
      var entries = await provider.fetchAllForExport(
        startDate: _start,
        endDate: _end,
        activityType: _activity,
        depositType: _depositType,
        customerId: _selectedCustomer?.id,
      );
      if (_query.trim().isNotEmpty) {
        entries = entries.where(_matchesQuery).toList();
      }
      final logoBytes = pdf ? await ReportExportService.loadLogoBytes() : null;
      final document = _buildExportDocument(
        provider.header,
        entries,
        logoBytes,
      );
      if (!mounted) return;
      final extension = pdf ? 'pdf' : 'xlsx';
      final fileName =
          'riwayat_deposit_${ReportExportBuilder.formatFileDate(_start)}_sd_${ReportExportBuilder.formatFileDate(_end)}.$extension';
      if (pdf) {
        await ReportExportService.exportPdf(
          context: context,
          document: document,
          fileName: fileName,
          shareTitle: 'Riwayat Deposit',
        );
      } else {
        await ReportExportService.exportExcel(
          context: context,
          document: document,
          fileName: fileName,
          shareTitle: 'Riwayat Deposit',
        );
      }
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Gagal export riwayat deposit: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  ReportPdfDocument _buildExportDocument(
    DepositReportHeader header,
    List<DepositReportEntry> entries,
    Uint8List? logoBytes,
  ) {
    String amount(DepositReportEntry item) {
      final prefix =
          item.activityType == 'TOP_UP' ||
              item.activityType == 'USAGE_REVERSAL' ||
              (item.activityType == 'CORRECTION' && item.amount >= 0)
          ? '+'
          : item.activityType == 'CORRECTION'
          ? ''
          : '-';
      return item.depositType == 'KG'
          ? '$prefix${formatCompactQuantity(item.amount)} Kg'
          : '$prefix${ReportExportBuilder.formatRupiah(item.amount)}';
    }

    String balance(DepositReportEntry item, double value) =>
        item.depositType == 'KG'
        ? '${formatCompactQuantity(value)} Kg'
        : ReportExportBuilder.formatRupiah(value);

    final filters = <String>[
      _activity.isEmpty
          ? 'Semua aktivitas'
          : _activity == 'TOP_UP'
          ? 'Top Up'
          : _activity == 'CORRECTION'
          ? 'Koreksi'
          : _activity == 'USAGE'
          ? 'Pemakaian'
          : 'Pengembalian',
      if (_depositType.isNotEmpty) _depositType == 'KG' ? 'Kiloan' : 'Rupiah',
      _selectedCustomer?.name ?? 'Semua pelanggan',
    ];

    return ReportPdfDocument(
      title: 'Riwayat Deposit',
      subtitle: 'Mutasi deposit sesuai periode dan filter yang dipilih.',
      periodLabel: 'Periode Aktivitas Deposit',
      rangeLabel: ReportExportBuilder.formatDateRange(_start, _end),
      // Use an ASCII separator because the PDF fallback font may omit the
      // bullet glyph and make adjacent filter values look concatenated.
      filterLabel: filters.join(' | '),
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: '${entries.length}',
      primaryCaption: 'Aktivitas deposit',
      metrics: [
        ReportPdfMetric(
          title: 'Total Top Up Rupiah',
          value: ReportExportBuilder.formatRupiah(header.totalTopUpRupiah),
          background: PdfColor.fromHex(AppPalette.primaryPaleHex),
          accent: PdfColor.fromHex(AppPalette.primaryHex),
        ),
        ReportPdfMetric(
          title: 'Total Top Up Kiloan',
          value: '${formatCompactQuantity(header.totalTopUpKg)} Kg',
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
        ReportPdfMetric(
          title: 'Total Kas Masuk',
          value: ReportExportBuilder.formatRupiah(
            header.totalPaidTopUpRupiah + header.totalPaidTopUpKg,
          ),
          background: PdfColor.fromHex('#FFF7ED'),
          accent: PdfColor.fromHex('#EA580C'),
        ),
        ReportPdfMetric(
          title: 'Diskon Program Deposit',
          value: ReportExportBuilder.formatRupiah(
            header.totalDiscountRupiah + header.totalDiscountKg,
          ),
          background: PdfColor.fromHex('#FFFBEB'),
          accent: PdfColor.fromHex('#D97706'),
        ),
        ReportPdfMetric(
          title: 'Sisa Deposit Rupiah',
          value: ReportExportBuilder.formatRupiah(header.currentRupiah),
          background: PdfColor.fromHex('#F3FBF6'),
          accent: PdfColor.fromHex('#10B981'),
        ),
        ReportPdfMetric(
          title: 'Sisa Deposit Kiloan',
          value: '${formatCompactQuantity(header.currentKg)} Kg',
          background: PdfColor.fromHex('#F0FDF4'),
          accent: PdfColor.fromHex('#059669'),
        ),
      ],
      tables: [
        ReportPdfTable(
          title: 'Mutasi Deposit',
          subtitle: 'Seluruh aktivitas yang sesuai filter aktif.',
          headers: const [
            'Waktu',
            'Pelanggan',
            'Aktivitas',
            'Jenis',
            'Nilai',
            'Saldo Sebelum',
            'Saldo Setelah',
            'Kas Masuk',
            'Diskon',
          ],
          rows: entries
              .map(
                (item) => [
                  item.createdAt == null
                      ? '-'
                      : DateFormat(
                          'dd MMM yyyy HH:mm',
                          'id_ID',
                        ).format(item.createdAt!),
                  ReportExportBuilder.sanitizeText(item.customerName),
                  item.activityType == 'CORRECTION'
                      ? 'Koreksi'
                      : item.activityType == 'TOP_UP'
                      ? 'Top Up'
                      : item.activityType == 'REFUND'
                      ? 'Pengembalian'
                      : item.activityType == 'USAGE_REVERSAL'
                      ? 'Pembatalan Pemakaian'
                      : 'Pemakaian',
                  item.depositType == 'KG' ? 'Kiloan' : 'Rupiah',
                  amount(item),
                  balance(item, item.balanceBefore),
                  balance(item, item.balanceAfter),
                  item.activityType == 'TOP_UP' ||
                          item.activityType == 'CORRECTION'
                      ? ReportExportBuilder.formatRupiah(item.paidAmount)
                      : '-',
                  item.discountAmount > 0
                      ? ReportExportBuilder.formatRupiah(item.discountAmount)
                      : '-',
                ],
              )
              .toList(),
        ),
      ],
      logoBytes: logoBytes,
    );
  }

  // ignore: unused_element
  Widget _customerChip() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(
          Icons.person_outline_rounded,
          color: AppPalette.primary,
          size: 16,
        ),
        label: Text(_selectedCustomer!.name),
        backgroundColor: AppPalette.primaryPale,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          color: AppPalette.ink,
          fontSize: 12,
          fontWeight: AppFont.w600,
        ),
      ),
    ),
  );

  Future<void> _showActivitySummary(DepositReportHeader header) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.viewPaddingOf(sheetContext).bottom + 24,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildActivitySummary(header),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildActivitySummary(DepositReportHeader header) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Ringkasan Mutasi Periode',
        style: TextStyle(
          fontSize: 16,
          fontWeight: AppFont.w800,
          color: AppPalette.ink,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Pergerakan deposit dan kas sesuai filter aktif',
        style: TextStyle(fontSize: 12, color: AppPalette.muted),
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: AppPalette.muted,
          ),
          const SizedBox(width: 5),
          Text(
            _summaryPeriodLabel(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: AppFont.w600,
              color: AppPalette.muted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF0)),
        ),
        child: Column(
          children: [
            _summaryValueRow(
              'Penambahan • Rupiah',
              Icons.add_rounded,
              header.totalTopUpRupiah,
              const Color(0xFF16A765),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Penambahan • Kiloan',
              Icons.scale_outlined,
              header.totalTopUpKg,
              const Color(0xFF16A765),
              isKg: true,
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _cashSummaryRow(
              header.totalPaidTopUpRupiah + header.totalPaidTopUpKg,
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Diskon Program Deposit',
              Icons.local_offer_outlined,
              header.totalDiscountRupiah + header.totalDiscountKg,
              const Color(0xFFD97706),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Pemakaian • Rupiah',
              Icons.shopping_bag_outlined,
              header.totalUsageRupiah,
              AppPalette.primary,
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Pemakaian • Kiloan',
              Icons.scale_outlined,
              header.totalUsageKg,
              AppPalette.primary,
              isKg: true,
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Pengembalian • Rupiah',
              Icons.replay_rounded,
              header.totalRefundRupiah,
              const Color(0xFF5B7CFA),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Pengembalian • Kiloan',
              Icons.replay_rounded,
              header.totalRefundKg,
              const Color(0xFF5B7CFA),
              isKg: true,
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Sisa saldo • Rupiah',
              Icons.account_balance_wallet_outlined,
              header.currentRupiah,
              const Color(0xFF16A765),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF0)),
            _summaryValueRow(
              'Sisa saldo • Kiloan',
              Icons.account_balance_wallet_outlined,
              header.currentKg,
              const Color(0xFF16A765),
              isKg: true,
            ),
          ],
        ),
      ),
    ],
  );

  String _summaryPeriodLabel() {
    if (_start.year == _end.year) {
      return '${DateFormat('d MMM', 'id_ID').format(_start)} – ${DateFormat('d MMM yyyy', 'id_ID').format(_end)}';
    }
    return '${_dateFormat.format(_start)} – ${_dateFormat.format(_end)}';
  }

  Widget _summaryValueRow(
    String label,
    IconData icon,
    double value,
    Color color, {
    bool isKg = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: AppPalette.ink,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isKg ? '${formatCompactQuantity(value)} Kg' : _money.format(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _cashSummaryRow(double paid) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppPalette.primary.withValues(alpha: .1),
          child: const Icon(
            Icons.payments_outlined,
            size: 16,
            color: AppPalette.primary,
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Kas diterima',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: AppPalette.ink,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _money.format(paid),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: AppPalette.primary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _activeFilterChips() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (_selectedCustomer != null)
          _filterChip(Icons.person_outline_rounded, _selectedCustomer!.name),
        if (_depositType.isNotEmpty)
          _filterChip(
            Icons.account_balance_wallet_outlined,
            _depositType == 'KG' ? 'Kiloan' : 'Rupiah',
          ),
      ],
    ),
  );

  Widget _filterChip(IconData icon, String label) => Chip(
    avatar: Icon(icon, size: 15, color: AppPalette.primary),
    label: Text(label),
    backgroundColor: AppPalette.primaryPale,
    side: BorderSide.none,
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: AppFont.w700,
      color: AppPalette.ink,
    ),
    visualDensity: VisualDensity.compact,
  );

  // ignore: unused_element
  Widget _summaryMetric({
    required String label,
    required IconData icon,
    required double rupiah,
    required double kg,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w800,
                color: AppPalette.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryValue('Rupiah', _money.format(rupiah), color),
            ),
            Container(width: 1, height: 30, color: const Color(0xFFE8EDF0)),
            Expanded(
              child: _summaryValue(
                'Kiloan',
                '${formatCompactQuantity(kg)} Kg',
                color,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _summaryValue(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppPalette.muted),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w900,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _periodLabel() => OutlinedButton.icon(
    onPressed: _pickDateRange,
    icon: const Icon(Icons.calendar_today_outlined, size: 16),
    label: Text(
      '${_dateFormat.format(_start)} – ${_dateFormat.format(_end)}',
      overflow: TextOverflow.ellipsis,
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppPalette.ink,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4E9EE)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _filterButton() => OutlinedButton.icon(
    onPressed: _showFilters,
    icon: const Icon(Icons.tune_rounded, size: 17),
    label: const Text('Filter'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppPalette.primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppPalette.primary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Future<void> _pickDateRange() async {
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
    await _load();
  }

  Future<void> _showFilters() async {
    final customerProvider = context.read<CustomerProvider>();
    if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
      await customerProvider.fetchCustomers();
      if (!mounted) return;
    }
    final result = await showModalBottomSheet<_HistoryFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HistoryFilterSheet(
        depositType: _depositType,
        selectedCustomer: _selectedCustomer,
        customers: customerProvider.customers,
        initialPeriod: DateTimeRange(start: _start, end: _end),
      ),
    );
    if (result == null) return;
    setState(() {
      _depositType = result.depositType;
      _selectedCustomer = result.customer;
      _start = result.period.start;
      _end = result.period.end;
    });
    await _load();
  }

  Widget _buildTabs() {
    const tabs = [
      ('Semua', ''),
      ('Top Up', 'TOP_UP'),
      ('Koreksi', 'CORRECTION'),
      ('Pemakaian', 'USAGE'),
      ('Kembali', 'REFUND'),
    ];
    const slotWidth = 104.0;
    const chipWidth = 96.0;
    final selectedIndex = tabs.indexWhere((item) => item.$2 == _activity);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: slotWidth * tabs.length,
        height: 38,
        child: Stack(
          children: [
            for (var index = 0; index < tabs.length; index++)
              Positioned(
                left: index * slotWidth,
                width: chipWidth,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFE1E7ED)),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: selectedIndex * slotWidth,
              width: chipWidth,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
            for (var index = 0; index < tabs.length; index++)
              Positioned(
                left: index * slotWidth,
                width: chipWidth,
                top: 0,
                bottom: 0,
                child: Builder(
                  builder: (context) {
                    final item = tabs[index];
                    final selected = index == selectedIndex;
                    return InkWell(
                      onTap: () {
                        if (selected) return;
                        setState(() => _activity = item.$2);
                        _load();
                      },
                      borderRadius: BorderRadius.circular(19),
                      child: Center(
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            color: selected ? Colors.white : AppPalette.ink,
                            fontSize: 12,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: (value) => setState(() => _query = value),
    decoration: InputDecoration(
      hintText: 'Cari pelanggan atau mutasi',
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
  );

  bool _matchesQuery(DepositReportEntry entry) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        entry.customerName.toLowerCase().contains(query) ||
        entry.activityType.toLowerCase().contains(query) ||
        entry.createdByName.toLowerCase().contains(query);
  }

  // Kept temporarily while the shared card is rolled out to every deposit list.
  // ignore: unused_element
  Widget _activityTile(DepositReportEntry entry) {
    final type = entry.activityType.toUpperCase();
    final isTopUp = type == 'TOP_UP';
    final isRefund = type == 'REFUND';
    final positive = isTopUp || isRefund;
    final color = positive ? AppPalette.success : AppPalette.danger;
    final label = isTopUp
        ? 'Top Up Deposit'
        : isRefund
        ? 'Pengembalian Deposit'
        : 'Pemakaian Deposit';
    final amount = entry.depositType.toUpperCase() == 'KG'
        ? '${positive ? '+' : '-'}${formatCompactQuantity(entry.amount)} Kg'
        : '${positive ? '+' : '-'}${_money.format(entry.amount)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: .1),
                  child: Icon(
                    isTopUp
                        ? Icons.add_rounded
                        : isRefund
                        ? Icons.replay_rounded
                        : Icons.shopping_bag_outlined,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.ink,
                                fontSize: 14,
                                fontWeight: AppFont.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 118),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                amount,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: AppFont.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$label • ${entry.depositType.toUpperCase() == 'KG' ? 'Kiloan' : 'Rupiah'}',
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.createdAt == null
                            ? 'Waktu tidak tersedia'
                            : DateFormat(
                                'dd MMM yyyy, HH:mm',
                                'id_ID',
                              ).format(entry.createdAt!),
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _ledgerTag(
                            Icons.account_balance_wallet_outlined,
                            entry.depositType.toUpperCase() == 'KG'
                                ? 'Saldo ${formatCompactQuantity(entry.balanceAfter)} Kg'
                                : 'Saldo ${_money.format(entry.balanceAfter)}',
                          ),
                          if (isTopUp && entry.paidAmount > 0)
                            _ledgerTag(
                              Icons.payments_outlined,
                              'Kas ${_money.format(entry.paidAmount)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.muted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ledgerTag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppPalette.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: AppFont.w700,
            color: AppPalette.muted,
          ),
        ),
      ],
    ),
  );

  void _openDetail(DepositReportEntry item) {
    final customer = Customer(
      id: item.customerId,
      outletId: '',
      kode: '',
      name: item.customerName,
      phone: '',
      gender: '',
      address: '',
      status: 1,
    );
    final entry = CustomerDepositLedgerEntry(
      entryType: item.activityType,
      depositType: item.depositType,
      referenceId: item.referenceId,
      note: item.note,
      paymentMethod: item.paymentMethod,
      createdBy: '',
      createdByName: item.createdByName,
      createdByType: '',
      amount: item.amount,
      paidAmount: item.paidAmount,
      discountAmount: item.discountAmount,
      balanceBefore: item.balanceBefore,
      balanceAfter: item.balanceAfter,
      createdAt: item.createdAt,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerDepositDetailScreen(customer: customer, entry: entry),
      ),
    );
  }
}

class _DepositLedgerListSkeleton extends StatelessWidget {
  const _DepositLedgerListSkeleton();

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Column(
      children: List.generate(
        4,
        (_) => const AppSkeletonBox(
          height: 112,
          radius: 18,
          margin: EdgeInsets.only(bottom: 10),
        ),
      ),
    ),
  );
}

class _DepositLedgerLoadMoreSkeleton extends StatelessWidget {
  const _DepositLedgerLoadMoreSkeleton();

  @override
  Widget build(BuildContext context) => const AppShimmer(
    child: AppSkeletonBox(
      height: 84,
      radius: 18,
      margin: EdgeInsets.only(top: 8),
    ),
  );
}
