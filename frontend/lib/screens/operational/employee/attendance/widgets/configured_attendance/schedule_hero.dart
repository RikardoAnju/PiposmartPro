part of '../configured_attendance_view.dart';

class _ScheduleHero extends StatelessWidget {
  final String start;
  final String end;

  const _ScheduleHero({required this.start, required this.end});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: AppPalette.brandGradient),
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppShadows.colored(AppPalette.primaryDeep),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: const Text(
                'Jadwal Absensi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: AppFont.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Jam operasional dan shift aktif outlet.',
          style: TextStyle(color: Color(0xFFFFE7DE), fontSize: 12),
        ),
        const SizedBox(height: 18),
        _HeroInfoRow(
          icon: Icons.schedule_rounded,
          label: 'Jam operasional',
          value: '$start - $end',
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
}

class _HeroInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFFFE7DE), fontSize: 11),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: AppFont.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
