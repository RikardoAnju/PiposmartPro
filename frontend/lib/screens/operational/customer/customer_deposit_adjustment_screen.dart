import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/customer_deposit_provider.dart';
import '../../../providers/metode_pembayaran_provider.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/rupiah_input_formatter.dart';

class CustomerDepositAdjustmentScreen extends StatefulWidget {
  final Customer customer;
  final String topupId;

  const CustomerDepositAdjustmentScreen({
    super.key,
    required this.customer,
    required this.topupId,
  });

  @override
  State<CustomerDepositAdjustmentScreen> createState() =>
      _CustomerDepositAdjustmentScreenState();
}

class _CustomerDepositAdjustmentScreenState
    extends State<CustomerDepositAdjustmentScreen> {
  final _value = TextEditingController();
  final _paid = TextEditingController();
  final _reason = TextEditingController();
  late final String _requestId =
      'deposit-adjust-${DateTime.now().microsecondsSinceEpoch}';
  String _kind = 'CORRECTION';
  String _type = 'RUPIAH';
  String? _methodId;
  String? _originalMethodId;
  DateTime? _topupCreatedAt;
  double _currentValue = 0;
  double _currentPaid = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        context.read<CustomerDepositProvider>().adjustmentState(
          widget.customer.id,
          widget.topupId,
        ),
        context.read<PaymentMethodProvider>().fetchPaymentMethods().then(
          (_) => <String, dynamic>{},
        ),
      ]);
      final state = results.first;
      if (!mounted) return;
      _type = state['deposit_type']?.toString() ?? 'RUPIAH';
      _currentValue = (state['current_value'] as num?)?.toDouble() ?? 0;
      _currentPaid = (state['current_paid'] as num?)?.toDouble() ?? 0;
      _originalMethodId = state['payment_method_id']?.toString();
      _methodId = _originalMethodId;
      _topupCreatedAt = DateTime.tryParse(
        state['topup_created_at']?.toString() ?? '',
      );
      _value.text = _type == 'KG'
          ? _currentValue.toStringAsFixed(2).replaceAll('.', ',')
          : _inputRupiah(_currentValue);
      _paid.text = _inputRupiah(_currentPaid);
    } catch (error) {
      if (mounted) _loadError = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _paid.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _parseDeposit(_value.text);
    final paid = _parseRupiah(_paid.text);
    if (value == null ||
        paid == null ||
        value < 0 ||
        paid < 0 ||
        (_kind == 'REFUND' && value <= 0) ||
        (_kind == 'REFUND' && _methodId == null) ||
        _reason.text.trim().isEmpty) {
      _message(
        _kind == 'REFUND'
            ? 'Isi nominal, metode pengembalian, dan alasan dengan benar.'
            : 'Isi nominal dan alasan koreksi dengan benar.',
      );
      return;
    }
    if (_kind == 'REFUND' && (value > _currentValue || paid > _currentPaid)) {
      _message(
        'Refund tidak boleh melebihi nilai deposit atau kas yang tersisa dari top up ini.',
      );
      return;
    }
    final scaledValue = _type == 'KG' ? value * 100 : value;
    if ((scaledValue - scaledValue.round()).abs() > 0.000001 ||
        (paid - paid.round()).abs() > 0.000001) {
      _message(
        _type == 'KG'
            ? 'Nilai kiloan maksimal 2 desimal dan kas harus Rupiah bulat.'
            : 'Nilai deposit dan kas harus Rupiah bulat.',
      );
      return;
    }
    if (_kind == 'CORRECTION' &&
        value == _currentValue &&
        paid == _currentPaid) {
      _message('Tidak ada selisih yang perlu dikoreksi.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          _kind == 'CORRECTION' ? 'Konfirmasi koreksi' : 'Konfirmasi refund',
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 18,
            fontWeight: AppFont.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customer.name,
              style: const TextStyle(color: AppPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _reviewLine(
              _kind == 'CORRECTION' ? 'Saldo berubah' : 'Deposit dikembalikan',
              _signedDeposit(
                _kind == 'CORRECTION' ? value - _currentValue : -value,
              ),
            ),
            const SizedBox(height: 10),
            _reviewLine(
              _kind == 'CORRECTION' ? 'Laporan top up' : 'Kas dikembalikan',
              _signedRupiah(
                _kind == 'CORRECTION' ? paid - _currentPaid : -paid,
              ),
            ),
            if (_kind == 'CORRECTION') ...[
              const SizedBox(height: 10),
              _reviewLine('Dampak kas hari ini', _rupiah(0)),
            ],
            const SizedBox(height: 16),
            Text(
              _kind == 'REFUND'
                  ? 'Pastikan uang sudah dikembalikan.'
                  : 'Dicatat pada tanggal top up${_topupDateLabel()}.',
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppPalette.ink),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final provider = context.read<CustomerDepositProvider>();
    final success = await provider.adjustTopUp(
      widget.customer.id,
      widget.topupId,
      kind: _kind,
      value: value,
      totalPaid: paid,
      paymentMethodId: _kind == 'REFUND' ? _methodId : null,
      note: _reason.text,
      requestId: _requestId,
      expectedValue: _currentValue,
      expectedPaid: _currentPaid,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      CustomToast.show(context, message: 'Penyesuaian deposit berhasil');
      Navigator.pop(context, true);
    } else {
      _message(provider.errorMessage ?? 'Penyesuaian gagal.');
    }
  }

  void _message(String value) {
    CustomToast.show(context, message: value, isError: true);
  }

  String _inputRupiah(double value) =>
      RupiahThousandsInputFormatter.format(value.round());

  String _topupDateLabel() {
    final date = _topupCreatedAt;
    if (date == null) return '';
    return ' (${DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal())})';
  }

  double? _parseRupiah(String input) =>
      RupiahThousandsInputFormatter.parse(input);

  double? _parseDeposit(String input) => _type == 'KG'
      ? double.tryParse(input.replaceAll(',', '.'))
      : _parseRupiah(input);

  String _signedRupiah(double value) => value > 0
      ? '+${_rupiah(value)}'
      : value < 0
      ? '-${_rupiah(value.abs())}'
      : _rupiah(0);

  String _signedDeposit(double value) => value > 0
      ? '+${_depositAmount(value)}'
      : value < 0
      ? '-${_depositAmount(value.abs())}'
      : _depositAmount(0);

  String _depositAmount(double value) => _type == 'KG'
      ? '${formatCompactQuantity(value)} Kg'
      : NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(value);

  String _rupiah(double value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  Widget _reviewLine(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppPalette.muted, fontSize: 12),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 13,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
    ],
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppPalette.ink,
      fontSize: 13,
      fontWeight: AppFont.w700,
    ),
  );

  InputDecoration _fieldDecoration(String hint, {String? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppPalette.muted, fontSize: 14),
        prefixText: prefix,
        prefixStyle: const TextStyle(
          color: AppPalette.ink,
          fontWeight: AppFont.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9E0E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD9E0E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.4),
        ),
      );

  Widget _balanceCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: AppPalette.brandGradient),
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppShadows.colored(AppPalette.primary),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SALDO TOP UP SAAT INI',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: AppFont.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    widget.customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _balanceMetric(
                'NILAI DEPOSIT',
                _depositAmount(_currentValue),
              ),
            ),
            Container(width: 1, height: 42, color: Colors.white38),
            const SizedBox(width: 16),
            Expanded(
              child: _balanceMetric('KAS DITERIMA', _rupiah(_currentPaid)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _balanceMetric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: AppFont.w700,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
    ],
  );

  Widget _kindSelector() => Container(
    height: 48,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Row(
      children: [
        _kindOption('CORRECTION', 'Koreksi', Icons.edit_note_rounded),
        _kindOption('REFUND', 'Refund', Icons.replay_rounded),
      ],
    ),
  );

  Widget _kindOption(String kind, String title, IconData icon) {
    final selected = _kind == kind;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (selected) return;
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            _kind = kind;
            _value.text = kind == 'CORRECTION'
                ? (_type == 'KG'
                      ? _currentValue.toStringAsFixed(2).replaceAll('.', ',')
                      : _inputRupiah(_currentValue))
                : '';
            _paid.text = kind == 'CORRECTION' ? _inputRupiah(_currentPaid) : '';
            _methodId = kind == 'REFUND' ? null : _originalMethodId;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : AppPalette.muted,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : AppPalette.ink,
                  fontSize: 13,
                  fontWeight: AppFont.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _impactPreview() {
    final value = _parseDeposit(_value.text);
    final paid = _parseRupiah(_paid.text);
    final valid = value != null && paid != null && value >= 0 && paid >= 0;
    final balanceDelta = !valid
        ? 0.0
        : _kind == 'CORRECTION'
        ? value - _currentValue
        : -value;
    final cashDelta = !valid
        ? 0.0
        : _kind == 'CORRECTION'
        ? paid - _currentPaid
        : -paid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RINGKASAN',
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 12,
              fontWeight: AppFont.w800,
            ),
          ),
          if (valid) ...[
            const SizedBox(height: 10),
            _reviewLine('Saldo berubah', _signedDeposit(balanceDelta)),
            const SizedBox(height: 7),
            _reviewLine(
              _kind == 'CORRECTION' ? 'Laporan top up' : 'Kas keluar hari ini',
              _signedRupiah(cashDelta),
            ),
            if (_kind == 'CORRECTION') ...[
              const SizedBox(height: 7),
              _reviewLine('Dampak kas hari ini', _rupiah(0)),
            ],
            if (_kind == 'REFUND') ...[
              const SizedBox(height: 7),
              _reviewLine(
                'Saldo setelah refund',
                _depositAmount(_currentValue - value),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = context
        .watch<PaymentMethodProvider>()
        .getActivePaymentMethods()
        .where((method) => !method.isNobu)
        .toList();
    final selectedMethod = methods.any((method) => method.id == _methodId)
        ? _methodId
        : null;
    return Scaffold(
      appBar: const AppPageBar(title: 'Penyesuaian Deposit'),
      backgroundColor: AppPalette.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 38,
                      color: AppPalette.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loadError = null;
                          _loading = true;
                        });
                        _load();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                _balanceCard(),
                const SizedBox(height: 24),
                _label('Jenis Penyesuaian'),
                const SizedBox(height: 9),
                _kindSelector(),
                const SizedBox(height: 10),
                Text(
                  _kind == 'REFUND'
                      ? 'Kurangi saldo dan catat uang yang dikembalikan hari ini.'
                      : 'Perbaiki top up asli tanpa mengubah kas hari ini.',
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _label(
                  _kind == 'CORRECTION'
                      ? 'Nilai deposit yang benar'
                      : 'Saldo deposit yang dikurangi',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _value,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: _type == 'KG',
                  ),
                  inputFormatters: _type == 'KG'
                      ? [
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) =>
                                RegExp(
                                  r'^\d*(,\d{0,2})?$',
                                ).hasMatch(newValue.text)
                                ? newValue
                                : oldValue,
                          ),
                        ]
                      : [RupiahThousandsInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                  ),
                  decoration: _fieldDecoration(
                    _type == 'KG' ? '0,00' : '0',
                    prefix: _type == 'KG' ? null : 'Rp ',
                  ),
                ),
                if (_type == 'KG')
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Dalam satuan kilogram (Kg)',
                      style: TextStyle(color: AppPalette.muted, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 16),
                _label(
                  _kind == 'CORRECTION'
                      ? 'Kas diterima yang benar'
                      : 'Uang dikembalikan ke pelanggan',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _paid,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahThousandsInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                  ),
                  decoration: _fieldDecoration('0', prefix: 'Rp '),
                ),
                if (_kind == 'REFUND') ...[
                  const SizedBox(height: 16),
                  _label('Metode pengembalian kas'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$_kind-${_methodId ?? 'none'}'),
                    initialValue: selectedMethod,
                    isExpanded: true,
                    decoration: _fieldDecoration('Pilih metode pengembalian'),
                    items: methods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method.id,
                            child: Text(
                              method.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _methodId = value),
                  ),
                ],
                const SizedBox(height: 16),
                _impactPreview(),
                const SizedBox(height: 16),
                _label('Alasan'),
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(color: AppPalette.ink, fontSize: 14),
                  decoration: _fieldDecoration('Contoh: nominal salah input'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.primaryBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppPalette.primary,
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _kind == 'REFUND'
                              ? 'Pastikan uang sudah dikembalikan.'
                              : 'Riwayat asli tetap tersimpan.',
                          style: const TextStyle(
                            color: AppPalette.ink,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                color: AppPalette.surface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _saving ? 'MEMPROSES...' : 'REVIEW PENYESUAIAN',
                      style: const TextStyle(
                        fontWeight: AppFont.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
