import 'package:flutter/material.dart';

class CustomerReportSkeleton extends StatefulWidget {
  const CustomerReportSkeleton({super.key});

  @override
  State<CustomerReportSkeleton> createState() => _CustomerReportSkeletonState();
}

class _CustomerReportSkeletonState extends State<CustomerReportSkeleton>
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

  BoxDecoration get _cardDecor => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      );

  // CustomerHeaderCard skeleton
  Widget _skHeaderCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 100, height: 12),
                  const SizedBox(height: 8),
                  _box(width: 60, height: 32),
                ],
              ),
              _box(width: 52, height: 52, radius: 26),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 55, height: 11),
                      const SizedBox(height: 7),
                      _box(width: 35, height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 60, height: 11),
                      const SizedBox(height: 7),
                      _box(width: 35, height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // CustomerTabSelector skeleton
  Widget _skTabSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(child: _box(height: 36, radius: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(opacity: 0.35, child: _box(height: 36, radius: 20)),
          ),
        ],
      ),
    );
  }

  // CustomerGrowthSection skeleton (chart)
  Widget _skGrowthSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 110, height: 11),
          const SizedBox(height: 8),
          _box(width: 55, height: 28),
          const SizedBox(height: 6),
          _box(width: 90, height: 11),
          const SizedBox(height: 16),
          // Bar chart area
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final pct in [0.55, 0.75, 0.45, 0.90, 0.60, 0.80, 0.50]) ...[
                  Expanded(
                    child: Opacity(
                      opacity: pct == 0.50 ? 0.5 : 1.0,
                      child: _box(
                        height: 100 * pct,
                        radius: 4,
                      ),
                    ),
                  ),
                  if (pct != 0.50) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // GrowthDetailTable skeleton
  Widget _skGrowthTable() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(flex: 2, child: _box(height: 11)),
              const SizedBox(width: 8),
              Expanded(child: _box(height: 11)),
              const SizedBox(width: 8),
              Expanded(child: _box(height: 11)),
              const SizedBox(width: 8),
              Expanded(child: _box(height: 11)),
            ],
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
        _skTableRow(isEven: false),
        _skTableRow(isEven: true),
        _skTableRow(isEven: false),
        _skTableRow(isEven: true, opacity: 0.4),
      ],
    );
  }

  Widget _skTableRow({bool isEven = false, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 11),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skHeaderCard(),
          _skTabSelector(),
          _skGrowthSection(),
          _skGrowthTable(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}