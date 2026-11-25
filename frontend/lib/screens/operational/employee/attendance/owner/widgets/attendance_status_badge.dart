part of '../attendance_dashboard_screen.dart';

/// Warna + label untuk status kehadiran harian.
({String label, Color fg, Color bg}) attendanceStatusStyle(String status) {
  switch (status.toUpperCase()) {
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
    case 'ALFA':
      return (label: 'ALFA', fg: AppPalette.danger, bg: Color(0xFFFDECEC));
    default:
      return (
        label: 'BELUM ABSEN',
        fg: AppPalette.muted,
        bg: Color(0xFFF1F3F6),
      );
  }
}

class AttendanceStatusBadge extends StatelessWidget {
  final String status;

  const AttendanceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = attendanceStatusStyle(status);
    final icon = switch (status.toUpperCase()) {
      'HADIR' => Icons.check_rounded,
      'TERLAMBAT' => Icons.schedule_rounded,
      'IZIN' => Icons.mail_outline_rounded,
      'ALFA' => Icons.remove_rounded,
      _ => Icons.hourglass_empty_rounded,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: s.fg),
          ),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: TextStyle(
              color: s.fg,
              fontSize: 9,
              fontWeight: AppFont.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class ShiftChip extends StatelessWidget {
  final String shiftName;

  const ShiftChip({super.key, required this.shiftName});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppPalette.primarySoft,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      shiftName.toUpperCase(),
      style: const TextStyle(
        color: AppPalette.primaryDeep,
        fontSize: 10,
        fontWeight: AppFont.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}
