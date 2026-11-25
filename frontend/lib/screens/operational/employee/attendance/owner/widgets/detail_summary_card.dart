part of '../employee_attendance_detail_screen.dart';

class _DetailSummaryCard extends StatelessWidget {
  final int hadir;
  final int izin;
  final int alfa;
  final bool monthly;

  const _DetailSummaryCard({
    required this.hadir,
    required this.izin,
    required this.alfa,
    required this.monthly,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthly ? 'Kehadiran Bulan Ini' : 'Kehadiran Minggu Ini',
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 13,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _cell('Hadir', hadir, AppPalette.success),
            _divider(),
            _cell('Izin', izin, AppPalette.info),
            _divider(),
            _cell('Alfa', alfa, AppPalette.danger),
          ],
        ),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 32, color: const Color(0xFFEDEFF3));

  Widget _cell(String label, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: AppFont.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.muted,
            fontSize: 10,
            fontWeight: AppFont.w700,
          ),
        ),
      ],
    ),
  );
}
