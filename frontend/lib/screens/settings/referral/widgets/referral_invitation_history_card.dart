import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralInvitationHistoryCard extends StatelessWidget {
  final String periodText;
  final VoidCallback onKomisiSayaTap;
  final VoidCallback onOwnerDirekrutTap;
  final VoidCallback onTopRankTap;
  final int recruitedOwners;
  final String? ownerBadge;

  const ReferralInvitationHistoryCard({
    super.key,
    required this.periodText,
    required this.onKomisiSayaTap,
    required this.onOwnerDirekrutTap,
    required this.onTopRankTap,
    required this.recruitedOwners,
    this.ownerBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Riwayat Undangan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w700,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  periodText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          _Row(
            icon: Icons.card_giftcard_rounded,
            title: 'Komisi Saya',
            onTap: onKomisiSayaTap,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _Row(
            icon: Icons.group_add_rounded,
            title: 'Owner Direkrut',
            badge: ownerBadge,
            trailingCount: recruitedOwners,
            onTap: onOwnerDirekrutTap,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _Row(
            icon: Icons.emoji_events_rounded,
            title: 'Top Rank Owner',
            onTap: onTopRankTap,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final int? trailingCount;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.trailingCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppPalette.primary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: AppFont.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.primary,
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
            ] else if (trailingCount != null) ...[
              Text(
                trailingCount.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.w600,
                  color: AppPalette.muted,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
