part of '../employee_attendance_detail_screen.dart';

/// Satu hari dalam minggu terpilih beserta record / izin bila ada.
class _DayEntry {
  final DateTime date;
  final int? shiftEndMinutes;
  final String? holidayLabel;
  final Map<String, dynamic> record;
  final Map<String, dynamic> leave;

  const _DayEntry({
    required this.date,
    this.shiftEndMinutes,
    this.holidayLabel,
    required this.record,
    required this.leave,
  });

  bool get isFuture => date.isAfter(DateTime.now());
  bool get hasRecord => record.isNotEmpty;
  bool get hasLeave => leave.isNotEmpty;
  bool get isHoliday => holidayLabel != null && holidayLabel!.isNotEmpty;
  bool get isBeforeTodayShiftEnd {
    final now = DateTime.now();
    if (date.year != now.year || date.month != now.month || date.day != now.day) {
      return false;
    }
    if (shiftEndMinutes == null) return true;
    return now.hour * 60 + now.minute < shiftEndMinutes!;
  }

  /// HADIR | TERLAMBAT | IZIN | ALFA | KOSONG
  String get statusCode {
    if (hasLeave) {
      final st = (leave['status']?.toString() ?? '').toUpperCase();
      if (st == 'APPROVED' || st == 'DISETUJUI' || st == 'APROVE') {
        return 'IZIN';
      }
    }
    if (hasRecord) {
      final st = (record['status']?.toString() ?? 'HADIR').toUpperCase();
      if (record['check_in_at'] != null) {
        return st == 'TERLAMBAT' ? 'TERLAMBAT' : 'HADIR';
      }
      // Backend may persist an ALFA row before the outlet holiday setting is
      // applied. A weekly/date holiday must still be shown as LIBUR unless
      // the employee actually checked in on that day.
      if (st == 'ALFA' && isHoliday) return 'KOSONG';
      if (st == 'ALFA') return 'ALFA';
    }
    // Hari lampau tanpa record absensi adalah ALFA. TANPA DATA hanya untuk
    // data yang belum final (atau hari yang belum lewat).
    if (!isFuture && !isBeforeTodayShiftEnd && !isHoliday) return 'ALFA';
    return 'KOSONG';
  }
}

class _DetailDayRow extends StatelessWidget {
  final _DayEntry entry;

  const _DetailDayRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(entry.date);
    final status = entry.statusCode;

    if (entry.isFuture || status == 'KOSONG') {
      return _shell(
        dateText,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            entry.isFuture
                ? '—'
                : (entry.isHoliday ? 'LIBUR' : 'BELUM ABSEN'),
            style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 10,
              fontWeight: AppFont.w700,
            ),
          ),
        ),
      );
    }

    final style = _style(status);
    return _shell(
      dateText,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          style.label,
          style: TextStyle(
            color: style.fg,
            fontSize: 10,
            fontWeight: AppFont.w700,
          ),
        ),
      ),
      body: _body(status),
    );
  }

  Widget? _body(String status) {
    if (status == 'IZIN') {
      return _InfoLine(
        icon: Icons.info_outline_rounded,
        text: entry.leave['reason']?.toString() ?? '-',
      );
    }
    if (status == 'HADIR' || status == 'TERLAMBAT') {
      return Row(
        children: [
          Expanded(
            child: _TimePill(
              label: 'Masuk',
              value: AttendanceProvider.formatAttendanceTime(
                entry.record['check_in_at'],
              ),
              color: AppPalette.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TimePill(
              label: 'Pulang',
              value: AttendanceProvider.formatAttendanceTime(
                entry.record['check_out_at'],
              ),
              color: AppPalette.danger,
            ),
          ),
        ],
      );
    }
    return null;
  }

  Widget _shell(String dateText, {required Widget trailing, Widget? body}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEFF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
            if (body != null) ...[const SizedBox(height: 12), body],
          ],
        ),
      );

  ({String label, Color fg, Color bg}) _style(String status) {
    switch (status) {
      case 'HADIR':
        return (label: 'HADIR', fg: AppPalette.success, bg: Color(0xFFE7F8F0));
      case 'TERLAMBAT':
        return (
          label: 'TERLAMBAT',
          fg: AppPalette.warning,
          bg: Color(0xFFFFF3E4),
        );
      case 'IZIN':
        return (label: 'IZIN', fg: AppPalette.info, bg: Color(0xFFE4F5FD));
      default:
        return (label: 'ALFA', fg: AppPalette.danger, bg: Color(0xFFFDECEC));
    }
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TimePill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFEDEFF3), width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.muted,
                fontWeight: AppFont.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFEDEFF3), width: 1),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppPalette.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.ink,
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
