import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/attendance_app_bar.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/section_title.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/settings_section.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

part 'holiday/holiday_cards.dart';
part 'holiday/holiday_chips.dart';

class AttendanceHolidayScreen extends StatefulWidget {
  const AttendanceHolidayScreen({super.key});

  @override
  State<AttendanceHolidayScreen> createState() =>
      _AttendanceHolidayScreenState();
}

class _AttendanceHolidayScreenState extends State<AttendanceHolidayScreen> {
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AttendanceProvider>().loadHolidays();
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _toggleWeekly(
    int weekday,
    Map<String, dynamic>? existing,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final provider = context.read<AttendanceProvider>();
    final result = existing != null
        ? await provider.deleteHoliday(existing['id'].toString())
        : await provider.addHoliday(weekday: weekday);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] != true) {
      CustomToast.show(
        context,
        message: result['message'].toString(),
        isError: true,
      );
    }
  }

  Future<void> _addDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Pilih tanggal libur',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: Colors.white,
            headerForegroundColor: AppPalette.ink,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: Colors.white,
            surfaceTint: Colors.transparent,
            primary: AppPalette.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final label = await _askLabel();
    if (label == null || label.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    final result = await context.read<AttendanceProvider>().addHoliday(
      date: AttendanceProvider.isoDate(picked),
      label: label.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] != true) {
      CustomToast.show(
        context,
        message: result['message'].toString(),
        isError: true,
      );
    }
  }

  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Nama Hari Libur',
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppFont.w800,
            color: AppPalette.ink,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'mis. HUT RI, Idul Fitri, Cuti Bersama',
            hintStyle: const TextStyle(fontSize: 12, color: AppPalette.muted),
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppPalette.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppPalette.muted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDate(Map<String, dynamic> holiday) async {
    setState(() => _busy = true);
    final result = await context.read<AttendanceProvider>().deleteHoliday(
      holiday['id'].toString(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] != true) {
      CustomToast.show(
        context,
        message: result['message'].toString(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidays = context.watch<AttendanceProvider>().holidays;
    final weeklyByDay = <int, Map<String, dynamic>>{};
    final dates = <Map<String, dynamic>>[];
    for (final h in holidays) {
      if (h['date'] == null && h['weekday'] is int) {
        weeklyByDay[h['weekday'] as int] = h;
      } else if (h['date'] != null) {
        dates.add(h);
      }
    }
    final weeklyCount = weeklyByDay.length;

    return AppScaffold(
      backgroundColor: AppPalette.surface,
      appBar: const AttendanceAppBar(title: 'Hari Libur Outlet'),
      body: _loading
          ? const _HolidayScreenSkeleton()
          : SafeArea(
              top: false,
              bottom: true,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                _hero(weeklyCount, dates.length),
                const SizedBox(height: 14),
                SettingsSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        icon: Icons.calendar_view_week_rounded,
                        title: 'Libur Mingguan',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pilih hari yang rutin libur setiap minggu. Karyawan tetap boleh '
                        'absen di hari libur dan dihitung sebagai lembur.',
                        style: TextStyle(
                          color: AppPalette.muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (i) {
                          final active = weeklyByDay.containsKey(i);
                          return _DayChip(
                            label: AttendanceProvider.weekdayShort[i],
                            active: active,
                            onTap: _busy
                                ? null
                                : () => _toggleWeekly(i, weeklyByDay[i]),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SettingsSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: SectionTitle(
                              icon: Icons.event_rounded,
                              title: 'Tanggal Merah / Libur Khusus',
                            ),
                          ),
                          _AddButton(onTap: _busy ? null : _addDate),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tambahkan tanggal libur nasional atau cuti bersama sesuai kalender.',
                        style: TextStyle(
                          color: AppPalette.muted,
                        fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (dates.isEmpty)
                        _emptyDates()
                      else
                        ...dates.map(
                          (h) => _dateTile(
                            h,
                            busy: _busy,
                            onDelete: () => _deleteDate(h),
                          ),
                        ),
                    ],
                  ),
                ),
                ],
              ),
            ),
    );
  }
}

class _HolidayScreenSkeleton extends StatelessWidget {
  const _HolidayScreenSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoader(
    isLoading: true,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Row(
              children: [
                SkeletonBox(width: 60, height: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 100, height: 18),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 150, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Weekly holidays section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 16),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    7,
                    (i) => SkeletonBox(width: 45, height: 36),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Date holidays section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 16),
                const SizedBox(height: 12),
                ...List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SkeletonBox(width: 150, height: 14),
                        const Spacer(),
                        SkeletonBox(width: 40, height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
