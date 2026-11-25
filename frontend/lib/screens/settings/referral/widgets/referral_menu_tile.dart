import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;

  final VoidCallback? onTap;

  const ReferralMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    this.onTap,
  });

  static const Color kPrimary = AppPalette.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              // Badge (optional)
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCCCCCC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
