import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/work_log_provider.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_employee_card.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_info_state.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_shimmer.dart';
import 'package:flutter/material.dart';

class WorkLogEmployeePicker extends StatelessWidget {
  const WorkLogEmployeePicker({super.key, required this.workLog});

  final WorkLogProvider workLog;

  @override
  Widget build(BuildContext context) {
    if (workLog.isLoading && workLog.employees.isEmpty) {
      return const WorkLogEmployeePickerShimmer();
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: workLog.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppPalette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.colored(AppPalette.primaryDeep),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktivitas Tim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Pilih karyawan untuk melihat kontribusi kerjanya.',
                        style: TextStyle(
                          color: Color(0xFFFFE7DE),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'DAFTAR PEGAWAI',
            style: TextStyle(
              color: AppPalette.muted,
              fontWeight: AppFont.w800,
              fontSize: 11,
              letterSpacing: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          if (workLog.errorMessage != null && workLog.employees.isEmpty)
            WorkLogInfoState(
              icon: Icons.cloud_off_rounded,
              title: 'Data pegawai tidak dapat dimuat',
              message: workLog.errorMessage!,
            )
          else if (workLog.employees.isEmpty)
            const WorkLogInfoState(
              icon: Icons.groups_outlined,
              title: 'Belum ada karyawan',
              message:
                  'Tambahkan karyawan terlebih dahulu dari menu Data Karyawan.',
            )
          else
            ...workLog.employees.map(
              (employee) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WorkLogEmployeeCard(
                  employee: employee,
                  onTap: () => workLog.selectEmployee(employee),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
