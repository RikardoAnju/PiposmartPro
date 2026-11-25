import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:flutter/material.dart';

class WorkLogActivityCard extends StatelessWidget {
  const WorkLogActivityCard({
    super.key,
    required this.assetPath,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    this.showDivider = true,
    this.onTap,
  });

  final String assetPath;
  final IconData? icon;
  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: AppBorders.card,
            boxShadow: AppShadows.cardSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: icon != null
                      ? Icon(icon, color: color, size: 21)
                      : AppAssetImage(
                          assetPath,
                          width: 30,
                          height: 30,
                          cacheWidth: 256,
                          cacheHeight: 256,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count aktivitas',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: AppFont.w700,
                ),
              ),
              if (showDivider)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.muted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
