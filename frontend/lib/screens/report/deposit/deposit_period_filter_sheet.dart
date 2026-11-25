import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';

/// Period selector shared by the Deposit report and its global activity ledger.
/// It deliberately follows the report-filter pattern used by Omset/Pendapatan.
class DepositPeriodFilterSheet extends StatefulWidget {
  final DateTimeRange initialRange;

  const DepositPeriodFilterSheet({super.key, required this.initialRange});

  @override
  State<DepositPeriodFilterSheet> createState() =>
      _DepositPeriodFilterSheetState();
}

class _DepositPeriodFilterSheetState extends State<DepositPeriodFilterSheet> {
  static const _primary = AppPalette.primary;
  final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  final _months = const [
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

  late String _periodMode;
  late int _month;
  late int _year;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final range = widget.initialRange;
    _start = _dateOnly(range.start);
    _end = _dateOnly(range.end);
    _month = _start.month;
    _year = _start.year;
    _periodMode = _inferMode(range);
  }

  DateTime get _today => _dateOnly(DateTime.now());

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _inferMode(DateTimeRange range) {
    final start = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    if (start == _today.subtract(const Duration(days: 6)) && end == _today) {
      return 'Minggu Ini';
    }
    final monthEnd = DateTime(start.year, start.month + 1, 0);
    if (start.day == 1 &&
        end == (monthEnd.isAfter(_today) ? _today : monthEnd)) {
      return 'Bulanan';
    }
    final yearEnd = DateTime(start.year, 12, 31);
    if (start.month == 1 &&
        start.day == 1 &&
        end == (yearEnd.isAfter(_today) ? _today : yearEnd)) {
      return 'Tahunan';
    }
    return 'Custom';
  }

  DateTimeRange get _activeRange {
    switch (_periodMode) {
      case 'Bulanan':
        final start = DateTime(_year, _month, 1);
        final end = DateTime(_year, _month + 1, 0);
        return DateTimeRange(
          start: start,
          end: end.isAfter(_today) ? _today : end,
        );
      case 'Tahunan':
        final start = DateTime(_year, 1, 1);
        final end = DateTime(_year, 12, 31);
        return DateTimeRange(
          start: start,
          end: end.isAfter(_today) ? _today : end,
        );
      case 'Custom':
        return DateTimeRange(start: _start, end: _end);
      default:
        return DateTimeRange(
          start: _today.subtract(const Duration(days: 6)),
          end: _today,
        );
    }
  }

  void _reset() => setState(() {
    _periodMode = 'Minggu Ini';
    _month = _today.month;
    _year = _today.year;
    _start = _today.subtract(const Duration(days: 6));
    _end = _today;
  });

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      _periodMode = 'Custom';
      _start = _dateOnly(range.start);
      _end = _dateOnly(range.end);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        child: Column(
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
              children: [
                const Expanded(
                  child: Text(
                    'Filter Laporan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    backgroundColor: _primary.withValues(alpha: .08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                  icon: const Icon(Icons.close_rounded, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Periode Laporan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFont.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 14),
            _periodToggle(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_periodMode),
                child: Column(
                  children: [
                    if (_periodMode == 'Bulanan') _monthPicker(),
                    if (_periodMode == 'Tahunan') _yearPicker(),
                    if (_periodMode == 'Bulanan' || _periodMode == 'Tahunan')
                      const SizedBox(height: 12),
                    _rangeFields(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _activeRange),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
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
  );

  Widget _periodToggle() => Container(
    height: 54,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const modes = ['Minggu Ini', 'Bulanan', 'Tahunan', 'Custom'];
        final selected = modes.indexOf(_periodMode).clamp(0, 3);
        final width = constraints.maxWidth / modes.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: selected * width,
              top: 0,
              bottom: 0,
              width: width,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: modes
                  .map(
                    (mode) => Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _periodMode = mode),
                        child: Center(
                          child: Text(
                            mode,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w900,
                              color: _periodMode == mode
                                  ? _primary
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
  );

  Widget _monthPicker() => Row(
    children: [
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<int>(
          initialValue: _month,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: List.generate(
            12,
            (index) =>
                DropdownMenuItem(value: index + 1, child: Text(_months[index])),
          ),
          onChanged: (value) => setState(() => _month = value ?? _month),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: _yearDropdown()),
    ],
  );

  Widget _yearPicker() => _yearDropdown();

  Widget _yearDropdown() => DropdownButtonFormField<int>(
    initialValue: _year,
    isExpanded: true,
    decoration: _inputDecoration(),
    items: List.generate(4, (index) => DateTime.now().year - index)
        .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
        .toList(),
    onChanged: (value) => setState(() => _year = value ?? _year),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: .08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
  );

  Widget _rangeFields() {
    final range = _activeRange;
    return Row(
      children: [
        Expanded(child: _dateField('Tanggal Mulai', range.start)),
        const SizedBox(width: 12),
        Expanded(child: _dateField('Tanggal Selesai', range.end)),
      ],
    );
  }

  Widget _dateField(String label, DateTime value) => InkWell(
    onTap: _pickCustomRange,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 17, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: AppFont.w700,
                    color: Color(0xFF9B8E88),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dateFormat.format(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
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
}
