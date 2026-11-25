import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_owner_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

part 'widgets/detail_summary_card.dart';
part 'widgets/detail_week_selector.dart';
part 'widgets/detail_day_row.dart';

class EmployeeAttendanceDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeAttendanceDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeAttendanceDetailScreen> createState() =>
      _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState
    extends State<EmployeeAttendanceDetailScreen> {
  /// 0 = minggu ini, -1 = minggu lalu, dst.
  int _weekOffset = 0;
  bool _monthly = false;
  int _monthOffset = 0;
  bool _isExporting = false;
  static const _daysPerPage = 10;
  int _dayPage = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final start = _weekStart;
      context.read<AttendanceProvider>().loadOwnerAttendanceRange(
            DateTimeRange(start: start, end: start.add(const Duration(days: 6))),
          );
    });
  }

  /// Senin dari minggu yang sedang dilihat.
  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset, 1);
  }

  List<_DayEntry> _getPaginatedDays(List<_DayEntry> allDays) {
    final start = 0;
    final end = (_dayPage * _daysPerPage).clamp(0, allDays.length);
    return allDays.sublist(start, end);
  }

  Future<void> _exportAttendance(List<_DayEntry> days, ({int hadir, int izin, int alfa}) summary) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      String time(dynamic value) {
        final parsed = DateTime.tryParse(value?.toString() ?? '');
        if (parsed == null) return '-';
        final local = parsed.toLocal();
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      final document = ReportPdfDocument(
        title: 'Laporan Kehadiran Karyawan',
        subtitle: widget.employeeName,
        periodLabel: _monthly
            ? DateFormat('MMMM yyyy', 'id_ID').format(_monthStart)
            : '${DateFormat('d MMM', 'id_ID').format(_weekStart)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_weekStart.add(const Duration(days: 6)))}',
        generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
        primaryValue: '${summary.hadir + summary.izin + summary.alfa} hari',
        primaryCaption: 'Rekap kehadiran',
        metrics: [
          ReportPdfMetric(title: 'Hadir', value: '${summary.hadir}', background: PdfColor.fromHex('#E9F8F1'), accent: PdfColor.fromHex('#18B979')),
          ReportPdfMetric(title: 'Izin', value: '${summary.izin}', background: PdfColor.fromHex('#EAF4FF'), accent: PdfColor.fromHex('#2684FF')),
          ReportPdfMetric(title: 'Alfa', value: '${summary.alfa}', background: PdfColor.fromHex('#FFF0EC'), accent: PdfColor.fromHex(AppPalette.primaryHex)),
        ],
        tables: [
          ReportPdfTable(
            title: 'Detail Kehadiran',
            headers: const ['Tanggal', 'Jam Masuk', 'Jam Pulang', 'Status'],
            rows: days.map((day) => [
              DateFormat('dd MMM yyyy', 'id_ID').format(day.date),
              time(day.record['check_in_at']),
              time(day.record['check_out_at']),
              day.isHoliday && !day.hasRecord ? 'LIBUR' : day.statusCode,
            ]).toList(),
          ),
        ],
        logoBytes: await ReportExportService.loadLogoBytes(),
      );
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName: 'laporan_kehadiran_${widget.employeeName.replaceAll(' ', '_')}.pdf',
        shareTitle: 'Laporan Kehadiran ${widget.employeeName}',
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export laporan: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _periodToggle(String label, bool selected, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppPalette.primary : Colors.white,
        foregroundColor: selected ? Colors.white : AppPalette.ink,
        side: BorderSide(color: selected ? AppPalette.primary : const Color(0xFFE3E8EF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: AppFont.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final employee = context.watch<PegawaiProvider>().employees.cast<Pegawai?>().firstWhere(
      (item) => item?.id == widget.employeeId,
      orElse: () => null,
    );
    final weekStart = _weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthStart = _monthStart;
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final rangeStart = _monthly ? monthStart : weekStart;
    final rangeEnd = _monthly ? monthEnd : weekEnd;
    // Rekap dipisahkan per bulan agar Agustus dan September tidak menumpuk.
    final summary = attendance.attendanceSummaryFor(
      widget.employeeId,
      from: rangeStart,
      to: rangeEnd,
    );
    final shiftName = attendance.shiftNameForEmployee(widget.employeeId);
    final assignedShift = attendance.configuration.shifts.where(
      (shift) => shift.name == shiftName,
    );
    final shiftEndMinutes = assignedShift.isEmpty
        ? null
        : assignedShift.first.endTime.hour * 60 +
            assignedShift.first.endTime.minute;
    final records = attendance.recordsForEmployee(widget.employeeId);
    final leaves = attendance.leavesForEmployee(widget.employeeId);

    final days = List.generate(
      _monthly ? monthEnd.day : 7,
      (i) {
      final date = rangeStart.add(Duration(days: i));
      final iso = AttendanceProvider.isoDate(date);
      return _DayEntry(
        date: date,
        shiftEndMinutes: shiftEndMinutes,
        holidayLabel: attendance.holidayLabelFor(date),
        record: records.firstWhere(
          (r) => (r['work_date']?.toString() ?? '').startsWith(iso),
          orElse: () => const {},
        ),
        leave: leaves.firstWhere(
          (r) => (r['work_date']?.toString() ?? '').startsWith(iso),
          orElse: () => const {},
        ),
      );
      },
    );
    // Hanya tampilkan hari yang sudah lewat / hari ini, terbaru di atas.
    final allVisibleDays = days
        .where(
          (d) =>
              !d.isFuture &&
              (employee == null ||
                  !d.date.isBefore(
                    DateTime(
                      employee.createdAt.year,
                      employee.createdAt.month,
                      employee.createdAt.day,
                    ),
                  )),
        )
        .toList()
        .reversed
        .toList();

    // Pagination untuk days
    final paginatedDays = _getPaginatedDays(allVisibleDays);

    return AppScaffold(
      backgroundColor: AppPalette.surface,
      appBar: AttendanceAppBar(
        title: 'Detail Kehadiran',
        actions: [
          IconButton(
            tooltip: 'Export laporan karyawan',
            onPressed: _isExporting ? null : () => _exportAttendance(allVisibleDays, summary),
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppPalette.primary),
          ),
        ],
      ),
      body: attendance.isLoadingConfig
          ? const EmployeeAttendanceDetailShimmer()
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _EmployeeHeader(
                    name: widget.employeeName,
                    shiftName: shiftName,
                  ),
                  const SizedBox(height: 12),
                  _DetailSummaryCard(
                    hadir: summary.hadir,
                    izin: summary.izin,
                    alfa: summary.alfa,
                    monthly: _monthly,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _periodToggle(
                          'Minggu',
                          !_monthly,
                          () => setState(() {
                            _monthly = false;
                            _dayPage = 1;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _periodToggle(
                          'Bulan',
                          _monthly,
                          () => setState(() {
                            _monthly = true;
                            _dayPage = 1;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_monthly)
                    _DetailWeekSelector(
                    label: _weekOffset == 0
                        ? 'Minggu Ini'
                        : _weekOffset == -1
                        ? 'Minggu Lalu'
                        : DateFormat('MMMM yyyy', 'id_ID').format(weekStart),
                    rangeText:
                        '${DateFormat('d MMM', 'id_ID').format(weekStart)} - '
                        '${DateFormat('d MMM yyyy', 'id_ID').format(weekEnd)}',
                    onPrev: () => setState(() {
                      _weekOffset -= 1;
                      _dayPage = 1;
                    }),
                    onNext: _weekOffset >= 0
                        ? null
                        : () => setState(() {
                              _weekOffset += 1;
                              _dayPage = 1;
                            }),
                    days: days,
                    )
                  else
                    _MonthSelector(
                      label: DateFormat('MMMM yyyy', 'id_ID').format(monthStart),
                      onPrev: () => setState(() {
                        _monthOffset -= 1;
                        _dayPage = 1;
                      }),
                      onNext: _monthOffset >= 0
                          ? null
                          : () => setState(() {
                                _monthOffset += 1;
                                _dayPage = 1;
                              }),
                    ),
                  const SizedBox(height: 12),
                  if (allVisibleDays.isEmpty)
                    const _NoDaysYet()
                  else
                    Column(
                      children: [
                        ...paginatedDays.map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DetailDayRow(entry: d),
                          ),
                        ),
                        if (allVisibleDays.length > _daysPerPage)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_dayPage > 1)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _dayPage -= 1),
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    label: const Text('Sebelumnya'),
                                  )
                                else
                                  const SizedBox.shrink(),
                                if (_dayPage * _daysPerPage < allVisibleDays.length)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _dayPage += 1),
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    label: const Text('Selanjutnya'),
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _NoDaysYet extends StatelessWidget {
  const _NoDaysYet();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: const Column(
      children: [
        Icon(Icons.calendar_today_outlined, color: AppPalette.muted, size: 24),
        SizedBox(height: 8),
        Text(
          'Belum ada hari yang tercatat minggu ini',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 11,
            fontWeight: AppFont.w700,
          ),
        ),
      ],
    ),
  );
}

class _MonthSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthSelector({required this.label, required this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        Text(label, style: const TextStyle(color: AppPalette.ink, fontWeight: AppFont.w800)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    ),
  );
}

class _EmployeeHeader extends StatelessWidget {
  final String name;
  final String shiftName;

  const _EmployeeHeader({required this.name, required this.shiftName});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppPalette.primarySoft,
          child: const Icon(Icons.person_rounded, color: AppPalette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 14,
                  fontWeight: AppFont.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                shiftName.isEmpty ? 'Belum ada shift' : shiftName,
                style: const TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
