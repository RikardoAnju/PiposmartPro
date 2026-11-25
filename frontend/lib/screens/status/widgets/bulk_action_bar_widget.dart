import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class BulkActionBarWidget extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onProcess;
  // Parameter baru untuk mengontrol visibilitas tombol proses
  final bool showProcessButton;

  const BulkActionBarWidget({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onProcess,
    this.showProcessButton = true, // Default true agar tidak merusak kode lama
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 25,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCount > 0
                    ? "$selectedCount pesanan dipilih"
                    : "Pilih pesanan...",
                style: const TextStyle(
                  fontWeight: AppFont.w700,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text(
                "Batal",
                style: TextStyle(fontWeight: AppFont.w700),
              ),
            ),

            // Logic untuk menyembunyikan tombol proses berdasarkan tab aktif
            if (showProcessButton && selectedCount > 0) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onProcess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Proses",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
