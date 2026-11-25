// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../data/models/item_model.dart';
import '../../../../../providers/item_provider.dart';
import '../../../../../shared/widgets/custom_textfield.dart';
import '../../../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ModalAddItem extends StatefulWidget {
  final ItemLaundry? existing;
  const ModalAddItem({super.key, this.existing});

  @override
  State<ModalAddItem> createState() => _ModalAddItemState();
}

class _ModalAddItemState extends State<ModalAddItem> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  bool _isLoading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _namaController.text = widget.existing!.nama;
      _isActive = widget.existing!.status == 1;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await context.read<ItemProvider>().saveItem(
      nama: _namaController.text.trim().toUpperCase(),
      id: widget.existing?.id,
      status: _isActive ? 1 : 0,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success']) {
        CustomToast.show(context, message: res['message']);
        Navigator.pop(context);
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (widget.existing != null) ...[
                _buildStatusToggle(),
                const SizedBox(height: 20),
              ],
              CustomTextField(
                controller: _namaController,
                labelText: "NAMA ITEM",
                hintText: "CONTOH: BAJU / CELANA / SPREI",
                isRequired: true,
                fillColor: const Color(0xFFF9F9F9),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        widget.existing != null ? "EDIT ITEM" : "TAMBAH ITEM",
        style: const TextStyle(fontSize: 16, fontWeight: AppFont.w900),
      ),
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close, size: 22),
        style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
      ),
    ],
  );

  Widget _buildStatusToggle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: _isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _isActive ? "STATUS: AKTIF" : "STATUS: NON-AKTIF",
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFont.w700,
            color: _isActive ? Colors.green[700] : Colors.red[700],
          ),
        ),
        Switch(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          activeColor: AppPalette.primary,
        ),
      ],
    ),
  );

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
}

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
