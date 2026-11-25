import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_badge.dart';
import 'package:flutter/material.dart';

class WorkLogEmployeeCard extends StatelessWidget {
  const WorkLogEmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
  });

  final Pegawai employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = (employee.role?.nama.isNotEmpty ?? false)
        ? employee.role!.nama.toUpperCase()
        : 'KARYAWAN';
    final type = employee.type == 'base' ? 'PEGAWAI DASAR' : 'PEGAWAI ADD-ON';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: AppBorders.card,
            boxShadow: AppShadows.cardSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppPalette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppPalette.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.nama.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        WorkLogBadge(label: role),
                        WorkLogBadge(label: type),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
