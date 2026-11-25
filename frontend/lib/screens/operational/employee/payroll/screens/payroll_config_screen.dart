part of '../../payroll_screen.dart';

class PayrollConfigScreen extends StatefulWidget {
  const PayrollConfigScreen({super.key});

  @override
  State<PayrollConfigScreen> createState() => _PayrollConfigScreenState();
}

class _PayrollConfigScreenState extends State<PayrollConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return const PayrollConfigScreenList();
  }
}

class PayrollConfigScreenList extends StatefulWidget {
  const PayrollConfigScreenList({super.key});

  @override
  State<PayrollConfigScreenList> createState() =>
      _PayrollConfigScreenListState();
}

class _PayrollConfigScreenListState extends State<PayrollConfigScreenList>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PayrollProvider>().fetchAll();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<PayrollProvider>().fetchAll(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PayrollProvider>().fetchAll(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollProvider>();

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
          'Atur Gaji Karyawan',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text(
              'Lihat config gaji tiap pegawai di list, lalu buka detail untuk mengubahnya.',
              style: TextStyle(color: AppPalette.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            if (provider.pendingEmployees.isEmpty && provider.isLoading)
              const _PayrollConfigListSkeleton()
            else if (provider.pendingEmployees.isEmpty)
              const _EmptyConfigListState()
            else
              ...provider.pendingEmployees.map(
                (emp) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EmployeeConfigCard(
                    employee: emp,
                    onTap: () => _openDetail(context, provider, emp),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    PayrollProvider provider,
    Map<String, dynamic> employee,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayrollConfigDetailSheet(
        employee: employee,
        onEdit: () async {
          final cfg = provider.configForEmployee(employee['id']?.toString());
          final amountController = TextEditingController(
            text: PayrollProvider.formatConfigAmount(cfg),
          );
          final payDayController = TextEditingController(
            text: PayrollProvider.payDayFromConfig(cfg),
          );
          final payEveryDaysController = TextEditingController(
            text: PayrollProvider.payEveryDaysFromConfig(cfg),
          );
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => _ConfigEditorSheet(
              employee: employee,
              salaryType: PayrollProvider.salaryTypeFromConfig(cfg),
              scheduleType: PayrollProvider.scheduleTypeFromConfig(cfg),
              amountController: amountController,
              payDayController: payDayController,
              payEveryDaysController: payEveryDaysController,
              payDayName: PayrollProvider.payDayNameFromConfig(cfg),
              onChanged: (salaryType, scheduleType, payDayName) {},
            ),
          );
          if (context.mounted) {
            await provider.fetchAll();
          }
        },
      ),
    );
  }
}

class _EmployeeConfigCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onTap;

  const _EmployeeConfigCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = employee['nama']?.toString() ?? '-';
    final role = employee['role_nama']?.toString() ?? '-';
    final hasConfig =
        PayrollProvider.toNum(employee['amount']) > 0 ||
        employee['salary_type'] != null ||
        employee['salary_config'] != null;
    final amountText = hasConfig
        ? PayrollProvider.employeeAmountText(employee)
        : 'Gaji Belum Diatur';
    final actionText = hasConfig ? 'Lihat' : 'Atur Sekarang';
    final actionColor = hasConfig ? AppPalette.muted : AppPalette.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEFF3)),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 14,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11.5,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasConfig ? AppPalette.ink : AppPalette.muted,
                        fontSize: 12.5,
                        fontWeight: hasConfig ? AppFont.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 12,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: actionColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigEditorSheet extends StatefulWidget {
  final Map<String, dynamic> employee;
  final String salaryType;
  final String scheduleType;
  final TextEditingController amountController;
  final TextEditingController payDayController;
  final TextEditingController payEveryDaysController;
  final String payDayName;
  final void Function(String salaryType, String scheduleType, String payDayName)
  onChanged;

  const _ConfigEditorSheet({
    required this.employee,
    required this.salaryType,
    required this.scheduleType,
    required this.amountController,
    required this.payDayController,
    required this.payEveryDaysController,
    required this.payDayName,
    required this.onChanged,
  });

  @override
  State<_ConfigEditorSheet> createState() => _ConfigEditorSheetState();
}

class _ConfigEditorSheetState extends State<_ConfigEditorSheet> {
  late String _salaryType;
  late String _scheduleType;
  late String _payDayName;

  @override
  void initState() {
    super.initState();
    // Pertahankan tipe dan jadwal konfigurasi lama saat form dibuka kembali.
    _salaryType = widget.salaryType == 'Bulanan' || widget.salaryType == 'Mingguan'
        ? widget.salaryType
        : 'Harian';
    _scheduleType = widget.scheduleType;
    _payDayName = widget.payDayName;
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = widget.employee['nama']?.toString() ?? '-';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E7EE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pengaturan Gaji - $employeeName',
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 18,
                  fontWeight: AppFont.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Isi nominal dan jadwal pembayaran pegawai.',
                style: TextStyle(color: AppPalette.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Tipe Gaji'),
              const SizedBox(height: 8),
              Row(
                children: ['Bulanan', 'Mingguan', 'Harian'].map((type) {
                  final selected = _salaryType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _salaryType = type;
                          _scheduleType = type == 'Mingguan'
                              ? 'weekly_day'
                              : type == 'Harian'
                                  ? 'every_n_days'
                                  : 'fixed_date';
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selected ? AppPalette.primary : AppPalette.ink,
                          side: BorderSide(color: selected ? AppPalette.primary : const Color(0xFFE3E7EE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(type, maxLines: 1),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _FieldLabel(_salaryType == 'Bulanan'
                  ? 'Gaji per Bulan'
                  : _salaryType == 'Mingguan'
                      ? 'Upah per Minggu'
                      : 'Tarif Gaji per Hari'),
              const SizedBox(height: 8),
              TextField(
                controller: widget.amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Rp 0',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildScheduleFields(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'SIMPAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: AppFont.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTanggalGajian() async {
    final currentDay = (int.tryParse(widget.payDayController.text.trim()) ?? 25)
        .clamp(1, 31);
    final picked = await showDayOfMonthPicker(
      context: context,
      selectedDay: currentDay,
    );
    if (picked != null && mounted) {
      widget.payDayController.text = '$picked';
      setState(() {});
    }
  }

  Widget _buildScheduleFields() {
    if (_salaryType == 'Mingguan') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Hari Pembayaran'),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: DropdownButton<String>(
              value: _payDayName.isEmpty ? 'Senin' : _payDayName,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              menuWidth: 180,
              items: const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']
                  .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                  .toList(),
              onChanged: (value) => setState(() => _payDayName = value ?? 'Senin'),
            ),
          ),
        ],
      );
    }
    if (_salaryType == 'Harian') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Jadwal Pembayaran'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _scheduleChoice('Setiap Hari', 'daily'),
              _scheduleChoice('Setiap Beberapa Hari', 'every_n_days'),
            ],
          ),
          if (_scheduleType == 'every_n_days') ...[
            const SizedBox(height: 12),
            _FieldLabel('Bayar Setiap'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [3, 7, 14].map((days) => _scheduleChoice(
                '$days Hari Sekali', 'every_n_days', days: days,
              )).toList(),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Tanggal Pembayaran'),
        const SizedBox(height: 8),
        _DateSelectField(
          valueText: widget.payDayController.text.isEmpty
              ? 'Tanggal 25'
              : 'Tanggal ${widget.payDayController.text}',
          onTap: _pickTanggalGajian,
        ),
      ],
    );
  }

  Widget _scheduleChoice(String label, String schedule, {int? days}) {
    final selected = _scheduleType == schedule &&
        (schedule != 'every_n_days' ||
            (days == null && ![3, 7, 14].contains(int.tryParse(widget.payEveryDaysController.text))) ||
            days == int.tryParse(widget.payEveryDaysController.text));
    return OutlinedButton(
      onPressed: () => setState(() {
        _scheduleType = schedule;
        if (days != null) widget.payEveryDaysController.text = '$days';
      }),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppPalette.primary : AppPalette.ink,
        side: BorderSide(color: selected ? AppPalette.primary : const Color(0xFFE3E7EE)),
      ),
      child: Text(label),
    );
  }

  Future<void> _save() async {
    final provider = context.read<PayrollProvider>();
    final res = await provider.saveConfigInputs(
      pegawaiId: widget.employee['id']?.toString() ?? '',
      salaryType: _salaryType,
      amount: PayrollProvider.parseRupiah(widget.amountController.text),
      scheduleType: _scheduleType,
      payDay: int.tryParse(widget.payDayController.text) ?? 25,
      payEveryDays: int.tryParse(widget.payEveryDaysController.text) ?? 3,
      payDayName: _payDayName,
    );
    if (!mounted) return;

    final bool ok = res['success'] == true;
    CustomToast.show(
      context,
      message:
          res['message']?.toString() ?? (ok ? 'Tersimpan' : 'Gagal menyimpan'),
      isError: !ok,
    );
    // Tutup sheet HANYA bila berhasil, agar input tidak hilang saat gagal.
    if (ok) {
      Navigator.pop(context);
    }
  }

}

class _PayrollConfigDetailSheet extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;

  const _PayrollConfigDetailSheet({
    required this.employee,
    required this.onEdit,
  });

  @override
  State<_PayrollConfigDetailSheet> createState() =>
      _PayrollConfigDetailSheetState();
}

class _PayrollConfigDetailSheetState extends State<_PayrollConfigDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollProvider>();
    final config = provider.configForEmployee(
      widget.employee['id']?.toString(),
    );
    final name = widget.employee['nama']?.toString() ?? '-';
    final email = widget.employee['email']?.toString() ?? '-';
    final role = widget.employee['role_nama']?.toString() ?? '-';
    final salaryType = PayrollProvider.salaryTypeFromConfig(config);
    final scheduleText = PayrollProvider.scheduleText(config);
    final amount = PayrollProvider.formatConfigAmount(config);
    final hasConfig = config != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E7EE),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.person, color: AppPalette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppPalette.ink,
                          fontSize: 16,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppPalette.primary,
                          fontSize: 11.5,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasConfig)
                  const _TinyChip(
                    label: 'SUDAH DIATUR',
                    color: AppPalette.success,
                  )
                else
                  const _TinyChip(
                    label: 'BELUM DIATUR',
                    color: AppPalette.primary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: Column(
                children: [
                  _detailRow('Gaji Pokok', amount.isEmpty ? '-' : amount),
                  const SizedBox(height: 10),
                  _detailRow('Jenis Penggajian', salaryType),
                  const SizedBox(height: 10),
                  _detailRow('Jadwal Pembayaran', scheduleText),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'TUTUP',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onEdit();
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'EDIT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppPalette.muted, fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 12.5,
            fontWeight: AppFont.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyConfigListState extends StatelessWidget {
  const _EmptyConfigListState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppPalette.primaryPale,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppPalette.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Semua pegawai sudah diatur',
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 16,
              fontWeight: AppFont.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tidak ada pegawai yang perlu dikonfigurasi lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
