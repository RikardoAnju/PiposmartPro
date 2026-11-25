import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AnalisaLaporanSkeleton extends StatefulWidget {
  const AnalisaLaporanSkeleton({super.key});

  @override
  State<AnalisaLaporanSkeleton> createState() => _AnalisaLaporanSkeletonState();
}

class _AnalisaLaporanSkeletonState extends State<AnalisaLaporanSkeleton>
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

  Widget _shimmerWhite({
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
                Color(0x4DFFFFFF),
                Color(0x80FFFFFF),
                Color(0x4DFFFFFF),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _skTotalCard() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerWhite(width: 100, height: 12),
              const SizedBox(height: 8),
              _shimmerWhite(width: 180, height: 28),
            ],
          ),
          _shimmerWhite(width: 120, height: 24, radius: 12),
        ],
      ),
    );
  }

  Widget _skKategoriRow() {
    return Row(
      children: [
        Expanded(child: _skInfoCardSkeleton()),
        const SizedBox(width: 12),
        Expanded(child: _skInfoCardSkeleton()),
      ],
    );
  }

  Widget _skInfoCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(width: 60, height: 8),
          const SizedBox(height: 12),
          _shimmerBox(width: 90, height: 14),
        ],
      ),
    );
  }

  Widget _skHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _shimmerBox(width: 130, height: 15),
          _shimmerBox(width: 80, height: 32, radius: 12),
        ],
      ),
    );
  }

  Widget _skTile({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerBox(width: 90, height: 12),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.black12,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerBox(width: 120, height: 14),
                _shimmerBox(width: 100, height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skLihatSelengkapnya() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: _shimmerBox(width: 120, height: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [_skTotalCard(), _skKategoriRow(), _skHeaderRow()],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _skTile(),
              _skTile(),
              _skTile(opacity: 0.6),
              _skLihatSelengkapnya(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}
