import 'package:flutter/material.dart';

class AllTransactionsSkeleton extends StatefulWidget {
  const AllTransactionsSkeleton({super.key});

  @override
  State<AllTransactionsSkeleton> createState() => _AllTransactionsSkeletonState();
}

class _AllTransactionsSkeletonState extends State<AllTransactionsSkeleton>
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

  // TransactionSummaryRow skeleton
  Widget _skSummaryRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(width: 80, height: 11),
                const SizedBox(height: 7),
                _box(width: 50, height: 18),
              ],
            ),
          ),
          Container(width: 0.5, height: 36, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 90, height: 11),
                  const SizedBox(height: 7),
                  _box(width: 110, height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Search + filter skeleton
  Widget _skSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: _box(height: 40, radius: 10)),
          const SizedBox(width: 10),
          _box(width: 40, height: 40, radius: 10),
        ],
      ),
    );
  }

  // Tab bar skeleton
  Widget _skTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _box(width: 70, height: 30, radius: 20),
            const SizedBox(width: 6),
            Opacity(opacity: 0.4, child: _box(width: 60, height: 30, radius: 20)),
            const SizedBox(width: 6),
            Opacity(opacity: 0.4, child: _box(width: 72, height: 30, radius: 20)),
            const SizedBox(width: 6),
            Opacity(opacity: 0.3, child: _box(width: 78, height: 30, radius: 20)),
            const SizedBox(width: 6),
            Opacity(opacity: 0.2, child: _box(width: 55, height: 30, radius: 20)),
          ],
        ),
      ),
    );
  }

  // Date header skeleton
  Widget _skDateHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: _box(width: 120, height: 12),
    );
  }

  // TransactionCard skeleton
  Widget _skCard({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 130, height: 14),
                      const SizedBox(height: 7),
                      _box(width: 90, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _box(width: 60, height: 22, radius: 10),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _box(width: 70, height: 11),
                _box(width: 100, height: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TransactionRingkasanBar skeleton
  Widget _skBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _box(width: 80, height: 11),
              const SizedBox(height: 7),
              _box(width: 130, height: 16),
            ],
          ),
          _box(width: 100, height: 38, radius: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _skSummaryRow(),
        _skSearchBar(),
        _skTabBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _skDateHeader(),
              _skCard(),
              _skCard(),
              _skDateHeader(),
              _skCard(),
              _skCard(opacity: 0.5),
            ],
          ),
        ),
        _skBottomBar(),
      ],
    );
  }
}