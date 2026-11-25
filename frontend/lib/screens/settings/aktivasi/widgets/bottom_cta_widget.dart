import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class BottomCtaWidget extends StatelessWidget {
  final String totalFormatted;
  final VoidCallback? onPressed; // ✅ Ubah jadi nullable biar bisa disabled
  final String buttonLabel;

  const BottomCtaWidget({
    super.key,
    required this.totalFormatted,
    required this.onPressed,
    this.buttonLabel = 'Lihat Ringkasan & Bayar',
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Logic deteksi apakah tombol aktif atau tidak
    final bool isEnabled = onPressed != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimasi Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  totalFormatted,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFont.w900,
                    // ✅ Kalau disabled, harganya kasih warna agak pudar
                    color: isEnabled ? AppPalette.primary : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // ✅ Gradient dinamis: Abu-abu kalau disabled
                  gradient: isEnabled
                      ? const LinearGradient(
                          colors: [AppPalette.primary, AppPalette.primaryWarm],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    isEnabled ? buttonLabel : 'Pilih Fitur Terlebih Dahulu',
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey.shade600,
                      fontWeight: AppFont.w900,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
