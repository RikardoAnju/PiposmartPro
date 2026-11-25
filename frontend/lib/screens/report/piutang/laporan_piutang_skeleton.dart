import 'package:flutter/material.dart';


class LaporanPiutangSkeleton extends StatefulWidget {
  const LaporanPiutangSkeleton({super.key});

  @override
  State<LaporanPiutangSkeleton> createState() => _LaporanPiutangSkeletonState();
}

class _LaporanPiutangSkeletonState extends State<LaporanPiutangSkeleton>
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
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
        ),
        child: child,
      ),
    );
  }

  // PiutangSummaryCard skeleton
  Widget _skSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Jatuh tempo
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 80, height: 11),
                      const SizedBox(height: 8),
                      _box(width: 110, height: 18),
                      const SizedBox(height: 6),
                      _box(width: 60, height: 11),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Belum jatuh tempo
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 90, height: 11),
                      const SizedBox(height: 8),
                      _box(width: 100, height: 18),
                      const SizedBox(height: 6),
                      _box(width: 55, height: 11),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 90, height: 12),
              _box(width: 120, height: 16),
            ],
          ),
        ],
      ),
    );
  }

  // Search bar + filter button
  Widget _skSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _box(height: 42, radius: 10)),
          const SizedBox(width: 8),
          _box(width: 42, height: 42, radius: 10),
        ],
      ),
    );
  }

  // Tab bar
  Widget _skTabBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(child: _box(height: 34, radius: 8)),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(opacity: 0.4, child: _box(height: 34, radius: 8)),
          ),
        ],
      ),
    );
  }

  // Header detail row
  Widget _skDetailHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _box(width: 100, height: 14),
          _box(width: 70, height: 12),
        ],
      ),
    );
  }

  // PiutangTile skeleton
  Widget _skTile({required double nameWidth, required double nominalWidth, double opacity = 1.0}) {
    return _card(
      opacity: opacity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: nameWidth, height: 14),
                  const SizedBox(height: 7),
                  _box(width: nameWidth * 0.65, height: 11),
                ],
              ),
              _box(width: 55, height: 22, radius: 10),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 80, height: 12),
              _box(width: nominalWidth, height: 12),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _skSummaryCard(),
        _skSearchBar(),
        _skTabBar(),
        _skDetailHeader(),
        _skTile(nameWidth: 130, nominalWidth: 100),
        _skTile(nameWidth: 150, nominalWidth: 110),
        _skTile(nameWidth: 110, nominalWidth: 95),
        _skTile(nameWidth: 120, nominalWidth: 105, opacity: 0.5),
      ],
    );
  }
}