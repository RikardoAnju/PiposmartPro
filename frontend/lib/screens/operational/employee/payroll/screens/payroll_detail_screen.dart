part of '../../payroll_screen.dart';

class _PayrollDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const _PayrollDetailScreen({required this.item});

  @override
  State<_PayrollDetailScreen> createState() => _PayrollDetailScreenState();
}

class _PayrollDetailScreenState extends State<_PayrollDetailScreen> {
  Map<String, dynamic> _detail = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detail = widget.item;
    _loading = _detail.isEmpty;
    _load();
  }

  Future<void> _load() async {
    // Simpan state _detail TERKINI (bisa sudah berubah karena edit rincian)
    // sebagai sumber fallback, bukan widget.item yang beku sejak layar dibuka
    // pertama kali — kalau tidak, nilai lama (mis. net_amount sebelum ada
    // potongan) bisa menimpa kembali nilai baru yang benar walau nilai baru
    // itu memang nol.
    final previousDetail = _detail;
    final res = await context.read<PayrollProvider>().fetchItemDetail(
      widget.item['id']?.toString() ?? '',
    );
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        final apiDetail = Map<String, dynamic>.from(res['data'] as Map);
        final sourceDetail = previousDetail.isNotEmpty
            ? previousDetail
            : widget.item;
        final apiSalaryType = apiDetail['salary_type']?.toString().trim();
        final sourceSalaryType = sourceDetail['salary_type']?.toString().trim();
        if ((apiSalaryType == null || apiSalaryType.isEmpty || apiSalaryType == '-') &&
            sourceSalaryType != null &&
            sourceSalaryType.isNotEmpty &&
            sourceSalaryType != '-') {
          apiDetail['salary_type'] = sourceSalaryType;
        }
        // Riwayat menyimpan snapshot payroll. Jika endpoint detail lama
        // mengembalikan angka nol untuk salah satu metrik, jangan menimpa
        // nilai snapshot yang masih valid.
        for (final key in [
          'base_amount',
          'work_days',
          'alfa_days',
          'overtime_minutes',
          'bonus_amount',
          'deduction_amount',
          'net_amount',
        ]) {
          final apiValue = PayrollProvider.toNum(apiDetail[key]);
          final sourceValue = PayrollProvider.toNum(sourceDetail[key]);
          if (apiValue == 0 && sourceValue != 0) {
            apiDetail[key] = sourceDetail[key];
          }
        }
        final apiComponents = apiDetail['components'] as List?;
        final sourceComponents = sourceDetail['components'] as List?;
        if ((apiComponents == null || apiComponents.isEmpty) &&
            sourceComponents != null &&
            sourceComponents.isNotEmpty) {
          apiDetail['components'] = sourceComponents;
        }
        if (sourceDetail['_combined'] == true) {
          apiDetail['_combined'] = true;
          apiDetail['_item_ids'] = sourceDetail['_item_ids'];
        }
        _detail = apiDetail;
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
    final isPaid = PayrollProvider.isPaidPayrollStatus(status);
    final name = _detail['pegawai_nama']?.toString() ?? '-';
    final salaryType = PayrollProvider.salaryTypeLabel(
      _detail['salary_type']?.toString(),
    );
    final base = PayrollProvider.toNum(_detail['base_amount']);
    final bonus = PayrollProvider.toNum(_detail['bonus_amount']);
    final deduction = PayrollProvider.toNum(_detail['deduction_amount']);
    final paymentMethod = PayrollProvider.paymentMethodLabel(
      _detail['payment_method']?.toString(),
    );
    final components =
        (_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final componentBonus = components
        .where((c) => c['type']?.toString().toLowerCase() == 'bonus')
        .fold<num>(0, (sum, c) => sum + PayrollProvider.toNum(c['amount']));
    final componentDeduction = components
        .where((c) => c['type']?.toString().toLowerCase() == 'deduction')
        .fold<num>(0, (sum, c) => sum + PayrollProvider.toNum(c['amount']));
    final effectiveBonus = components.isEmpty ? bonus : componentBonus;
    final effectiveDeduction = components.isEmpty
        ? deduction
        : componentDeduction;
    final net = PayrollProvider.formatCurrency(
      (base + effectiveBonus - effectiveDeduction).clamp(0, double.infinity),
    );
    final alfaAlreadyApplied = components.any(
      (component) =>
          component['type']?.toString().toLowerCase() == 'deduction' &&
          component['name']?.toString().toLowerCase().contains('alfa') == true,
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
        actions: isPaid
            ? const []
            : [
                IconButton(
                  tooltip: 'Hapus payroll',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppPalette.primary,
                    size: 22,
                  ),
                  onPressed: () => _deleteUnpaidItem(context),
                ),
              ],
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              bonus: effectiveBonus,
              deduction: effectiveDeduction,
              baseLabel: 'Gaji Pokok',
              workDays: PayrollProvider.toNum(_detail['work_days']),
              alfaDays: PayrollProvider.toNum(_detail['alfa_days']),
              overtimeMinutes: PayrollProvider.toNum(
                _detail['overtime_minutes'],
              ),
              // Payroll yang sudah dibayar memakai deduction_amount final.
              // Jangan hitung ulang Alfa sebagai pending karena akan membuat
              // potongan tampil dua kali pada riwayat pembayaran.
              // Jika backend sudah menyimpan deduction_amount dari Alfa,
              // jangan tambahkan lagi sebagai potongan pending di UI.
              // Potongan manual (misalnya kasbon) tidak berarti potongan alfa
              // sudah diterapkan. Alfa tetap tampil sebagai pending sampai
              // pengguna menekan tombol Potong Gaji.
              pendingDeduction: isPaid || alfaAlreadyApplied
                  ? 0
                  : PayrollProvider.toNum(_detail['alfa_days']) *
                        (PayrollProvider.toNum(_detail['work_days']) > 0
                            ? base / PayrollProvider.toNum(_detail['work_days'])
                            : 0),
              componentDetails: components,
              baseNote: PayrollProvider.baseBreakdownText(_detail),
            ),
            editable: !isPaid,
            onAddBonus: null,
            onAddDeduction: alfaAlreadyApplied
                ? () => _openQuickComponent(context, 'deduction')
                : () => _applyPendingDeduction(context),
            deductionActionLabel: alfaAlreadyApplied
                ? 'Tambah Potongan'
                : 'Potong Gaji',
            onTapMethod: null,
            onPaymentMethodChanged: null,
          ),
          const SizedBox(height: 16),
          if (isPaid)
            _DetailActionButton(
              label: 'Lihat Bukti',
              variant: _DetailActionVariant.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PayrollSuccessScreen(
                    item: _detail,
                    paymentData: {
                      'reference_no':
                          _detail['reference_no'] ??
                          _detail['payment_reference_no'] ??
                          'PAY/${DateFormat('yyyyMMdd').format(DateTime.now())}/${_detail['id']?.toString() ?? ''}',
                      'payment_method': _detail['payment_method'],
                      'paid_at': _detail['paid_at'],
                      'total_amount': _detail['net_amount'],
                    },
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _DetailActionButton(
                    label: 'Ubah Rincian',
                    variant: _DetailActionVariant.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _PayrollEntryEditorScreen(item: _detail),
                        ),
                      ).then((saved) async {
                        if (!mounted) return;
                        if (saved is Map) {
                          setState(() {
                            _detail['components'] = saved['components'];
                            _detail['bonus_amount'] = saved['bonus'];
                            _detail['deduction_amount'] = saved['deduction'];
                            _detail['net_amount'] = saved['net_amount'];
                          });
                        }
                        await _load();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailActionButton(
                    label: 'Lanjut Bayar',
                    variant: _DetailActionVariant.primary,
                    onTap: () => _openConfirmPaySheet(context),
                  ),
                ),
              ],
            ),
        ],
        ),
      ),
    );
  }

  // Pilih metode penggajian langsung dari layar detail (tanpa masuk Ubah
  // Rincian). Metode disimpan di state lokal dan dipakai saat Lanjut Bayar.
  Future<void> _pickPaymentMethod(BuildContext context) async {
    const options = [
      ['transfer', 'Transfer'],
      ['cash', 'Tunai'],
      ['ewallet', 'E-Wallet'],
    ];
    final current = PayrollProvider.normalizePaymentMethod(
      _detail['payment_method']?.toString(),
    );
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E7EE),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Metode Penggajian',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 16,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ),
            ),
            ...options.map((o) {
              final sel = o[0] == current;
              return ListTile(
                title: Text(
                  o[1],
                  style: TextStyle(
                    color: sel ? AppPalette.primary : AppPalette.ink,
                    fontWeight: sel ? AppFont.w800 : AppFont.w600,
                  ),
                ),
                trailing: sel
                    ? const Icon(Icons.check_rounded, color: AppPalette.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, o[0]),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _detail['payment_method'] = selected);
    }
  }

  Future<void> _openConfirmPaySheet(BuildContext context) async {
    final provider = context.read<PayrollProvider>();
    final selectedMethod = PayrollProvider.normalizePaymentMethod(
      _detail['payment_method']?.toString(),
    );
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PayrollConfirmPaySheet(item: _detail, paymentMethod: selectedMethod),
    );
    if (res == null || res['confirm'] != true) return;
    final chosenMethod = res['payment_method']?.toString() ?? selectedMethod;

    final sendSlip =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Kirim Slip Gaji?'),
            content: Text(
              'Apakah Anda ingin mengirim slip gaji ke karyawan ${_detail['pegawai_nama'] ?? '-'}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Tidak'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Ya, Kirim'),
              ),
            ],
          ),
        ) ??
        false;

    final itemIds = (widget.item['_item_ids'] as List?)
            ?.map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toList() ??
        [widget.item['id']?.toString() ?? ''];
    final payRes = itemIds.length > 1
        ? await provider.markBulkPaid(
            itemIds: itemIds,
            paymentMethod: chosenMethod,
          )
        : await provider.markPaid(
            itemId: itemIds.first,
            paymentMethod: chosenMethod,
            buktiPath: null,
          );
    if (context.mounted) {
      CustomToast.show(
        context,
        message: payRes['message']?.toString() ?? 'Selesai',
        isError: payRes['success'] != true,
      );
      if (payRes['success'] == true) {
        PayrollReceiptData? receiptData;
        if (context.mounted) {
          receiptData = buildPayrollReceiptData(
            item: _detail,
            outletName: context.read<AppProvider>().outlet?.nama ?? 'AyoCuci Laundry',
            method: PayrollProvider.paymentMethodLabel(chosenMethod),
            dueDate: PayrollProvider.formatDate(_detail['due_date']),
            paidAt: PayrollProvider.formatDateTime(DateTime.now()),
            period: PayrollProvider.formatPeriodLong(_detail),
          );
        }
        final data = (payRes['data'] as Map<String, dynamic>?) ?? const {};
        if (mounted) {
          setState(() {
            _detail['status'] = 'paid';
            _detail['payment_method'] =
                data['payment_method']?.toString() ?? selectedMethod;
            if (data['paid_at'] != null) {
              _detail['paid_at'] = data['paid_at'];
            }
            if (data['reference_no'] != null) {
              _detail['reference_no'] = data['reference_no'];
            }
          });
        }
        if (sendSlip && receiptData != null && context.mounted) {
          await PayrollReceiptShare.share(context: context, data: receiptData);
        }
        appEventBus.add(ExpenseChanged());
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _PayrollSuccessScreen(item: _detail, paymentData: data),
          ),
        );
      }
    }
  }

  // Tambah bonus/potongan langsung dari layar detail tanpa masuk "Ubah Rincian".
  Future<void> _applyPendingDeduction(BuildContext context) async {
    final employeeName = _detail['pegawai_nama']?.toString() ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Potong Gaji?'),
        content: Text('Apakah Anda yakin ingin memotong gaji $employeeName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Potong'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final provider = context.read<PayrollProvider>();
    final base = PayrollProvider.toNum(_detail['base_amount']);
    final workDays = PayrollProvider.toNum(_detail['work_days']);
    final alfaDays = PayrollProvider.toNum(_detail['alfa_days']);
    final salaryType = _detail['salary_type']?.toString().toLowerCase();
    final divisor = salaryType == 'daily' ? workDays : workDays + alfaDays;
    final amount = alfaDays * (divisor > 0 ? base / divisor : 0);
    if (amount <= 0) return;

    final result = await provider.addItemComponent(
      itemId: _detail['id']?.toString() ?? '',
      detail: _detail,
      type: 'deduction',
      rawName: 'Potongan alfa',
      amount: amount,
    );
    if (!context.mounted) return;
    if (result['success'] == true) {
      final saved = result['data'];
      if (saved is Map) {
        setState(() {
          _detail['components'] = saved['components'];
          _detail['bonus_amount'] = saved['bonus'];
          _detail['deduction_amount'] = saved['deduction'];
          _detail['net_amount'] = saved['net_amount'];
        });
      }
      await _load();
      if (context.mounted) {
        CustomToast.show(context, message: 'Potongan gaji berhasil diterapkan');
      }
    } else {
      CustomToast.show(
        context,
        message: result['message']?.toString() ?? 'Gagal menerapkan potongan',
        isError: true,
      );
    }
  }

  // Tambah bonus/potongan manual langsung dari layar detail.
  Future<void> _openQuickComponent(BuildContext context, String type) async {
    final provider = context.read<PayrollProvider>();
    final existingAmount = type == 'deduction'
        ? PayrollProvider.toNum(_detail['deduction_amount'])
        : PayrollProvider.toNum(_detail['bonus_amount']);
    final components =
        (_detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final existingComponent = components
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (component) => component['type']?.toString().toLowerCase() == type,
          orElse: () => const <String, dynamic>{},
        );
    final nameController = TextEditingController(
      text: existingComponent['name']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: existingAmount > 0 ? existingAmount.toInt().toString() : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComponentEditorSheet(
        type: type,
        nameController: nameController,
        amountController: amountController,
        onSave: () async {
          final amount = PayrollProvider.parseRupiah(amountController.text);
          if (amount <= 0) {
            CustomToast.show(
              context,
              message: 'Nominal harus lebih dari 0',
              isError: true,
            );
            return;
          }
          final res = await provider.addItemComponent(
            itemId: widget.item['id']?.toString() ?? '',
            detail: _detail,
            type: type,
            rawName: nameController.text,
            amount: amount,
          );
          if (!context.mounted) return;
          Navigator.pop(context);
          CustomToast.show(
            context,
            message: res['message']?.toString() ?? 'Tersimpan',
            isError: res['success'] != true,
          );
          if (res['success'] == true) await _load();
        },
      ),
    );
  }

  Future<void> _deleteUnpaidItem(BuildContext context) async {
    final provider = context.read<PayrollProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Penggajian?'),
        content: const Text(
          'Data penggajian yang belum dibayar akan dihapus permanen dari daftar aktif.',
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
              style: TextStyle(color: AppPalette.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await provider.deleteItem(widget.item['id']?.toString() ?? '');
    if (!context.mounted) return;

    CustomToast.show(
      context,
      message: res['message']?.toString() ?? 'Selesai',
      isError: res['success'] != true,
    );
    if (res['success'] == true && Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }
}
