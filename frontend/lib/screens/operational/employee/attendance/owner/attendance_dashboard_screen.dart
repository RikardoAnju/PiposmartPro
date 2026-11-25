import 'dart:async';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance_management_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/owner/employee_attendance_detail_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/owner/leave_approval_screen.dart';
import 'package:ayocucinew/screens/settings/outlet/edit_profile_outlet_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_owner_shimmer.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:ayocucinew/screens/report/laporan pelanggan/ringkasan/widgets/customer_filter_sheet.dart';

// ignore_for_file: use_build_context_synchronously

part 'widgets/dashboard_header.dart';
part 'widgets/dashboard_stats.dart';
part 'widgets/roster_tile.dart';
part 'widgets/attendance_status_badge.dart';

class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  StreamSubscription<AppEvent>? _outletSubscription;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTimeRange? _attendanceRange;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _outletSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched && mounted) _reloadForOutlet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reloadForOutlet();
      if (mounted) _showSetupGuideIfNeeded();
    });
  }

  @override
  void dispose() {
    _outletSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadForOutlet() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final employeeProvider = context.read<PegawaiProvider>();
    attendanceProvider.resetForOutlet();
    await employeeProvider.fetchEmployees();
    if (mounted) await _load();
  }

  Future<void> _load() {
    if (_attendanceRange != null) {
      return context.read<AttendanceProvider>().loadOwnerAttendanceRange(
            _attendanceRange!,
          );
    }
    final now = DateTime.now();
    final provider = context.read<AttendanceProvider>();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      return provider.loadOwnerDashboard(context.read<PegawaiProvider>());
    }
    return provider.loadOwnerAttendanceMonth(_selectedMonth);
  }

  void _showSetupGuideIfNeeded() {
    final outlet = context.read<AppProvider>().outlet;
    final attendance = context.read<AttendanceProvider>();
    final hasLocation = outlet?.latitude != null && outlet?.longitude != null &&
        outlet!.latitude != 0 && outlet.longitude != 0;
    final hasSchedule = attendance.configuration.isConfigured;
    if (hasLocation && hasSchedule) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.fact_check_outlined, color: AppPalette.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Siapkan Absensi Outlet')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lengkapi pengaturan berikut sebelum karyawan mulai absen.'),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (hasLocation ? 0.5 : 0) + (hasSchedule ? 0.5 : 0),
                minHeight: 1,
                backgroundColor: const Color(0xFFEFF2F6),
                valueColor: const AlwaysStoppedAnimation(AppPalette.primary),
              ),
            ),
            const SizedBox(height: 16),
            _setupStep(
              icon: Icons.location_on_outlined,
              title: 'Simpan koordinat outlet',
              done: hasLocation,
              onTap: hasLocation
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileOutletScreen())).then((_) async {
                        if (!mounted) return;
                        await context.read<AppProvider>().fetchOutletProfile(force: true);
                        _showSetupGuideIfNeeded();
                      });
                    },
            ),
            const SizedBox(height: 10),
            _setupStep(
              icon: Icons.schedule_outlined,
              title: 'Atur jadwal dan shift absensi',
              done: hasSchedule,
              onTap: hasSchedule
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _openSettings();
                    },
            ),
          ],
        ),
        actions: [
          if (hasLocation && hasSchedule)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Selesai'),
            ),
        ],
      ),
    );
  }

  Widget _setupStep({
    required IconData icon,
    required String title,
    required bool done,
    required VoidCallback? onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? const Color(0xFFD9F2E5) : const Color(0xFFE8EBF0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : icon, color: done ? AppPalette.success : AppPalette.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: AppFont.w700))),
              Icon(done ? Icons.check : Icons.chevron_right, color: done ? AppPalette.success : AppPalette.muted),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _showReportStyleAttendanceFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerFilterSheet(
        startDate: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        endDate: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      ),
    );
    if (result == null || !mounted) return;
    final start = result['startDate'] as DateTime?;
    if (start == null) return;
    final end = result['endDate'] as DateTime? ?? start;
    setState(() {
      _selectedMonth = DateTime(start.year, start.month);
      _attendanceRange = DateTimeRange(start: start, end: end);
    });
    await _load();
  }



  List<Map<String, dynamic>> _getFilteredRoster(List<Map<String, dynamic>> fullRoster) {
    var list = fullRoster;

    if (_selectedStatusFilter == 'BELUM_ABSEN') {
      list = list.where((r) => (r['status'] as String? ?? '').toUpperCase() == 'BELUM_ABSEN').toList();
    } else if (_selectedStatusFilter == 'HADIR') {
      list = list.where((r) {
        final st = (r['status'] as String? ?? '').toUpperCase();
        return st == 'HADIR' || st == 'TERLAMBAT';
      }).toList();
    } else if (_selectedStatusFilter == 'IZIN_ALFA') {
      list = list.where((r) {
        final st = (r['status'] as String? ?? '').toUpperCase();
        return st == 'IZIN' ||
            st == 'ALFA' ||
            r['has_leave'] == true ||
            r['has_alfa'] == true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((row) => (row['name'] as String)
              .toLowerCase()
              .contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _openSettings() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const AttendanceManagementScreen()),
  ).then((_) async {
    if (!mounted) return;
    await context.read<AttendanceProvider>().loadConfigurationData(
      context.read<PegawaiProvider>(),
    );
    _showSetupGuideIfNeeded();
  });

  Future<void> _showQuickMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(sheetContext),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.mail_outline,
                            color: AppPalette.primary),
                        title: const Text('Pengajuan Izin'),
                        onTap: () => Navigator.pop(sheetContext, 'leave'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.tune_rounded,
                            color: AppPalette.primary),
                        title: const Text('Setting Jadwal Absen'),
                        onTap: () => Navigator.pop(sheetContext, 'settings'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'leave') {
      _openLeaveApproval();
    } else if (action == 'settings') {
      _openSettings();
    }
  }



  Future<void> _showExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan absensi karyawan.',
        onExportPdf: () {
          Navigator.pop(sheetContext);
          _exportAttendance('pdf');
        },
        onExportExcel: () {
          Navigator.pop(sheetContext);
          _exportAttendance('excel');
        },
      ),
    );
  }

  Future<void> _exportAttendance(String format) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final attendance = context.read<AttendanceProvider>();
      final employees = context.read<PegawaiProvider>();
      if (_attendanceRange != null) {
        await attendance.loadOvertimeRequests();
      }
      List<Map<String, dynamic>> rows;
      if (_attendanceRange == null) {
        rows = attendance.ownerTodayRoster(employees);
      } else {
        final names = {for (final employee in employees.employees) employee.id: employee.nama};
        final start = DateTime(
          _attendanceRange!.start.year,
          _attendanceRange!.start.month,
          _attendanceRange!.start.day,
        );
        final end = DateTime(
          _attendanceRange!.end.year,
          _attendanceRange!.end.month,
          _attendanceRange!.end.day,
        );
        rows = attendance.records.where((record) {
          final date = DateTime.tryParse(record['work_date']?.toString() ?? '');
          if (date == null) return false;
          final day = DateTime(date.year, date.month, date.day);
          return !day.isBefore(start) && !day.isAfter(end);
        }).map((record) {
          final date = DateTime.tryParse(record['work_date']?.toString() ?? '');
          final status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
          final isHoliday = date != null && attendance.holidayLabelFor(date) != null;
          return <String, dynamic>{
            'name': names[record['employee_id']?.toString()] ?? '-',
            'shift_name': record['shift_name']?.toString() ?? '-',
            'status': status == 'ALFA' && isHoliday ? 'LIBUR' : status,
            'record': record,
          };
        }).toList();
        final approvedLeaves = attendance.leaveRequests.where((leave) {
          final date = DateTime.tryParse(leave['work_date']?.toString() ?? '');
          if (date == null) return false;
          final day = DateTime(date.year, date.month, date.day);
          final status = (leave['status']?.toString() ?? '').toUpperCase();
          return !day.isBefore(start) && !day.isAfter(end) &&
              ['APPROVED', 'DISETUJUI', 'APROVE'].contains(status);
        });
        for (final leave in approvedLeaves) {
          final employeeId = leave['employee_id']?.toString() ?? '';
          rows.add({
            'name': names[employeeId] ?? '-',
            'shift_name': attendance.shiftNameForEmployee(employeeId),
            'status': 'IZIN',
            'record': {
              'work_date': leave['work_date'],
              'leave_type': leave['leave_type'] ?? leave['type'],
            },
          });
        }
        for (final row in rows) {
          final record = row['record'];
          if (record is! Map) continue;
          final employeeId = record['employee_id']?.toString() ?? '';
          final workDate = record['work_date']?.toString() ?? '';
          Map<String, dynamic>? overtime;
          for (final item in attendance.overtimeRequests) {
            if (item['employee_id']?.toString() == employeeId &&
                (item['work_date']?.toString() ?? '').startsWith(workDate)) {
              overtime = item;
              break;
            }
          }
          if (overtime != null) record['overtime'] = overtime;
        }
      }
      String attendanceTime(dynamic value) {
        final parsed = DateTime.tryParse(value?.toString() ?? '');
        if (parsed == null) return '-';
        final local = parsed.toLocal();
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      String overtimeDuration(dynamic value) {
        final minutes = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
        if (minutes == null || minutes <= 0) return '-';
        final hours = minutes ~/ 60;
        final remainder = minutes % 60;
        if (hours == 0) return '$remainder menit';
        if (remainder == 0) return '$hours jam';
        return '$hours jam $remainder menit';
      }
      final logo = format == 'pdf'
          ? await ReportExportService.loadLogoBytes()
          : null;
      final document = ReportPdfDocument(
        title: 'Laporan Absensi Karyawan',
        subtitle: _attendanceRange == null
            ? 'Rekap kehadiran karyawan hari ini.'
            : 'Rekap kehadiran karyawan sesuai periode filter.',
        periodLabel: _attendanceRange == null
            ? DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())
            : '${DateFormat('dd MMM yyyy', 'id_ID').format(_attendanceRange!.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_attendanceRange!.end)}',
        generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
        primaryValue: '${rows.length} data',
        primaryCaption: 'Total record periode',
        metrics: [
          ReportPdfMetric(
            title: 'Hadir',
            value: '${rows.where((r) => r['status'] == 'HADIR' || r['status'] == 'TERLAMBAT').length}',
            background: PdfColor.fromHex('#E9F8F1'),
            accent: PdfColor.fromHex('#18B979'),
          ),
          ReportPdfMetric(
            title: 'Terlambat',
            value: '${rows.where((r) => r['status'] == 'TERLAMBAT').length}',
            background: PdfColor.fromHex('#FFF4E5'),
            accent: PdfColor.fromHex('#F59E0B'),
          ),
          ReportPdfMetric(
            title: 'Izin / Alfa',
            value: '${rows.where((r) => r['status'] == 'IZIN' || r['status'] == 'ALFA').length}',
            background: PdfColor.fromHex('#FFF0EC'),
            accent: PdfColor.fromHex(AppPalette.primaryHex),
          ),
        ],
        tables: [
          ReportPdfTable(
            title: 'Daftar Absensi',
            headers: const [
              'Tanggal',
              'Nama Karyawan',
              'Shift',
              'Jam Masuk',
              'Jam Pulang',
              'Lembur',
              'Status',
            ],
            rows: rows
                .map((r) {
                  final record = r['record'] is Map
                      ? (r['record'] as Map).cast<String, dynamic>()
                      : const <String, dynamic>{};
                  return [
                    record['work_date'] != null
                        ? ReportExportBuilder.formatTableDate(record['work_date'])
                        : DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now()),
                    r['name']?.toString() ?? '-',
                    r['shift_name']?.toString() ?? '-',
                    attendanceTime(record['check_in_at']),
                    attendanceTime(record['check_out_at']),
                    overtimeDuration(
                      (r['overtime'] as Map?)?['approved_minutes'] ??
                          (r['overtime'] as Map?)?['requested_minutes'],
                    ),
                    attendanceStatusStyle(r['status']?.toString() ?? '-').label,
                  ];
                })
                .toList(),
          ),
        ],
        logoBytes: logo,
      );
      final date = _attendanceRange == null
          ? DateFormat('yyyyMMdd').format(DateTime.now())
          : '${DateFormat('yyyyMMdd').format(_attendanceRange!.start)}_${DateFormat('yyyyMMdd').format(_attendanceRange!.end)}';
      final safeContext = context;
      if (format == 'pdf') {
        await ReportExportService.exportPdf(
          context: safeContext,
          document: document,
          fileName: 'laporan_absensi_$date.pdf',
          shareTitle: 'Laporan Absensi Karyawan',
        );
      } else {
        await ReportExportService.exportExcel(
          context: safeContext,
          document: document,
          fileName: 'laporan_absensi_$date.xlsx',
          shareTitle: 'Laporan Absensi Karyawan',
        );
      }
      if (!mounted || !safeContext.mounted) return;
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Gagal export laporan: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openLeaveApproval() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const LeaveApprovalScreen()));

  void _openEmployeeDetail(String id, String name) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EmployeeAttendanceDetailScreen(
            employeeId: id,
            employeeName: name,
          ),
        ),
      ).then((_) {
        if (mounted) _load();
      });

  @override
  Widget build(BuildContext context) {
    final hasAddon = context.watch<AddonProvider>().isFeatureActive('ATTENDANCE');
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );

    if (!canAccessAddonFeature) {
      return AppScaffold(
        backgroundColor: AppPalette.surface,
        appBar: const AttendanceAppBar(
          title: 'Kelola Absen',
          centerTitle: true,
        ),
        body: AddonLockedPlaceholder(
          title: 'Add-on Absensi Karyawan',
          message:
              'Aktifkan add-on Absensi Karyawan untuk mencatat, mengatur jadwal shift, dan memantau kehadiran karyawan.',
          features: const [
            'Pencatatan absen masuk & pulang karyawan',
            'Pengaturan shift kerja & lokasi radius outlet',
            'Riwayat & kelola persetujuan izin/lembur',
          ],
          onActionTap: () => Navigator.pushNamed(context, '/aktivasi-akun'),
        ),
      );
    }

    final attendance = context.watch<AttendanceProvider>();
    final employees = context.watch<PegawaiProvider>();
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final rawRoster = isCurrentMonth && _attendanceRange == null
        ? attendance.ownerTodayRoster(employees)
        : attendance.ownerRosterForMonth(
            employees,
            _selectedMonth,
            range: _attendanceRange,
          );
  
    final roster = rawRoster;
    final periodStart = _attendanceRange?.start;
    final periodEnd = _attendanceRange?.end;
    bool inPeriod(dynamic value) {
      final date = DateTime.tryParse(value?.toString() ?? '');
      if (date == null || periodStart == null || periodEnd == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
      final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }
    final displayRoster = <Map<String, dynamic>>[];
    if (_attendanceRange != null) {
      final employeeById = {
        for (final employee in employees.employees) employee.id: employee,
      };
      final recordEmployeeIds = <String>{};
      for (final record in attendance.records.where(
        (item) => inPeriod(item['work_date']),
      )) {
        final employeeId = record['employee_id']?.toString() ?? '';
        final employee = employeeById[employeeId];
        if (employee == null) continue;
        recordEmployeeIds.add(employeeId);
        displayRoster.add({
          'id': '${employeeId}_${record['work_date']}_${record['id']}',
          'name': employee.nama,
          'shift_name': record['shift_name']?.toString() ?? '',
          'status': (record['status']?.toString() ?? 'HADIR').toUpperCase(),
          'record': record,
        });
      }
      for (final row in roster) {
        if (row['record'] == null && !recordEmployeeIds.contains(row['id'])) {
          displayRoster.add(row);
        }
      }
    } else {
      displayRoster.addAll(roster);
    }
    final totalActive = _attendanceRange == null
        ? employees.activeEmployeeCount
        : roster.length;
    final periodRecords = attendance.records.where(
      (record) => inPeriod(record['work_date']),
    );
    final periodLeaves = attendance.leaveRequests.where(
      (leave) => inPeriod(leave['work_date']) &&
          ['APPROVED', 'DISETUJUI', 'APROVE']
              .contains((leave['status']?.toString() ?? '').toUpperCase()),
    );
    int countStatus(String status) => roster.where((row) {
      final rowStatus = row['status']?.toString().toUpperCase();
      if (status == 'HADIR') {
        return rowStatus == 'HADIR' || rowStatus == 'TERLAMBAT';
      }
      if (status == 'ALFA') return rowStatus == 'ALFA' || row['has_alfa'] == true;
      if (status == 'IZIN') return rowStatus == 'IZIN' || row['has_leave'] == true;
      return rowStatus == status;
    }).length;
    final summaryHadir = _attendanceRange == null
        ? countStatus('HADIR')
        : periodRecords.where((record) {
            final status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
            return status != 'ALFA' && record['check_in_at'] != null;
          }).length;
    final summaryTerlambat = _attendanceRange == null
        ? countStatus('TERLAMBAT')
        : periodRecords
            .where((record) => (record['status']?.toString() ?? '').toUpperCase() == 'TERLAMBAT')
            .length;
    final summaryAlfa = _attendanceRange == null
        ? countStatus('ALFA')
        : periodRecords
            .where((record) {
              final date = DateTime.tryParse(record['work_date']?.toString() ?? '');
              return (record['status']?.toString() ?? '').toUpperCase() == 'ALFA' &&
                  (date == null || attendance.holidayLabelFor(date) == null);
            })
            .length;
    final summaryIzin = _attendanceRange == null
        ? countStatus('IZIN') + attendance.pendingLeaveCount
        : periodLeaves.length;
    final filteredRoster = _getFilteredRoster(displayRoster).map((row) {
      if (_selectedStatusFilter == 'IZIN_ALFA') {
        final filteredStatus = row['has_leave'] == true
            ? 'IZIN'
            : row['has_alfa'] == true
            ? 'ALFA'
            : row['status'];
        return {
          ...row,
          'status': filteredStatus,
          'record': null,
        };
      }
      return row;
    }).toList();

    return AppScaffold(
      backgroundColor: AppPalette.surface,
      appBar: AttendanceAppBar(
        title: 'Kelola Absen',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Download laporan',
            icon: const Icon(
              Icons.description_outlined,
              color: AppPalette.primary,
            ),
            onPressed: _showExportSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Pengaturan absen',
        backgroundColor: Colors.white,
        foregroundColor: AppPalette.primary,
        elevation: 3,
        onPressed: _showQuickMenu,
        child: const Icon(Icons.tune_rounded),
      ),
      body: attendance.isLoadingConfig
          ? const AttendanceDashboardShimmer()
          : SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppPalette.primary,
                child: CustomScrollView(
                  controller: _scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(700),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RepaintBoundary(
                              child: _DashboardHeader(
                                selectedMonth: _selectedMonth,
                                onCalendarTap: _showReportStyleAttendanceFilter,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RepaintBoundary(
                              child: _DashboardStats(
                                total: totalActive,
                                hadir: summaryHadir,
                                terlambat: summaryTerlambat,
                      belumAbsen: countStatus('BELUM_ABSEN'),
                      // Tampilkan juga izin yang masih menunggu persetujuan
                      // agar angka statistik sama dengan kartu notifikasi.
                                izin: summaryIzin,
                                alfa: summaryAlfa,
                              ),
                            ),
                            if (attendance.pendingLeaveCount > 0) ...[
                              const SizedBox(height: 14),
                              _LeaveApprovalTile(
                                count: attendance.pendingLeaveCount,
                                onTap: _openLeaveApproval,
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Section Header: Title & Total Count Pill
                            Text(
                              _attendanceRange != null &&
                                      _attendanceRange!.start.day == 1 &&
                                      _attendanceRange!.end.month ==
                                          _attendanceRange!.start.month &&
                                      _attendanceRange!.end.day ==
                                          DateTime(
                                            _attendanceRange!.start.year,
                                            _attendanceRange!.start.month + 1,
                                            0,
                                          ).day
                                  ? 'Kehadiran ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}'
                                  : _attendanceRange == null
                                  ? 'Kehadiran Hari Ini'
                                  : 'Kehadiran Minggu Ini',
                              style: TextStyle(
                                color: AppPalette.ink,
                                fontSize: 16,
                                fontWeight: AppFont.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Status Filter Chips Row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChipItem(
                                    label: 'Semua',
                                    isSelected: _selectedStatusFilter == 'ALL',
                                    onTap: () => setState(() => _selectedStatusFilter = 'ALL'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipItem(
                                    label: 'Belum Absen',
                                    isSelected: _selectedStatusFilter == 'BELUM_ABSEN',
                                    onTap: () => setState(() => _selectedStatusFilter = 'BELUM_ABSEN'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipItem(
                                    label: 'Hadir',
                                    isSelected: _selectedStatusFilter == 'HADIR',
                                    onTap: () => setState(() => _selectedStatusFilter = 'HADIR'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipItem(
                                    label: 'Izin / Alfa',
                                    isSelected: _selectedStatusFilter == 'IZIN_ALFA',
                                    onTap: () => setState(() => _selectedStatusFilter = 'IZIN_ALFA'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Search Bar Input
                            if (roster.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  onChanged: (value) => setState(() => _searchQuery = value),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppPalette.ink,
                                    fontWeight: AppFont.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama karyawan...',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                      fontWeight: AppFont.w500,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? GestureDetector(
                                            onTap: () => setState(() => _searchQuery = ''),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppPalette.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredRoster.isEmpty)
                      const SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: _EmptyRoster(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filteredRoster.length,
                          itemBuilder: (context, index) {
                            final row = filteredRoster[index];
                            final id = row['id'] as String? ?? '$index';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RepaintBoundary(
                                child: RosterTile(
                                  key: ValueKey(id),
                                  row: row,
                                  onTap: () => _openEmployeeDetail(
                                    id,
                                    row['name'] as String? ?? '',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 24),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppPalette.primary : const Color(0xFFE2E8F0),
        ),
        boxShadow: isSelected ? AppShadows.colored(AppPalette.primary) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: isSelected ? AppFont.w800 : AppFont.w600,
        ),
      ),
    ),
  );
}

class _LeaveApprovalTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _LeaveApprovalTile({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEFF3)),
          boxShadow: AppShadows.cardSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1EC), Color(0xFFFFE3D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.mark_email_unread_rounded,
                color: AppPalette.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pengajuan Izin',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 14,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count > 0 ? '$count permohonan perlu persetujuan' : 'Tidak ada permohonan baru',
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.colored(AppPalette.primary),
                ),
                child: Text(
                  '$count Baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppPalette.muted, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_off_rounded,
            color: AppPalette.muted,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tidak Ada Data Karyawan',
          style: TextStyle(
            color: AppPalette.ink,
            fontSize: 13,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tidak ditemukan karyawan sesuai kata kunci atau filter status.',
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 11,
            fontWeight: AppFont.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
