import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralPageSkeleton extends StatefulWidget {
  const ReferralPageSkeleton({super.key});

  @override
  State<ReferralPageSkeleton> createState() => _ReferralPageSkeletonState();
}

class _ReferralPageSkeletonState extends State<ReferralPageSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 14,
    double radius = 6,
  }) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 0.5),
      ),
      child: child,
    );
  }

  // 1. Skeleton ReferralCodeCard — putih, label kecil + kode + icon copy
  Widget _skCodeCard() {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 90, height: 11), // label "REFERRAL CODE"
                const SizedBox(height: 8),
                _shimmerBox(width: 130, height: 20, radius: 6), // kode Z3ZKEG
              ],
            ),
          ),
          const SizedBox(width: 12),
          _shimmerBox(width: 28, height: 28, radius: 6), // icon copy
        ],
      ),
    );
  }

  // 2. Skeleton ExpandCard — label + chevron
  Widget _skExpandCard({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: _card(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(child: _shimmerBox(width: 160, height: 14)),
            const SizedBox(width: 12),
            _shimmerBox(width: 18, height: 18, radius: 4),
          ],
        ),
      ),
    );
  }

  // 3. Skeleton MenuTile — icon bulat merah + label + chevron
  Widget _skMenuTile({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: _card(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // icon placeholder (kotak rounded warna salmon muda)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _shimmerBox(width: 100, height: 14)),
            const SizedBox(width: 12),
            _shimmerBox(width: 18, height: 18, radius: 4), // chevron
          ],
        ),
      ),
    );
  }

  // 4. Skeleton baris menu di dalam kartu Riwayat Undangan (icon 32 rounded +
  //    label + chevron) — meniru _Row di referral_invitation_history_card.
  Widget _skHistoryRow() {
    return Padding(
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
          ),
          const SizedBox(width: 12),
          Expanded(child: _shimmerBox(width: 110, height: 13)),
          const SizedBox(width: 12),
          _shimmerBox(width: 18, height: 18, radius: 4), // chevron
        ],
      ),
    );
  }

  // 5. Skeleton kartu "Riwayat Undangan" — judul + subjudul di tengah, divider,
  //    lalu 3 baris menu (Komisi Saya, Owner Direkrut, Top Rank Owner).
  Widget _skInvitationHistoryCard() {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _shimmerBox(width: 130, height: 14)), // "Riwayat Undangan"
          const SizedBox(height: 8),
          Center(child: _shimmerBox(width: 200, height: 11)), // periode
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          _skHistoryRow(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _skHistoryRow(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _skHistoryRow(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _skCodeCard(), // ReferralCodeCard
        _skExpandCard(), // Cara Dapat Bonus Referral
        _skExpandCard(), // Ketentuan Reward
        _skInvitationHistoryCard(), // Riwayat Undangan (3 baris)
        _skExpandCard(), // Skema Komisi Top Up
        _skMenuTile(opacity: 0.6), // Syarat dan Ketentuan
      ],
    );
  }
}
