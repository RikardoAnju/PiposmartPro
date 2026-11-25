part of '../../payroll_screen.dart';

class _PayrollDetailInfoCard extends StatelessWidget {
  final PayrollDetailViewData data;
  final bool editable;
  final VoidCallback? onAddBonus;
  final VoidCallback? onAddDeduction;
  final String deductionActionLabel;
  final VoidCallback? onTapMethod;
  final ValueChanged<String?>? onPaymentMethodChanged;

  const _PayrollDetailInfoCard({
    required this.data,
    this.editable = false,
    this.onAddBonus,
    this.onAddDeduction,
    this.deductionActionLabel = 'Potong Gaji',
    this.onTapMethod,
    this.onPaymentMethodChanged,
  });

  String _componentLabel(Map<String, dynamic> component) {
    final name = component['name']?.toString().trim() ?? 'Komponen';
    final normalized = name.toLowerCase();
    if ((normalized == 'lembur' || normalized == 'bonus lembur') &&
        (overtimeMinutes ?? 0) > 0) {
      final detail = PayrollProvider.overtimeText({
        'overtime_minutes': overtimeMinutes,
      })?.replaceFirst(' lembur', '');
      if (detail != null && detail.isNotEmpty) {
        return 'Lembur $detail';
      }
    }
    return name;
  }

  String? _paymentMethodValue() {
    final value = paymentMethod.toLowerCase().trim();
    if (value == 'tunai') return 'cash';
    if (value == 'e-wallet') return 'ewallet';
    if (value == 'transfer') return null;
    if (value == 'bca' ||
        value == 'mandiri' ||
        value == 'bri' ||
        value == 'bni' ||
        value == 'bsi' ||
        value == 'cimb') {
      return 'transfer_${value}';
    }
    if (value.startsWith('transfer - ')) {
      return 'transfer_${value.substring('transfer - '.length).replaceAll(' ', '_')}';
    }
    if (value.startsWith('transfer_')) return value;
    return null;
  }

  String? _paymentCategoryValue() {
    final value = paymentMethod.toLowerCase().trim();
    if (value.isEmpty || value == 'belum dipilih') return null;
    if (value == 'tunai') return 'cash';
    if (value == 'e-wallet') return 'ewallet';
    return 'transfer';
  }

  String? get employeeName => data.employeeName;
  String? get salaryType => data.salaryType;
  String? get status => data.status;
  String get period => data.period;
  String get dueDate => data.dueDate;
  String get paidAt => data.paidAt;
  String get paymentMethod => data.paymentMethod;
  String get net => data.net;
  num get base => data.base;
  num get bonus => data.bonus;
  num get deduction => data.deduction;
  String? get baseNote => data.baseNote;
  String get baseLabel => data.baseLabel;
  num? get workDays => data.workDays;
  num? get alfaDays => data.alfaDays;
  num? get overtimeMinutes => data.overtimeMinutes;
  num? get pendingDeduction => data.pendingDeduction;
  List<Map<String, dynamic>>? get componentDetails => data.componentDetails;

  @override
  Widget build(BuildContext context) {
    final isPaid = status != null && PayrollProvider.isPaidPayrollStatus(status!);
    // Total potongan mencakup potongan manual dan potongan alfa pending.
    final totalDeduction = deduction + (pendingDeduction ?? 0);
    final bonusComponents =
        componentDetails
            ?.where((c) => c['type']?.toString().toLowerCase() == 'bonus')
            .toList() ??
        const <Map<String, dynamic>>[];
    final deductionComponents =
        componentDetails
            ?.where((c) => c['type']?.toString().toLowerCase() == 'deduction')
            .toList() ??
        const <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (employeeName != null) ...[
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName!,
                        style: const TextStyle(
                          color: AppPalette.ink,
                          fontSize: 15,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: PayrollProvider.isPaidPayrollStatus(status!)
                          ? const Color(0xFFEAF8F0)
                          : AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      status!,
                      style: TextStyle(
                        color: PayrollProvider.isPaidPayrollStatus(status!)
                            ? AppPalette.success
                            : AppPalette.primary,
                        fontSize: 10,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],
          _detailRow(
            'Tipe Gaji',
            PayrollProvider.salaryTypeLabel(salaryType),
          ),
          const SizedBox(height: 10),
          _detailRow('Periode', period),
          const SizedBox(height: 10),
          _detailRow('Jadwal Bayar', dueDate),
          if (paidAt.trim().isNotEmpty && paidAt.trim() != '-') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Dibayar Pada',
                  style: TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
                const Spacer(),
                SizedBox(
                  width: 140,
                  child: Text(
                    paidAt,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12.5,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (baseLabel.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EDF3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _breakdownRow(
                    baseLabel,
                    PayrollProvider.formatCurrency(base),
                    AppPalette.ink,
                  ),
                  if (baseNote != null && baseNote!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      baseNote!,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11.5,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bonus > 0 || bonusComponents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Bonus & Insentif',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12,
                      fontWeight: AppFont.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (bonusComponents.isEmpty)
                    _componentRow(
                      label: 'Bonus lembur',
                      amount: bonus,
                      prefix: '+',
                      color: AppPalette.success,
                      onAdd: editable ? onAddBonus : null,
                    ),
                  if (bonusComponents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...bonusComponents.map(
                      (component) => _breakdownRow(
                        _componentLabel(component),
                        '${component['type']?.toString().toLowerCase() == 'deduction' ? '-' : '+'}${PayrollProvider.formatCurrency(PayrollProvider.toNum(component['amount']))}',
                        component['type']?.toString().toLowerCase() ==
                                'deduction'
                            ? const Color(0xFFFF5A3C)
                            : AppPalette.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE9EDF3)),
                    const SizedBox(height: 8),
                    _breakdownRow(
                      'Total Bonus',
                      '+${PayrollProvider.formatCurrency(bonus)}',
                      AppPalette.success,
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                const Text(
                  'Potongan',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 12,
                    fontWeight: AppFont.w900,
                  ),
                ),
                if (editable && (pendingDeduction ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  _breakdownRow(
                    'Potongan alfa (belum diterapkan)',
                    '-${PayrollProvider.formatCurrency(pendingDeduction!)}',
                    const Color(0xFFFF5A3C),
                  ),
                  if ((workDays ?? 0) > 0 && (alfaDays ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 4),
                      child: Text(
                        'Potongan alfa = gaji pokok ÷ hari kerja × hari alfa',
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                if (deductionComponents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...deductionComponents.map(
                    (component) => _breakdownRow(
                      component['name']?.toString() ?? 'Potongan',
                      '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(component['amount']))}',
                      const Color(0xFFFF5A3C),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE9EDF3)),
                const SizedBox(height: 10),
                _breakdownRow(
                  'Total Potongan',
                  '- ${PayrollProvider.formatCurrency(totalDeduction)}',
                  const Color(0xFFFF5A3C),
                ),
                if (workDays != null) ...[
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFE9EDF3)),
                  const SizedBox(height: 10),
                  _breakdownRow(
                    'Jumlah hadir',
                    '${workDays!.toInt()} hari',
                    AppPalette.ink,
                  ),
                  _breakdownRow(
                    'Jumlah alfa',
                    '${alfaDays?.toInt() ?? 0} hari',
                    AppPalette.ink,
                  ),
                  if ((overtimeMinutes ?? 0) > 0)
                    _breakdownRow(
                      'Lembur',
                      PayrollProvider.overtimeText({
                            'overtime_minutes': overtimeMinutes,
                          })?.replaceFirst(' lembur', '') ??
                          '${overtimeMinutes!.toInt()} menit',
                      AppPalette.ink,
                    ),
                ],
                const SizedBox(height: 16),
                if ((pendingDeduction ?? 0) > 0 && onAddDeduction != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onAddDeduction,
                      icon: const Icon(Icons.remove_circle_outline, size: 15),
                      label: const Text('Potong Gaji'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A3C),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ),
                  ),
                if (onPaymentMethodChanged != null ||
                    (status != null &&
                        PayrollProvider.isPaidPayrollStatus(status!))) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEDEFF3)),
                    ),
                    child: Column(
                      children: [
                  if (isPaid)
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Metode Pembayaran',
                            style: TextStyle(color: AppPalette.muted, fontSize: 12),
                          ),
                        ),
                        Text(
                          paymentMethod,
                          style: const TextStyle(
                            color: AppPalette.ink,
                            fontSize: 13,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                      ],
                    )
                  else
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Metode Pembayaran',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppPalette.muted, fontSize: 12),
                        ),
                      ),
                      Container(
                        width: 145,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E7EE)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            borderRadius: BorderRadius.circular(14),
                            value: _paymentCategoryValue(),
                            hint: const Text(
                              'Pilih metode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                              DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                              DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                            ],
                            onChanged: onPaymentMethodChanged == null
                                ? null
                                : (value) {
                                    if (value != null) {
                                      onPaymentMethodChanged!(
                                        value,
                                      );
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isPaid && _paymentCategoryValue() == 'transfer') ...[
                    const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pilih Bank',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        width: 145,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E7EE)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: Colors.white,
                            elevation: 4,
                            value: _paymentMethodValue(),
                            hint: const Text(
                              'Pilih bank',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'transfer_bca',
                                child: Text('BCA', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'transfer_mandiri',
                                child: Text('Mandiri', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'transfer_bri',
                                child: Text('BRI', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'transfer_bni',
                                child: Text('BNI', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'transfer_bsi',
                                child: Text('BSI', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'transfer_cimb',
                                child: Text('CIMB', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('Tunai', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'ewallet',
                                child: Text('E-Wallet', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: onPaymentMethodChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE9EDF3)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Total Gaji',
                      style: TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      net,
                      style: const TextStyle(
                        color: AppPalette.success,
                        fontSize: 20,
                        height: 1.0,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 13,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 124,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 13.5,
                fontWeight: AppFont.w800,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  // Baris komponen (Bonus/Potongan). Bila nilainya 0 dan bisa diedit, tampilkan
  // chip "+ Tambah" di kanan supaya fiturnya terlihat tanpa masuk Ubah Rincian.
  Widget _componentRow({
    required String label,
    required num amount,
    required String prefix,
    required Color color,
    VoidCallback? onAdd,
  }) {
    final bool hasValue = amount > 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 13,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
        if (!hasValue && onAdd != null)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'Tambah',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SizedBox(
            width: 116,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$prefix ${PayrollProvider.formatCurrency(amount)}',
                textAlign: TextAlign.end,
                maxLines: 1,
                style: TextStyle(
                  color: hasValue ? color : AppPalette.muted,
                  fontSize: 13.5,
                  fontWeight: AppFont.w800,
                ),
              ),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deductionActionLabel == 'Tambah Potongan'
                          ? 'Tambah'
                          : deductionActionLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppPalette.muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 12.5,
              fontWeight: AppFont.w800,
            ),
          ),
        ),
      ],
    );
  }
}
