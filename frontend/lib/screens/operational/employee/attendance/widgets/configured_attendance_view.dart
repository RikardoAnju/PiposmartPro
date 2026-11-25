import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_configuration.dart';
import 'package:flutter/material.dart';

part 'configured_attendance/schedule_hero.dart';
part 'configured_attendance/shift_card.dart';

class ConfiguredAttendanceView extends StatelessWidget {
  final AttendanceConfiguration configuration;
  final VoidCallback onEditConfiguration;
  final VoidCallback onAdd;
  final void Function(String shiftName) onEditShift;
  final void Function(String shiftName) onAssignEmployees;
  final void Function(String shiftName) onDelete;
  final void Function(String shiftName, bool autoApproveLeave)?
  onToggleAutoApprove;
  final VoidCallback? onOpenHolidays;
  final Map<String, String> employeeNames;
  final GlobalKey? nightShiftMenuKey;

  const ConfiguredAttendanceView({
    super.key,
    required this.configuration,
    required this.onEditConfiguration,
    required this.onAdd,
    required this.onEditShift,
    required this.onAssignEmployees,
    required this.onDelete,
    this.onToggleAutoApprove,
    this.onOpenHolidays,
    this.employeeNames = const {},
    this.nightShiftMenuKey,
  });

  @override
  Widget build(BuildContext context) {
    final start = AttendanceProvider.formatTimeOfDay(configuration.startTime);
    final end = AttendanceProvider.formatTimeOfDay(configuration.endTime);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _ScheduleHero(start: start, end: end),
                const SizedBox(height: 16),
                const Text(
                  'Shift karyawan',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 15,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...configuration.shifts.map(
                  (shift) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ShiftCard(
                      menuKey: shift.name.toLowerCase().contains('malam')
                          ? nightShiftMenuKey
                          : null,
                      shiftName: shift.name,
                      start: AttendanceProvider.formatTimeOfDay(
                        shift.startTime,
                      ),
                      end: AttendanceProvider.formatTimeOfDay(shift.endTime),
                      autoApproveLeave: shift.autoApproveLeave,
                      employeeCount: shift.employeeIds.length,
                      employees: shift.employeeIds
                          .map((id) => employeeNames[id] ?? id)
                          .toList(),
                      onEdit: () => onEditShift(shift.name),
                      onAssignEmployees: () => onAssignEmployees(shift.name),
                      onDelete: () => onDelete(shift.name),
                      onToggleAutoApprove: onToggleAutoApprove == null
                          ? null
                          : (value) =>
                                onToggleAutoApprove!(shift.name, value),
                    ),
                  ),
                ),
                if (onOpenHolidays != null) ...[
                  const SizedBox(height: 6),
                  Material(
                    color: const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.event_busy_rounded,
                        color: Color(0xFF3978DD),
                      ),
                      title: const Text(
                        'Hari Libur Outlet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                      subtitle: const Text(
                        'Atur libur mingguan & tanggal merah',
                        style: TextStyle(fontSize: 10, color: AppPalette.muted),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onOpenHolidays,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'TAMBAH JADWAL ABSEN',
                  style: TextStyle(fontSize: 12, fontWeight: AppFont.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
