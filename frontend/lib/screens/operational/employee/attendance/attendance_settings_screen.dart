import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_configuration.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/digital_time_dialog.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/section_title.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/settings_section.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/time_field.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/work_time_note.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/assign_employees_dialog.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AttendanceSettingsScreen extends StatefulWidget {
  final AttendanceConfiguration configuration;
  final bool isAddingShift;
  final String? editingShiftName;

  const AttendanceSettingsScreen({
    super.key,
    required this.configuration,
    this.isAddingShift = false,
    this.editingShiftName,
  });
  @override
  State<AttendanceSettingsScreen> createState() =>
      _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState extends State<AttendanceSettingsScreen> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _auto;
  int? _lateToleranceMinutes;
  late List<AttendanceShift> _shifts;
  late final Set<String> _originalShiftNames;
  String? _selectedShiftName;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _start = widget.configuration.startTime;
    _end = widget.configuration.endTime;
    _auto = widget.configuration.autoApproveLeave;
    _lateToleranceMinutes = widget.configuration.lateToleranceMinutes == 0
        ? null
        : widget.configuration.lateToleranceMinutes;
    _shifts = List<AttendanceShift>.of(widget.configuration.shifts);
    _originalShiftNames = widget.configuration.shifts
        .map((shift) => shift.name)
        .toSet();
    // Jangan memilih shift otomatis. Owner harus memilih shift secara eksplisit.
    _selectedShiftName = widget.editingShiftName;
    if (widget.editingShiftName != null) {
      final editingShift = _shifts.where(
        (shift) => shift.name == widget.editingShiftName,
      );
      if (editingShift.isNotEmpty) {
        _auto = editingShift.first.autoApproveLeave;
        _start = editingShift.first.startTime;
        _end = editingShift.first.endTime;
      }
    }
  }

  AttendanceConfiguration get _value {
    final shifts = widget.isAddingShift && _selectedShiftName != null
        ? [
            ..._shifts.where((shift) =>
                _originalShiftNames.contains(shift.name) &&
                shift.name != _selectedShiftName),
            AttendanceShift(
              name: _selectedShiftName!,
              autoApproveLeave: _auto,
              startTime: _start,
              endTime: _end,
              employeeIds: _shifts
                  .firstWhere(
                    (shift) => shift.name == _selectedShiftName,
                    orElse: () => AttendanceShift(name: _selectedShiftName!),
                  )
                  .employeeIds,
            ),
          ]
        : _shifts;
    return AttendanceConfiguration(
      isConfigured: true,
      startTime: _start,
      endTime: _end,
      autoApproveLeave: _auto,
      lateToleranceMinutes: _lateToleranceMinutes ?? 0,
      shifts: shifts,
    );
  }
  void _cancel() {
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final value = _value;
    try {
      final saved = await context.read<AttendanceProvider>().save(value);
      if (!mounted) return;
      CustomToast.show(
        context,
        message: widget.isAddingShift || !widget.configuration.isConfigured
            ? 'Jadwal absensi berhasil ditambahkan'
            : 'Jadwal absensi berhasil diperbarui',
      );
      if (widget.isAddingShift && saved.shifts.isNotEmpty) {
        final shiftName = saved.shifts.last.name;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Langkah berikutnya'),
            content: Text(
              'Jadwal $shiftName berhasil dibuat. Tekan tombol titik tiga (…) pada card shift, lalu pilih “Atur karyawan”.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
      Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      CustomToast.show(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _pick(bool isStart) async {
    final value = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => DigitalTimeDialog(initialTime: isStart ? _start : _end),
    );
    if (value != null && mounted) {
      setState(() {
        if (isStart) {
          _start = value;
        } else {
          _end = value;
        }
        if (widget.editingShiftName != null) {
          _shifts = _shifts
              .map(
                (shift) => shift.name == widget.editingShiftName
                    ? AttendanceShift(
                        name: shift.name,
                        autoApproveLeave: shift.autoApproveLeave,
                        startTime: _start,
                        endTime: _end,
                        employeeIds: shift.employeeIds,
                      )
                    : shift,
              )
              .toList();
        }
      });
    }
  }

  void _selectShift(String? name) {
    if (name == null) return;
    final provider = context.read<AttendanceProvider>();
    final previousSelection = _selectedShiftName;
    setState(() {
      _selectedShiftName = name;
      if (widget.isAddingShift) {
        // Keep the dropdown choice as an unsaved draft. The final payload is
        // assembled by _value only when the owner presses Save.
      } else if (widget.editingShiftName == null) {
        // This screen represents a single shift selection at a time, so
        // switching the dropdown must replace the previous pick instead of
        // accumulating both (e.g. picking "Shift Pagi" then "Shift Malam"
        // should leave only "Shift Malam", not both).
        if (previousSelection != null && previousSelection != name) {
          _shifts = provider.removeShift(_shifts, previousSelection);
        }
        if (!_shifts.any((shift) => shift.name == name)) {
          _shifts = provider.addShift(
            _shifts,
            name,
            autoApproveLeave: _auto,
            startTime: _start,
            endTime: _end,
          );
        }
      } else {
        _shifts = provider.renameShift(
          _shifts,
          widget.editingShiftName!,
          name,
          autoApproveLeave: _auto,
          startTime: _start,
          endTime: _end,
        );
      }
    });
  }

  List<String> get _shiftOptions => AttendanceProvider.shiftOptions;

  Future<void> _pickEmployees() async {
    final shiftName = _selectedShiftName;
    if (shiftName == null) return;
    final employeesProvider = context.read<PegawaiProvider>();
    if (employeesProvider.employees.isEmpty) {
      await employeesProvider.fetchEmployees();
    }
    if (!mounted) return;
    final shift = _shifts.firstWhere(
      (item) => item.name == shiftName,
      orElse: () => AttendanceShift(name: shiftName),
    );
    final selected = await showAssignEmployeesDialog(
      context,
      shiftName: shiftName,
      available: employeesProvider.employees
          .where(PegawaiProvider.isActiveEmployee)
          .toList(),
      initialSelected: shift.employeeIds.toSet(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final exists = _shifts.any((item) => item.name == shiftName);
      final updated = _shifts
          .map(
            (item) => item.name == shiftName
                ? AttendanceShift(
                    name: item.name,
                    autoApproveLeave: item.autoApproveLeave,
                    startTime: item.startTime,
                    endTime: item.endTime,
                    employeeIds: selected.toList(),
                  )
                : item,
          )
          .toList();
      if (exists) {
        _shifts = updated;
      } else {
        _shifts = [
          ...updated,
          AttendanceShift(
            name: shiftName,
            autoApproveLeave: _auto,
            startTime: _start,
            endTime: _end,
            employeeIds: selected.toList(),
          ),
        ];
      }
    });
  }

  Widget _selectedEmployeesList() {
    final shiftName = _selectedShiftName;
    if (shiftName == null) return const SizedBox.shrink();
    final matchingShifts = _shifts.where((item) => item.name == shiftName);
    final shift = matchingShifts.isEmpty ? null : matchingShifts.first;
    final ids = shift?.employeeIds ?? const <String>[];
    if (ids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Belum ada karyawan dipilih untuk shift ini.',
          style: TextStyle(color: AppPalette.muted, fontSize: 11),
        ),
      );
    }
    final employees = context.watch<PegawaiProvider>().employees;
    final names = {
      for (final employee in employees) employee.id: employee.nama,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFE8EDF2)),
          const SizedBox(height: 10),
          Text(
            'Karyawan terpilih (${ids.length})',
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 11,
              fontWeight: AppFont.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...ids.map(
            (id) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 16, color: AppPalette.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      names[id] ?? id,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _cancel();
    },
    child: AppScaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AttendanceAppBar(title: 'Pengaturan Absen', onBack: _cancel),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Pengaturan Jam Kerja',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tentukan jam kerja operasional outlet Anda sebelum mengaktifkan fitur absensi.',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        label: 'JAM MASUK',
                        value: AttendanceProvider.formatTimeOfDay(_start),
                        onTap: () => _pick(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TimeField(
                        label: 'JAM PULANG',
                        value: AttendanceProvider.formatTimeOfDay(_end),
                        onTap: () => _pick(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const WorkTimeNote(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsSection(
            child: DropdownButtonFormField<int?>(
              value: _lateToleranceMinutes,
              isExpanded: true,
              menuMaxHeight: 280,
              borderRadius: BorderRadius.circular(16),
              decoration: const InputDecoration(
                labelText: 'Toleransi keterlambatan',
                helperText:
                    'Jika tanpa toleransi, terlambat dihitung langsung dari jam masuk.',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('Tanpa toleransi')),
                DropdownMenuItem<int?>(value: 5, child: Text('5 menit')),
                DropdownMenuItem<int?>(value: 10, child: Text('10 menit')),
                DropdownMenuItem<int?>(value: 15, child: Text('15 menit')),
                DropdownMenuItem<int?>(value: 20, child: Text('20 menit')),
                DropdownMenuItem<int?>(value: 30, child: Text('30 menit')),
                DropdownMenuItem<int?>(value: 45, child: Text('45 menit')),
                DropdownMenuItem<int?>(value: 60, child: Text('60 menit')),
              ],
              onChanged: (value) => setState(() => _lateToleranceMinutes = value),
            ),
          ),
          const SizedBox(height: 14),
          SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan Shift',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih shift untuk tim. Jam otomatis mengikuti pengaturan di atas.',
                  style: TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedShiftName),
                  initialValue: _selectedShiftName,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  hint: const Text(
                    'Pilih shift yang belum ditambahkan',
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: _shiftOptions
                      .map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  disabledHint: const Text(
                    'Semua shift sudah ditambahkan',
                    style: TextStyle(color: AppPalette.muted, fontSize: 13),
                  ),
                  onChanged: _selectShift,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsSection(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilih Karyawan', style: TextStyle(color: AppPalette.ink, fontSize: 14, fontWeight: AppFont.w700)),
                          SizedBox(height: 5),
                          Text('Tentukan karyawan yang mengikuti shift ini.', style: TextStyle(color: AppPalette.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _selectedShiftName == null || _saving ? null : _pickEmployees,
                      icon: const Icon(Icons.groups_rounded, size: 17),
                      label: const Text('Pilih'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                _selectedEmployeesList(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsSection(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setujui Izin Otomatis',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 14,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Setujui perizinan karyawan secara otomatis',
                        style: TextStyle(color: AppPalette.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _auto,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppPalette.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Color(0xFFDDE2E8),
                  onChanged: (value) => setState(() {
                    _auto = value;
                    if (widget.editingShiftName != null) {
                      _shifts = _shifts
                          .map(
                            (shift) => shift.name == widget.editingShiftName
                                ? AttendanceShift(
                                    name: shift.name,
                                    autoApproveLeave: value,
                                  )
                                : shift,
                          )
                          .toList();
                    }
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SIMPAN PENGATURAN',
                      style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
