// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';

part 'employee_attendance/widgets/attendance_cards.dart';
part 'employee_attendance/widgets/attendance_history.dart';
part 'employee_attendance/widgets/leave_request_dialog.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final ScrollController _scrollController = ScrollController();
  Timer? _actionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_loadMoreHistoryNearBottom);
    _actionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AttendanceProvider>();
      provider.loadEmployeeAttendanceData();
      final pos = await provider.refreshLocation();
      if (pos != null && mounted) {
        final point = LatLng(pos.latitude, pos.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_loadMoreHistoryNearBottom)
      ..dispose();
    _actionTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadMoreHistoryNearBottom() {
    if (!_scrollController.hasClients || !mounted) return;
    final position = _scrollController.position;
    if (position.extentAfter < 500) {
      context.read<AttendanceProvider>().loadMoreEmployeeAttendanceHistory();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Pengguna mungkin baru saja mengaktifkan GPS/izin dari Settings.
      context.read<AttendanceProvider>().refreshLocation();
    }
  }

  Future<void> _refreshLocation() async {
    final pos = await context.read<AttendanceProvider>().refreshLocation();
    if (pos != null && mounted) {
      final point = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 16),
      );
    }
  }

  Future<void> _submit(bool checkOut) async {
    final provider = context.read<AttendanceProvider>();
    final result = await provider.submitAttendance(isCheckOut: checkOut);
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message']?.toString() ?? 'Absensi diproses',
      isError: result['success'] != true,
    );
  }

  Future<void> _confirmSubmit(bool checkOut) async {
    if (!checkOut) {
      await _submit(false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Absen Pulang'),
        content: const Text(
          'Apakah Anda yakin ingin melakukan absen pulang sekarang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('TIDAK'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('YA'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _submit(true);
  }

  @override
  Widget build(BuildContext context) {
    final outlet = context.watch<AppProvider>().outlet;
    final auth = context.watch<AuthProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final position = attendance.currentPosition;
    final actionLabel = attendance.actionLabel;
    final actionIcon = attendance.actionIcon;
    final isCheckOut = attendance.isCheckOutAction;
    final actionAvailable = attendance.isActionAvailable;
    final hadirCount = attendance.hadirCount;
    final izinCount = attendance.izinCount;
    final alfaCount = attendance.alfaCount;
    final hasCheckedIn = attendance.hasCheckedIn;
    final hasActiveLeave = attendance.hasActiveLeave;
    final hasPendingLeaveToday = attendance.hasPendingLeaveToday;
    final activeOvertime = attendance.overtimeRequests.where((item) {
      final status = item['status']?.toString().toUpperCase();
      return status == 'PENDING' || status == 'APPROVED';
    });

    final outletLatitude = outlet?.latitude;
    final outletLongitude = outlet?.longitude;
    final outletLocationConfigured = outletLatitude != null &&
        outletLongitude != null &&
        outletLatitude != 0 &&
        outletLongitude != 0;
    final outletPoint = outletLatitude != null && outletLongitude != null
        ? LatLng(outletLatitude, outletLongitude)
        : const LatLng(-0.9471, 100.4172);
    final employeePoint = position == null
        ? outletPoint
        : LatLng(position.latitude, position.longitude);
    final distance = attendance.calculateDistance(
      outletLatitude,
      outletLongitude,
    );
    // Samakan indikator FE dengan validasi backend: radius outlet mendapat
    // toleransi 10 meter untuk mengatasi noise GPS di area yang sama.
    final effectiveRadius = (outlet?.locationRadiusMeters ?? 5) + 10;
    final isInside = attendance.isWithinRadius(
      outletLatitude,
      outletLongitude,
      effectiveRadius.toDouble(),
    );
    final todayHoliday = attendance.holidayLabelFor(DateTime.now());
    final leaveSetupReady = attendance.configuration.isConfigured &&
        outletLatitude != null &&
        outletLongitude != null;

    return AppScaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Kehadiran Saya'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF34495E),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLocation,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(
                children: [
                  _header(auth.userName ?? 'Karyawan'),
                  const SizedBox(height: 14),
                  const _LiveClockCard(),
                  const SizedBox(height: 18),
                  _sectionTitle('Ringkasan Kehadiran'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _summary(
                        'HADIR',
                        hadirCount.toString(),
                        const Color(0xFF16B979),
                      ),
                      _summary(
                        'IZIN',
                        izinCount.toString(),
                        const Color(0xFF3978DD),
                      ),
                      _summary(
                        'ALFA',
                        alfaCount.toString(),
                        const Color(0xFFE45757),
                      ),
                    ],
                  ),
                  if (attendance.canRequestOvertime) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showOvertimeDialog(context),
                      icon: const Icon(Icons.more_time_rounded, size: 18),
                      label: const Text('Ajukan Lembur'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFFB56A00),
                        side: const BorderSide(color: Color(0xFFB56A00)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                  if (activeOvertime.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.more_time_rounded, color: Color(0xFFB66A00)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeOvertime.first['status']?.toString().toUpperCase() == 'APPROVED'
                                  ? 'Lembur disetujui: ${activeOvertime.first['approved_minutes'] ?? activeOvertime.first['requested_minutes'] ?? 0} menit.'
                                  : 'Lembur sedang berjalan • menunggu persetujuan owner.',
                              style: const TextStyle(color: Color(0xFFB66A00), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!hasCheckedIn &&
                      !hasActiveLeave &&
                      !hasPendingLeaveToday &&
                      todayHoliday == null &&
                      leaveSetupReady) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showLeaveDialog(context),
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text('Ajukan Izin ke Owner'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        foregroundColor: const Color(0xFF3978DD),
                        side: const BorderSide(color: Color(0xFF3978DD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  outletLocationConfigured
                      ? _locationCard(
                          outlet,
                          outletLocationConfigured,
                          outletPoint,
                          employeePoint,
                          distance,
                          isInside,
                          attendance.loadingLocation,
                          attendance.locationError,
                          (controller) => _mapController = controller,
                          () => _refreshLocation(),
                        )
                      : _outletLocationNotConfiguredCard(),
                  if (todayHoliday != null) ...[
                    const SizedBox(height: 12),
                    _noteChip(
                      'Hari ini libur ($todayHoliday). Jika tetap masuk, absen dihitung lembur.',
                      const Color(0xFF3978DD),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          outletLocationConfigured
                              ? actionLabel
                              : 'Menunggu lokasi outlet',
                          outletLocationConfigured
                              ? actionIcon
                              : Icons.location_off_outlined,
                          outletLocationConfigured &&
                              actionAvailable &&
                              !attendance.isSubmittingAttendance &&
                              (isCheckOut || isInside),
                          () => _confirmSubmit(isCheckOut),
                          outlined: isCheckOut,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _AttendanceHistoryHeaderDelegate(),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.viewPaddingOf(context).bottom + 28,
              ),
              sliver: _historySliver(
                attendance.records,
                attendance.leaveRequests,
                attendance.overtimeRequests,
              ),
            ),
            if (attendance.loadingMoreHistory)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOvertimeDialog(BuildContext context) async {
  final reason = TextEditingController();
  final startHour = TextEditingController();
  final startMinute = TextEditingController();
  final endHour = TextEditingController();
  final endMinute = TextEditingController();
  String? formError;
  final currentTime = TimeOfDay.now();
  startHour.text = currentTime.hour.toString().padLeft(2, '0');
  startMinute.text = currentTime.minute.toString().padLeft(2, '0');
  void disposeReasonAfterDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reason.dispose();
      startHour.dispose();
      startMinute.dispose();
      endHour.dispose();
      endMinute.dispose();
    });
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.more_time_rounded, color: Color(0xFFFF6B3D), size: 21),
            ),
            const SizedBox(width: 10),
            const Text('Ajukan Lembur', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tentukan satu rentang waktu lembur dan alasannya.', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
            const SizedBox(height: 18),
            const Text('WAKTU LEMBUR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF718096))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8EDF3))),
              child: Column(children: [
                _overtimeRangeRow(title: 'Dari jam', hourController: startHour, minuteController: startMinute, hourHint: '15', readOnly: true),
                const SizedBox(height: 14),
                _overtimeRangeRow(title: 'Sampai jam', hourController: endHour, minuteController: endMinute, hourHint: '18'),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan lembur',
                hintText: 'Contoh: menyelesaikan pesanan pelanggan',
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8EDF3))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B3D), width: 1.5)),
              ),
            ),
            if (formError != null) ...[
              const SizedBox(height: 8),
              Text(formError!, style: const TextStyle(color: Color(0xFFE45757), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            ]),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('BATAL')),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) {
                setState(() => formError = 'Alasan lembur wajib diisi.');
                return;
              }
              if (_parseInlineTime(endHour.text, endMinute.text) == null) {
                setState(() => formError = 'Jam selesai wajib diisi dengan benar.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('KIRIM'),
          ),
        ],
      ),
    ),
  );
  final start = _parseInlineTime(startHour.text, startMinute.text);
  final end = _parseInlineTime(endHour.text, endMinute.text);
  if (result != true || !context.mounted) { disposeReasonAfterDialog(); return; }
  if (reason.text.trim().isEmpty) {
    disposeReasonAfterDialog();
    CustomToast.show(context, message: 'Alasan lembur wajib diisi', isError: true);
    return;
  }
  if (start == null || end == null) {
    disposeReasonAfterDialog();
    CustomToast.show(context, message: 'Jam mulai dan selesai wajib diisi', isError: true);
    return;
  }
  if (start.hour * 60 + start.minute >= end.hour * 60 + end.minute) {
    disposeReasonAfterDialog();
    if (context.mounted) CustomToast.show(context, message: 'Jam selesai harus setelah jam mulai', isError: true);
    return;
  }
  final now = DateTime.now();
  DateTime at(TimeOfDay t) => DateTime(now.year, now.month, now.day, t.hour, t.minute);
  final response = await context.read<AttendanceProvider>().requestOvertime(workDate: now, startAt: at(start), endAt: at(end), reason: reason.text.trim());
  disposeReasonAfterDialog();
  if (context.mounted) CustomToast.show(context, message: response['message']?.toString() ?? 'Pengajuan diproses', isError: response['success'] != true);
}

Widget _overtimeNumberField(TextEditingController controller, String label, String hint, {bool readOnly = false}) {
  return TextField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    maxLength: 2,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    ),
  );
}

Widget _overtimeRangeRow({
  required String title,
  required TextEditingController hourController,
  required TextEditingController minuteController,
  required String hourHint,
  bool readOnly = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF536579))),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _overtimeNumberField(hourController, 'Jam', hourHint, readOnly: readOnly)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          Expanded(child: _overtimeNumberField(minuteController, 'Menit', '00', readOnly: readOnly)),
        ],
      ),
    ],
  );
}

TimeOfDay? _parseInlineTime(String hourText, String minuteText) {
  final hour = int.tryParse(hourText);
  final minute = int.tryParse(minuteText);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
