import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/customer_deposit_provider.dart';
import '../../../providers/metode_pembayaran_provider.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_shimmer.dart';
import 'widgets/customer_deposit_receipt_share.dart';

class CustomerDepositTopupScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDepositTopupScreen({super.key, required this.customer});
  @override
  State<CustomerDepositTopupScreen> createState() => _TopupState();
}

class _TopupState extends State<CustomerDepositTopupScreen> {
  static const double _maxRupiah = 999999999;
  static const double _maxKg = 999999;

  final amount = TextEditingController();
  final paid = TextEditingController();
  final discount = TextEditingController();
  final note = TextEditingController();
  String kind = 'RUPIAH';
  String? paymentMethodId;
  bool review = false;
  bool done = false;
  bool showValidation = false;
  bool _submitting = false;
  late final AudioPlayer _audioPlayer;
  late final String _requestId =
      'topup-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _audioPlayer.dispose();
    amount.dispose();
    paid.dispose();
    discount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PaymentMethodProvider>();
      await provider.fetchPaymentMethods();
    });
  }

  double get value => _parseAmount(amount.text, kind == 'RUPIAH');
  double get paidValue => _parseAmount(paid.text, true);
  double get discountValue => _parseAmount(discount.text, true);
  double get maxDepositValue => kind == 'KG' ? _maxKg : _maxRupiah;
  bool get isCashWithinDepositLimit => kind != 'RUPIAH' || paidValue <= value;
  bool get isRupiahBreakdownValid =>
      kind != 'RUPIAH' || (paidValue + discountValue - value).abs() < 0.001;
  bool get isFormValid =>
      value > 0 &&
      value <= maxDepositValue &&
      paidValue > 0 &&
      paidValue <= _maxRupiah &&
      discountValue <= _maxRupiah &&
      isCashWithinDepositLimit &&
      isRupiahBreakdownValid &&
      paymentMethodId != null;
  @override
  Widget build(BuildContext context) {
    if (done) return _success();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: const AppPageBar(title: 'Top Up Deposit'),
      body: _form(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: const Color(0xFFF5F6F7),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (!isFormValid) {
                  setState(() => showValidation = true);
                  return;
                }
                _openReview();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'REVIEW TOP UP',
                style: TextStyle(
                  fontSize: 14,
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

  Future<void> _openReview() {
    if (!isFormValid) {
      setState(() => showValidation = true);
      return Future.value();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheetState) => _reviewSheet(setSheetState),
      ),
    );
  }

  Widget _form() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      _sectionLabel('Jenis Deposit'),
      const SizedBox(height: 8),
      _depositTypeSelector(),
      const SizedBox(height: 16),
      _sectionLabel(kind == 'KG' ? 'Jumlah Kilo' : 'Nominal Deposit'),
      const SizedBox(height: 8),
      _inputField(
        controller: amount,
        hintText: kind == 'KG' ? '10 Kg' : '300.000',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        prefixText: kind == 'KG' ? null : 'Rp ',
        inputFormatters: kind == 'KG'
            ? [const _DecimalLimitInputFormatter(_maxKg)]
            : [const _RupiahInputFormatter(maxValue: _maxRupiah)],
        onChanged: (_) => setState(() {}),
      ),
      if (showValidation && value <= 0) _fieldError('Masukkan nilai deposit.'),
      if (showValidation && value > maxDepositValue)
        _fieldError(
          kind == 'KG'
              ? 'Maksimal deposit 999.999 kg.'
              : 'Maksimal deposit Rp999.999.999.',
        ),
      const SizedBox(height: 14),
      _sectionLabel('Kas Diterima'),
      const SizedBox(height: 8),
      _inputField(
        controller: paid,
        hintText: kind == 'KG' ? '70.000' : '270.000',
        keyboardType: TextInputType.number,
        prefixText: 'Rp ',
        inputFormatters: const [_RupiahInputFormatter(maxValue: _maxRupiah)],
        onChanged: (_) => setState(() {}),
      ),
      if (showValidation && paidValue <= 0)
        _fieldError('Masukkan kas yang diterima.'),
      if (showValidation && paidValue > _maxRupiah)
        _fieldError('Maksimal kas diterima Rp999.999.999.'),
      if (showValidation &&
          paidValue <= _maxRupiah &&
          !isCashWithinDepositLimit)
        _fieldError('Kas diterima tidak boleh melebihi nominal deposit.'),
      const SizedBox(height: 14),
      _sectionLabel('Diskon Deposit (Opsional)'),
      const SizedBox(height: 8),
      _inputField(
        controller: discount,
        hintText: '0',
        keyboardType: TextInputType.number,
        prefixText: 'Rp ',
        inputFormatters: const [_RupiahInputFormatter(maxValue: _maxRupiah)],
        onChanged: (_) => setState(() {}),
      ),
      if (showValidation && discountValue > _maxRupiah)
        _fieldError('Maksimal diskon Rp999.999.999.'),
      if (showValidation &&
          kind == 'RUPIAH' &&
          paidValue > 0 &&
          !isRupiahBreakdownValid)
        _fieldError('Kas diterima + diskon harus sama dengan nominal deposit.'),
      const SizedBox(height: 10),
      _depositHint(),
      const SizedBox(height: 16),
      _sectionLabel('Metode Pembayaran'),
      const SizedBox(height: 8),
      _paymentField(),
      if (showValidation && paymentMethodId == null)
        _fieldError('Pilih metode pembayaran.'),
      const SizedBox(height: 16),
      _sectionLabel('Catatan (Opsional)'),
      const SizedBox(height: 8),
      _inputField(
        controller: note,
        hintText: 'Tambahkan Catatan',
        maxLines: 3,
        alignTop: true,
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppPalette.ink,
      fontSize: 14,
      fontWeight: AppFont.w400,
    ),
  );

  Widget _fieldError(String message) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: AppPalette.danger,
        ),
        const SizedBox(width: 5),
        Text(
          message,
          style: const TextStyle(color: AppPalette.danger, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _depositTypeSelector() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: kind == 'RUPIAH'
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _typeOption('RUPIAH', 'Rupiah'),
              _typeOption('KG', 'Kiloan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeOption(String value, String label) {
    final selected = kind == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => _changeDepositType(value),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppPalette.primary,
              fontSize: 12,
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _changeDepositType(String value) {
    FocusManager.instance.primaryFocus?.unfocus();
    amount.clear();
    paid.clear();
    discount.clear();
    setState(() => kind = value);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    bool alignTop = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      maxLines: maxLines,
      textAlignVertical: alignTop
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      style: const TextStyle(
        color: AppPalette.ink,
        fontSize: 14,
        fontWeight: AppFont.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFC7CBD2),
          fontSize: 14,
          fontWeight: AppFont.w600,
        ),
        filled: true,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: AppPalette.ink,
          fontSize: 14,
          fontWeight: AppFont.w600,
        ),
        fillColor: Colors.white,
        contentPadding: EdgeInsets.fromLTRB(14, alignTop ? 15 : 0, 14, 0),
        constraints: BoxConstraints(minHeight: maxLines > 1 ? 80 : 48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFD9E0E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFD9E0E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.2),
        ),
      ),
    );
  }

  Widget _depositHint() {
    final amountValue = value;
    final paidValue = _parseAmount(paid.text, true);
    final discountValue = _parseAmount(discount.text, true);
    final text = kind == 'KG'
        ? discountValue > 0
              ? 'Diskon program ${_formatRupiah(discountValue)} untuk ${formatCompactQuantity(amountValue)} Kg'
              : 'Kas diterima untuk ${formatCompactQuantity(amountValue)} Kg deposit'
        : paidValue <= 0
        ? 'Masukkan kas yang diterima dari pelanggan'
        : discountValue > 0
        ? 'Kas + diskon = ${_formatRupiah(paidValue + discountValue)}'
        : 'Tanpa diskon, kas harus sama dengan nominal deposit';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        border: Border.all(color: const Color(0xFFD1E5FF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF1976FF),
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF1976FF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _paymentField() {
    return Consumer<PaymentMethodProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppSkeletonBox(height: 48, radius: 9);
        }
        final methods = provider
            .getActivePaymentMethods()
            .where((method) => !method.isNobu)
            .toList();
        final selectedId = methods.any((m) => m.id == paymentMethodId)
            ? paymentMethodId
            : null;
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD9E0E6)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              hint: Text(
                methods.isEmpty
                    ? 'Belum ada metode pembayaran aktif'
                    : 'Pilih metode pembayaran',
                style: const TextStyle(color: AppPalette.muted, fontSize: 14),
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppPalette.muted,
              ),
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 14,
                fontWeight: AppFont.w600,
              ),
              items: methods
                  .map(
                    (method) => DropdownMenuItem<String>(
                      value: method.id,
                      child: Text(method.name),
                    ),
                  )
                  .toList(),
              onChanged: methods.isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => paymentMethodId = value);
                      }
                    },
            ),
          ),
        );
      },
    );
  }

  double _parseAmount(String input, bool rupiah) {
    if (input.trim().isEmpty) return 0;
    final normalized = rupiah
        ? input.replaceAll(RegExp(r'[^0-9]'), '')
        : input.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _formatRupiah(double number) {
    final value = number.round().toString();
    final parts = <String>[];
    for (var end = value.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      parts.insert(0, value.substring(start, end));
    }
    return 'Rp${parts.join('.')}';
  }

  Widget _reviewSheet(StateSetter setSheetState) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 9, 16, 38),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E2EA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEEE9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppPalette.primary,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Konfirmasi Top Up',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 18,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 38, top: 2),
              child: Text(
                'Periksa rincian sebelum melanjutkan pembayaran',
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _card(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAF2),
                border: Border.all(color: const Color(0xFFF3E6D1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF8B7560), size: 14),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Pastikan rincian sudah sesuai. Transaksi yang sudah diproses tidak dapat dibatalkan.',
                      style: TextStyle(
                        color: Color(0xFF8B7560),
                        fontSize: 11,
                        fontWeight: AppFont.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _submitting ? null : () => _submit(setSheetState),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'KONFIRMASI TOP UP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFont.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.ink,
                  side: const BorderSide(color: Color(0xFFD9E2EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 12, fontWeight: AppFont.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );

  Widget _card({bool success = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: BoxDecoration(
      color: success ? Colors.white : const Color(0xFFF3F5F7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0E6EB)),
    ),
    child: Column(
      children: [
        _line('Pelanggan', widget.customer.name),
        _line('Tanggal', _dateLabel()),
        _line('Jenis Deposit', kind == 'KG' ? 'Kiloan' : 'Rupiah'),
        _line(
          'Metode Pembayaran',
          context
                  .read<PaymentMethodProvider>()
                  .paymentMethods
                  .where((m) => m.id == paymentMethodId)
                  .map((m) => m.name)
                  .firstOrNull ??
              'Belum dipilih',
        ),
        if (discountValue > 0)
          _line('Diskon Program Deposit', _formatRupiah(discountValue)),
        if (note.text.trim().isNotEmpty) _noteBlock(note.text.trim()),
        const Divider(height: 18, color: Color(0xFFDCE3E8)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            children: [
              const Text(
                'Nilai Deposit',
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 12,
                  fontWeight: AppFont.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kind == 'KG'
                    ? '${_parseAmount(amount.text, false).toStringAsFixed(0)} Kg'
                    : _formatRupiah(value),
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontSize: 28,
                  fontWeight: AppFont.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Kas Diterima',
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: AppFont.w500,
                ),
              ),
              Text(
                _formatRupiah(
                  _parseAmount(paid.text, true) == 0
                      ? value
                      : _parseAmount(paid.text, true),
                ),
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 13,
                  fontWeight: AppFont.w600,
                ),
              ),
              if (discountValue > 0) ...[
                const SizedBox(height: 7),
                const Text(
                  'Diskon',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    fontWeight: AppFont.w500,
                  ),
                ),
                Text(
                  _formatRupiah(discountValue),
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontSize: 13,
                    fontWeight: AppFont.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _line(String label, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7F8790),
              fontSize: 12,
              fontWeight: AppFont.w500,
            ),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 12,
            fontWeight: AppFont.w600,
          ),
        ),
      ],
    ),
  );

  Widget _noteBlock(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 7, bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE0E6EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan',
          style: TextStyle(
            color: Color(0xFF7F8790),
            fontSize: 12,
            fontWeight: AppFont.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 12,
            fontWeight: AppFont.w600,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
  String _dateLabel() {
    final now = DateTime.now();
    final minute = now.minute.toString().padLeft(2, '0');
    return '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}, ${now.hour}:$minute';
  }

  String _monthName(int month) => const [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ][month];

  Widget _success() => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: const AppPageBar(title: 'Detail Top Up'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF9F0), Color(0xFFF8FCF9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8F0E0)),
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8F5E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF249653),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Top Up Deposit Berhasil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 18,
                  fontWeight: AppFont.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Deposit pelanggan berhasil ditambahkan',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF718096), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(success: true),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFF8F9FA),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: () {
                  final balance = context
                      .read<CustomerDepositProvider>()
                      .balance;
                  CustomerDepositReceiptShare.send(
                    context: context,
                    customerName: widget.customer.name,
                    customerPhone: widget.customer.phone,
                    title: 'TOP UP DEPOSIT',
                    amount: kind == 'KG'
                        ? '${formatCompactQuantity(value)} Kg'
                        : _formatRupiah(value),
                    depositType: kind == 'KG' ? 'Deposit Kg' : 'Deposit Rupiah',
                    createdAt: _dateLabel(),
                    balanceAfter: kind == 'KG'
                        ? '${formatCompactQuantity(balance?.balanceKg ?? value)} Kg'
                        : _formatRupiah(balance?.balanceRupiah ?? value),
                    cashAmount: _formatRupiah(paidValue),
                    discountAmount: discountValue > 0
                        ? _formatRupiah(discountValue)
                        : '',
                    paymentMethod:
                        context
                            .read<PaymentMethodProvider>()
                            .paymentMethods
                            .where((method) => method.id == paymentMethodId)
                            .map((method) => method.name)
                            .firstOrNull ??
                        'Manual',
                    note: note.text,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'KIRIM KE WHATSAPP',
                  style: TextStyle(fontSize: 11, fontWeight: AppFont.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.ink,
                  side: const BorderSide(color: Color(0xFFD9E2EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: const Text(
                  'Kembali',
                  style: TextStyle(fontSize: 11, fontWeight: AppFont.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit(StateSetter setSheetState) async {
    if (_submitting) return;
    setSheetState(() => _submitting = true);
    try {
      final ok = await context.read<CustomerDepositProvider>().topUp(
        widget.customer.id,
        type: kind,
        value: value,
        totalPaid: _parseAmount(paid.text, true) == 0
            ? value
            : _parseAmount(paid.text, true),
        discountAmount: discountValue,
        paymentMethodId: paymentMethodId ?? '',
        note: note.text,
        requestId: _requestId,
      );
      if (ok && mounted) {
        Navigator.of(context).pop();
        setState(() => done = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _playSuccessSound();
        });
      } else if (mounted) {
        setSheetState(() => _submitting = false);
        final message = context.read<CustomerDepositProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Top up gagal diproses.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setSheetState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Top up gagal diproses. Coba lagi.')),
        );
      }
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(AssetSource('sounds/success_warm.wav'));
    } catch (error) {
      debugPrint('Top up success sound playback failed: $error');
    }
  }
}

class _DecimalLimitInputFormatter extends TextInputFormatter {
  final double maxValue;

  const _DecimalLimitInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (!RegExp(r'^\d*[,.]?\d{0,2}$').hasMatch(newValue.text)) {
      return oldValue;
    }
    final value = double.tryParse(newValue.text.replaceAll(',', '.'));
    if (value == null || value > maxValue) return oldValue;
    return newValue;
  }
}

class _RupiahInputFormatter extends TextInputFormatter {
  final double maxValue;

  const _RupiahInputFormatter({required this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final value = double.tryParse(digits);
    if (value == null || value > maxValue) return oldValue;
    final formatted = _groupThousands(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _groupThousands(String digits) {
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.insert(0, digits.substring(start, end));
    }
    return groups.join('.');
  }
}
