part of '../attendance_dashboard_screen.dart';

class RosterTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const RosterTile({super.key, required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = row['status'] as String;
    final shiftName = (row['shift_name'] as String?) ?? '';
    final record = row['record'] as Map<String, dynamic>?;
    final hasTimes = record != null && record['check_in_at'] != null;
    final overtimeMinutes = (record?['overtime_minutes'] as num?)?.toInt() ?? 0;
    final hasOvertime = overtimeMinutes > 0 && record?['out_of_area'] != true;
    final overtime = row['overtime'] as Map<String, dynamic>? ?? const {};
    final hasPendingOvertime = overtime.isNotEmpty;
    final statusStyle = attendanceStatusStyle(status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EDF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EmployeeAvatar(
                    name: row['name'] as String,
                    color: statusStyle.fg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172B3A),
                            fontSize: 14,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        if (shiftName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.wb_sunny_outlined,
                                size: 13,
                                color: Color(0xFF718096),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  shiftName.toLowerCase().startsWith('shift ')
                                      ? shiftName
                                      : 'Shift $shiftName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF718096),
                                    fontSize: 10.5,
                                    fontWeight: AppFont.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceStatusBadge(status: status),
                ],
              ),
              if (hasTimes) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE8EDF3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeBox(
                          label: 'Masuk',
                          value: AttendanceProvider.formatAttendanceTime(
                            record['check_in_at'],
                          ),
                          color: AppPalette.success,
                        ),
                      ),
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: statusStyle.fg.withValues(alpha: .08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: statusStyle.fg,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: _TimeBox(
                          label: 'Pulang',
                          value: AttendanceProvider.formatAttendanceTime(
                            record['check_out_at'],
                          ),
                          color: AppPalette.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record['check_in_distance'] != null ||
                    record['check_out_distance'] != null) ...[
                  const SizedBox(height: 11),
                  _AttendanceDistanceInfo(record: record),
                ],
                if (hasOvertime) ...[
                  const SizedBox(height: 9),
                  _OvertimeInfo(minutes: overtimeMinutes),
                ],
                if (hasPendingOvertime) ...[
                  const SizedBox(height: 10),
                  _PendingOvertimeCard(request: overtime),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingOvertimeCard extends StatelessWidget {
  final Map<String, dynamic> request;
  const _PendingOvertimeCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final minutes = request['requested_minutes'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.more_time_rounded, color: Color(0xFFB66A00), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Pengajuan lembur $minutes menit', style: const TextStyle(color: Color(0xFFB66A00), fontSize: 12, fontWeight: AppFont.w700))),
        ]),
        if ((request['reason']?.toString() ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text('Alasan: ${request['reason']}', style: const TextStyle(color: Color(0xFF8A5A00), fontSize: 11, height: 1.3)),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () async {
          final result = await context.read<AttendanceProvider>().decideOvertime(id: request['id'].toString(), status: 'REJECTED');
          if (context.mounted) { CustomToast.show(context, message: result['message']?.toString() ?? 'Diproses', isError: result['success'] != true); }
          }, child: const Text('Tolak')),
          const SizedBox(width: 8),
          FilledButton(onPressed: () async {
          final result = await context.read<AttendanceProvider>().decideOvertime(id: request['id'].toString(), status: 'APPROVED');
          if (context.mounted) { CustomToast.show(context, message: result['message']?.toString() ?? 'Diproses', isError: result['success'] != true); }
          }, child: const Text('Setujui')),
        ]),
      ]),
    );
  }
}

class _OvertimeInfo extends StatelessWidget {
  const _OvertimeInfo({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final duration = hours > 0
        ? '$hours jam${rest > 0 ? ' $rest menit' : ''}'
        : '$rest menit';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(Icons.more_time_rounded, size: 17, color: Color(0xFFE58A00)),
          const SizedBox(width: 8),
          Text(
            'Lembur $duration',
            style: const TextStyle(
              color: Color(0xFFB66A00),
              fontSize: 11,
              fontWeight: AppFont.w800,
            ),
          ),
          const Spacer(),
          const Text(
            'Terdeteksi di outlet',
            style: TextStyle(color: Color(0xFFB66A00), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDistanceInfo extends StatelessWidget {
  final Map<String, dynamic> record;

  const _AttendanceDistanceInfo({required this.record});

  String _distance(dynamic raw) {
    final meters = (raw as num?)?.toDouble();
    if (meters == null) return '--';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: (outOfArea ? AppPalette.danger : AppPalette.info)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              outOfArea ? Icons.location_off_rounded : Icons.near_me_rounded,
              size: 15,
              color: outOfArea ? AppPalette.danger : AppPalette.info,
            ),
          ),
          const SizedBox(width: 9),
          if (checkIn != null)
            Expanded(
              child: _DistanceValue(
                label: 'Jarak masuk',
                value: _distance(checkIn),
              ),
            ),
          if (checkIn != null && checkOut != null)
            Container(
              width: 1,
              height: 25,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFFDDE4EB),
            ),
          if (checkOut != null)
            Expanded(
              child: _DistanceValue(
                label: outOfArea ? 'Pulang · luar area' : 'Jarak pulang',
                value: _distance(checkOut),
                color: outOfArea ? AppPalette.danger : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DistanceValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DistanceValue({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? const Color(0xFF718096),
          fontSize: 9,
          fontWeight: AppFont.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color ?? const Color(0xFF34495E),
          fontSize: 12,
          fontWeight: AppFont.w800,
        ),
      ),
    ],
  );
}

class _EmployeeAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _EmployeeAvatar({required this.name, required this.color});

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 46,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: .18),
                color.withValues(alpha: .07),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: .14)),
          ),
          child: Text(
            initials,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: AppFont.w900,
              letterSpacing: .3,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .22), blurRadius: 4),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TimeBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
              fontSize: 15,
              fontWeight: AppFont.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
