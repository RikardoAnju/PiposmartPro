import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/cairkan_saldo/widgets/bank_picker.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutAccountFormPage extends StatefulWidget {
  final ReferralPayoutAccountModel? existingAccount; // null → tambah baru
  final Future<void> Function({
    required String bankName,
    required String accountNumber,
    required String accountName,
  })
  onSave;
  final Future<void> Function()? onDelete;

  const PayoutAccountFormPage({
    super.key,
    this.existingAccount,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<PayoutAccountFormPage> createState() => _PayoutAccountFormPageState();
}

class _PayoutAccountFormPageState extends State<PayoutAccountFormPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noRekController;
  late final TextEditingController _namaController;
  String? _selectedBank;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedBank = widget.existingAccount?.bankName;
    _noRekController = TextEditingController(
      text: widget.existingAccount?.accountNumber ?? '',
    );
    _namaController = TextEditingController(
      text: widget.existingAccount?.accountName ?? '',
    );
  }

  @override
  void dispose() {
    _noRekController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existingAccount != null;

  Future<void> _pickBank() async {
    final result = await BankPickerPage.show(context, selected: _selectedBank);
    if (result != null) setState(() => _selectedBank = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.onSave(
        bankName: _selectedBank!,
        accountNumber: _noRekController.text.trim(),
        accountName: _namaController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Rekening',
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: const Text('Yakin ingin menghapus rekening ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Edit Rekening' : 'Tambah Rekening',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
        // Tombol hapus di AppBar jika mode edit
        actions: _isEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _loading ? null : _delete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Nama Bank/E-Wallet ──
            _fieldLabel('Nama Bank/E-Wallet'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBank,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedBank != null
                        ? kPrimary
                        : Colors.transparent,
                    width: _selectedBank != null ? 1.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedBank ?? 'Pilih Bank/E-Wallet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedBank != null
                              ? AppFont.w600
                              : AppFont.w400,
                          color: _selectedBank != null
                              ? Colors.black87
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: _selectedBank != null ? kPrimary : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            // Validasi manual bank
            if (_formKey.currentState != null && _selectedBank == null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Pilih bank/e-wallet',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),

            // ── No Rekening ──
            _fieldLabel('No Rekening'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noRekController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(hint: 'No Rekening atau No Hp'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Masukkan nomor rekening'
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Nama Penerima ──
            _fieldLabel('Nama Penerima'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _namaController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'Nama Lengkap Sesuai Rekening',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Masukkan nama penerima'
                  : null,
            ),
            const SizedBox(height: 32),

            // ── Buttons ──
            if (_isEdit) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(fontWeight: AppFont.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _SubmitButton(
                      loading: _loading,
                      label: 'Simpan',
                      onTap: _submit,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _SubmitButton(
                loading: _loading,
                label: 'Tambah Rekening',
                onTap: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text.rich(
    TextSpan(
      text: label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: AppFont.w600,
        color: Colors.black87,
      ),
      children: const [
        TextSpan(
          text: '*',
          style: TextStyle(color: kPrimary),
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: AppFont.w700, fontSize: 15),
              ),
      ),
    );
  }
}
