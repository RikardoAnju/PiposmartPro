part of '../attendance_holiday_screen.dart';

Widget _hero(int weeklyCount, int dateCount) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    gradient: const LinearGradient(colors: AppPalette.brandGradient),
    borderRadius: BorderRadius.circular(22),
    boxShadow: AppShadows.colored(AppPalette.primaryDeep),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Hari Libur Outlet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: AppFont.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Atur libur mingguan dan tanggal merah. Absen di hari libur otomatis '
        'tercatat sebagai lembur.',
        style: TextStyle(color: Color(0xFFFFE7DE), fontSize: 11, height: 1.4),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          _heroStat('$weeklyCount hari', 'Libur mingguan'),
          const SizedBox(width: 10),
          _heroStat('$dateCount tanggal', 'Libur khusus'),
        ],
      ),
    ],
  ),
);

Widget _heroStat(String value, String label) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFFFE7DE), fontSize: 9),
        ),
      ],
    ),
  ),
);

Widget _emptyDates() => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
  decoration: BoxDecoration(
    color: AppPalette.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE9EDF2)),
  ),
  child: const Column(
    children: [
      Icon(Icons.event_available_rounded, color: AppPalette.muted, size: 26),
      SizedBox(height: 8),
      Text(
        'Belum ada tanggal libur khusus',
        style: TextStyle(
          fontSize: 11,
          color: AppPalette.muted,
          fontWeight: AppFont.w700,
        ),
      ),
      SizedBox(height: 2),
      Text(
        'Ketuk "Tambah" untuk menambahkan',
        style: TextStyle(fontSize: 9, color: AppPalette.muted),
      ),
    ],
  ),
);

Widget _dateTile(
  Map<String, dynamic> h, {
  required bool busy,
  required VoidCallback onDelete,
}) {
  final parts = AttendanceProvider.holidayDateParts(h['date'].toString());
  final text = parts.text;
  final day = parts.day;
  final month = parts.month;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEDEFF3), width: 1.2),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppPalette.primarySoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.w800,
                  color: AppPalette.primaryDeep,
                  height: 1,
                ),
              ),
              Text(
                month,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: AppFont.w700,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h['label'].toString(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: AppFont.w800,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(fontSize: 10, color: AppPalette.muted),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppPalette.danger,
            size: 20,
          ),
          onPressed: busy ? null : onDelete,
        ),
      ],
    ),
  );
}
