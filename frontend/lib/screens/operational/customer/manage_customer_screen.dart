import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/customer/manage_customer_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/core/utils/contact_phone_formatter.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // v2.x.x
import '../../../../providers/customer_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class _CustomerNameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = newValue.text
        .replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s.,:/@+\-()&]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (sanitized == newValue.text) return newValue;
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }
}

class ManageCustomerScreen extends StatefulWidget {
  final Customer? existingCustomer;
  final String? initialName;
  final String? initialPhone;

  const ManageCustomerScreen({
    super.key,
    this.existingCustomer,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<ManageCustomerScreen> createState() => _ManageCustomerScreenState();
}

class _ManageCustomerScreenState extends State<ManageCustomerScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthDateController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _isEditMode = false;

  String _resolveSaveMessage(Map<String, dynamic> response) {
    final rawMessage = response['message']?.toString().trim();
    if (rawMessage == null || rawMessage.isEmpty) {
      return 'Terjadi kesalahan saat menyimpan pelanggan';
    }

    final normalized = rawMessage.toLowerCase();
    final isDuplicatePhone =
        normalized.contains('nomor hp') &&
        (normalized.contains('terdaftar') || normalized.contains('digunakan'));

    if (isDuplicatePhone) {
      return _isEditMode
          ? 'Nomor WhatsApp ini sudah dipakai pelanggan lain di outlet ini'
          : 'Nomor WhatsApp sudah terdaftar sebagai pelanggan di outlet ini';
    }

    return rawMessage;
  }

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingCustomer != null;
    if (_isEditMode) {
      final c = widget.existingCustomer!;
      _nameController.text = sanitizeCustomerName(c.name);
      _phoneController.text = c.phone;
      _addressController.text = c.address;
      _selectedGender = c.isWanita
          ? "Wanita"
          : c.isPria
          ? "Pria"
          : null;

      if (c.birthDate != null) {
        _selectedBirthDate = c.birthDate;
        _birthDateController.text = DateFormat(
          'dd/MM/yyyy',
        ).format(c.birthDate!);
      }
    } else {
      if (widget.initialName != null) {
        _nameController.text = sanitizeCustomerName(widget.initialName!);
      }
      if (widget.initialPhone != null) {
        _phoneController.text = widget.initialPhone!;
      }
    }
  }

  Future<void> _importFromContacts() async {
    HapticFeedback.mediumImpact();
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (status == PermissionStatus.granted ||
          status == PermissionStatus.limited) {
        final contact = await FlutterContacts.native.showPicker(
          properties: const {ContactProperty.name, ContactProperty.phone},
        );

        if (contact != null) {
          final phoneNumber = pickContactPhoneNumber(contact.phones);

          setState(() {
            _nameController.text = sanitizeCustomerName(
              contact.displayName ?? '',
            );
            _phoneController.text = phoneNumber;
          });

          CustomToast.show(
            context,
            message: phoneNumber.isEmpty
                ? "Kontak tidak punya nomor WhatsApp"
                : "Kontak berhasil dimuat",
            isError: phoneNumber.isEmpty,
          );
        }
      } else {
        CustomToast.show(
          context,
          message: "Akses kontak ditolak",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("Error import contact: $e");
      CustomToast.show(
        context,
        message: "Gagal mengambil kontak",
        isError: true,
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthDate ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppPalette.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _handleSave() async {
    final auth = context.read<AuthProvider>();
    final action = _isEditMode ? 'update' : 'create';
    if (!auth.canAccess('pelanggan', action)) {
      CustomToast.show(
        context,
        message: 'Anda tidak memiliki izin untuk menyimpan pelanggan.',
        isError: true,
      );
      return;
    }
    final customerProvider = context.read<CustomerProvider>();

    final customerName = sanitizeCustomerName(_nameController.text);

    if (customerName.isEmpty) {
      CustomToast.show(
        context,
        message: "Nama lengkap wajib diisi",
        isError: true,
      );
      return;
    }

    if (_selectedGender == null) {
      CustomToast.show(context, message: "Pilih jenis kelamin", isError: true);
      return;
    }

    final payload = {
      "nama": customerName,
      "no_hp": _phoneController.text.trim(),
      "jenis_kelamin": _selectedGender == "Wanita" ? "P" : "L",
      "tanggal_lahir": _selectedBirthDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
          : "",
      "alamat": _addressController.text.trim(),
    };

    Map<String, dynamic> res;
    if (_isEditMode) {
      res = await customerProvider.updateCustomer(
        widget.existingCustomer!.id,
        payload,
      );
    } else {
      res = await customerProvider.saveCustomer(payload);
    }
    bool success = res['success'];

    if (success && mounted) {
      Navigator.pop(context, res['data']);
      return;
    }

    if (mounted) {
      CustomToast.show(
        context,
        message: _resolveSaveMessage(res),
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<CustomerProvider>().isLoading;
    final action = _isEditMode ? 'update' : 'create';
    final canManage = context.select<AuthProvider, bool>(
      (auth) => auth.canAccess('pelanggan', action),
    );

    if (!canManage) {
      return AppScaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: Text(_isEditMode ? 'Edit Pelanggan' : 'Pelanggan Baru'),
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 52,
                  color: AppPalette.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'Anda tidak memiliki izin untuk mengelola pelanggan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? "Edit Pelanggan" : "Pelanggan Baru",
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            CustomTextField(
              controller: _nameController,
              labelText: "Nama Lengkap",
              hintText: "Nama pelanggan",
              isRequired: true,
              fillColor: const Color(0xFFF9F9F9),
              inputFormatters: [_CustomerNameInputFormatter()],
            ),
            const SizedBox(height: 20),

            // --- FIELD WHATSAPP DENGAN TOMBOL IMPOR DI SAMPING ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _phoneController,
                    labelText: "Nomor WhatsApp (Opsional)",
                    hintText: "Boleh dikosongkan",
                    isRequired: false,
                    keyboardType: TextInputType.phone,
                    fillColor: const Color(0xFFF9F9F9),
                  ),
                ),
                if (!_isEditMode) ...[
                  const SizedBox(width: 12),
                  _buildImportButton(),
                ],
              ],
            ),

            const SizedBox(height: 20),
            _buildLabel("Jenis Kelamin", isRequired: true),
            Row(
              children: [
                _buildGenderCard("Pria", Icons.male_rounded),
                const SizedBox(width: 15),
                _buildGenderCard("Wanita", Icons.female_rounded),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _selectBirthDate,
              child: AbsorbPointer(
                child: CustomTextField(
                  controller: _birthDateController,
                  labelText: "Tanggal Lahir (Opsional)",
                  hintText: "Pilih tanggal",
                  prefixIcon: const Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                  ),
                  fillColor: const Color(0xFFF9F9F9),
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _addressController,
              labelText: "Alamat (Opsional)",
              hintText: "Alamat lengkap...",
              maxLines: 3,
              fillColor: const Color(0xFFF9F9F9),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: AppCircularLoader(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditMode ? "SIMPAN PERUBAHAN" : "TAMBAH PELANGGAN",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return Container(
      height: 56, // Menyesuaikan tinggi CustomTextField standar
      width: 56,
      margin: const EdgeInsets.only(
        bottom: 2,
      ), // Halus buat alignment shadow container sebelah
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _importFromContacts,
          borderRadius: BorderRadius.circular(18),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.contact_phone_rounded,
                color: AppPalette.primary,
                size: 22,
              ),
              SizedBox(height: 2),
              Text(
                "Impor",
                style: TextStyle(color: AppPalette.primary, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(String label, IconData icon) {
    bool isSelected = _selectedGender == label;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedGender = label);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppPalette.primary : const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppPalette.primary : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          if (isRequired)
            const Text("*", style: TextStyle(color: AppPalette.primary)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
          ),
        ],
      ),
    );
  }
}
