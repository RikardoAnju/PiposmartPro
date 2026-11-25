import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

enum _CustomerPeriodPreset { week, month, year, custom }

class CustomerFilterSheet extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const CustomerFilterSheet({super.key, this.startDate, this.endDate});

  @override
  State<CustomerFilterSheet> createState() => _CustomerFilterSheetState();
}

class _CustomerFilterSheetState extends State<CustomerFilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  late _CustomerPeriodPreset _preset;
  late int _selectedMonth;
  late int _selectedYear;

  static const _primary = Color(0xFFFF5F4D);
  static const _textDark = Color(0xFF241815);
  static const _textSoft = Color(0xFF8D807A);

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _preset = _inferPreset(widget.startDate, widget.endDate);
    final baseDate = widget.startDate ?? DateTime.now();
    _selectedMonth = baseDate.month;
    _selectedYear = _safeYear(baseDate.year);
  }

  _CustomerPeriodPreset _inferPreset(DateTime? start, DateTime? end) {
    if (start == null || end == null) return _CustomerPeriodPreset.week;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);

    if (_sameDay(normalizedEnd, today) &&
        _sameDay(normalizedStart, today.subtract(const Duration(days: 6)))) {
      return _CustomerPeriodPreset.week;
    }
    if (_sameDay(normalizedEnd, today) &&
        _sameDay(normalizedStart, DateTime(today.year, today.month, 1))) {
      return _CustomerPeriodPreset.month;
    }
    if (_sameDay(normalizedEnd, today) &&
        _sameDay(normalizedStart, DateTime(today.year, 1, 1))) {
      return _CustomerPeriodPreset.year;
    }
    return _CustomerPeriodPreset.custom;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTimeRange _rangeForPreset(_CustomerPeriodPreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case _CustomerPeriodPreset.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _CustomerPeriodPreset.month:
        final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
        final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 0);
        return DateTimeRange(
          start: monthStart,
          end: monthEnd.isAfter(today) ? today : monthEnd,
        );
      case _CustomerPeriodPreset.year:
        final yearStart = DateTime(_selectedYear, 1, 1);
        final yearEnd = DateTime(_selectedYear, 12, 31);
        return DateTimeRange(
          start: yearStart,
          end: yearEnd.isAfter(today) ? today : yearEnd,
        );
      case _CustomerPeriodPreset.custom:
        return DateTimeRange(
          start: _startDate ?? today.subtract(const Duration(days: 6)),
          end: _endDate ?? today,
        );
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final range = _rangeForPreset(_CustomerPeriodPreset.custom);
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final picked = await showDatePicker(
      context: context,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: child!,
      ),
      initialDate: _clampDate(
        isStart ? range.start : range.end,
        firstDate,
        now,
      ),
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _preset = _CustomerPeriodPreset.custom;
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

  void _reset() {
    setState(() {
      _preset = _CustomerPeriodPreset.week;
      _startDate = null;
      _endDate = null;
      final now = DateTime.now();
      _selectedMonth = now.month;
      _selectedYear = now.year;
    });
  }

  void _selectPreset(_CustomerPeriodPreset preset) {
    setState(() {
      _preset = preset;
      if (preset != _CustomerPeriodPreset.custom) {
        final range = _rangeForPreset(preset);
        _startDate = range.start;
        _endDate = range.end;
        _selectedMonth = range.start.month;
        _selectedYear = _safeYear(range.start.year);
      }
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _selectedMonth = month;
      final range = _rangeForPreset(_CustomerPeriodPreset.month);
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  void _selectYear(int year) {
    setState(() {
      _selectedYear = _safeYear(year);
      final range = _rangeForPreset(_preset);
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  void _apply() {
    final range = _rangeForPreset(_preset);
    Navigator.pop(context, {'startDate': range.start, 'endDate': range.end});
  }

  String _fmtDate(DateTime dt) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
  }

  String _monthName(int month) => const [
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
  ][month - 1];

  List<int> get _yearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(3, (index) => currentYear - index);
  }

  int _safeYear(int year) {
    final years = _yearOptions;
    return years.contains(year) ? year : years.first;
  }

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final showMonth = _preset == _CustomerPeriodPreset.month;
    final showYear = _preset == _CustomerPeriodPreset.year;
    final availableYears = _yearOptions;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6DED9),
                    borderRadius: BorderRadius.circular(999),
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
                        color: _textDark,
                        fontWeight: AppFont.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF0D8D2)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: AppFont.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF6F2F0),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFAAA19D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionLabel(label: 'Periode Laporan'),
              const SizedBox(height: 10),
              _PeriodSegmentedControl(
                selected: _preset,
                onChanged: _selectPreset,
              ),
              if (showMonth) ...[
                const SizedBox(height: 10),
                _MonthYearPicker(
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                  availableYears: availableYears,
                  monthName: _monthName,
                  onMonthChanged: _selectMonth,
                  onYearChanged: _selectYear,
                ),
              ],
              if (showYear) ...[
                const SizedBox(height: 10),
                _YearPicker(
                  selectedYear: _selectedYear,
                  availableYears: availableYears,
                  onChanged: _selectYear,
                ),
              ],
              const SizedBox(height: 12),
              _DateRangePickerRow(
                startLabel: _fmtDate(_rangeForPreset(_preset).start),
                endLabel: _fmtDate(_rangeForPreset(_preset).end),
                onStartTap: () => _pickDate(isStart: true),
                onEndTap: () => _pickDate(isStart: false),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'TERAPKAN FILTER',
                    style: TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: AppFont.w800,
        color: Color(0xFF2B1E1A),
      ),
    );
  }
}

class _PeriodSegmentedControl extends StatelessWidget {
  final _CustomerPeriodPreset selected;
  final ValueChanged<_CustomerPeriodPreset> onChanged;

  const _PeriodSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  static const _items = [
    (_CustomerPeriodPreset.week, 'Minggu Ini'),
    (_CustomerPeriodPreset.month, 'Bulanan'),
    (_CustomerPeriodPreset.year, 'Tahunan'),
    (_CustomerPeriodPreset.custom, 'Custom'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _PeriodSegment(
                label: item.$2,
                selected: selected == item.$1,
                onTap: () => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? _CustomerFilterSheetState._primary
                    : _CustomerFilterSheetState._textSoft,
                fontSize: 12,
                fontWeight: AppFont.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthYearPicker extends StatelessWidget {
  final int selectedMonth;
  final int selectedYear;
  final List<int> availableYears;
  final String Function(int month) monthName;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const _MonthYearPicker({
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableYears,
    required this.monthName,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final month = _SelectTile(
            label: 'Bulan',
            value: monthName(selectedMonth),
            child: DropdownButton<int>(
              value: selectedMonth,
              isExpanded: true,
              isDense: true,
              itemHeight: 52,
              menuMaxHeight: 320,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (var month = 1; month <= 12; month++)
                  DropdownMenuItem(value: month, child: Text(monthName(month))),
              ],
              onChanged: (value) {
                if (value != null) onMonthChanged(value);
              },
            ),
          );
        final year = _YearDropdownTile(
            selectedYear: selectedYear,
            availableYears: availableYears,
            onChanged: onYearChanged,
          );
        return compact
            ? Column(
                children: [month, const SizedBox(height: 10), year],
              )
            : Row(
                children: [
                  Expanded(flex: 3, child: month),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: year),
                ],
              );
      },
    );
  }
}

class _YearPicker extends StatelessWidget {
  final int selectedYear;
  final List<int> availableYears;
  final ValueChanged<int> onChanged;

  const _YearPicker({
    required this.selectedYear,
    required this.availableYears,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _YearDropdownTile(
      selectedYear: selectedYear,
      availableYears: availableYears,
      onChanged: onChanged,
    );
  }
}

class _YearDropdownTile extends StatelessWidget {
  final int selectedYear;
  final List<int> availableYears;
  final ValueChanged<int> onChanged;

  const _YearDropdownTile({
    required this.selectedYear,
    required this.availableYears,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectTile(
      label: 'Tahun',
      value: '$selectedYear',
      child: DropdownButton<int>(
        value: selectedYear,
        isExpanded: true,
        isDense: true,
        itemHeight: 52,
        menuMaxHeight: 280,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        items: [
          for (final year in availableYears)
            DropdownMenuItem(value: year, child: Text('$year')),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;

  const _SelectTile({
    required this.label,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _CustomerFilterSheetState._textSoft,
              fontSize: 10,
              fontWeight: AppFont.w800,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: _CustomerFilterSheetState._textDark,
                fontSize: 13,
                fontWeight: AppFont.w900,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangePickerRow extends StatelessWidget {
  final String startLabel;
  final String endLabel;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  const _DateRangePickerRow({
    required this.startLabel,
    required this.endLabel,
    required this.onStartTap,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final start = _DatePickerTile(
            title: 'Tanggal Mulai',
            label: startLabel,
            onTap: onStartTap,
          );
        final end = _DatePickerTile(
            title: 'Tanggal Selesai',
            label: endLabel,
            onTap: onEndTap,
          );
        return compact
            ? Column(
                children: [start, const SizedBox(height: 10), end],
              )
            : Row(
                children: [
                  Expanded(child: start),
                  const SizedBox(width: 10),
                  Expanded(child: end),
                ],
              );
      },
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String title;
  final String label;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.title,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.primaryBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: _CustomerFilterSheetState._primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _CustomerFilterSheetState._textSoft,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 2,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _CustomerFilterSheetState._textDark,
                        fontWeight: AppFont.w800,
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
