import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner ajakan buka dashboard owner versi desktop di browser.
/// Tap tombol "Buka" → membuka https://ayocuci.co.id/login di browser eksternal.
class DesktopVersionBanner extends StatelessWidget {
  const DesktopVersionBanner({super.key});

  static final Uri _dashboardUrl = Uri.parse('https://ayocuci.co.id/login');

  Future<void> _openDashboard(BuildContext context) async {
    try {
      final ok = await launchUrl(
        _dashboardUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        CustomToast.show(
          context,
          message: 'Tidak bisa membuka dashboard',
          isError: true,
        );
      }
    } catch (_) {
      if (context.mounted) {
        CustomToast.show(
          context,
          message: 'Tidak bisa membuka dashboard',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Samakan lebar dengan OperationalGrid (margin horizontal 18).
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.desktop_windows_rounded,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tersedia Versi Desktop',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: AppFont.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Akses layanan lebih mudah dari browser',
                  style: TextStyle(fontSize: 11.5, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _openDashboard(context),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.primary,
              backgroundColor: AppPalette.primarySoft,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Buka',
              style: TextStyle(fontSize: 13, fontWeight: AppFont.w700),
            ),
          ),
        ],
      ),
    );
  }
}
