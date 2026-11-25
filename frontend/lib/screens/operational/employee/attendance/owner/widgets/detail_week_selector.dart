part of '../employee_attendance_detail_screen.dart';

class _DetailWeekSelector extends StatelessWidget {
  final String label;
  final String rangeText;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final List<_DayEntry> days;

  const _DetailWeekSelector({
    required this.label,
    required this.rangeText,
    required this.onPrev,
    required this.onNext,
    required this.days,
  });

  static const _dow = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

  @override
  Widget build(BuildContext context) {
    final today = AttendanceProvider.isoDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _navButton(Icons.chevron_left_rounded, onPrev),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 12,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    Text(
                      rangeText,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _navButton(Icons.chevron_right_rounded, onNext),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayDot(
                    dow: _dow[i],
                    day: days[i].date.day,
                    status: days[i].statusCode,
                    isToday: AttendanceProvider.isoDate(
                      days[i].date,
                    ).startsWith(today),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) => IconButton(
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      icon,
      size: 22,
      color: onTap == null ? const Color(0xFFCBD3DD) : AppPalette.ink,
    ),
  );
}

class _DayDot extends StatelessWidget {
  final String dow;
  final int day;
  final String status;
  final bool isToday;

  const _DayDot({
    required this.dow,
    required this.day,
    required this.status,
    required this.isToday,
  });

  Color get _color {
    switch (status) {
      case 'HADIR':
      case 'TERLAMBAT':
        return AppPalette.success;
      case 'IZIN':
        return AppPalette.info;
      case 'ALFA':
        return AppPalette.danger;
      default:
        return const Color(0xFFD7DCE3);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        dow,
        style: const TextStyle(
          fontSize: 8,
          color: AppPalette.muted,
          fontWeight: AppFont.w700,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? AppPalette.primary : Colors.transparent,
          border: isToday ? null : Border.all(color: const Color(0xFFEDEFF3)),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFont.w800,
            color: isToday ? Colors.white : AppPalette.ink,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
      ),
    ],
  );
}
