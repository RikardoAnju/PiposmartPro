part of '../../payroll_screen.dart';

class _PayrollEntryEditorScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const _PayrollEntryEditorScreen({required this.item});

  @override
  State<_PayrollEntryEditorScreen> createState() =>
      _PayrollEntryEditorScreenState();
}

class _PayrollEntryEditorScreenState extends State<_PayrollEntryEditorScreen> {
  Map<String, dynamic> _detail = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detail = widget.item;
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<PayrollProvider>().fetchItemDetail(
      widget.item['id']?.toString() ?? '',
    );
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        _detail = Map<String, dynamic>.from(res['data'] as Map);
        // Keep a method selected on the previous detail screen when the
        // detail endpoint has not returned it yet.
        _detail['payment_method'] ??= widget.item['payment_method'];
        final salaryType = _detail['salary_type']?.toString().trim();
        if (salaryType == null || salaryType.isEmpty || salaryType == '-') {
          _detail['salary_type'] = widget.item['salary_type'];
        }
        _error = null;
      } else {
        _error = res['message']?.toString();
      }
      _loading = false;
    });
  }

  void _recalculateDraft() {
    final components =
        (_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final bonus = components
        .where((c) => c['type']?.toString().toLowerCase() == 'bonus')
        .fold<num>(0, (sum, c) => sum + PayrollProvider.toNum(c['amount']));
    final deduction = components
        .where((c) => c['type']?.toString().toLowerCase() == 'deduction')
        .fold<num>(0, (sum, c) => sum + PayrollProvider.toNum(c['amount']));
    final base = PayrollProvider.toNum(_detail['base_amount']);
    setState(() {
      _detail['bonus_amount'] = bonus;
      _detail['deduction_amount'] = deduction;
      _detail['net_amount'] = (base + bonus - deduction).clamp(
        0,
        double.infinity,
      );
    });
  }

  Future<void> _saveDraft() async {
    final provider = context.read<PayrollProvider>();
    final components =
        (_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final result = await provider.updateItemComponents(
      itemId: widget.item['id']?.toString() ?? '',
      payload: {
        'base_amount': PayrollProvider.toNum(_detail['base_amount']),
        'components': components,
        'notes': _detail['notes']?.toString() ?? '',
        'payment_method': _detail['payment_method'],
      },
    );
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, result['data']);
    } else {
      setState(() => _error = result['message']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _PayrollDetailSkeleton();
    }

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
    final components =
        (_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final bonusItems = components
        .where(
          (e) =>
              e['type']?.toString() != 'deduction' &&
              e['type']?.toString() != 'base',
        )
        .where((e) => PayrollProvider.toNum(e['amount']) > 0)
        .toList();
    final deductionItems = components
        .where((e) => e['type']?.toString() == 'deduction')
        .where((e) => PayrollProvider.toNum(e['amount']) > 0)
        .toList();
    final paymentMethod = PayrollProvider.paymentMethodLabel(
      _detail['payment_method']?.toString(),
    );
    final isPaid = PayrollProvider.isPaidPayrollStatus(
      PayrollProvider.payrollStatusText(_detail),
    );

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
          'Detail Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: SafeArea(
          top: false,
          child: !isPaid
              ? _DetailActionButton(
                  label: 'Simpan',
                  variant: _DetailActionVariant.primary,
                  onTap: _saveDraft,
                )
              : _DetailActionButton(
                  label: 'Kembali',
                  variant: _DetailActionVariant.secondary,
                  onTap: () => Navigator.pop(context),
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _PayrollDetailHeader(
            name: name,
            salaryType: salaryType,
            status: PayrollProvider.payrollStatusText(_detail),
          ),
          const SizedBox(height: 14),
          _PayrollDetailInfoCard(
            data: PayrollDetailViewData(
              salaryType: salaryType,
              period: PayrollProvider.formatPeriodLong(_detail),
              dueDate: PayrollProvider.formatDate(_detail['due_date']),
              paidAt: PayrollProvider.formatDateTime(_detail['paid_at']),
              paymentMethod: paymentMethod,
              net: net,
              base: base,
              bonus: bonus,
              deduction: deduction,
              baseNote: PayrollProvider.baseBreakdownText(_detail),
              componentDetails: components,
              workDays: PayrollProvider.toNum(_detail['work_days']),
              alfaDays: PayrollProvider.toNum(_detail['alfa_days']),
              overtimeMinutes: PayrollProvider.toNum(
                _detail['overtime_minutes'],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PayrollSectionCard(
            title: 'Bonus dan Insentif',
            child: Column(
              children: [
                if (bonusItems.isNotEmpty)
                  ...bonusItems.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ComponentRow(
                        name: c['name']?.toString() ?? 'Bonus',
                        amount: PayrollProvider.formatCurrency(
                          PayrollProvider.toNum(c['amount']),
                        ),
                        amountColor: AppPalette.success,
                        onDelete: () => _removeComponent(context, component: c),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openComponentEditor(context, 'bonus'),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppPalette.primary,
                      size: 18,
                    ),
                    label: const Text('Tambah Komponen'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.primary,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PayrollSectionCard(
            title: 'Potongan',
            child: Column(
              children: [
                if (deductionItems.isNotEmpty)
                  ...deductionItems.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ComponentRow(
                        name: PayrollProvider.displayComponentLabel(
                          c['name']?.toString(),
                          fallback: 'Potongan',
                        ),
                        amount:
                            '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(c['amount']))}',
                        amountColor: const Color(0xFFFF5A3C),
                        onDelete: () => _removeComponent(context, component: c),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openComponentEditor(context, 'deduction'),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppPalette.primary,
                      size: 18,
                    ),
                    label: const Text('Tambah Komponen'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.primary,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PayrollSectionCard(
            title: 'Ringkasan Perhitungan',
            child: Column(
              children: [
                if (base > 0) ...[
                  _SummaryRow(
                    label: 'Gaji Pokok',
                    value: PayrollProvider.formatCurrency(base),
                  ),
                  const SizedBox(height: 8),
                ],
                if (bonus > 0) ...[
                  _SummaryRow(
                    label: 'Bonus dan Insentif',
                    value: PayrollProvider.formatCurrency(bonus),
                  ),
                  const SizedBox(height: 8),
                ],
                if (deductionItems.isNotEmpty) ...[
                  ...deductionItems.map(
                    (component) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SummaryRow(
                        label: PayrollProvider.displayComponentLabel(
                          component['name']?.toString(),
                          fallback: 'Potongan',
                        ),
                        value:
                            '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(component['amount']))}',
                      ),
                    ),
                  ),
                ] else if (deduction > 0) ...[
                  _SummaryRow(
                    label: 'Potongan',
                    value: '-${PayrollProvider.formatCurrency(deduction)}',
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(height: 22),
                _SummaryRow(
                  label: 'Total Gaji Bersih',
                  value: net,
                  valueColor: AppPalette.success,
                  valueFontSize: 18,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openComponentEditor(BuildContext context, String type) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComponentEditorSheet(
        type: type,
        nameController: nameController,
        amountController: amountController,
        onSave: () {
          final amount = PayrollProvider.parseRupiah(amountController.text);
          if (amount <= 0) return;
          setState(() {
            final components =
                ((_detail['components'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                <Map<String, dynamic>>[]);
            components.add({
              'type': type,
              'name': nameController.text.trim().isEmpty
                  ? (type == 'deduction' ? 'Potongan' : 'Bonus')
                  : nameController.text.trim(),
              'amount': amount,
              'source': 'manual',
            });
            _detail['components'] = components;
          });
          _recalculateDraft();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _removeComponent(
    BuildContext context, {
    required Map<String, dynamic> component,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus komponen?'),
        content: Text(
          'Komponen "${component['name']?.toString() ?? 'ini'}" akan dihapus dari payroll.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      final components =
          ((_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[]);
      components.remove(component);
      _detail['components'] = components;
    });
    _recalculateDraft();
  }
}
