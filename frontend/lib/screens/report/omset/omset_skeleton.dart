import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OmsetSkeleton extends StatefulWidget {
  const OmsetSkeleton({super.key});

  @override
  State<OmsetSkeleton> createState() => _OmsetSkeletonState();
}

class _OmsetSkeletonState extends State<OmsetSkeleton>
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB), width: 0.5),
      ),
      child: child,
    );
  }

  // Skeleton TotalOmsetCard (merah)
  Widget _skTotalOmset() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 110,
                height: 13,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment(_anim.value - 1, 0),
                    end: Alignment(_anim.value + 1, 0),
                    colors: const [
                      Color(0x55FFFFFF),
                      Color(0x88FFFFFF),
                      Color(0x55FFFFFF),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 160,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment(_anim.value - 1, 0),
                    end: Alignment(_anim.value + 1, 0),
                    colors: const [
                      Color(0x55FFFFFF),
                      Color(0x88FFFFFF),
                      Color(0x55FFFFFF),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 11,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment(_anim.value - 1, 0),
                    end: Alignment(_anim.value + 1, 0),
                    colors: const [
                      Color(0x44FFFFFF),
                      Color(0x77FFFFFF),
                      Color(0x44FFFFFF),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Skeleton TotalTransaksiRow
  Widget _skTransaksi() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _shimmerBox(width: 90, height: 13),
          _shimmerBox(width: 50, height: 18, radius: 10),
        ],
      ),
    );
  }

  // Skeleton header row (judul + filter button)
  Widget _skHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _shimmerBox(width: 100, height: 14),
              const SizedBox(width: 8),
              _shimmerBox(width: 60, height: 20, radius: 20),
            ],
          ),
          _shimmerBox(width: 70, height: 32, radius: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _skTotalOmset(),
        _skTransaksi(),
        _skHeaderRow(),
        const OmsetTileSkeleton(),
        const OmsetTileSkeleton(),
        const OmsetTileSkeleton(),
        const OmsetTileSkeleton(),
        const OmsetTileSkeleton(opacity: 0.6),
      ],
    );
  }
}

class OmsetTileSkeleton extends StatefulWidget {
  final double opacity;
  const OmsetTileSkeleton({super.key, this.opacity = 1.0});

  @override
  State<OmsetTileSkeleton> createState() => _OmsetTileSkeletonState();
}

class _OmsetTileSkeletonState extends State<OmsetTileSkeleton>
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

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: 100, height: 14),
                  const SizedBox(height: 8),
                  _shimmerBox(width: 60, height: 12),
                ],
              ),
            ),
            _shimmerBox(width: 80, height: 20),
          ],
        ),
      ),
    );
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
}
