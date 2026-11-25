import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TopRankOwnerSkeleton extends StatefulWidget {
  const TopRankOwnerSkeleton({super.key});

  @override
  State<TopRankOwnerSkeleton> createState() => _TopRankOwnerSkeletonState();
}

class _TopRankOwnerSkeletonState extends State<TopRankOwnerSkeleton>
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
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _HeaderSkeleton(progress: _anim.value),
            const SizedBox(height: 14),
            ...List.generate(6, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RankTileSkeleton(
                  progress: _anim.value,
                  offset: i * 0.12,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  final double progress;

  const _HeaderSkeleton({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.4, 0.6, 1.0],
          colors: [
            AppPalette.primaryBorder,
            _shimmerHighlight(
              progress,
              base: AppPalette.primaryBorder,
              highlight: AppPalette.primarySoft,
            ),
            _shimmerHighlight(
              progress,
              base: AppPalette.primaryBorder,
              highlight: AppPalette.primarySoft,
            ),
            AppPalette.primaryBorder,
          ],
          transform: _ShimmerTransform(progress),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShimmerCircle(progress: progress, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  progress: progress,
                  height: 16,
                  radius: 6,
                  widthFactor: 0.6,
                ),
                const SizedBox(height: 8),
                _ShimmerBox(
                  progress: progress,
                  height: 11,
                  radius: 4,
                  widthFactor: 0.9,
                ),
                const SizedBox(height: 4),
                _ShimmerBox(
                  progress: progress,
                  height: 11,
                  radius: 4,
                  widthFactor: 0.7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTileSkeleton extends StatelessWidget {
  final double progress;
  final double offset;

  const _RankTileSkeleton({required this.progress, this.offset = 0});

  @override
  Widget build(BuildContext context) {
    final p = (progress + offset) % 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          _ShimmerCircle(progress: p, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  progress: p,
                  height: 14,
                  radius: 6,
                  widthFactor: 0.55,
                ),
                const SizedBox(height: 8),
                _ShimmerBox(
                  progress: p,
                  height: 11,
                  radius: 4,
                  widthFactor: 0.38,
                ),
                const SizedBox(height: 10),
                _ShimmerBox(
                  progress: p,
                  height: 24,
                  radius: 999,
                  widthFactor: 0.30,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ShimmerBox(progress: p, height: 11, radius: 4, width: 36),
              const SizedBox(height: 6),
              _ShimmerBox(progress: p, height: 14, radius: 4, width: 64),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double progress;
  final double height;
  final double radius;
  final double? width;
  final double widthFactor;

  const _ShimmerBox({
    required this.progress,
    required this.height,
    required this.radius,
    this.width,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth * widthFactor;
        return Container(
          width: w,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.4, 0.6, 1.0],
              colors: [
                const Color(0xFFEEEEEE),
                _shimmerHighlight(progress),
                _shimmerHighlight(progress),
                const Color(0xFFEEEEEE),
              ],
              transform: _ShimmerTransform(progress),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double progress;
  final double size;

  const _ShimmerCircle({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.4, 0.6, 1.0],
          colors: [
            const Color(0xFFEEEEEE),
            _shimmerHighlight(progress),
            _shimmerHighlight(progress),
            const Color(0xFFEEEEEE),
          ],
          transform: _ShimmerTransform(progress),
        ),
      ),
    );
  }
}

Color _shimmerHighlight(
  double progress, {
  Color base = const Color(0xFFEEEEEE),
  Color highlight = const Color(0xFFF8F8F8),
}) {
  final t = math.sin(progress * math.pi);
  return Color.lerp(base, highlight, t)!;
}

class _ShimmerTransform extends GradientTransform {
  final double progress;
  const _ShimmerTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * 2.0 * (progress - 0.5);
    return Matrix4.translationValues(dx, 0, 0);
  }
}
