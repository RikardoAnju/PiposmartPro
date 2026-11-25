import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/omset_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OmsetFilterSheet extends StatefulWidget {
  final OmsetFilter initialFilter;

  const OmsetFilterSheet({super.key, required this.initialFilter});

  @override
  State<OmsetFilterSheet> createState() => _OmsetFilterSheetState();
}

class _OmsetFilterSheetState extends State<OmsetFilterSheet> {
  static const Color kPrimary = AppPalette.primary;

  String? _statusPembayaran;
  late String _periodMode;
  late int _bulan;
  late int _tahun;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;

  final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');
  final List<String> _namaBulan = [
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

  @override
  void initState() {
    super.initState();
    _statusPembayaran = widget.initialFilter.statusPembayaran;
    _periodMode = widget.initialFilter.filterBerdasarkan;
    _bulan = widget.initialFilter.bulan;
    _tahun = widget.initialFilter.tahun;
    _tanggalMulai = widget.initialFilter.tanggalMulai;
    _tanggalSelesai = widget.initialFilter.tanggalSelesai;
  }

  void _reset() {
    setState(() {
      _statusPembayaran = null;
      _periodMode = 'Minggu Ini';
      _bulan = DateTime.now().month;
      _tahun = DateTime.now().year;
      _tanggalMulai = null;
      _tanggalSelesai = null;
    });
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_periodMode) {
      case 'Bulanan':
        final monthStart = DateTime(_tahun, _bulan, 1);
        final monthEnd = DateTime(_tahun, _bulan + 1, 0);
        return DateTimeRange(
          start: monthStart,
          end: monthEnd.isAfter(today) ? today : monthEnd,
        );
      case 'Tahunan':
        final yearStart = DateTime(_tahun, 1, 1);
        final yearEnd = DateTime(_tahun, 12, 31);
        return DateTimeRange(
          start: yearStart,
          end: yearEnd.isAfter(today) ? today : yearEnd,
        );
      case 'Custom':
        return DateTimeRange(
          start: _tanggalMulai ?? today.subtract(const Duration(days: 6)),
          end: _tanggalSelesai ?? today,
        );
      default:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
    }
  }

  void _apply() {
    DateTime? start;
    DateTime? end;

    if (_periodMode == 'Custom') {
      start = _tanggalMulai;
      end = _tanggalSelesai;
    }

    final result = OmsetFilter(
      statusPembayaran: _statusPembayaran,
      filterBerdasarkan: _periodMode,
      bulan: _periodMode == 'Bulanan' ? _bulan : DateTime.now().month,
      tahun: (_periodMode == 'Bulanan' || _periodMode == 'Tahunan')
          ? _tahun
          : DateTime.now().year,
      tanggalMulai: start,
      tanggalSelesai: end,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 20),
            child: Row(
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
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundColor: kPrimary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: kPrimary,
                          fontSize: 12,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Status Pembayaran',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _buildStatusSelector(),

                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Periode Laporan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _buildPeriodToggle(),

                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1.0,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: KeyedSubtree(
                      key: ValueKey(_periodMode),
                      child: _buildPeriodFields(),
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildApplyButton(),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusPembayaran != null
              ? kPrimary.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _statusPembayaran,
        isExpanded: true,
        hint: const Text(
          'Semua Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w700,
            color: Colors.black87,
          ),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        icon: const Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Colors.black26,
          ),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        items: const [
          DropdownMenuItem(
            value: null,
            child: Text(
              'Semua Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w700,
                color: Colors.black87,
              ),
            ),
          ),
          DropdownMenuItem(
            value: 'Lunas',
            child: Text(
              'Lunas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w700,
                color: Colors.black87,
              ),
            ),
          ),
          DropdownMenuItem(
            value: 'Belum Lunas',
            child: Text(
              'Belum Lunas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
        onChanged: (val) => setState(() => _statusPembayaran = val),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double segmentWidth = constraints.maxWidth / 4;
          int activeIndex = 0;
          if (_periodMode == 'Bulanan') activeIndex = 1;
          if (_periodMode == 'Tahunan') activeIndex = 2;
          if (_periodMode == 'Custom') activeIndex = 3;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: activeIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _toggleLabel('Minggu Ini', activeIndex == 0),
                  _toggleLabel('Bulanan', activeIndex == 1),
                  _toggleLabel('Tahunan', activeIndex == 2),
                  _toggleLabel('Custom', activeIndex == 3),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggleLabel(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _periodMode = label),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFont.w900,
              color: isActive ? kPrimary : const Color(0xFF999999),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildBulananPicker() {
    final years = List.generate(3, (i) => DateTime.now().year - i);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            value: _bulan,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(
                  _namaBulan[i],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            onChanged: (val) => setState(() => _bulan = val ?? _bulan),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _tahun,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            items: years
                .map(
                  (y) => DropdownMenuItem(
                    value: y,
                    child: Text(
                      '$y',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _tahun = val ?? _tahun),
          ),
        ),
      ],
    );
  }

  Widget _buildTahunanPicker() {
    final years = List.generate(3, (i) => DateTime.now().year - i);
    return DropdownButtonFormField<int>(
      value: _tahun,
      isExpanded: true,
      decoration: _dropdownDecoration(),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      items: years
          .map(
            (y) => DropdownMenuItem(
              value: y,
              child: Text(
                '$y',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _tahun = val ?? _tahun),
    );
  }

  Widget _buildPeriodFields() {
    Widget? selector;
    if (_periodMode == 'Bulanan') {
      selector = _buildBulananPicker();
    } else if (_periodMode == 'Tahunan') {
      selector = _buildTahunanPicker();
    }

    return Column(
      children: [
        if (selector != null) ...[selector, const SizedBox(height: 12)],
        _buildDateRangePicker(),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    final range = _activeRange;
    return Row(
      children: [
        Expanded(
          child: _dateField(
            label: 'Tanggal Mulai',
            value: range.start,
            onTap: () async {
              setState(() => _periodMode = 'Custom');
              final picked = await _showStyledDatePicker(_tanggalMulai);
              if (picked == null) return;
              setState(() {
                _tanggalMulai = picked;
                if (_tanggalSelesai != null &&
                    _tanggalSelesai!.isBefore(picked)) {
                  _tanggalSelesai = picked;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dateField(
            label: 'Tanggal Selesai',
            value: range.end,
            onTap: () async {
              setState(() => _periodMode = 'Custom');
              final picked = await _showStyledDatePicker(
                _tanggalSelesai,
                initialDate: _tanggalMulai,
              );
              if (picked == null) return;
              setState(() {
                _tanggalSelesai = picked;
                if (_tanggalMulai != null && _tanggalMulai!.isAfter(picked)) {
                  _tanggalMulai = picked;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value != null
                ? kPrimary.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: kPrimary),
            const SizedBox(width: 10),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value != null
                          ? _dateFormat.format(value)
                          : 'Pilih tanggal',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                        color: value != null ? Colors.black87 : Colors.black26,
                      ),
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

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  Future<DateTime?> _showStyledDatePicker(
    DateTime? initial, {
    DateTime? initialDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 2, 1, 1);
    final requestedInitial = initial ?? initialDate ?? today;

    return await showDatePicker(
      context: context,
      initialDate: _clampDate(requestedInitial, firstDate, today),
      firstDate: firstDate,
      lastDate: today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: kPrimary),
          ),
        ),
        child: child!,
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
    );
  }

  Widget _buildApplyButton() {
    final canApply =
        _periodMode != 'Custom' ||
        (_tanggalMulai != null && _tanggalSelesai != null);
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: canApply
            ? [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: canApply ? _apply : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          disabledBackgroundColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'TERAPKAN FILTER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
