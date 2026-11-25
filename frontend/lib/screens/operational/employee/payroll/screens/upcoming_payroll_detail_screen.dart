part of '../../payroll_screen.dart';

class _UpcomingPayrollDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const _UpcomingPayrollDetailScreen({required this.item});

  @override
  State<_UpcomingPayrollDetailScreen> createState() =>
      _UpcomingPayrollDetailScreenState();
}

class _UpcomingPayrollDetailScreenState
    extends State<_UpcomingPayrollDetailScreen> {
  Map<String, dynamic> _detail = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detail = widget.item;
    _load();
  }

  Future<void> _load() async {
    final itemId = widget.item['id']?.toString() ?? '';
    if (itemId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final res = await context.read<PayrollProvider>().fetchItemDetail(
      itemId,
    );
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        _detail = Map<String, dynamic>.from(res['data'] as Map);
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _PayrollDetailSkeleton();
    }

    final status = PayrollProvider.payrollStatusText(_detail);
    final name = _detail['pegawai_nama']?.toString() ?? '-';
    final salaryType = PayrollProvider.salaryTypeLabel(
      _detail['salary_type']?.toString(),
    );
    final base = PayrollProvider.toNum(_detail['base_amount']);
    final bonus = PayrollProvider.toNum(_detail['bonus_amount']);
    final deduction = PayrollProvider.toNum(_detail['deduction_amount']);
    final net = PayrollProvider.formatCurrency(
      PayrollProvider.toNum(_detail['net_amount']),
    );
    final paymentMethod = PayrollProvider.paymentMethodLabel(
      _detail['payment_method']?.toString(),
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom + 56;

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
        actions: const [],
        title: const Text(
          'Detail Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
        children: [
          _PayrollDetailInfoCard(
            data: PayrollDetailViewData(
              employeeName: name,
              salaryType: salaryType,
              status: status,
              period: PayrollProvider.formatPeriodLong(_detail),
              dueDate: PayrollProvider.formatDate(_detail['due_date']),
              paidAt: PayrollProvider.formatDateTime(_detail['paid_at']),
              paymentMethod: paymentMethod,
              net: net,
              base: base,
              bonus: bonus,
              deduction: deduction,
              baseLabel: '',
              workDays: PayrollProvider.toNum(_detail['work_days']),
              alfaDays: PayrollProvider.toNum(_detail['alfa_days']),
              overtimeMinutes: PayrollProvider.toNum(_detail['overtime_minutes']),
            ),
            editable: false,
            onAddBonus: null,
            onAddDeduction: null,
            onTapMethod: null,
          ),
        ],
      ),
    );
  }
}
