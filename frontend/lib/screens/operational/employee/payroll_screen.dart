import 'dart:async';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/payroll_provider.dart';
import 'package:ayocucinew/screens/operational/employee/employee_list_screen.dart';
import 'widgets/payroll_receipt_share.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'widgets/day_of_month_picker.dart';

part 'payroll/screens/payroll_config_screen.dart';
part 'payroll/screens/payroll_detail_screen.dart';
part 'payroll/screens/payroll_entry_editor_screen.dart';
part 'payroll/screens/payroll_success_screen.dart';
part 'payroll/screens/upcoming_payroll_detail_screen.dart';
part 'payroll/skeletons/payroll_skeletons.dart';
part 'payroll/widgets/common.dart';
part 'payroll/widgets/payroll_access.dart';
part 'payroll/widgets/payroll_components.dart';
part 'payroll/widgets/payroll_component_editor.dart';
part 'payroll/widgets/payroll_detail_controls.dart';
part 'payroll/widgets/payroll_detail_info_card.dart';
part 'payroll/widgets/payroll_section_card.dart';
part 'payroll/widgets/primary_component_card.dart';
part 'payroll/widgets/payroll_confirm_pay_sheet.dart';
part 'payroll/widgets/payroll_group_card.dart';
part 'payroll/widgets/upcoming_payroll_card.dart';
part 'payroll/widgets/payroll_hero.dart';

class SalarySettingsScreen extends StatefulWidget {
  const SalarySettingsScreen({super.key});

  @override
  State<SalarySettingsScreen> createState() => _SalarySettingsScreenState();
}

class _SalarySettingsScreenState extends State<SalarySettingsScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _isLoadingWelcomeState = true;
  bool _showWelcome = false;
  Timer? _refreshTimer;
  DateTime? _historyFrom;
  DateTime? _historyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWelcomeState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_showWelcome) {
      context.read<PayrollProvider>().fetchAll(silent: true);
    }
  }

  Future<void> _initWelcomeState() async {
    final seen = await context.read<PayrollProvider>().isWelcomeSeen();
    if (!mounted) return;
    setState(() {
      _showWelcome = !seen;
      _isLoadingWelcomeState = false;
    });
    if (!seen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PayrollProvider>().fetchAll();
    });
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_showWelcome) {
        context.read<PayrollProvider>().fetchAll(silent: true);
      }
    });
  }

  Future<void> _openConfigList() async {
    await context.read<PayrollProvider>().markWelcomeSeen();
    if (!mounted) return;
    setState(() => _showWelcome = false);
    await Navigator.push(
      context,
      // Pengaturan gaji sudah tersedia di tab kedua Edit Pegawai. Gunakan
      // satu sumber form agar perubahan tipe gaji tidak punya alur berbeda.
      MaterialPageRoute(
        builder: (_) => const EmployeeListScreen(openSalarySettings: true),
      ),
    );
    if (mounted) {
      context.read<PayrollProvider>().fetchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isOwnerOrAdmin) {
      return const _PayrollAccessDenied();
    }

    final hasAddon = context.watch<AddonProvider>().isFeatureActive('PAYROLL');
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );

    if (!canAccessAddonFeature) {
      return AppScaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppPalette.ink,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Penggajian',
            style: TextStyle(
              color: AppPalette.ink,
              fontWeight: AppFont.w800,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
        ),
        body: AddonLockedPlaceholder(
          title: 'Add-on Payroll Karyawan',
          message:
              'Aktifkan add-on Payroll Karyawan untuk mengelola komponen gaji, slip gaji, dan pembayaran payroll otomatis.',
          features: const [
            'Pengaturan gaji pokok, bonus & potongan',
            'Perhitungan payroll otomatis per periode',
            'Riwayat slip gaji dan konfirmasi pembayaran',
          ],
          onActionTap: () => Navigator.pushNamed(context, '/aktivasi-akun'),
        ),
      );
    }

    if (_isLoadingWelcomeState) {
      return const _PayrollPageSkeleton();
    }

    if (_showWelcome) {
      return _PayrollWelcomeScreen(
        onStart: _openConfigList,
        onBack: () => Navigator.pop(context),
      );
    }

    final payroll = context.watch<PayrollProvider>();
    final groupedItems = _tabIndex == 0
        ? payroll.groupedUnpaidPayrollItems
        : payroll.groupedPaidPayrollItems;
    final historyPeriods = payroll.periodGroupedPaidPayrollItemsBetween(
      _historyFrom,
      _historyTo,
    );
    final historyTotal = historyPeriods.fold<double>(
      0,
      (sum, period) => sum + (period['total'] as num).toDouble(),
    );
    final hasVisibleItems = _tabIndex == 1
        ? historyPeriods.isNotEmpty
        : groupedItems.isNotEmpty;
    final employeesNeedSetup = payroll.employeesWithoutSalaryConfig;

    return AppScaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _PayrollHero(
              periodLabel: PayrollProvider.indoPeriodLabel(payroll.periodLabel),
              totalAmount: _tabIndex == 1 ? historyTotal : payroll.totalAmount,
              title: _tabIndex == 1 ? 'Total Riwayat' : 'Payroll Aktif',
              amountLabel: _tabIndex == 1
                  ? 'Total pembayaran tersaring'
                  : 'Total yang harus dibayar',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SmallStat(
                    label: 'Belum Dibayar',
                    value: payroll.unpaidCount.toString(),
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallStat(
                    label: 'Sudah Dibayar',
                    value: payroll.paidCount.toString(),
                    color: AppPalette.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _TabBar(
              index: _tabIndex,
              onChanged: (v) => setState(() {
                _tabIndex = v;
                if (v == 0) {
                  _historyFrom = null;
                  _historyTo = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            if (_tabIndex == 1) ...[
              _HistoryDateFilter(
                from: _historyFrom,
                to: _historyTo,
                onTap: _pickHistoryDateRange,
                onClear: () => setState(() {
                  _historyFrom = null;
                  _historyTo = null;
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (_tabIndex == 0 && employeesNeedSetup.isNotEmpty) ...[
              _SalarySetupNotice(
                employees: employeesNeedSetup,
                onTap: _openConfigList,
              ),
              const SizedBox(height: 16),
            ],
            if (payroll.isLoading && groupedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _PayrollListSkeleton(),
              )
            else if (!hasVisibleItems &&
                !(_tabIndex == 0 && payroll.upcomingItems.isNotEmpty) &&
                !(_tabIndex == 0 && employeesNeedSetup.isNotEmpty))
              _EmptyState(
                title: _tabIndex == 0
                    ? 'Belum ada penggajian'
                    : 'Riwayat kosong',
                subtitle: _tabIndex == 0
                    ? 'Tambahkan pengaturan gaji karyawan terlebih dahulu agar penggajian dapat dibuat otomatis.'
                    : 'Belum ada pembayaran yang tercatat.',
                actionLabel: _tabIndex == 0 ? 'Atur Gaji Karyawan' : null,
                onAction: _tabIndex == 0 ? _openConfigList : null,
              )
            else if (_tabIndex == 1)
              // Riwayat: dikelompokkan PER PERIODE (bulan).
              ...historyPeriods.map(
                (period) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PayrollPeriodSection(
                    period: period,
                    onTapItem: (item) => _openDetail(context, item),
                  ),
                ),
              )
            else
              // Aktif: dikelompokkan per pegawai.
              ...groupedItems.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PayrollGroupCard(
                    group: group,
                    onTapItem: (item) => _openDetail(context, item),
                    compact: true,
                    showPeriod: true,
                  ),
                ),
              ),
            if (_tabIndex == 0 && payroll.upcomingItems.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppPalette.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gaji Mendatang',
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 14,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Jadwal pembayaran gaji berikutnya.',
                style: TextStyle(color: AppPalette.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...payroll.upcomingItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UpcomingPayrollCard(
                    item: item,
                    onTap: () => _openDetail(context, item, readOnly: true),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> item, {
    bool readOnly = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => readOnly
            ? _UpcomingPayrollDetailScreen(item: item)
            : _PayrollDetailScreen(item: item),
      ),
    );
    // Kartu list (Total Gaji Gabungan dkk) memakai snapshot lama yang
    // dimuat sebelum layar detail dibuka. Kalau di detail ada bonus/
    // potongan yang ditambah, kartu di list tidak ikut ter-update sampai
    // timer refresh 30 detik jalan. Refresh langsung begitu kembali agar
    // totalnya selalu sinkron dengan hasil edit terbaru.
    if (context.mounted) {
      context.read<PayrollProvider>().fetchAll(silent: true);
    }
  }

  Future<void> _pickHistoryDateRange() async {
    DateTime? start = _historyFrom;
    DateTime? end = _historyTo;
    final today = DateTime.now();
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: const SizedBox.shrink(),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  start == null
                      ? 'Pilih tanggal mulai'
                      : end == null
                      ? 'Pilih tanggal akhir'
                      : '${DateFormat('dd MMM yyyy').format(start!)} – ${DateFormat('dd MMM yyyy').format(end!)}',
                  style: const TextStyle(fontWeight: AppFont.w700),
                ),
                CalendarDatePicker(
                  initialDate: end ?? start ?? today,
                  firstDate: DateTime(2020),
                  lastDate: today.add(const Duration(days: 1)),
                  onDateChanged: (date) {
                    setDialogState(() {
                      if (start == null || end != null) {
                        start = date;
                        end = null;
                      } else {
                        end = date.isBefore(start!) ? start : date;
                        if (date.isBefore(start!)) start = date;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: start != null && end != null
                  ? () => Navigator.pop(
                      dialogContext,
                      DateTimeRange(start: start!, end: end!),
                    )
                  : null,
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _historyFrom = picked.start;
      _historyTo = picked.end;
    });
  }
}


class _HistoryDateFilter extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _HistoryDateFilter({
    required this.from,
    required this.to,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy', 'id_ID');
    final label = from == null || to == null
        ? 'Semua tanggal pembayaran'
        : '${formatter.format(from!)} – ${formatter.format(to!)}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Align(alignment: Alignment.centerLeft, child: Text(label)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.ink,
              side: const BorderSide(color: Color(0xFFDDE3EC)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (from != null || to != null)
          IconButton(
            tooltip: 'Hapus filter',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}

class _SalarySetupNotice extends StatelessWidget {
  final List<Map<String, dynamic>> employees;
  final VoidCallback onTap;

  const _SalarySetupNotice({required this.employees, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final names = employees
        .map((employee) => employee['nama']?.toString().trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    final namePreview = names.length > 3
        ? '${names.take(3).join(', ')} dan ${names.length - 3} lainnya'
        : names.join(', ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.primaryBorder),
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
                  Icons.person_add_alt_1_rounded,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${employees.length} karyawan belum diatur gajinya',
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      namePreview.isEmpty
                          ? 'Atur gaji agar masuk ke daftar payroll.'
                          : namePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppPalette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
