import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class ReferralPromoTiles extends StatelessWidget {
  final int bonusPercent;

  const ReferralPromoTiles({super.key, required this.bonusPercent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -68,
            top: 120,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.98,
                child: Image.asset(
                  'assets/maskot/referral_hero_mascot.png',
                  width: 250,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 90, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referral',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: AppFont.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 220,
                  child: Text(
                    'UNDANG TEMAN\nDAPAT JUTAAN RUPIAH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      height: 1.0,
                      fontWeight: AppFont.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const SizedBox(
                  width: 190,
                  child: Text(
                    'Semakin banyak teman bergabung\nsemakin besar hadiah untukmu.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      height: 1.22,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ReferralBonusTile(percent: bonusPercent),
                const SizedBox(height: 8),
                const _ReferralFlowTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralFlowTile extends StatelessWidget {
  const _ReferralFlowTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0E2).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _FlowStep(
              icon: Icons.link_rounded,
              label: 'Bagikan\nkode kamu',
            ),
          ),
          _FlowArrow(),
          Expanded(
            child: _FlowStep(
              icon: Icons.people_alt_rounded,
              label: 'Teman daftar &\ntop up pertama',
            ),
          ),
          _FlowArrow(),
          Expanded(
            child: _FlowStep(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Kamu dapat\nbonus',
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FlowStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppPalette.primary, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.15,
            fontWeight: AppFont.w500,
            color: Color(0xFF222222),
          ),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: Color(0xFFFF8E6A),
        size: 16,
      ),
    );
  }
}

class _ReferralBonusTile extends StatelessWidget {
  final int percent;

  const _ReferralBonusTile({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0E0).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE0CC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dapatkan Bonus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w800,
                    height: 1.0,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: AppFont.w900,
                    height: 1.0,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'dari top up pertama\nteman kamu!',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
