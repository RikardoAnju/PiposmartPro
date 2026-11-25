part of '../../payroll_screen.dart';

class _PayrollConfirmPaySheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String paymentMethod;

  const _PayrollConfirmPaySheet({
    required this.item,
    required this.paymentMethod,
  });

  @override
  State<_PayrollConfirmPaySheet> createState() => _PayrollConfirmPaySheetState();
}

class _PayrollConfirmPaySheetState extends State<_PayrollConfirmPaySheet> {
  late String _selectedMethod;
  String _selectedCategory = '';
  String _selectedBank = '';

  @override
  void initState() {
    super.initState();
    _selectedMethod = PayrollProvider.normalizePaymentMethod(widget.paymentMethod);
    if (_selectedMethod.startsWith('transfer_')) {
      _selectedCategory = 'transfer';
      _selectedBank = _selectedMethod;
    } else if (_selectedMethod == 'cash' || _selectedMethod == 'ewallet') {
      _selectedCategory = _selectedMethod;
    } else {
      _selectedMethod = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item['pegawai_nama']?.toString() ?? '-';
    final period = PayrollProvider.formatPeriodLong(item);
    final isDaily = item['salary_type']?.toString().toLowerCase() == 'daily';
    final cycleLabel = PayrollProvider.payrollDueLabel(item);
    final methodLabel = _selectedMethod.isEmpty
        ? 'Pilih metode'
        : PayrollProvider.paymentMethodLabel(_selectedMethod);
    final components =
        (item['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final base = PayrollProvider.toNum(item['base_amount']);
    final bonusItems = components.where((c) {
      final type = c['type']?.toString().toLowerCase().trim();
      return type != 'base' &&
          type != 'deduction' &&
          PayrollProvider.toNum(c['amount']) > 0;
    }).toList();
    final deductionItems = components
        .where((c) => c['type']?.toString().toLowerCase().trim() == 'deduction')
        .where((c) => PayrollProvider.toNum(c['amount']) > 0)
        .toList();
    final net = PayrollProvider.formatCurrency(
      (base +
              bonusItems.fold<num>(
                0,
                (sum, c) => sum + PayrollProvider.toNum(c['amount']),
              ) -
              deductionItems.fold<num>(
                0,
                (sum, c) => sum + PayrollProvider.toNum(c['amount']),
              ))
          .clamp(0, double.infinity),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .9,
      ),
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          const Text(
            'Konfirmasi Penggajian',
            style: TextStyle(
              color: AppPalette.ink,
              fontWeight: AppFont.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Periksa rincian sebelum memproses pembayaran.',
            style: TextStyle(color: AppPalette.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          _confirmDetailRow('Nama Pegawai', name),
          _confirmDetailRow('Periode', period),
          _confirmDetailRow('Jadwal Bayar', cycleLabel),
          _confirmDetailRow('Metode Penggajian', methodLabel),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Metode pembayaran',
              hintText: 'Pilih metode',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Color(0xFFE3E7EE)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            menuMaxHeight: 220,
            items: const [
              DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
              DropdownMenuItem(value: 'cash', child: Text('Tunai')),
              DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
            ],
            onChanged: (value) => setState(() {
              _selectedCategory = value ?? '';
              _selectedBank = '';
              _selectedMethod = value == 'cash' || value == 'ewallet' ? value! : '';
            }),
          ),
          if (_selectedCategory == 'transfer') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedBank.isEmpty ? null : _selectedBank,
            decoration: const InputDecoration(
              labelText: 'Bank',
              hintText: 'Pilih bank',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFFE3E7EE)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 280,
              items: const [
                DropdownMenuItem(value: 'transfer_bca', child: Text('BCA')),
                DropdownMenuItem(value: 'transfer_mandiri', child: Text('Mandiri')),
                DropdownMenuItem(value: 'transfer_bri', child: Text('BRI')),
                DropdownMenuItem(value: 'transfer_bni', child: Text('BNI')),
                DropdownMenuItem(value: 'transfer_bsi', child: Text('BSI')),
                DropdownMenuItem(value: 'transfer_cimb', child: Text('CIMB')),
              ],
              onChanged: (value) => setState(() {
                _selectedBank = value ?? '';
                _selectedMethod = _selectedBank;
              }),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (base > 0) ...[
                  _ConfirmComponentRow(
                    label: isDaily ? 'Gaji Harian' : 'Gaji Pokok',
                    value: PayrollProvider.formatCurrency(base),
                  ),
                  // Gap hanya kalau masih ada baris di bawahnya, supaya saat
                  // "Gaji Pokok" satu-satunya baris ia tetap center vertikal.
                  if (bonusItems.isNotEmpty || deductionItems.isNotEmpty)
                    const SizedBox(height: 8),
                ],
                if (bonusItems.isNotEmpty) ...[
                  const _ConfirmSectionLabel('Bonus & Insentif'),
                  const SizedBox(height: 8),
                  ...bonusItems.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ConfirmComponentRow(
                        label: PayrollProvider.displayComponentLabel(
                          c['name']?.toString(),
                          fallback: 'Bonus',
                        ),
                        value: PayrollProvider.formatCurrency(
                          PayrollProvider.toNum(c['amount']),
                        ),
                        valueColor: AppPalette.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _ConfirmComponentRow(
                    label: 'Total Bonus',
                    value: PayrollProvider.formatCurrency(
                      PayrollProvider.toNum(item['bonus_amount']),
                    ),
                    valueColor: AppPalette.success,
                  ),
                ],
                if (deductionItems.isNotEmpty) ...[
                  if (bonusItems.isNotEmpty) const SizedBox(height: 4),
                  const _ConfirmSectionLabel('Potongan'),
                  const SizedBox(height: 8),
                  ...deductionItems.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ConfirmComponentRow(
                        label: PayrollProvider.displayComponentLabel(
                          c['name']?.toString(),
                          fallback: 'Potongan',
                        ),
                        value:
                            '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(c['amount']))}',
                        valueColor: AppPalette.primary,
                      ),
                    ),
                  ),
                ],
                if (bonusItems.isNotEmpty || deductionItems.isNotEmpty)
                  const Divider(height: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.primaryPale,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL GAJI DIBAYARKAN',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  net,
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontSize: 24,
                    fontWeight: AppFont.w900,
                  ),
                ),
              ],
            ),
          ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedMethod.isEmpty ? null : () => Navigator.pop(context, {
                'confirm': true,
                'payment_method': _selectedMethod,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'BAYAR',
                style: TextStyle(color: Colors.white, fontWeight: AppFont.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'BATAL',
                style: TextStyle(
                  color: AppPalette.ink,
                  fontWeight: AppFont.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _confirmDetailRow(
    String label,
    String value, {
    Color valueColor = AppPalette.ink,
    double valueSize = 12.5,
    FontWeight valueWeight = AppFont.w800,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: valueSize,
              fontWeight: valueWeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSectionLabel extends StatelessWidget {
  final String label;

  const _ConfirmSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppPalette.primary,
        fontSize: 11,
        fontWeight: AppFont.w900,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ConfirmComponentRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _ConfirmComponentRow({
    required this.label,
    required this.value,
    this.valueColor = AppPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.5,
            fontWeight: AppFont.w800,
          ),
        ),
      ],
    );
  }
}
