import 'package:flutter/material.dart';

class AttendanceConfiguration {
  final bool isConfigured;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool autoApproveLeave;
  final int lateToleranceMinutes;
  final List<AttendanceShift> shifts;

  const AttendanceConfiguration({
    required this.isConfigured,
    required this.startTime,
    required this.endTime,
    required this.autoApproveLeave,
    required this.shifts,
    this.lateToleranceMinutes = 0,
  });

  factory AttendanceConfiguration.defaults() => const AttendanceConfiguration(
    isConfigured: false,
    startTime: TimeOfDay(hour: 6, minute: 0),
    endTime: TimeOfDay(hour: 17, minute: 0),
    autoApproveLeave: false,
    shifts: [],
  );

  factory AttendanceConfiguration.fromApi(Map<String, dynamic> data) {
    final rawShifts = data['shifts'] as List? ?? const [];
    final autoApprove = _asBool(data['auto_approve_leave'], fallback: false);
    return AttendanceConfiguration(
      isConfigured: data['is_configured'] == true,
      startTime: TimeOfDay(
        hour: (data['start_hour'] as num?)?.toInt() ?? 6,
        minute: (data['start_minute'] as num?)?.toInt() ?? 0,
      ),
      endTime: TimeOfDay(
        hour: (data['end_hour'] as num?)?.toInt() ?? 17,
        minute: (data['end_minute'] as num?)?.toInt() ?? 0,
      ),
      autoApproveLeave: autoApprove,
      lateToleranceMinutes: (data['late_tolerance_minutes'] as num?)?.toInt() ?? 0,
      shifts: rawShifts
          .map(
            (item) => AttendanceShift.fromJson(
              (item as Map?)?.cast<String, dynamic>() ??
                  {'name': item.toString()},
              fallbackAutoApproveLeave: autoApprove,
              fallbackStartTime: TimeOfDay(
                hour: (data['start_hour'] as num?)?.toInt() ?? 6,
                minute: (data['start_minute'] as num?)?.toInt() ?? 0,
              ),
              fallbackEndTime: TimeOfDay(
                hour: (data['end_hour'] as num?)?.toInt() ?? 17,
                minute: (data['end_minute'] as num?)?.toInt() ?? 0,
              ),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toApi() => {
    'is_configured': isConfigured,
    'start_hour': startTime.hour,
    'start_minute': startTime.minute,
    'end_hour': endTime.hour,
    'end_minute': endTime.minute,
    'auto_approve_leave': autoApproveLeave,
    'late_tolerance_minutes': lateToleranceMinutes,
    'shifts': shifts.map((shift) => shift.toJson()).toList(),
  };
}

/// Shift identifies a schedule; its hours always follow outlet hours.
class AttendanceShift {
  final String name;
  final bool autoApproveLeave;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<String> employeeIds;

  const AttendanceShift({
    required this.name,
    this.autoApproveLeave = false,
    this.startTime = const TimeOfDay(hour: 6, minute: 0),
    this.endTime = const TimeOfDay(hour: 17, minute: 0),
    this.employeeIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'auto_approve_leave': autoApproveLeave,
    'start_hour': startTime.hour,
    'start_minute': startTime.minute,
    'end_hour': endTime.hour,
    'end_minute': endTime.minute,
    'employee_ids': employeeIds,
  };

  factory AttendanceShift.fromJson(
    Map<String, dynamic> data, {
    bool fallbackAutoApproveLeave = false,
    TimeOfDay fallbackStartTime = const TimeOfDay(hour: 6, minute: 0),
    TimeOfDay fallbackEndTime = const TimeOfDay(hour: 17, minute: 0),
  }) => AttendanceShift(
    name: data['name']?.toString() ?? 'Shift',
    autoApproveLeave: _asBool(
      data['auto_approve_leave'],
      fallback: fallbackAutoApproveLeave,
    ),
    startTime: TimeOfDay(
      hour: (data['start_hour'] as num?)?.toInt() ?? fallbackStartTime.hour,
      minute:
          (data['start_minute'] as num?)?.toInt() ?? fallbackStartTime.minute,
    ),
    endTime: TimeOfDay(
      hour: (data['end_hour'] as num?)?.toInt() ?? fallbackEndTime.hour,
      minute: (data['end_minute'] as num?)?.toInt() ?? fallbackEndTime.minute,
    ),
    employeeIds: (data['employee_ids'] as List? ?? const [])
        .map((id) => id.toString())
        .toList(),
  );
}

bool _asBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}
