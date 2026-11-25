import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/data/models/transaction_model.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum WorkLogStage { newOrder, processing, ready, completed, cancelled }

class WorkLogProvider extends ChangeNotifier {
  List<Pegawai> _employees = [];
  List<TransactionModel> _transactions = [];
  Pegawai? _selectedEmployee;
  DateTimeRange? _selectedRange;
  final Map<String, DateTimeRange> _rangesByEmployee = {};
  bool _isLoading = false;
  String? _errorMessage;
  WorkLogStage? _selectedStage;
  String _searchQuery = '';
  bool _excludeCancelled = true;
  PegawaiProvider? _employeeProvider;
  TransactionProvider? _transactionProvider;
  String? _employeeId;
  Pegawai? _selfEmployee;

  List<Pegawai> get employees => _employees;
  Pegawai? get selectedEmployee => _selectedEmployee;
  DateTimeRange get selectedRange => _selectedRange!;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSelectedEmployee => _selectedEmployee != null;
  WorkLogStage? get selectedStage => _selectedStage;
  String get searchQuery => _searchQuery;
  bool get excludeCancelled => _excludeCancelled;

  void setExcludeCancelled(bool value) {
    if (_excludeCancelled == value) return;
    _excludeCancelled = value;
    notifyListeners();
  }

  List<TransactionModel> get workLogs {
    final employee = _selectedEmployee;
    if (employee == null || _selectedRange == null) return [];

    return _transactions
        .where((transaction) => _hasEmployeeActivity(transaction, employee))
        .toList();
  }

  // Ringkasan hanya menghitung transaksi yang masih aktif. Transaksi batal
  // tetap tersedia di tahap "Membatalkan Pesanan" sebagai histori aktivitas,
  // tetapi tidak boleh menambah pelanggan, pesanan, layanan, atau kuantitas.
  List<TransactionModel> get _summaryWorkLogs => workLogs.where((transaction) {
    return !_excludeCancelled || !_isCancelledTransaction(transaction);
  }).toList();

  bool _isCancelledTransaction(TransactionModel transaction) {
    final status = transaction.orderStatus.trim().toLowerCase();
    return status.contains('batal') ||
        transaction.logs.any(
          (log) => log.status.trim().toLowerCase().contains('batal'),
        );
  }

  int get customerCount => _summaryWorkLogs
      .map((transaction) => transaction.customer?.id ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  int get transactionCount => _summaryWorkLogs.length;

  int get serviceCount => _summaryWorkLogs
      .expand((transaction) => transaction.items)
      .map((item) => item.serviceName)
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .length;

  int get newOrderCount =>
      _countStatus(const ['nota dibuat', 'antrian', 'baru']);
  int get processingCount =>
      _countStatus(const ['proses', 'cuci', 'dikerjakan']);
  int get readyCount => _countStatus(const ['siap']);
  int get completedCount => _countStatus(const ['selesai']);
  int get cancelledCount => _countStatus(const ['batal']);

  Map<String, double> get totalQuantities {
    // Tiga satuan utama tetap ditampilkan meskipun belum ada pekerjaan.
    final quantities = <String, double>{'kg': 0, 'pcs': 0, 'meter': 0};
    for (final transaction in _summaryWorkLogs) {
      for (final item in transaction.items) {
        final unit = _canonicalQuantityUnit(item.unit);
        quantities.update(
          unit,
          (value) => value + item.qty,
          ifAbsent: () => item.qty,
        );
      }
    }
    return quantities;
  }

  List<TransactionModel> get stageTransactions {
    final stage = _selectedStage;
    if (stage == null) return [];
    final terms = switch (stage) {
      WorkLogStage.newOrder => const ['nota dibuat', 'antrian', 'baru'],
      WorkLogStage.processing => const ['proses', 'cuci', 'dikerjakan'],
      WorkLogStage.ready => const ['siap'],
      WorkLogStage.completed => const ['selesai'],
      WorkLogStage.cancelled => const ['batal'],
    };
    final employee = _selectedEmployee;
    if (employee == null) return [];
    final source = stage == WorkLogStage.cancelled || !_excludeCancelled
        ? workLogs
        : _summaryWorkLogs;
    return source.where((transaction) {
      final latestStatus = _latestEmployeeStatus(transaction, employee);
      final matchesStage =
          latestStatus != null &&
          terms.any(latestStatus.toLowerCase().contains);
      final search = _searchQuery.trim().toLowerCase();
      if (search.isEmpty) return matchesStage;
      final customer = transaction.customer?.name.toLowerCase() ?? '';
      final invoice = transaction.invoiceNumber?.toLowerCase() ?? '';
      return matchesStage &&
          (customer.contains(search) || invoice.contains(search));
    }).toList();
  }

  Map<String, double> get stageQuantities {
    final quantities = <String, double>{};
    for (final transaction in stageTransactions) {
      for (final item in transaction.items) {
        final unit = _canonicalQuantityUnit(item.unit);
        quantities.update(
          unit,
          (value) => value + item.qty,
          ifAbsent: () => item.qty,
        );
      }
    }
    return quantities;
  }

  /// Semua aktivitas tahap yang dilakukan karyawan pada periode terpilih.
  /// Berbeda dari [workLogs] yang berisi transaksi unik, laporan perlu
  /// menampilkan setiap perpindahan tahap agar status seperti proses, siap
  /// ambil, dan selesai tidak hilang ketika status terakhir berubah.
  List<Map<String, String>> get performanceReportRows {
    final employee = _selectedEmployee;
    if (employee == null) return [];
    final rows = <Map<String, String>>[];
    for (final transaction in workLogs) {
      // Jika filter aktif, buang seluruh transaksi yang pernah dibatalkan.
      // Jangan hanya membuang log "Batal", karena transaksi yang sama bisa
      // masih memiliki log sebelumnya seperti "Nota Dibuat".
      if (_excludeCancelled && _isCancelledTransaction(transaction)) continue;
      final employeeLogs =
          transaction.logs
              .where(
                (log) =>
                    _matchesEmployee(log.adminName, employee) &&
                    _isInRange(log.createdAt),
              )
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final log in employeeLogs) {
        final status = log.status.trim().toLowerCase();
        if (_excludeCancelled && status.contains('batal')) continue;
        if (status.contains('lunas') ||
            status.contains('pelunasan') ||
            status == 'dibayar' ||
            status == 'bayar') {
          continue;
        }
        rows.add({
          'invoice': transaction.invoiceNumber ?? '-',
          'customer': transaction.customer?.name ?? '-',
          'status': log.status,
          'date': DateFormat(
            'dd MMM yyyy HH:mm',
            'id_ID',
          ).format(log.createdAt.toLocal()),
        });
      }
    }
    return rows;
  }

  Future<void> load({
    required PegawaiProvider employeeProvider,
    required TransactionProvider transactionProvider,
    String? employeeId,
    Pegawai? selfEmployee,
  }) async {
    _employeeProvider = employeeProvider;
    _transactionProvider = transactionProvider;
    _employeeId = employeeId;
    _selfEmployee = selfEmployee;
    await refresh();
  }

  Future<void> refresh() async {
    final employeeProvider = _employeeProvider;
    final transactionProvider = _transactionProvider;
    if (employeeProvider == null || transactionProvider == null) return;

    _selectedRange ??= _defaultRange();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Tampilkan daftar pegawai lebih dahulu; transaksi performa menyusul
    // karena biasanya merupakan request paling berat.
    if (_selfEmployee != null) {
      _employees = [_selfEmployee!];
    } else if (_employeeId != null && _employeeId!.isNotEmpty) {
      final employee = await employeeProvider.fetchCurrentEmployee();
      _employees = employee == null ? [] : [employee];
    } else {
      await employeeProvider.fetchEmployees();
      _employees = employeeProvider.employees;
    }
    notifyListeners();

    await transactionProvider.fetchPerformanceTransactions();
    _transactions = transactionProvider.allTransactions;
    _errorMessage =
        employeeProvider.errorMessage ?? transactionProvider.errorMessage;
    _isLoading = false;
    notifyListeners();
  }

  void selectEmployee(Pegawai employee) {
    final previousEmployee = _selectedEmployee;
    if (previousEmployee != null && _selectedRange != null) {
      _rangesByEmployee[_employeeKey(previousEmployee)] = _selectedRange!;
    }
    _selectedEmployee = employee;
    _selectedRange =
        _rangesByEmployee[_employeeKey(employee)] ?? _defaultRange();
    notifyListeners();
  }

  void clearSelectedEmployee() {
    _selectedEmployee = null;
    _selectedStage = null;
    notifyListeners();
  }

  void selectStage(WorkLogStage stage) {
    _selectedStage = stage;
    _searchQuery = '';
    notifyListeners();
  }

  void clearSelectedStage() {
    _selectedStage = null;
    _searchQuery = '';
    notifyListeners();
  }

  void resetView() {
    _selectedEmployee = null;
    _selectedStage = null;
    _searchQuery = '';
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void resetRange() {
    _selectedRange = _defaultRange();
    final employee = _selectedEmployee;
    if (employee != null) {
      _rangesByEmployee[_employeeKey(employee)] = _selectedRange!;
    }
    notifyListeners();
  }

  Future<void> pickRange(BuildContext context) async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) => _WorkLogCalendarDialog(
        initialRange: selectedRange,
        defaultRange: _defaultRange(),
      ),
    );
    if (picked == null) return;
    _selectedRange = picked;
    final employee = _selectedEmployee;
    if (employee != null) {
      _rangesByEmployee[_employeeKey(employee)] = picked;
    }
    notifyListeners();
  }

  DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      // Default satu minggu, tetapi tiap karyawan memiliki filter sendiri.
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
  }

  String _employeeKey(Pegawai employee) {
    final id = employee.id.trim();
    return id.isNotEmpty ? id : employee.nama.trim().toLowerCase();
  }

  int _countStatus(List<String> terms) {
    final source = terms.any((term) => term == 'batal') && _excludeCancelled
        ? workLogs
        : _summaryWorkLogs;
    return source.where((transaction) {
      final employee = _selectedEmployee;
      if (employee == null) return false;
      final latestStatus = _latestEmployeeStatus(transaction, employee);
      return latestStatus != null &&
          terms.any(latestStatus.toLowerCase().contains);
    }).length;
  }

  String? _latestEmployeeStatus(
    TransactionModel transaction,
    Pegawai employee,
  ) {
    final employeeLogs =
        transaction.logs
            .where(
              (log) =>
                  _matchesEmployee(log.adminName, employee) &&
                  _isInRange(log.createdAt),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return employeeLogs.isEmpty ? null : employeeLogs.first.status;
  }

  bool _hasEmployeeActivity(TransactionModel transaction, Pegawai employee) {
    final createdByEmployee =
        _matchesEmployee(transaction.kasirName, employee) &&
        transaction.createdAt != null &&
        _isInRange(transaction.createdAt!);
    final updatedByEmployee = transaction.logs.any(
      (log) =>
          _matchesEmployee(log.adminName, employee) &&
          _isInRange(log.createdAt),
    );
    return createdByEmployee || updatedByEmployee;
  }

  bool _matchesEmployee(String? actor, Pegawai employee) {
    final value = actor?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value == employee.nama.trim().toLowerCase() ||
        value == employee.id.toLowerCase();
  }

  bool _isInRange(DateTime date) {
    final start = DateUtils.dateOnly(selectedRange.start);
    final end = DateUtils.dateOnly(selectedRange.end);
    final value = DateUtils.dateOnly(date);
    return !value.isBefore(start) && !value.isAfter(end);
  }
}

class _WorkLogCalendarDialog extends StatefulWidget {
  const _WorkLogCalendarDialog({required this.initialRange, this.defaultRange});

  final DateTimeRange initialRange;
  final DateTimeRange? defaultRange;

  @override
  State<_WorkLogCalendarDialog> createState() => _WorkLogCalendarDialogState();
}

class _WorkLogCalendarDialogState extends State<_WorkLogCalendarDialog> {
  late DateTime _start;
  DateTime? _end;
  late DateTime _focusedDate;
  bool _selectingEnd = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
    _focusedDate = _start;
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (!_selectingEnd) {
        _start = date;
        _end = null;
        _selectingEnd = true;
      } else if (date.isBefore(_start)) {
        _start = date;
        _end = null;
      } else {
        _end = date;
        _selectingEnd = false;
      }
      _focusedDate = date;
    });
  }

  void _onReset() {
    final now = DateTime.now();
    final def =
        widget.defaultRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
    Navigator.pop(context, def);
  }

  @override
  Widget build(BuildContext context) {
    final lastDate = DateTime.now();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Periode',
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontSize: 18,
                            fontWeight: AppFont.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Filter aktivitas berdasarkan tanggal',
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppPalette.muted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Date Range Display Cards (Mulai -> Selesai)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateCard(
                        label: 'MULAI',
                        date: _start,
                        isActive: !_selectingEnd,
                        onTap: () {
                          setState(() {
                            _selectingEnd = false;
                            _focusedDate = _start;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppPalette.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DateCard(
                        label: 'SELESAI',
                        date: _end,
                        isActive: _selectingEnd,
                        onTap: () {
                          setState(() {
                            _selectingEnd = true;
                            if (_end != null) _focusedDate = _end!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Hint Text Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppPalette.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectingEnd
                            ? 'Pilih tanggal selesai pada kalender di bawah'
                            : 'Pilih tanggal mulai pada kalender di bawah',
                        style: const TextStyle(
                          color: AppPalette.primary,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Calendar Theme & Picker
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppPalette.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppPalette.ink,
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.primary,
                      textStyle: const TextStyle(fontWeight: AppFont.w700),
                    ),
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: _focusedDate,
                  firstDate: DateTime(2020),
                  lastDate: lastDate,
                  currentDate: lastDate,
                  onDateChanged: _selectDate,
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Buttons: Reset & Terapkan
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _onReset,
                        icon: const Icon(Icons.restart_alt_rounded, size: 17),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          side: const BorderSide(
                            color: AppPalette.primaryBorder,
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () {
                          final end = _end ?? _start;
                          Navigator.pop(
                            context,
                            DateTimeRange(start: _start, end: end),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        child: const Text('Terapkan'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.date,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final DateTime? date;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = date == null
        ? 'Pilih tanggal'
        : DateFormat('dd MMM yyyy', 'id_ID').format(date!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppPalette.primary : const Color(0xFFE2E8F0),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppPalette.primary : AppPalette.muted,
                  fontSize: 9,
                  fontWeight: AppFont.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: date == null ? AppPalette.muted : AppPalette.ink,
                  fontSize: 12,
                  fontWeight: AppFont.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _canonicalQuantityUnit(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'kg':
    case 'kilogram':
      return 'kg';
    case 'm':
    case 'meter':
    case 'meteran':
    case 'meter persegi':
    case 'm²':
      return 'meter';
    case 'pc':
    case 'pcs':
    case 'piece':
      return 'pcs';
    default:
      return raw.trim().isEmpty ? 'pcs' : raw.trim().toLowerCase();
  }
}
