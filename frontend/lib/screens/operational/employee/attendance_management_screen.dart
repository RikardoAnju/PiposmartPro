import 'dart:async';

import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_management_shimmer.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_configuration.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_settings_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_holiday_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_empty_state.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/configured_attendance_view.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/assign_employees_dialog.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ayocucinew/screens/home/widgets/tutorial/first_home_tutorial_overlay.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});
  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  StreamSubscription<AppEvent>? _outletSubscription;
  final GlobalKey _nightShiftMenuKey = GlobalKey();
  bool _showNightShiftTutorial = false;
  bool _nightTutorialCheckScheduled = false;

  Future<void> _maybeShowNightShiftTutorial(
    AttendanceConfiguration configuration,
  ) async {
    if (_nightTutorialCheckScheduled || _showNightShiftTutorial) return;
    if (!configuration.shifts.any(
      (shift) => shift.name.toLowerCase().contains('malam'),
    )) {
      return;
    }
    _nightTutorialCheckScheduled = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted ||
        (prefs.getBool('first_night_shift_employee_tutorial_v3') ?? false)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showNightShiftTutorial = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _outletSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched && mounted) _reloadForOutlet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadForOutlet();
    });
  }

  Future<void> _reloadForOutlet() async {
    final employeeProvider = context.read<PegawaiProvider>();
    // Daftar pegawai tersimpan di provider lintas halaman. Saat outlet
    // berganti, list lama tidak boleh dianggap valid hanya karena tidak kosong.
    await employeeProvider.fetchEmployees();
    if (!mounted) return;
    await context.read<AttendanceProvider>().loadConfigurationData(
      employeeProvider,
    );
  }

  @override
  void dispose() {
    _outletSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openSettings({
    bool isAddingShift = false,
    String? editingShiftName,
  }) async {
    final configuration = context.read<AttendanceProvider>().configuration;
    final hadNightShift = configuration.shifts.any(
      (shift) => shift.name.toLowerCase().contains('malam'),
    );
    final saved = await Navigator.of(context).push<AttendanceConfiguration>(
      MaterialPageRoute(
        builder: (_) => AttendanceSettingsScreen(
          configuration: configuration,
          isAddingShift: isAddingShift,
          editingShiftName: editingShiftName,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    final hasNightShift = saved.shifts.any(
      (shift) => shift.name.toLowerCase().contains('malam'),
    );
    // Panduan hanya muncul setelah membuat shift baru. Mengubah nama shift
    // yang sudah ada dari Pagi ke Malam bukan onboarding baru.
    if (isAddingShift && hasNightShift && !hadNightShift) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('first_night_shift_employee_tutorial_v3') ?? false) &&
          mounted) {
        // Tunggu satu frame agar kartu dan tombol titik tiga sudah terpasang
        // sebelum coachmark menghitung posisi targetnya.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showNightShiftTutorial = true);
        });
      }
    }
  }

  void _addSchedule() => _openSettings(isAddingShift: true);
  void _editConfiguration() => _openSettings();
  void _editShift(String shiftName) =>
      _openSettings(editingShiftName: shiftName);

  Future<void> _assignEmployees(String shiftName) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final employeeProvider = context.read<PegawaiProvider>();
    if (employeeProvider.employees.isEmpty) {
      await employeeProvider.fetchEmployees();
    }
    if (!mounted) return;

    final available = attendanceProvider.getAvailableEmployeesForShift(
      shiftName,
      employeeProvider.employees,
    );
    final initialSelected = attendanceProvider.getAssignedEmployeeIdsForShift(
      shiftName,
    );

    final selected = await showAssignEmployeesDialog(
      context,
      shiftName: shiftName,
      available: available,
      initialSelected: initialSelected,
    );
    if (selected == null || !mounted) return;

    final result = await attendanceProvider.assignEmployeesToShift(
      shiftName: shiftName,
      employeeIds: selected.toList(),
      employeeProvider: employeeProvider,
    );
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message']?.toString() ?? 'Karyawan berhasil diatur',
      isError: result['success'] != true,
    );
  }

  Future<void> _toggleAutoApprove(String shiftName, bool value) async {
    final result = await context.read<AttendanceProvider>().toggleShiftAutoApprove(
      shiftName: shiftName,
      autoApproveLeave: value,
    );
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message']?.toString() ??
          'Persetujuan izin otomatis diperbarui',
      isError: result['success'] != true,
    );
  }

  Future<void> _deleteShift(String shiftName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text('Apakah Anda yakin ingin menghapus shift $shiftName?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final result = await context.read<AttendanceProvider>().deleteShiftAndSave(
      shiftName,
    );
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message']?.toString() ?? 'Shift berhasil dihapus',
      isError: result['success'] != true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final isLoading = attendance.isLoadingConfig;
    final loadError = attendance.loadConfigError;
    final configuration = attendance.configuration;
    final employeeNames = attendance.employeeNames;
    final content = AppScaffold(
      backgroundColor: Colors.white,
      appBar: const AttendanceAppBar(title: 'Pengaturan Absen'),
      body: isLoading
          ? const AttendanceManagementShimmer()
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(loadError, textAlign: TextAlign.center),
              ),
            )
          : configuration.isConfigured
          ? ConfiguredAttendanceView(
              configuration: configuration,
              employeeNames: employeeNames,
              onEditConfiguration: _editConfiguration,
              onAdd: _addSchedule,
              onEditShift: _editShift,
              onAssignEmployees: _assignEmployees,
              onDelete: _deleteShift,
              onToggleAutoApprove: _toggleAutoApprove,
              onOpenHolidays: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const AttendanceHolidayScreen(),
                ),
              ),
              nightShiftMenuKey: _nightShiftMenuKey,
            )
          : AttendanceEmptyState(onConfigure: _editConfiguration),
    );
    return Stack(
      children: [
        content,
        if (_showNightShiftTutorial)
          FirstHomeTutorialOverlay(
            steps: [
              TutorialStepData(
                targetKey: _nightShiftMenuKey,
                icon: Icons.group_add_outlined,
                title: 'Atur karyawan Shift Malam',
                description:
                    'Tekan tombol titik tiga pada kartu Shift Malam, lalu pilih “Atur karyawan” untuk menentukan siapa saja yang masuk shift ini.',
              ),
            ],
            onCompleted: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(
                'first_night_shift_employee_tutorial_v3',
                true,
              );
              if (mounted) setState(() => _showNightShiftTutorial = false);
            },
          ),
      ],
    );
  }
}
