import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class AttendanceEmptyState extends StatelessWidget {
  final VoidCallback onConfigure;
  const AttendanceEmptyState({super.key, required this.onConfigure});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/maskot/outlet_pro_mascot.png',
            width: 166,
            height: 166,
          ),
          const SizedBox(height: 18),
          const Text(
            'Selamat Datang di Absensi!',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: AppFont.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Atur jadwal kerja karyawan sebelum mulai\nmenggunakan fitur absensi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onConfigure,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'ATUR SEKARANG',
                style: TextStyle(fontSize: 11, fontWeight: AppFont.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
