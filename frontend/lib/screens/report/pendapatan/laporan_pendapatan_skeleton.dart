import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LaporanPendapatanSkeleton extends StatefulWidget {
  const LaporanPendapatanSkeleton({super.key});

  @override
  State<LaporanPendapatanSkeleton> createState() =>
      _LaporanPendapatanSkeletonState();
}

class _LaporanPendapatanSkeletonState extends State<LaporanPendapatanSkeleton>
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

  Widget _box({
    double width = double.infinity,
    double height = 13,
    double radius = 6,
    bool white = false,
  }) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: white
                ? const [
                    Color(0x4DFFFFFF),
                    Color(0x80FFFFFF),
                    Color(0x4DFFFFFF),
                  ]
                : const [
                    Color(0xFFE8E8E8),
                    Color(0xFFF5F5F5),
                    Color(0xFFE8E8E8),
                  ],
          ),
        ),
      ),
    );
  }

  // TotalPendapatanCard skeleton
  Widget _skTotalCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppPalette.danger, Color(0xFFFF9A57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 120, height: 13, white: true),
          const SizedBox(height: 16),
          _box(width: 190, height: 32, white: true),
          const Spacer(),
          _box(width: 140, height: 30, radius: 20, white: true),
        ],
      ),
    );
  }

  // Header row
  Widget _skHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _box(width: 110, height: 13),
          _box(width: 78, height: 34, radius: 10),
        ],
      ),
    );
  }

  // DayTile collapsed
  Widget _skDayTileCollapsed({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _box(width: 140, height: 13),
            Row(
              children: [
                _box(width: 80, height: 13),
                const SizedBox(width: 6),
                _box(width: 18, height: 18, radius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // DayTile expanded — tampilkan breakdown
  Widget _skDayTileExpanded() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _box(width: 140, height: 13),
                Row(
                  children: [
                    _box(width: 80, height: 13),
                    const SizedBox(width: 6),
                    _box(width: 18, height: 18, radius: 4),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              children: [
                _skBreakdownItem(nameWidth: 100),
                const SizedBox(height: 12),
                _skBreakdownItem(nameWidth: 80),
                const SizedBox(height: 12),
                _skBreakdownItem(nameWidth: 90),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skBreakdownItem({required double nameWidth}) {
    return Row(
      children: [
        _box(width: 32, height: 32, radius: 8),
        const SizedBox(width: 10),
        Expanded(child: _box(height: 13)),
        const SizedBox(width: 10),
        _box(width: nameWidth, height: 13),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _skTotalCard(),
        _skHeaderRow(),
        _skDayTileExpanded(),
        _skDayTileCollapsed(),
        _skDayTileCollapsed(),
        _skDayTileCollapsed(opacity: 0.5),
        const SizedBox(height: 32),
      ],
    );
  }
}
