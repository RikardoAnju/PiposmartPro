part of '../../employee_attendance_screen.dart';

const _historyInk = Color(0xFF172B3A);
const _historyMuted = Color(0xFF718096);
const _historyBorder = Color(0xFFE8EDF3);

class _AttendanceHistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      boxShadow: overlapsContent
          ? const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ]
          : null,
    ),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.history_rounded,
            size: 18,
            color: AppPalette.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Riwayat Kehadiran',
          style: TextStyle(
            color: _historyInk,
            fontSize: 15,
            fontWeight: AppFont.w800,
          ),
        ),
      ],
    ),
  );

  @override
  bool shouldRebuild(covariant _AttendanceHistoryHeaderDelegate oldDelegate) =>
      false;
}

class _HistoryEntry {
  final Map<String, dynamic> data;
  final bool isLeave;
  const _HistoryEntry(this.data, {required this.isLeave});
  DateTime get date =>
      DateTime.tryParse(data['work_date']?.toString() ?? '') ?? DateTime(1970);
}

Widget _historySliver(
  List<Map<String, dynamic>> records,
  List<Map<String, dynamic>> leaveRequests,
  List<Map<String, dynamic>> overtimeRequests,
) {
  final now = DateTime.now();
  bool isCurrentMonth(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['work_date']?.toString() ?? '');
    return date != null && date.year == now.year && date.month == now.month;
  }

  final entries = <_HistoryEntry>[
    ...records
        .where(isCurrentMonth)
        .map((e) => _HistoryEntry(e, isLeave: false)),
    ...leaveRequests
        .where(isCurrentMonth)
        .map((e) => _HistoryEntry(e, isLeave: true)),
  ]..sort((a, b) => b.date.compareTo(a.date));
  if (entries.isEmpty) {
    return SliverToBoxAdapter(child: _emptyHistory());
  }
  return SliverList.builder(
    itemCount: entries.length,
    itemBuilder: (context, index) {
      final entry = entries[index];
      return RepaintBoundary(
        child: entry.isLeave
            ? _leaveCard(entry.data)
            : _historyCard(
                entry.data,
                overtimeRequests.where((o) =>
                    o['work_date']?.toString().startsWith(
                      entry.data['work_date']?.toString() ?? '',
                    ) ?? false,
                ).toList(),
              ),
      );
    },
  );
}

Widget _emptyHistory() => Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
  decoration: _historyCardDecoration(),
  child: const Column(
    children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: Color(0xFFFFF1EC),
        child: Icon(
          Icons.event_note_rounded,
          color: AppPalette.primary,
          size: 25,
        ),
      ),
      SizedBox(height: 14),
      Text(
        'Belum ada riwayat',
        style: TextStyle(
          color: _historyInk,
          fontSize: 15,
          fontWeight: AppFont.w800,
        ),
      ),
      SizedBox(height: 5),
      Text(
        'Aktivitas kehadiran Anda akan muncul di sini.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _historyMuted, fontSize: 12),
      ),
    ],
  ),
);

Widget _leaveCard(Map<String, dynamic> request) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(15),
  decoration: _historyCardDecoration(),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateTile(request['work_date']),
          const SizedBox(width: 12),
          Expanded(
            child: _historyHeading('Pengajuan izin', request['work_date']),
          ),
          _approvalPill(request['status']?.toString() ?? 'PENDING'),
        ],
      ),
      const SizedBox(height: 13),
      _historyMessage(
        Icons.notes_rounded,
        request['reason']?.toString() ?? 'Tidak ada keterangan',
        const Color(0xFF5D6B79),
      ),
    ],
  ),
);

Widget _historyCard(
  Map<String, dynamic> record,
  List<Map<String, dynamic>> overtimeRequests,
) {
  final status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
  final style = _historyStatusStyle(status);
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: _historyCardDecoration(),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _dateTile(record['work_date']),
            const SizedBox(width: 11),
            Expanded(child: _historyDateHeading(record['work_date'])),
            _modernStatusPill(style.$1, style.$2, style.$3),
          ],
        ),
        if (status != 'ALFA') ...[
          const SizedBox(height: 13),
          _attendanceTimeline(record),
          const SizedBox(height: 10),
          _attendanceMeta(record),
          if (record['check_in_distance'] != null ||
              record['check_out_distance'] != null) ...[
            const SizedBox(height: 11),
            _historyDistance(record),
          ],
        ],
        if ((record['holiday_label']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 11),
          _historyMessage(
            Icons.celebration_rounded,
            'Lembur hari libur: ${record['holiday_label']}',
            const Color(0xFF3978DD),
          ),
        ],
        if (record['auto_checkout'] == true) ...[
          const SizedBox(height: 11),
          _historyMessage(
            Icons.info_outline_rounded,
            'Jam pulang diisi otomatis karena lupa absen pulang.',
            const Color(0xFFC88716),
          ),
        ],
        ...overtimeRequests.where((o) {
          final status = o['status']?.toString().toUpperCase();
          return status == 'APPROVED' || status == 'PENDING';
        }).map((o) {
          final status = o['status']?.toString().toUpperCase();
          final minutes = status == 'APPROVED'
              ? o['approved_minutes'] ?? o['requested_minutes'] ?? 0
              : o['requested_minutes'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(top: 11),
            child: _historyMessage(
              Icons.more_time_rounded,
              status == 'APPROVED'
                  ? 'Lembur disetujui: $minutes menit.'
                  : 'Pengajuan lembur: $minutes menit (menunggu persetujuan).',
              const Color(0xFFB66A00),
            ),
          );
        }),
        if (record['out_of_area'] == true &&
            record['check_out_distance'] == null) ...[
          const SizedBox(height: 11),
          _historyMessage(
            Icons.location_off_rounded,
            'Absen pulang dilakukan di luar area outlet.',
            const Color(0xFFE04F5F),
          ),
        ],
      ],
    ),
  );
}

Widget _historyHeading(String title, dynamic date) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: const TextStyle(
        color: _historyInk,
        fontSize: 14,
        fontWeight: AppFont.w800,
      ),
    ),
    const SizedBox(height: 3),
    Text(
      AttendanceProvider.formatAttendanceDate(date),
      style: const TextStyle(
        color: _historyMuted,
        fontSize: 11,
        fontWeight: AppFont.w600,
      ),
    ),
  ],
);

Widget _historyDateHeading(dynamic date) => SizedBox(
  height: 44,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      AttendanceProvider.formatAttendanceDate(date),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _historyInk,
        fontSize: 13.5,
        fontWeight: AppFont.w800,
      ),
    ),
  ),
);

Widget _dateTile(dynamic rawDate) {
  final date = DateTime.tryParse(rawDate?.toString() ?? '');
  return Container(
    width: 44,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2ED),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Text(
          date == null ? '--' : DateFormat('dd').format(date),
          style: const TextStyle(
            color: AppPalette.primary,
            fontSize: 17,
            height: 1,
            fontWeight: AppFont.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date == null
              ? '---'
              : DateFormat('MMM', 'id_ID').format(date).toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFB65B3E),
            fontSize: 8,
            letterSpacing: .6,
            fontWeight: AppFont.w800,
          ),
        ),
      ],
    ),
  );
}

Widget _attendanceTimeline(Map<String, dynamic> record) => Container(
  padding: const EdgeInsets.all(2),
  decoration: BoxDecoration(
    color: const Color(0xFFF9FAFC),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: const Color(0xFFE8EDF3)),
  ),
  child: Row(
    children: [
      Expanded(
        child: _timePoint(
          'Masuk',
          AttendanceProvider.formatAttendanceTime(record['check_in_at']),
          const Color(0xFF0E9F6E),
        ),
      ),
      Container(width: 1, height: 35, color: const Color(0xFFE2E7ED)),
      Expanded(
        child: _timePoint(
          'Pulang',
          AttendanceProvider.formatAttendanceTime(record['check_out_at']),
          const Color(0xFFE04F5F),
        ),
      ),
    ],
  ),
);

Widget _timePoint(String label, String value, Color color) {
  final alignEnd = label == 'Pulang';
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    child: Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: AppFont.w900,
          ),
        ),
      ],
    ),
  );
}

Widget _attendanceMeta(Map<String, dynamic> record) {
  final shift = record['shift_name']?.toString() ?? '';
  if (shift.isEmpty) return const SizedBox.shrink();
  return Row(children: [
    const Icon(Icons.wb_sunny_outlined, size: 15, color: _historyMuted),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        shift.toLowerCase().startsWith('shift ') ? shift : 'Shift $shift',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF5D6B79),
          fontSize: 11,
          fontWeight: AppFont.w600,
        ),
      ),
    ),
  ]);
}

Widget _historyDistance(Map<String, dynamic> record) {
  String format(dynamic raw) {
    final meters = (raw as num?)?.toDouble();
    if (meters == null) return '--';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  final checkIn = record['check_in_distance'];
  final checkOut = record['check_out_distance'];
  final outOfArea = record['out_of_area'] == true;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: outOfArea ? const Color(0xFFFFF1F2) : const Color(0xFFF5F8FC),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        Icon(
          outOfArea ? Icons.location_off_rounded : Icons.near_me_rounded,
          size: 16,
          color: outOfArea ? const Color(0xFFE04F5F) : const Color(0xFF3978DD),
        ),
        const SizedBox(width: 8),
        if (checkIn != null)
          Expanded(
            child: Text(
              'Masuk ${format(checkIn)}',
              style: const TextStyle(
                color: Color(0xFF526273),
                fontSize: 10,
                fontWeight: AppFont.w700,
              ),
            ),
          ),
        if (checkOut != null)
          Text(
            outOfArea
                ? 'Pulang ${format(checkOut)} · luar area'
                : 'Pulang ${format(checkOut)}',
            style: TextStyle(
              color: outOfArea
                  ? const Color(0xFFE04F5F)
                  : const Color(0xFF526273),
              fontSize: 10,
              fontWeight: AppFont.w700,
            ),
          ),
      ],
    ),
  );
}

Widget _historyMessage(IconData icon, String text, Color color) => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(11),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: .20),
              color.withValues(alpha: .08),
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: .12)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            height: 1.3,
            color: color,
            fontSize: 10.5,
            fontWeight: AppFont.w600,
          ),
        ),
      ),
    ],
  ),
);

Widget _approvalPill(String status) {
  final value = status.toUpperCase();
  final approved = const ['APPROVED', 'DISETUJUI', 'APROVE'].contains(value);
  final rejected = const ['REJECTED', 'DITOLAK', 'TOLAK'].contains(value);
  return _modernStatusPill(
    approved
        ? 'Disetujui'
        : rejected
        ? 'Ditolak'
        : 'Menunggu',
    approved
        ? const Color(0xFF0E9F6E)
        : rejected
        ? const Color(0xFFE04F5F)
        : const Color(0xFFB7791F),
    approved
        ? Icons.check_circle_rounded
        : rejected
        ? Icons.cancel_rounded
        : Icons.schedule_rounded,
  );
}

Widget _modernStatusPill(String label, Color color, IconData icon) => Container(
  padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .10),
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
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 12, color: color),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: .15,
          fontWeight: AppFont.w800,
        ),
      ),
    ],
  ),
);

(String, Color, IconData) _historyStatusStyle(
  String status,
) => switch (status) {
  'TERLAMBAT' => (
    'Terlambat',
    const Color(0xFFE08A19),
    Icons.history_toggle_off_rounded,
  ),
  'ALFA' => ('Alfa', const Color(0xFFE04F5F), Icons.do_not_disturb_on_rounded),
  'LEMBUR' => ('Lembur', const Color(0xFF3978DD), Icons.bolt_rounded),
  'IZIN' => ('Izin', const Color(0xFF7B61C8), Icons.mark_email_read_rounded),
  _ => ('Hadir', const Color(0xFF0E9F6E), Icons.verified_rounded),
};

BoxDecoration _historyCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: _historyBorder),
  boxShadow: const [
    BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 4)),
  ],
);
