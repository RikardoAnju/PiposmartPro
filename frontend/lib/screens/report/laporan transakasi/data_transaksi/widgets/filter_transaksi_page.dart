import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/customer_provider.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';

class TransaksiFilter {
  final List<String> statusPesanan;
  final List<String> statusPembayaran;
  final List<String> metodePembayaran;
  final String filterBerdasarkan;
  final int? bulan;
  final int? tahun;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? customerId;
  final String? customerName;

  const TransaksiFilter({
    this.statusPesanan = const [],
    this.statusPembayaran = const [],
    this.metodePembayaran = const [],
    this.filterBerdasarkan = 'Bulanan',
    this.bulan,
    this.tahun,
    this.startDate,
    this.endDate,
    this.customerId,
    this.customerName,
  });

  static const Object _sentinel = Object();

  TransaksiFilter copyWith({
    List<String>? statusPesanan,
    List<String>? statusPembayaran,
    List<String>? metodePembayaran,
    String? filterBerdasarkan,
    int? bulan,
    int? tahun,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    Object? customerId = _sentinel,
    Object? customerName = _sentinel,
  }) {
    return TransaksiFilter(
      statusPesanan: statusPesanan ?? this.statusPesanan,
      statusPembayaran: statusPembayaran ?? this.statusPembayaran,
      metodePembayaran: metodePembayaran ?? this.metodePembayaran,
      filterBerdasarkan: filterBerdasarkan ?? this.filterBerdasarkan,
      bulan: bulan ?? this.bulan,
      tahun: tahun ?? this.tahun,
      startDate: startDate == _sentinel
          ? this.startDate
          : startDate as DateTime?,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      customerId: customerId == _sentinel
          ? this.customerId
          : customerId as String?,
      customerName: customerName == _sentinel
          ? this.customerName
          : customerName as String?,
    );
  }

  bool get hasActiveFilter =>
      statusPesanan.isNotEmpty ||
      statusPembayaran.isNotEmpty ||
      metodePembayaran.isNotEmpty ||
      filterBerdasarkan != 'Bulanan' ||
      startDate != null ||
      endDate != null ||
      customerId != null;
}

class FilterTransaksiPage extends StatefulWidget {
  final TransaksiFilter initialFilter;
  final List<String> availableMethods;
  final bool showPaymentFilters;

  const FilterTransaksiPage({
    super.key,
    required this.initialFilter,
    this.availableMethods = const [],
    this.showPaymentFilters = true,
  });

  @override
  State<FilterTransaksiPage> createState() => _FilterTransaksiPageState();
}

class _FilterTransaksiPageState extends State<FilterTransaksiPage> {
  static const Color kPrimary = AppPalette.primary;

  static const _orderOptions = [
    'Antrian',
    'Proses',
    'Siap Ambil',
    'Selesai',
    'Batal',
  ];
  static const _paymentOptions = ['Lunas', 'Belum Lunas', 'DP'];

  late Set<String> _statusPesanan;
  late Set<String> _statusPembayaran;
  late Set<String> _metodePembayaran;
  bool _isCompletingOrderSelection = false;
  bool _isCompletingPaymentSelection = false;
  bool _isCompletingMethodSelection = false;
  int _orderSelectionTransition = 0;
  int _paymentSelectionTransition = 0;
  int _methodSelectionTransition = 0;
  String? _customerId;
  String? _customerName;
  String _filterBerdasarkan = 'Bulanan';
  int? _bulan;
  int? _tahun;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _filterOptions = [
    'Minggu Ini',
    'Bulanan',
    'Tahunan',
    'Custom',
  ];
  final List<String> _bulanNames = [
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

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filterBerdasarkan) {
      case 'Bulanan':
        final month = _bulan ?? today.month;
        final year = _tahun ?? today.year;
        final monthStart = DateTime(year, month, 1);
        final monthEnd = DateTime(year, month + 1, 0);
        return DateTimeRange(
          start: monthStart,
          end: monthEnd.isAfter(today) ? today : monthEnd,
        );
      case 'Tahunan':
        final year = _tahun ?? today.year;
        final yearStart = DateTime(year, 1, 1);
        final yearEnd = DateTime(year, 12, 31);
        return DateTimeRange(
          start: yearStart,
          end: yearEnd.isAfter(today) ? today : yearEnd,
        );
      case 'Custom':
        return DateTimeRange(
          start: _startDate ?? today.subtract(const Duration(days: 6)),
          end: _endDate ?? today,
        );
      default:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
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

  List<String> get _allMethodOptions {
    final methods = widget.availableMethods.map(_displayMethodLabel).toSet();
    methods.addAll(const ['Tunai', 'Transfer']);
    final result = methods.toList()..sort();
    return result;
  }

  Future<void> _toggleOptionWithCompletion(
    Set<String> selected,
    String option,
    List<String> allOptions, {
    required int transition,
    required bool Function() isCurrentTransition,
    required void Function(bool value) setCompleting,
  }) async {
    if (selected.length == allOptions.length) {
      setState(() {
        setCompleting(false);
        selected
          ..clear()
          ..add(option);
      });
      return;
    }

    if (selected.contains(option)) {
      if (selected.length > 1) {
        setState(() {
          setCompleting(false);
          selected.remove(option);
        });
      }
      return;
    }

    final completesAllOptions = selected.length == allOptions.length - 1;
    setState(() {
      selected.add(option);
      setCompleting(completesAllOptions);
    });

    if (!completesAllOptions) return;

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || !isCurrentTransition()) return;
    setState(() => setCompleting(false));
  }

  @override
  void initState() {
    super.initState();
    _statusPesanan = widget.initialFilter.statusPesanan.isEmpty
        ? _orderOptions.toSet()
        : widget.initialFilter.statusPesanan.toSet();
    _statusPembayaran = widget.initialFilter.statusPembayaran.isEmpty
        ? _paymentOptions.toSet()
        : widget.initialFilter.statusPembayaran.toSet();
    _metodePembayaran = widget.initialFilter.metodePembayaran.isEmpty
        ? _allMethodOptions.toSet()
        : widget.initialFilter.metodePembayaran.toSet();
    _filterBerdasarkan = widget.initialFilter.filterBerdasarkan;
    _bulan = widget.initialFilter.bulan ?? DateTime.now().month;
    _tahun = _safeYear(widget.initialFilter.tahun);
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
    _customerId = widget.initialFilter.customerId;
    _customerName = widget.initialFilter.customerName;

    Future.microtask(() {
      if (mounted) {
        final prov = context.read<CustomerProvider>();
        if (prov.customers.isEmpty) {
          prov.fetchCustomers();
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _statusPesanan = _orderOptions.toSet();
      _statusPembayaran = _paymentOptions.toSet();
      _metodePembayaran = {};
      _isCompletingOrderSelection = false;
      _isCompletingPaymentSelection = false;
      _isCompletingMethodSelection = false;
      _orderSelectionTransition++;
      _paymentSelectionTransition++;
      _methodSelectionTransition++;
      _filterBerdasarkan = 'Bulanan';
      _bulan = DateTime.now().month;
      _tahun = _safeYear(null);
      _startDate = null;
      _endDate = null;
      _customerId = null;
      _customerName = null;
    });
  }

  void _apply() {
    final now = DateTime.now();
    final defaultStart = now.subtract(const Duration(days: 6));
    Navigator.pop(
      context,
      TransaksiFilter(
        statusPesanan: _statusPesanan.length == _orderOptions.length
            ? const []
            : _statusPesanan.toList(),
        statusPembayaran: _statusPembayaran.length == _paymentOptions.length
            ? const []
            : _statusPembayaran.toList(),
        metodePembayaran: _metodePembayaran.length == _allMethodOptions.length
            ? const []
            : _metodePembayaran.toList(),
        filterBerdasarkan: _filterBerdasarkan,
        bulan: _bulan,
        tahun: _tahun,
        startDate: _filterBerdasarkan == 'Custom'
            ? (_startDate ?? defaultStart)
            : _startDate,
        endDate: _filterBerdasarkan == 'Custom' ? (_endDate ?? now) : _endDate,
        customerId: _customerId,
        customerName: _customerName,
      ),
    );
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final initialDate = isStart
        ? (_startDate ?? now.subtract(const Duration(days: 6)))
        : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate, firstDate, now),
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _filterBerdasarkan = 'Custom';
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  String _formatShortDate(DateTime dt) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Filter Laporan',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: kPrimary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Pilih Pelanggan'),
            const SizedBox(height: 12),
            _buildPelangganSelector(),
            const SizedBox(height: 24),

            if (widget.showPaymentFilters) ...[
              _buildSection('Status Pesanan', [
                _ChipOption(
                  label: 'Semua',
                  selected:
                      _statusPesanan.length == _orderOptions.length &&
                      !_isCompletingOrderSelection,
                  onTap: () => setState(() {
                    _orderSelectionTransition++;
                    _isCompletingOrderSelection = false;
                    _statusPesanan = _orderOptions.toSet();
                  }),
                ),
                ..._orderOptions.map(
                  (status) => _ChipOption(
                    label: status,
                    selected:
                        (_statusPesanan.length != _orderOptions.length ||
                            _isCompletingOrderSelection) &&
                        _statusPesanan.contains(status),
                    onTap: () {
                      final transition = ++_orderSelectionTransition;
                      _toggleOptionWithCompletion(
                        _statusPesanan,
                        status,
                        _orderOptions,
                        transition: transition,
                        isCurrentTransition: () =>
                            transition == _orderSelectionTransition,
                        setCompleting: (value) =>
                            _isCompletingOrderSelection = value,
                      );
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Status Pembayaran', [
                _ChipOption(
                  label: 'Semua',
                  selected:
                      _statusPembayaran.length == _paymentOptions.length &&
                      !_isCompletingPaymentSelection,
                  onTap: () => setState(() {
                    _paymentSelectionTransition++;
                    _isCompletingPaymentSelection = false;
                    _statusPembayaran = _paymentOptions.toSet();
                  }),
                ),
                ..._paymentOptions.map(
                  (status) => _ChipOption(
                    label: status,
                    selected:
                        (_statusPembayaran.length != _paymentOptions.length ||
                            _isCompletingPaymentSelection) &&
                        _statusPembayaran.contains(status),
                    onTap: () {
                      final transition = ++_paymentSelectionTransition;
                      _toggleOptionWithCompletion(
                        _statusPembayaran,
                        status,
                        _paymentOptions,
                        transition: transition,
                        isCurrentTransition: () =>
                            transition == _paymentSelectionTransition,
                        setCompleting: (value) =>
                            _isCompletingPaymentSelection = value,
                      );
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Metode Pembayaran', [
                _ChipOption(
                  label: 'Semua',
                  selected:
                      _metodePembayaran.length == _allMethodOptions.length &&
                      !_isCompletingMethodSelection,
                  onTap: () => setState(() {
                    _methodSelectionTransition++;
                    _isCompletingMethodSelection = false;
                    _metodePembayaran = _allMethodOptions.toSet();
                  }),
                ),
                ..._allMethodOptions.map(
                  (m) => _ChipOption(
                    label: m,
                    selected:
                        (_metodePembayaran.length != _allMethodOptions.length ||
                            _isCompletingMethodSelection) &&
                        _metodePembayaran.contains(m),
                    onTap: () {
                      final transition = ++_methodSelectionTransition;
                      _toggleOptionWithCompletion(
                        _metodePembayaran,
                        m,
                        _allMethodOptions,
                        transition: transition,
                        isCurrentTransition: () =>
                            transition == _methodSelectionTransition,
                        setCompleting: (value) =>
                            _isCompletingMethodSelection = value,
                      );
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF7DED4)),
                ),
                child: const Text(
                  'Screen ini memakai filter periode untuk membaca performa layanan pada rentang waktu tertentu.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF8C6A60),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            const _SectionLabel('Rentang Waktu'),
            const SizedBox(height: 12),
            _buildTimeFilter(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 10, children: children),
      ],
    );
  }

  Widget _buildTimeFilter() {
    return Column(
      children: [
        _buildDropdown<String>(
          value: _filterBerdasarkan,
          hint: 'Pilih Filter',
          items: _filterOptions
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (val) => setState(() {
            _filterBerdasarkan = val ?? 'Bulanan';
          }),
        ),
        const SizedBox(height: 12),
        if (_filterBerdasarkan == 'Bulanan')
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<int>(
                      value: _bulan,
                      hint: 'Bulan',
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_bulanNames[i]),
                        ),
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
                            (y) =>
                                DropdownMenuItem(value: y, child: Text('$y')),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _tahun = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDateRangePicker(),
            ],
          )
        else if (_filterBerdasarkan == 'Tahunan')
          Column(
            children: [
              _buildDropdown<int>(
                value: _tahun,
                hint: 'Tahun',
                items: _yearOptions
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (val) => setState(() => _tahun = val),
              ),
              const SizedBox(height: 12),
              _buildDateRangePicker(),
            ],
          )
        else
          _buildDateRangePicker(),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    final range = _activeRange;
    return Row(
      children: [
        Expanded(
          child: _DateFilterTile(
            title: 'Tanggal Mulai',
            value: _formatShortDate(range.start),
            onTap: () => _pickCustomDate(isStart: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateFilterTile(
            title: 'Tanggal Selesai',
            value: _formatShortDate(range.end),
            onTap: () => _pickCustomDate(isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        15,
        20,
        MediaQuery.of(context).padding.bottom + 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Terapkan Filter',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPelangganSelector() {
    return InkWell(
      onTap: () {
        final customers = context.read<CustomerProvider>().customers;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _PelangganPickerSheet(
            items: customers,
            initialValue: _customerId,
            onSelected: (id, name) {
              setState(() {
                _customerId = id;
                _customerName = name;
              });
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _customerId != null
                ? AppPalette.primary.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 18,
              color: _customerId != null ? AppPalette.primary : Colors.black26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _customerName ?? 'Semua Pelanggan',
                style: TextStyle(
                  fontSize: 14,
                  color: _customerId != null ? Colors.black87 : Colors.black26,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _DateFilterTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF6B55)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppPalette.primary : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
    );
  }
}

class _PelangganPickerSheet extends StatefulWidget {
  final List<Customer> items;
  final String? initialValue;
  final void Function(String?, String?) onSelected;

  const _PelangganPickerSheet({
    required this.items,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<_PelangganPickerSheet> createState() => _PelangganPickerSheetState();
}

class _PelangganPickerSheetState extends State<_PelangganPickerSheet> {
  late List<Customer> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filter(String query) {
    setState(
      () => _filteredItems = widget.items
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = AppPalette.primary;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Pelanggan',
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black26),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppSearchField(
              controller: _searchController,
              onChanged: _filter,
              onClear: () {
                _searchController.clear();
                _filter('');
              },
              hintText: 'Cari pelanggan',
              height: 44,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredItems.length + 1,
              itemBuilder: (context, index) {
                final customer = index == 0 ? null : _filteredItems[index - 1];
                final isSelected = widget.initialValue == customer?.id;
                return ListTile(
                  onTap: () {
                    widget.onSelected(customer?.id, customer?.name);
                    Navigator.pop(context);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    customer?.name ?? 'Semua Pelanggan',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? kPrimary : Colors.black87,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: kPrimary,
                          size: 20,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
