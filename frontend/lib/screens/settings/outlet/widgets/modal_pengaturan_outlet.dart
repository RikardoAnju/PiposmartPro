// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/custom_toast.dart'; // Gunakan CustomToast
import 'package:ayocucinew/core/theme/app_palette.dart';

class ModalPengaturanOutlet extends StatefulWidget {
  final bool initialSkipProses;

  const ModalPengaturanOutlet({super.key, this.initialSkipProses = false});

  @override
  State<ModalPengaturanOutlet> createState() => _ModalPengaturanOutletState();
}

class _ModalPengaturanOutletState extends State<ModalPengaturanOutlet> {
  bool _skipProses = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi dari data provider jika tersedia, jika tidak gunakan parameter widget
    final profile = context.read<AppProvider>().outlet;
    if (profile != null) {
      _skipProses = profile.skipProses == 1;
    } else {
      _skipProses = widget.initialSkipProses;
    }
  }

  Future<void> _savePengaturan() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<AppProvider>();

      // Hit API Update Profile dengan parameter skipProses saja (Partial Update)
      // Mengirim 1 untuk aktif, 0 untuk tidak aktif
      final result = await provider.updateOutletProfile(
        skipProses: _skipProses ? 1 : 0,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          CustomToast.show(
            context,
            message: "Pengaturan alur laundry berhasil disimpan",
          );
          Navigator.pop(context, _skipProses);
        } else {
          CustomToast.show(
            context,
            message: result['message'] ?? "Gagal menyimpan pengaturan",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.show(
          context,
          message: "Terjadi kesalahan sistem",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            24,
          ), // Radius disesuaikan dengan tema pendaftaran
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pengaturan Alur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Info Box (Penjelasan fitur)
              const Text(
                "Skip Tahapan Proses",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Jika diaktifkan, transaksi akan langsung menuju status 'Selesai' tanpa melalui tahap Proses dan Siap Diambil.",
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Toggle Container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _skipProses
                      ? const Color(0xFFFFE4E1).withValues(alpha: 0.5)
                      : const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _skipProses
                        ? AppPalette.primary.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _skipProses ? 'Fitur Aktif' : 'Fitur Tidak Aktif',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w700,
                        color: _skipProses ? AppPalette.primary : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: _skipProses,
                      onChanged: (value) => setState(() => _skipProses = value),
                      activeColor: AppPalette.primary,
                      activeTrackColor: AppPalette.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePengaturan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: AppCircularLoader(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SIMPAN PERUBAHAN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.w700,
                            color: Colors.white,
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
