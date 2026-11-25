import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_owner_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

part 'widgets/leave_request_card.dart';
part 'widgets/reject_reason_sheet.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadOwnerDashboard(
        context.read<PegawaiProvider>(),
      );
    });
  }

  Future<void> _decide(String id, String status, {String? reason}) async {
    setState(() => _busyId = id);
    final result = await context.read<AttendanceProvider>().setLeaveStatus(
      id,
      status,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _busyId = null);
    CustomToast.show(
      context,
      message: result['message']?.toString() ?? 'Berhasil',
      isError: result['success'] != true,
    );
  }

  Future<void> _approve(String id) => _decide(id, 'APPROVED');

  Future<void> _cancelApproval(String id) => _decide(id, 'PENDING');

  Future<void> _reject(String id) async {
    final reason = await showRejectReasonSheet(context);
    if (reason == null) return;
    await _decide(id, 'REJECTED', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final requests = attendance.leaveRequestsSorted;
    final names = attendance.employeeNames;

    return AppScaffold(
      backgroundColor: AppPalette.surface,
      appBar: const AttendanceAppBar(
        title: 'Pengajuan Izin',
        centerTitle: true,
      ),
      body: attendance.isLoadingConfig
          ? const LeaveApprovalShimmer()
          : requests.isEmpty
          ? const _EmptyLeaves()
          : SafeArea(
              top: false,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 24,
                ),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final req = requests[i];
                  final id = req['id'].toString();
                  return _LeaveRequestCard(
                    request: req,
                    employeeName:
                        names[req['employee_id']?.toString()] ?? 'Karyawan',
                    busy: _busyId == id,
                    onApprove: () => _approve(id),
                    onReject: () => _reject(id),
                    onCancelApproval: () => _cancelApproval(id),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyLeaves extends StatelessWidget {
  const _EmptyLeaves();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.mark_email_read_outlined,
            color: AppPalette.muted,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'Belum ada pengajuan izin',
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 12,
              fontWeight: AppFont.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
