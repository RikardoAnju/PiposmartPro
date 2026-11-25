part of '../attendance_dashboard_screen.dart';

class _DashboardHeader extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onCalendarTap;

  const _DashboardHeader({
    required this.selectedMonth,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7043), Color(0xFFFFA447)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24FF7043),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -24,
          top: -38,
          child: CircleAvatar(radius: 60, backgroundColor: Color(0x18FFFFFF)),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'MONITORING LIVE',
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 9.5,
                            fontWeight: AppFont.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(selectedMonth),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: AppFont.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pantau kehadiran tim hari ini',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onCalendarTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x28FFFFFF)),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
