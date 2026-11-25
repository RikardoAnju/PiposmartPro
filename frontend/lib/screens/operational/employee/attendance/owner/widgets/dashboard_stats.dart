part of '../attendance_dashboard_screen.dart';

class _DashboardStats extends StatefulWidget {
  final int total;
  final int hadir;
  final int terlambat;
  final int belumAbsen;
  final int izin;
  final int alfa;

  const _DashboardStats({
    required this.total,
    required this.hadir,
    required this.terlambat,
    required this.belumAbsen,
    required this.izin,
    required this.alfa,
  });

  @override
  State<_DashboardStats> createState() => _DashboardStatsState();
}

class _DashboardStatsState extends State<_DashboardStats> {
  @override
  Widget build(BuildContext context) {
    final primaryCards = [
        _StatCard(
          label: 'Hadir',
          value: widget.hadir,
          color: AppPalette.success,
          icon: Icons.check_rounded,
        ),
        _StatCard(
          label: 'Alfa',
          value: widget.alfa,
          color: AppPalette.danger,
          icon: Icons.remove_rounded,
        ),
    ];
    final secondaryCards = [
        _StatCard(
          label: 'Karyawan',
          value: widget.total,
          color: const Color(0xFF526273),
          icon: Icons.groups_2_outlined,
        ),
        _StatCard(
          label: 'Terlambat',
          value: widget.terlambat,
          color: AppPalette.warning,
          icon: Icons.schedule_rounded,
        ),
        _StatCard(
          label: 'Belum Absen',
          value: widget.belumAbsen,
          color: const Color(0xFF718096),
          icon: Icons.hourglass_empty_rounded,
        ),
        _StatCard(
          label: 'Izin',
          value: widget.izin,
          color: AppPalette.info,
          icon: Icons.mail_outline_rounded,
        ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: primaryCards[0]),
            const SizedBox(width: 8),
            Expanded(child: primaryCards[1]),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: secondaryCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => SizedBox(
              width: 148,
              child: secondaryCards[index],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE8EDF3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 10,
                  fontWeight: AppFont.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 18,
            height: 1,
            fontWeight: AppFont.w900,
          ),
        ),
      ],
    ),
  );
}
