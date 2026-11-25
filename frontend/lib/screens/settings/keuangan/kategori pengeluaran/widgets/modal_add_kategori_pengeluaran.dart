import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/kategori_pengeluaran_provider.dart';
import '../../../../../data/models/kategori_pengeluaran_model.dart';
import '../../../../../shared/widgets/custom_toast.dart';
import '../../../../../shared/widgets/custom_textfield.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ModalAddKategoriPengeluaran extends StatefulWidget {
  final KategoriPengeluaran? existing;
  const ModalAddKategoriPengeluaran({super.key, this.existing});

  @override
  State<ModalAddKategoriPengeluaran> createState() =>
      _ModalAddKategoriPengeluaranState();
}

class _ModalAddKategoriPengeluaranState
    extends State<ModalAddKategoriPengeluaran> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.kategori;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<KategoriPengeluaranProvider>();

    final namaKategori = _nameController.text.trim();
    final normalizedName = namaKategori.toLowerCase();
    final isDuplicateName = provider.kategoriList.any((item) {
      final isCurrentItem =
          widget.existing != null && item.id == widget.existing!.id;
      return !isCurrentItem &&
          item.kategori.trim().toLowerCase() == normalizedName;
    });

    if (isDuplicateName) {
      CustomToast.show(
        context,
        message: 'Nama kategori ini sudah ada. Pakai nama lain ya.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = {"kategori": namaKategori};

    final Map<String, dynamic> res;
    if (widget.existing != null) {
      res = await provider.updateKategoriPengeluaran(
        widget.existing!.id,
        payload,
      );
    } else {
      res = await provider.createKategoriPengeluaran(payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? "Edit Kategori" : "Kategori Baru",
                    style: const TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 18,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFF5F5F5),
                      child: Icon(Icons.close, size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              CustomTextField(
                controller: _nameController,
                labelText: "Nama Kategori",
                hintText: "Contoh: Listrik, Gaji, Sabun",
                isRequired: true,
                fillColor: const Color(0xFFF9F9F9),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: AppCircularLoader(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.existing != null
                              ? "UPDATE KATEGORI"
                              : "SIMPAN KATEGORI",
                          style: const TextStyle(
                            fontWeight: AppFont.w900,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
