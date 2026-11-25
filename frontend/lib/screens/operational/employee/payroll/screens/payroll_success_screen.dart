part of '../../payroll_screen.dart';

class _PayrollSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> paymentData;

  const _PayrollSuccessScreen({required this.item, required this.paymentData});

  void _backToPayrollList(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final hasAttendanceData = item.containsKey('work_days') &&
        item.containsKey('alfa_days') &&
        item.containsKey('overtime_minutes');
    final detailResult = hasAttendanceData
        ? <String, dynamic>{'success': false}
        : await context.read<PayrollProvider>().fetchItemDetail(
            item['id']?.toString() ?? '',
          );
    final receiptItem = detailResult['success'] == true &&
            detailResult['data'] is Map
        ? Map<String, dynamic>.from(detailResult['data'] as Map)
        : item;
    final components =
        (receiptItem['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final baseAmount = PayrollProvider.toNum(receiptItem['base_amount']);
    final bonusItems = components.where((c) {
      final type = c['type']?.toString().toLowerCase().trim();
      return type != 'base' &&
          type != 'deduction' &&
          PayrollProvider.toNum(c['amount']) > 0;
    });
    final deductionItems = components
        .where((c) => c['type']?.toString().toLowerCase().trim() == 'deduction')
        .where((c) => PayrollProvider.toNum(c['amount']) > 0);

    final lines = <PayrollReceiptLine>[
      if (baseAmount > 0)
        PayrollReceiptLine(
          'Gaji Pokok',
          PayrollProvider.formatCurrency(baseAmount),
        ),
      ...bonusItems.map(
        (c) => PayrollReceiptLine(
          PayrollProvider.displayComponentLabel(
            c['name']?.toString(),
            fallback: 'Bonus',
          ),
          PayrollProvider.formatCurrency(PayrollProvider.toNum(c['amount'])),
        ),
      ),
      ...deductionItems.map(
        (c) => PayrollReceiptLine(
          PayrollProvider.displayComponentLabel(
            c['name']?.toString(),
            fallback: 'Potongan',
          ),
          '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(c['amount']))}',
          isDeduction: true,
        ),
      ),
    ];

    final data = PayrollReceiptData(
      outletName: context.read<AppProvider>().outlet?.nama ?? 'AyoCuci Laundry',
      employeeName: receiptItem['pegawai_nama']?.toString() ?? '-',
      role: receiptItem['role_nama']?.toString() ?? '-',
      period: PayrollProvider.formatPeriodLong(receiptItem),
      dueDate: PayrollProvider.formatDate(receiptItem['due_date']),
      method: PayrollProvider.paymentMethodLabel(
        paymentData['payment_method']?.toString() ??
            receiptItem['payment_method']?.toString(),
      ),
      paidAt: PayrollProvider.formatDateTime(paymentData['paid_at']),
      lines: lines,
      total: PayrollProvider.formatCurrency(
        PayrollProvider.toNum(
          paymentData['total_amount'] ?? receiptItem['net_amount'],
        ),
      ),
    );

    await PayrollReceiptShare.share(context: context, data: data);
  }

  @override
  Widget build(BuildContext context) {
    final name = item['pegawai_nama']?.toString() ?? '-';
    final period = PayrollProvider.formatPeriodLong(item);
    final dueDate = PayrollProvider.formatDate(item['due_date']);
    final method = PayrollProvider.paymentMethodLabel(
      paymentData['payment_method']?.toString() ??
          item['payment_method']?.toString(),
    );
    final paidAt = PayrollProvider.formatDateTime(
      paymentData['paid_at'] ?? item['paid_at'],
    );
    final net = PayrollProvider.formatCurrency(
      PayrollProvider.toNum(paymentData['total_amount'] ?? item['net_amount']),
    );
    final components =
        (item['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final baseAmount = PayrollProvider.toNum(item['base_amount']);
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
          onPressed: () => _backToPayrollList(context),
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
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppPalette.success,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pembayaran Berhasil',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 22,
              fontWeight: AppFont.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gaji karyawan telah berhasil dibayar',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 21,
              fontWeight: AppFont.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEFF3)),
              boxShadow: AppShadows.cardSoft,
            ),
            child: Column(
              children: [
                _detailRow('Periode', period),
                _detailRow('Jadwal Bayar', dueDate),
                _detailRow('Metode Penggajian', method),
                _detailRow('Tanggal Bayar', paidAt, isLast: true),
                if (baseAmount > 0 ||
                    bonusItems.isNotEmpty ||
                    deductionItems.isNotEmpty) ...[
                  const Divider(height: 26, color: Color(0xFFEDEFF3)),
                  if (baseAmount > 0)
                    _detailRow(
                      'Gaji Pokok',
                      PayrollProvider.formatCurrency(baseAmount),
                      isLast: bonusItems.isEmpty && deductionItems.isEmpty,
                    ),
                  ...bonusItems.map(
                    (c) => _detailRow(
                      PayrollProvider.displayComponentLabel(
                        c['name']?.toString(),
                        fallback: 'Bonus',
                      ),
                      PayrollProvider.formatCurrency(
                        PayrollProvider.toNum(c['amount']),
                      ),
                      isLast: c == bonusItems.last && deductionItems.isEmpty,
                    ),
                  ),
                  ...deductionItems.map(
                    (c) => _detailRow(
                      PayrollProvider.displayComponentLabel(
                        c['name']?.toString(),
                        fallback: 'Potongan',
                      ),
                      '-${PayrollProvider.formatCurrency(PayrollProvider.toNum(c['amount']))}',
                      valueColor: AppPalette.primary,
                      isLast: c == deductionItems.last,
                    ),
                  ),
                ],
                const Divider(height: 26, color: Color(0xFFEDEFF3)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total Gaji Bersih',
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontSize: 13,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                      ),
                      Text(
                        net,
                        style: const TextStyle(
                          color: AppPalette.primary,
                          fontSize: 19,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _shareReceipt(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.ios_share_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'BAGIKAN SLIP GAJI',
                style: TextStyle(color: Colors.white, fontWeight: AppFont.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Struk gaji dibagikan sebagai gambar — pilih sendiri kontak WhatsApp tujuannya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => _backToPayrollList(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Kembali',
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

  Widget _detailRow(
    String label,
    String value, {
    Color valueColor = AppPalette.ink,
    double valueSize = 12.5,
    FontWeight valueWeight = AppFont.w800,
    bool allowWrap = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: allowWrap ? 3 : 1,
              softWrap: allowWrap,
              overflow: allowWrap
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: valueSize,
                fontWeight: valueWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
