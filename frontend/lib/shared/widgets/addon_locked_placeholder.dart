import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AddonLockedPlaceholder extends StatelessWidget {
  final String title;
  final String message;
  final List<String> features;
  final VoidCallback onActionTap;
  final String actionLabel;
  final String mascotAsset;

  const AddonLockedPlaceholder({
    super.key,
    required this.title,
    required this.message,
    required this.features,
    required this.onActionTap,
    this.actionLabel = 'Lihat Add-On',
    this.mascotAsset = 'assets/maskot/4 1.webp',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppPalette.primaryBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppPalette.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppPalette.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF1F1F1F),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset(
                  mascotAsset,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    features
                        .map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FeatureRow(label: feature),
                          ),
                        )
                        .toList()
                      ..removeLast(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onActionTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
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

class _FeatureRow extends StatelessWidget {
  final String label;

  const _FeatureRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: AppPalette.primary,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w500,
            color: Color(0xFF454545),
          ),
        ),
      ],
    );
  }
}
