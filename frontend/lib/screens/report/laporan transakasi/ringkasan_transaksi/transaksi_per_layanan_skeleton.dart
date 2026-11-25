import 'package:flutter/material.dart';

class TransaksiPerLayananSkeleton extends StatefulWidget {
  const TransaksiPerLayananSkeleton({super.key});

  @override
  State<TransaksiPerLayananSkeleton> createState() =>
      _TransaksiPerLayananSkeletonState();
}

class _TransaksiPerLayananSkeletonState
    extends State<TransaksiPerLayananSkeleton>
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
    double? width,
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
                ? const [Color(0x40FFFFFF), Color(0x73FFFFFF), Color(0x40FFFFFF)]
                : const [Color(0xFFE8E8E8), Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
          ),
        ),
      ),
    );
  }

  // LayananSummaryHeader skeleton
  Widget _skSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 100, height: 12, white: true),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _skStatChip()),
              const SizedBox(width: 8),
              Expanded(child: _skStatChip()),
              const SizedBox(width: 8),
              Expanded(child: _skStatChip()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skStatChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 55, height: 10, white: true),
          const SizedBox(height: 7),
          _box(width: 40, height: 18, white: true),
        ],
      ),
    );
  }

  // LayananTableHeader skeleton
  Widget _skTableHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: _box(height: 12)),
          const SizedBox(width: 8),
          Expanded(child: _box(height: 12)),
          const SizedBox(width: 8),
          Expanded(child: _box(height: 12)),
          const SizedBox(width: 8),
          Expanded(child: _box(height: 12)),
        ],
      ),
    );
  }

  // LayananTableRow skeleton
  Widget _skTableRow({bool isEven = false, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _box(width: 28, height: 28, radius: 8),
                  const SizedBox(width: 8),
                  Expanded(child: _box(height: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _box(height: 13)),
            const SizedBox(width: 8),
            Expanded(child: _box(height: 13)),
            const SizedBox(width: 8),
            Expanded(child: _box(height: 13)),
          ],
        ),
      ),
    );
  }

  // LayananInsightCard skeleton
  Widget _skInsightCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(width: 18, height: 18, radius: 9),
              const SizedBox(width: 8),
              _box(width: 80, height: 13),
            ],
          ),
          const SizedBox(height: 10),
          _box(height: 11),
          const SizedBox(height: 6),
          _box(height: 11),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity * 0.7,
            child: _box(height: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skSummaryHeader(),
          const SizedBox(height: 8),
          _skTableHeader(),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          _skTableRow(isEven: false),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          _skTableRow(isEven: true),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          _skTableRow(isEven: false),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          _skTableRow(isEven: true),
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
          _skTableRow(isEven: false, opacity: 0.45),
          _skInsightCard(),
        ],
      ),
    );
  }
}