// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/config/feature_flags.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart'; // Dibutuhkan untuk inputFormatters
import 'package:provider/provider.dart';
import '../../../../../data/models/metode_pembayaran_model.dart';
import '../../../../../providers/metode_pembayaran_provider.dart';
import '../../../../../shared/widgets/custom_textfield.dart';
import '../../../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ModalAddPayment extends StatefulWidget {
  final PaymentMethod? existing;

  const ModalAddPayment({super.key, this.existing});

  @override
  State<ModalAddPayment> createState() => _ModalAddPaymentState();
}

class _ModalAddPaymentState extends State<ModalAddPayment> {
  final _formKey = GlobalKey<FormState>();

  final _accNumController = TextEditingController();
  final _accHolderController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCategory = "Transfer";
  String _selectedQrisType = "QRIS Outlet Statis";
  String? _selectedBank; // Selected bank dari dropdown
  String? _selectedEwallet; // Selected ewallet dari dropdown
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _categories = ["Transfer", "E-Wallet", "QRIS"];

  // Dropdown options untuk Bank
  final List<String> _bankOptions = [
    "BCA",
    "BNI",
    "BRI",
    "BSI",
    "CIMB",
    "MANDIRI",
  ];

  // Dropdown options untuk E-Wallet
  final List<String> _ewalletOptions = [
    "DANA",
    "GOPAY",
    "LINK AJA",
    "OVO",
    "SEABANK",
    "SHOPEE PAY",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _selectedCategory = e.category;
      if (FeatureFlags.nobuQrisEnabled && e.isNobu) {
        _selectedQrisType = "QRIS Nobu";
      }
      _isActive = e.status == 1;

      // Set selected bank atau ewallet dari data existing
      if (e.category == "Transfer" && e.bankName != null) {
        _selectedBank = _bankOptions.contains(e.bankName!.toUpperCase())
            ? e.bankName!.toUpperCase()
            : null;
      }

      if (e.category == "E-Wallet" && e.ewalletProvider != null) {
        _selectedEwallet =
            _ewalletOptions.contains(e.ewalletProvider!.toUpperCase())
            ? e.ewalletProvider!.toUpperCase()
            : null;
      }

      _accNumController.text = e.accountNumber ?? '';
      _accHolderController.text = e.accountHolder ?? '';
      _phoneController.text = e.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _accNumController.dispose();
    _accHolderController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Validasi nama pemilik (WAJIB untuk Transfer dan E-Wallet, OPSIONAL untuk QRIS)
    if (_selectedCategory != "QRIS" &&
        _accHolderController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        message: "Nama Pemilik Rekening / Akun wajib diisi",
        isError: true,
      );
      return;
    }

    // Validasi khusus untuk dropdown
    if (_selectedCategory == "Transfer" && _selectedBank == null) {
      CustomToast.show(
        context,
        message: "Silahkan pilih Bank terlebih dahulu",
        isError: true,
      );
      return;
    }

    if (_selectedCategory == "E-Wallet" && _selectedEwallet == null) {
      CustomToast.show(
        context,
        message: "Silahkan pilih E-Wallet terlebih dahulu",
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String generatedName = "";
      String generatedDesc = "";

      // Logika Auto-Generate
      if (_selectedCategory == "Transfer") {
        generatedName = "$_selectedBank - TRANSFER";
        generatedDesc = "$_selectedBank ${_accHolderController.text.trim()}";
      } else if (_selectedCategory == "E-Wallet") {
        generatedName = "$_selectedEwallet - E-WALLET";
        generatedDesc = "PEMBAYARAN VIA $_selectedEwallet";
      } else if (_selectedCategory == "QRIS") {
        generatedName = _selectedQrisType == "QRIS Nobu" ? "QRIS Nobu" : "QRIS";
        generatedDesc = _selectedQrisType == "QRIS Nobu"
            ? "Pembayaran QRIS otomatis via Nobu"
            : "Pembayaran QRIS outlet statis";
      }

      final Map<String, dynamic> payload = {
        "name": generatedName,
        "description": generatedDesc,
        "category": _selectedCategory,
        "is_active": _isActive ? 1 : 0, // Convert boolean ke integer
        "status": _isActive ? 1 : 0, // Tambahkan field status juga
      };
      if (_selectedCategory == "QRIS") {
        payload["qris_type"] = _selectedQrisType;
      }

      // Tambahkan account_holder hanya untuk Transfer dan E-Wallet (wajib) atau QRIS jika diisi
      if (_selectedCategory == "Transfer" || _selectedCategory == "E-Wallet") {
        payload["account_holder"] = _accHolderController.text.trim();
      } else if (_selectedCategory == "QRIS" &&
          _accHolderController.text.trim().isNotEmpty) {
        payload["account_holder"] = _accHolderController.text.trim();
      }

      if (_selectedCategory == "Transfer") {
        payload.addAll({
          "bank_name": _selectedBank,
          "account_number": _accNumController.text.trim(),
        });
      } else if (_selectedCategory == "E-Wallet") {
        payload.addAll({
          "ewallet_provider": _selectedEwallet,
          "phone_number": _phoneController.text.trim(),
        });
      }
      // QRIS tidak perlu field tambahan

      // Debug: Print payload
      debugPrint("📤 Payload yang dikirim: $payload");
      debugPrint(
        "📝 Mode: ${widget.existing?.id != null ? 'UPDATE' : 'CREATE'}",
      );

      final res = await context.read<PaymentMethodProvider>().saveMethod(
        payload,
        id: widget.existing?.id,
      );

      debugPrint("📥 Response: $res");

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['success'] == true) {
          CustomToast.show(
            context,
            message: res['message'] ?? 'Berhasil disimpan',
          );
          Navigator.pop(context);
        } else {
          CustomToast.show(
            context,
            message: res['message'] ?? 'Terjadi kesalahan',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error di _handleSave: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(
          context,
          message: "Error: ${e.toString()}",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusToggle(),
                      const SizedBox(height: 20),

                      _buildDropdownLabel("Pilih Kategori Metode Pembayaran"),
                      _buildSimpleDropdown(
                        value: _selectedCategory,
                        items: _categories,
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val!;
                            // Reset selected bank/ewallet saat ganti kategori
                            _selectedBank = null;
                            _selectedEwallet = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      if (_selectedCategory == "Transfer") ...[
                        _buildDropdownLabel("Pilih Bank"),
                        _buildSimpleDropdown(
                          value: _selectedBank,
                          items: _bankOptions,
                          hint: "PILIH BANK",
                          onChanged: (val) =>
                              setState(() => _selectedBank = val),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _accNumController,
                          labelText: "Nomor Rekening",
                          hintText: "MASUKKAN NOMOR REKENING",
                          keyboardType: TextInputType.number,
                          isRequired: true,
                          fillColor: const Color(0xFFF9F9F9),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _accHolderController,
                          labelText: "Nama Pemilik Rekening",
                          hintText: "MASUKKAN NAMA LENGKAP",
                          isRequired: true,
                          fillColor: const Color(0xFFF9F9F9),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                        ),
                      ],

                      if (_selectedCategory == "E-Wallet") ...[
                        _buildDropdownLabel("Pilih E-Wallet"),
                        _buildSimpleDropdown(
                          value: _selectedEwallet,
                          items: _ewalletOptions,
                          hint: "PILIH E-WALLET",
                          onChanged: (val) =>
                              setState(() => _selectedEwallet = val),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _phoneController,
                          labelText: "Nomor Handphone",
                          hintText: "CONTOH: 08123456789",
                          keyboardType: TextInputType.phone,
                          isRequired: true,
                          fillColor: const Color(0xFFF9F9F9),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _accHolderController,
                          labelText: "Nama Pemilik Akun",
                          hintText: "MASUKKAN NAMA LENGKAP",
                          isRequired: true,
                          fillColor: const Color(0xFFF9F9F9),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                        ),
                      ],

                      if (_selectedCategory == "QRIS") ...[
                        _buildDropdownLabel("Pilih Jenis QRIS"),
                        _buildSimpleDropdown(
                          value: _selectedQrisType,
                          items: const [
                            "QRIS Outlet Statis",
                            if (FeatureFlags.nobuQrisEnabled) "QRIS Nobu",
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedQrisType = val);
                            }
                          },
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              _selectedQrisType == "QRIS Nobu"
                                  ? "QRIS Nobu menghasilkan QR dinamis saat transaksi"
                                  : "QRIS outlet statis hanya untuk pencatatan pembayaran",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.existing != null
              ? "EDIT METODE PEMBAYARAN"
              : "TAMBAH METODE PEMBAYARAN",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: AppFont.w900,
            color: Color(0xFF2C3E50),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[100],
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );

  Widget _buildStatusToggle() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "AKTIF",
        style: TextStyle(
          fontSize: 16,
          fontWeight: AppFont.w700,
          color: Color(0xFF2C3E50),
        ),
      ),
      Switch(
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
        activeThumbColor: AppPalette.primary,
        activeTrackColor: AppPalette.primary.withValues(alpha: 0.3),
      ),
    ],
  );

  Widget _buildDropdownLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: AppFont.w600,
        color: Color(0xFF2C3E50),
      ),
    ),
  );

  Widget _buildSimpleDropdown({
    String? value,
    required List<String> items,
    String? hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: hint != null
              ? Text(
                  hint,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                )
              : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e.toUpperCase(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
              "SIMPAN",
              style: TextStyle(
                color: Colors.white,
                fontWeight: AppFont.w900,
                letterSpacing: 1,
              ),
            ),
    ),
  );

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FDF1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CATATAN :",
            style: TextStyle(
              fontSize: 11,
              fontWeight: AppFont.w700,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedCategory == "QRIS"
                ? "• Sistem akan otomatis membuat metode pembayaran QRIS.\n"
                      "• Tidak ada data tambahan yang perlu diisi."
                : _selectedCategory == "Transfer"
                ? "• Sistem akan otomatis membuat nama tampilan berdasarkan Bank yang dipilih.\n"
                      "• Semua field wajib diisi."
                : "• Sistem akan otomatis membuat nama tampilan berdasarkan E-Wallet yang dipilih.\n"
                      "• Semua field wajib diisi.",
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper untuk uppercase formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
