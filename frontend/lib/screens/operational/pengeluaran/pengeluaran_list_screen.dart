import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/pengeluaran_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../data/models/pengeluaran_model.dart';
import '../../../../shared/widgets/currency_formatter.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import 'pengeluaran_form_screen.dart';
import 'pengeluaran_detail_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PengeluaranListScreen extends StatefulWidget {
  const PengeluaranListScreen({super.key});

  @override
  State<PengeluaranListScreen> createState() => _PengeluaranListScreenState();
}

class _PengeluaranListScreenState extends State<PengeluaranListScreen> {
  static final DateFormat _groupDateFormat = DateFormat('dd MMMM yyyy', 'id');
  static final DateFormat _compactGroupDateFormat = DateFormat(
    'd MMM yyyy',
    'id',
  );

  String _selectedFilterLabel = "7 Hari Terakhir";
  DateTimeRange? _customFilterRange;

  @override
  void initState() {
    super.initState();
    // Inisialisasi data awal
    Future.microtask(() {
      if (!mounted) return;
      if (context.read<AuthProvider>().canAccess('pengeluaran', 'read')) {
        _applyFilter(_selectedFilterLabel);
      }
    });
  }

  Future<void> _applyFilter(String label, {DateTimeRange? customRange}) async {
    final provider = context.read<PengeluaranProvider>();
    if (provider.isLoading) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime startDate;
    DateTime endDate = today;

    if (label == "Custom" && customRange != null) {
      startDate = customRange.start;
      endDate = customRange.end;
      setState(() {
        _selectedFilterLabel = label;
        _customFilterRange = customRange;
      });
    } else {
      setState(() {
        _selectedFilterLabel = label;
        _customFilterRange = null;
      });
      switch (label) {
        case "Hari Ini":
          startDate = today;
          break;
        case "30 Hari Terakhir":
          startDate = today.subtract(const Duration(days: 29));
          break;
        case "7 Hari Terakhir":
        default:
          startDate = today.subtract(const Duration(days: 6));
          break;
      }
    }

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    await provider.fetchExpenses(start: startStr, end: endStr);
  }

  Future<void> _refreshSelectedRange() {
    return _applyFilter(_selectedFilterLabel, customRange: _customFilterRange);
  }

  void _showFilterSheet() async {
    final selection = await showModalBottomSheet<_ExpensePeriodSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => _ExpensePeriodFilterSheet(
        selectedMode: _selectedFilterLabel,
        customRange: _customFilterRange,
      ),
    );
    if (selection != null) {
      await _applyFilter(selection.mode, customRange: selection.range);
    }
  }

  // Penjelasan perbedaan jenis pengeluaran gaji, supaya user tidak bingung
  // antara badge "Payroll" (otomatis) dan kategori manual "Gaji Pegawai".
  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Jenis Pengeluaran Gaji',
              style: TextStyle(fontSize: 16, fontWeight: AppFont.w800),
            ),
            const SizedBox(height: 14),
            _infoRow(
              icon: Icons.payments_rounded,
              color: AppPalette.primary,
              title: 'Payroll (otomatis)',
              desc:
                  'Dibuat otomatis dari fitur Penggajian saat gaji pegawai dibayarkan. Tidak bisa diedit/hapus manual di sini.',
            ),
            const SizedBox(height: 12),
            _infoRow(
              icon: Icons.sell_rounded,
              color: const Color(0xFF546E7A),
              title: 'Gaji Pegawai (manual)',
              desc:
                  'Pengeluaran yang kamu catat sendiri lewat kategori "Gaji Pegawai". Bisa diedit/hapus seperti pengeluaran biasa.',
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: AppFont.w800,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF7A7A7A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎧 Watch agar UI rebuild saat list _expenses di Provider berubah (termasuk saat reset)
    final provider = context.watch<PengeluaranProvider>();
    final expenses = provider.expenses;
    final isLoading = provider.isLoading;

    final canRead = context.select<AuthProvider, bool>(
      (a) => a.canAccess('pengeluaran', 'read'),
    );

    if (!canRead) {
      return const _ExpenseAccessDenied();
    }

    final canCreate = context.select<AuthProvider, bool>(
      (a) => a.canAccess('pengeluaran', 'create'),
    );

    // 🚀 Logic grouping dibuat reactive terhadap variabel 'expenses' terbaru
    Map<String, List<Pengeluaran>> groupedExpenses = {};
    for (var item in expenses) {
      String dateKey = _groupDateFormat.format(item.tanggal);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(item);
    }

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pengeluaran",
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showInfoSheet,
            icon: const Icon(Icons.info_outline_rounded, color: Colors.black),
            tooltip: 'Jenis pengeluaran',
          ),
          IconButton(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.tune_rounded, color: Colors.black),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: canCreate ? _buildFab() : null,
      body: RefreshIndicator(
        onRefresh: _refreshSelectedRange,
        color: AppPalette.primary,
        child: isLoading && expenses.isEmpty
            ? const ManagementListSkeleton(
                showSearch: false,
                grouped: true,
                itemCount: 4,
              )
            : expenses.isEmpty
            ? Stack(
                children: [
                  const EmptyStateWidget.pengeluaran(
                    title: "Kosong",
                    message: "Belum ada catatan pengeluaran di outlet ini.",
                  ),

                  ListView(physics: const AlwaysScrollableScrollPhysics()),
                ],
              )
            : ListView(
                key: ValueKey('list_exp_${expenses.length}'),
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 120),
                children: [
                  for (final entry in groupedExpenses.entries) ...[
                    _buildDateGroupCard(entry.key, entry.value),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildFab() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.72,
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const PengeluaranFormScreen(),
                ),
              );
              if (changed == true && mounted) {
                await context.read<PengeluaranProvider>().refreshActiveRange(
                  silent: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 10,
              shadowColor: AppPalette.primary.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 20),
                SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "TAMBAH PENGELUARAN",
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateGroupCard(String date, List<Pengeluaran> items) {
    final compactDate = _compactDateLabel(date);
    final total = items.fold(0.0, (sum, item) => sum + item.total);
    final badgeChips = _buildBadgeChips(items);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PengeluaranDetailScreen(date: date),
            ),
          ),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE9ECEF)),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icons/pengeluaran/icon_list.webp',
                        width: 26,
                        height: 26,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.receipt_long,
                          color: Colors.blueGrey,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          compactDate,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: AppFont.w800,
                            fontSize: 16,
                            color: Color(0xFF495057),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          CurrencyFormatter.formatToRupiah(total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: AppFont.w900,
                            fontSize: 15,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFFB7BDC5),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F1F3)),
                if (badgeChips.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < badgeChips.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                badgeChips[i],
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items.length} transaksi',
                        style: const TextStyle(
                          color: Color(0xFF98A1AB),
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compactDateLabel(String date) {
    try {
      final parsed = _groupDateFormat.parse(date);
      return _compactGroupDateFormat.format(parsed);
    } catch (_) {
      return date;
    }
  }

  List<Widget> _buildBadgeChips(List<Pengeluaran> items) {
    final badges = <_ExpenseBadge>[];
    final seen = <String>{};

    for (final item in items) {
      final badge = _expenseBadgeFor(item);
      if (seen.add(badge.key)) {
        badges.add(badge);
      }
    }

    // Tampilkan maksimal 2 badge supaya baris tetap rapi.
    final visibleBadges = badges.take(2).toList();
    final overflowCount = badges.length - visibleBadges.length;

    final chips = visibleBadges
        .map(
          (badge) => _buildBadgeChip(
            label: badge.label,
            icon: badge.icon,
            foreground: badge.foreground,
            background: badge.background,
          ),
        )
        .toList();

    if (overflowCount > 0) {
      chips.add(
        _buildBadgeChip(
          label: '+$overflowCount',
          icon: Icons.more_horiz_rounded,
          foreground: const Color(0xFF6B7280),
          background: const Color(0xFFF3F4F6),
        ),
      );
    }

    return chips;
  }

  _ExpenseBadge _expenseBadgeFor(Pengeluaran item) {
    if (item.isPayrollSource) {
      return const _ExpenseBadge(
        key: 'payroll',
        label: 'Payroll',
        icon: Icons.payments_rounded,
        foreground: AppPalette.primary,
        background: AppPalette.primarySoft,
      );
    }

    final label = item.kategoriNama.trim().isEmpty
        ? 'Pengeluaran'
        : item.kategoriNama.trim();

    return _ExpenseBadge(
      key: label.toLowerCase(),
      label: label,
      icon: Icons.label_rounded,
      foreground: const Color(0xFF4B5563),
      background: const Color(0xFFF3F4F6),
    );
  }

  Widget _buildBadgeChip({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: AppFont.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseAccessDenied extends StatelessWidget {
  const _ExpenseAccessDenied();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Pengeluaran'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppPalette.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Akses pengeluaran tidak tersedia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 17,
                  fontWeight: AppFont.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Minta pemilik outlet memberikan izin Lihat pada modul Pengeluaran.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseBadge {
  final String key;
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _ExpenseBadge({
    required this.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });
}

class _ExpensePeriodSelection {
  final String mode;
  final DateTimeRange? range;

  const _ExpensePeriodSelection({required this.mode, this.range});
}

class _ExpensePeriodFilterSheet extends StatefulWidget {
  final String selectedMode;
  final DateTimeRange? customRange;

  const _ExpensePeriodFilterSheet({
    required this.selectedMode,
    required this.customRange,
  });

  @override
  State<_ExpensePeriodFilterSheet> createState() =>
      _ExpensePeriodFilterSheetState();
}

class _ExpensePeriodFilterSheetState extends State<_ExpensePeriodFilterSheet> {
  static const Color kPrimary = AppPalette.primary;
  final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

  late String _mode;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _mode = widget.selectedMode == 'Custom' ? 'Custom' : widget.selectedMode;
    _startDate = widget.customRange?.start;
    _endDate = widget.customRange?.end;
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_mode) {
      case 'Hari Ini':
        return DateTimeRange(start: today, end: today);
      case '30 Hari Terakhir':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case 'Custom':
        return DateTimeRange(
          start: _startDate ?? today.subtract(const Duration(days: 6)),
          end: _endDate ?? today,
        );
      case '7 Hari Terakhir':
      default:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
    }
  }

  void _reset() {
    setState(() {
      _mode = '7 Hari Terakhir';
      _startDate = null;
      _endDate = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _ExpensePeriodSelection(
        mode: _mode,
        range: _mode == 'Custom'
            ? DateTimeRange(start: _activeRange.start, end: _activeRange.end)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 20),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Periode',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: AppFont.w900,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Atur rentang waktu untuk daftar pengeluaran.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.w600,
                          color: Color(0xFF8D7F78),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: kPrimary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 13,
                      fontWeight: AppFont.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodToggle(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          label: 'Tanggal Mulai',
                          value: _activeRange.start,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          label: 'Tanggal Selesai',
                          value: _activeRange.end,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildApplyButton(),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    const modes = [
      ('Hari Ini', 'Hari Ini'),
      ('7 Hari', '7 Hari Terakhir'),
      ('30 Hari', '30 Hari Terakhir'),
      ('Custom', 'Custom'),
    ];
    final activeIndex = modes.indexWhere((item) => item.$2 == _mode);

    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / modes.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: (activeIndex < 0 ? 1 : activeIndex) * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: modes.map((item) {
                  final isActive = _mode == item.$2;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _mode = item.$2;
                          if (_mode == 'Custom') {
                            final range = _activeRange;
                            _startDate ??= range.start;
                            _endDate ??= range.end;
                          }
                        });
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isActive
                                ? kPrimary
                                : const Color(0xFF8E8581),
                            fontSize: 12,
                            fontWeight: AppFont.w900,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(item.$1, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: kPrimary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: AppFont.w800,
                      color: Color(0xFF9B8E88),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateFormat.format(value),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w900,
                        color: Colors.black87,
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

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 2, now.month, now.day);
    final range = _activeRange;
    final current = isStart ? range.start : range.end;

    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(current, firstDate, today),
      firstDate: firstDate,
      lastDate: today,
      locale: const Locale('id', 'ID'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: kPrimary),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      _mode = 'Custom';
      if (isStart) {
        _startDate = picked;
        if (_endDate == null || _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate == null || _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'TERAPKAN PERIODE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
