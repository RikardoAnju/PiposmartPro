import 'package:flutter/material.dart';

class MyRewardSkeleton extends StatefulWidget {
  const MyRewardSkeleton({super.key});

  @override
  State<MyRewardSkeleton> createState() => _MyRewardSkeletonState();
}

class _MyRewardSkeletonState extends State<MyRewardSkeleton>
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
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({
    double width = double.infinity,
    double height = 14,
    double radius = 8,
  }) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFE9E9E9),
                Color(0xFFF7F7F7),
                Color(0xFFE9E9E9),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 0.6,
        ),
      ),
      child: child,
    );
  }

  Widget _balanceCard() {
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 110, height: 12),
          const SizedBox(height: 14),

          _box(width: 180, height: 28),

          const SizedBox(height: 14),

          _box(width: 140, height: 12),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _box(height: 44, radius: 12)),
              const SizedBox(width: 12),
              Expanded(child: _box(height: 44, radius: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return _card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 100, height: 12),
              _box(width: 20, height: 20, radius: 20),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(width: 90, height: 11),
                    const SizedBox(height: 8),
                    _box(width: 120, height: 18),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _box(width: 90, height: 11),
                    const SizedBox(height: 8),
                    _box(width: 120, height: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _box(
              height: 38,
              radius: 10,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: 0.45,
              child: _box(
                height: 38,
                radius: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityItem({
    required double titleWidth,
    required double amountWidth,
    double opacity = 1,
  }) {
    return Opacity(
      opacity: opacity,
      child: _card(
        child: Row(
          children: [
            _box(width: 48, height: 48, radius: 48),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: titleWidth, height: 14),
                  const SizedBox(height: 8),
                  _box(width: titleWidth * 0.6, height: 11),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _box(width: amountWidth, height: 14),
                const SizedBox(height: 8),
                _box(width: 70, height: 10),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _balanceCard(),
        _summaryCard(),

        const SizedBox(height: 8),

        _box(width: 80, height: 16),

        const SizedBox(height: 12),

        _tabBar(),

        _activityItem(
          titleWidth: 130,
          amountWidth: 90,
        ),

        _activityItem(
          titleWidth: 150,
          amountWidth: 100,
        ),

        _activityItem(
          titleWidth: 120,
          amountWidth: 85,
        ),

        _activityItem(
          titleWidth: 140,
          amountWidth: 95,
          opacity: 0.5,
        ),
      ],
    );
  }
}