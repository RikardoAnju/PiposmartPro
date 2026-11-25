import 'package:flutter/material.dart';

class LaporanLabaRugiSkeleton extends StatefulWidget {
  const LaporanLabaRugiSkeleton({super.key});

  @override
  State<LaporanLabaRugiSkeleton> createState() => _LaporanLabaRugiSkeletonState();
}

class _LaporanLabaRugiSkeletonState extends State<LaporanLabaRugiSkeleton>
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

  BoxDecoration _cardDecor({double radius = 12}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // LabaRugiCard skeleton
  Widget _skLabaRugiCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 110, height: 12),
          const SizedBox(height: 12),
          _box(width: 180, height: 32),
          const SizedBox(height: 10),
          Row(
            children: [
              _box(width: 60, height: 20, radius: 20),
              const SizedBox(width: 8),
              _box(width: 80, height: 11),
            ],
          ),
        ],
      ),
    );
  }

  // 2 Summary cards (pendapatan & pengeluaran)
  Widget _skSummaryCards() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(child: _skSingleSummary()),
          const SizedBox(width: 8),
          Expanded(child: _skSingleSummary(nominalWidth: 110)),
        ],
      ),
    );
  }

  Widget _skSingleSummary({double nominalWidth = 120}) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      decoration: _cardDecor(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 90, height: 12),
              _box(width: 22, height: 22, radius: 7),
            ],
          ),
          const Spacer(),
          _box(width: nominalWidth, height: 18),
        ],
      ),
    );
  }

  // Header row
  Widget _skHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _box(width: 120, height: 15),
          _box(width: 70, height: 32, radius: 8),
        ],
      ),
    );
  }

  // Tab bar (3 tab)
  Widget _skTabBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(5),
      decoration: _cardDecor(radius: 10),
      child: Row(
        children: [
          Expanded(child: _box(height: 34, radius: 7)),
          const SizedBox(width: 6),
          Expanded(
            child: Opacity(opacity: 0.35, child: _box(height: 34, radius: 7)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Opacity(opacity: 0.35, child: _box(height: 34, radius: 7)),
          ),
        ],
      ),
    );
  }

  // TransaksiTile skeleton
  Widget _skTransaksiTile({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDecor(radius: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _box(width: 100, height: 13),
                _box(width: 80, height: 13),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _box(height: 11)),
                const SizedBox(width: 8),
                Expanded(child: _box(height: 11)),
                const SizedBox(width: 8),
                Expanded(child: _box(height: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _skLabaRugiCard(),
        _skSummaryCards(),
        _skHeaderRow(),
        _skTabBar(),
        _skTransaksiTile(),
        _skTransaksiTile(),
        _skTransaksiTile(),
        _skTransaksiTile(opacity: 0.5),
      ],
    );
  }
}