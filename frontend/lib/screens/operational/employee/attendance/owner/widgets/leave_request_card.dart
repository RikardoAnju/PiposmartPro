part of '../leave_approval_screen.dart';

class _LeaveRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String employeeName;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancelApproval;

  const _LeaveRequestCard({
    required this.request,
    required this.employeeName,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancelApproval,
  });

  String get _statusCode {
    final value = (request['status']?.toString() ?? 'PENDING').toUpperCase();
    if (const ['APPROVED', 'DISETUJUI', 'APROVE'].contains(value)) {
      return 'APPROVED';
    }
    if (const ['REJECTED', 'DITOLAK', 'TOLAK'].contains(value)) {
      return 'REJECTED';
    }
    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusCode;
    final workDate = DateTime.tryParse(request['work_date']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date Tile
              _DateTile(date: workDate),
              const SizedBox(width: 11),
              // Employee Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengajuan izin',
                      style: const TextStyle(
                        color: Color(0xFF172B3A),
                        fontSize: 14,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ModernStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 13),
          _ReasonMessage(
            icon: Icons.notes_rounded,
            text: request['reason']?.toString() ?? 'Tidak ada keterangan',
          ),
          if (status == 'REJECTED' &&
              (request['reject_reason']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 11),
            _DecisionNote(
              text: request['reject_reason'].toString(),
              color: AppPalette.danger,
            ),
          ],
          if (status == 'PENDING' || status == 'APPROVED' || busy) ...[
            const SizedBox(height: 12),
            _actions(status),
          ],
        ],
      ),
    );
  }

  Widget _actions(String status) {
    if (busy) {
      return const SizedBox(
        height: 42,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.danger,
                minimumSize: const Size.fromHeight(42),
                side: const BorderSide(color: Color(0xFFF2B8BE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Setujui'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.success,
                minimumSize: const Size.fromHeight(42),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (status == 'APPROVED') {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onCancelApproval,
          icon: const Icon(Icons.undo_rounded, size: 15),
          label: const Text('Batalkan persetujuan'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF718096),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            textStyle: const TextStyle(
              fontSize: 10.5,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _DateTile extends StatelessWidget {
  final DateTime? date;

  const _DateTile({required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted = date == null
        ? DateTime.now()
        : date!;

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
            DateFormat('dd').format(formatted),
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 17,
              height: 1,
              fontWeight: AppFont.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM', 'id_ID').format(formatted).toUpperCase(),
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
}

class _ReasonMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReasonMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFC),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFE8EDF3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0F5FF),
                Color(0xFFF9FAFC),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE8EDF3)),
          ),
          child: Icon(
            icon,
            size: 15,
            color: const Color(0xFF718096),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              height: 1.3,
              color: Color(0xFF5D6B79),
              fontSize: 10.5,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DecisionNote extends StatelessWidget {
  final String text;
  final Color color;

  const _DecisionNote({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 10.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _ModernStatusPill extends StatelessWidget {
  final String status;

  const _ModernStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'APPROVED' => ('Disetujui', const Color(0xFF0E9F6E), Icons.check_circle_rounded),
      'REJECTED' => ('Ditolak', const Color(0xFFE04F5F), Icons.cancel_rounded),
      _ => ('Menunggu', const Color(0xFFB7791F), Icons.schedule_rounded),
    };
    return Container(
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
  }
}
