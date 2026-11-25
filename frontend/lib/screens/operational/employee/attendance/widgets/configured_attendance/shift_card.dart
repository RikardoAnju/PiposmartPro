part of '../configured_attendance_view.dart';

class _ShiftCard extends StatelessWidget {
  final GlobalKey? menuKey;
  final String shiftName;
  final String start;
  final String end;
  final bool autoApproveLeave;
  final int employeeCount;
  final List<String> employees;
  final VoidCallback onEdit;
  final VoidCallback onAssignEmployees;
  final VoidCallback onDelete;
  final void Function(bool value)? onToggleAutoApprove;

  const _ShiftCard({
    this.menuKey,
    required this.shiftName,
    required this.start,
    required this.end,
    required this.autoApproveLeave,
    required this.employeeCount,
    required this.employees,
    required this.onEdit,
    required this.onAssignEmployees,
    required this.onDelete,
    this.onToggleAutoApprove,
  });

  bool get _isNight => shiftName.toLowerCase().contains('malam');
  Color get _accent =>
      _isNight ? const Color(0xFF6C63D9) : const Color(0xFFF28C45);
  Color get _soft =>
      _isNight ? const Color(0xFFF1F0FF) : const Color(0xFFFFF2E9);

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, _soft.withValues(alpha: .48)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _accent.withValues(alpha: .13)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          top: -34,
          child: Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .045),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 16, 12, 15),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: .22),
                          blurRadius: 9,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isNight
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      shiftName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172B3A),
                        fontSize: 15,
                        fontWeight: AppFont.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                  ),
                  _ShiftMenu(
                    targetKey: menuKey,
                    onEdit: onEdit,
                    onAssignEmployees: onAssignEmployees,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _TimeRange(start: start, end: end, accent: _accent),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onAssignEmployees,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _EmployeeAvatars(
                          employees: employees,
                          accent: _accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _EmployeeCount(count: employeeCount, accent: _accent),
                ],
              ),
              const SizedBox(height: 13),
              Container(height: 1, color: _accent.withValues(alpha: .09)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: autoApproveLeave
                          ? const Color(0xFFE8F8F1)
                          : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      autoApproveLeave
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_outlined,
                      size: 15,
                      color: autoApproveLeave
                          ? AppPalette.success
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Persetujuan izin otomatis',
                      style: TextStyle(
                        color: Color(0xFF526273),
                        fontSize: 10.5,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  _StatusSwitch(
                    active: autoApproveLeave,
                    onChanged: onToggleAutoApprove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TimeRange extends StatelessWidget {
  final String start;
  final String end;
  final Color accent;

  const _TimeRange({
    required this.start,
    required this.end,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .78),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: accent.withValues(alpha: .10)),
    ),
    child: Row(
      children: [
        _TimePoint(label: 'Masuk', value: start, alignEnd: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: accent.withValues(alpha: .18),
                  ),
                ),
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: accent,
                    size: 14,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: accent.withValues(alpha: .18),
                  ),
                ),
              ],
            ),
          ),
        ),
        _TimePoint(label: 'Pulang', value: end, alignEnd: true),
      ],
    ),
  );
}

class _TimePoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _TimePoint({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF172B3A),
          fontSize: 15,
          fontWeight: AppFont.w900,
        ),
      ),
    ],
  );
}

class _EmployeeAvatars extends StatelessWidget {
  final List<String> employees;
  final Color accent;

  const _EmployeeAvatars({required this.employees, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(width: 7),
          Text(
            'Tambahkan karyawan',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
          ),
        ],
      );
    }
    final visible = employees.take(4).toList();
    return Row(
      children: [
        SizedBox(
          width: 28 + ((visible.length - 1) * 20),
          height: 30,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.lerp(Colors.white, accent, .10 + (i * .035)),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      visible[i].trim().isEmpty
                          ? '?'
                          : visible[i].trim()[0].toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            employees.length == 1
                ? employees.first
                : '${employees.first} dan tim',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF526273),
              fontSize: 10.5,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeCount extends StatelessWidget {
  final int count;
  final Color accent;
  const _EmployeeCount({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) => Text(
    '$count karyawan',
    style: TextStyle(color: accent, fontSize: 10, fontWeight: AppFont.w800),
  );
}

class _StatusSwitch extends StatelessWidget {
  final bool active;
  final void Function(bool value)? onChanged;
  const _StatusSwitch({required this.active, this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onChanged == null ? null : () => onChanged!(!active),
    child: Container(
      width: 38,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: active ? AppPalette.success : const Color(0xFFDDE3EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 3)],
          ),
        ),
      ),
    ),
  );
}

class _ShiftMenu extends StatelessWidget {
  final GlobalKey? targetKey;
  final VoidCallback onEdit;
  final VoidCallback onAssignEmployees;
  final VoidCallback onDelete;

  const _ShiftMenu({
    super.key,
    this.targetKey,
    required this.onEdit,
    required this.onAssignEmployees,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: targetKey,
    color: Colors.white,
    tooltip: 'Pilihan shift',
    padding: EdgeInsets.zero,
    onSelected: (value) {
      if (value == 'assign') onAssignEmployees();
      if (value == 'edit') onEdit();
      if (value == 'delete') onDelete();
    },
    icon: const Icon(
      Icons.more_horiz_rounded,
      color: Color(0xFF718096),
      size: 23,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'assign',
        child: _MenuRow(icon: Icons.group_add_outlined, text: 'Atur karyawan'),
      ),
      PopupMenuItem(
        value: 'edit',
        child: _MenuRow(icon: Icons.tune_rounded, text: 'Ubah shift'),
      ),
      PopupMenuItem(
        value: 'delete',
        child: _MenuRow(
          icon: Icons.delete_outline_rounded,
          text: 'Hapus',
          danger: true,
        ),
      ),
    ],
  );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool danger;
  const _MenuRow({required this.icon, required this.text, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.danger : const Color(0xFF526273);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
