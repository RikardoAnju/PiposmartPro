import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color baseColor;
  final Color highlightColor;

  const SkeletonLoader({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor = const Color(0xFFE8E8E8),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - _animation.value, 0),
              end: Alignment(1 - _animation.value, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    margin: margin,
    decoration: BoxDecoration(
      color: const Color(0xFFE8E8E8),
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    ),
  );
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry margin;

  const SkeletonCircle({
    super.key,
    this.size = 40,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    margin: margin,
    decoration: const BoxDecoration(
      color: Color(0xFFE8E8E8),
      shape: BoxShape.circle,
    ),
  );
}

class AttendanceConfigSkeleton extends StatelessWidget {
  const AttendanceConfigSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonLoader(
    isLoading: true,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SkeletonBox(width: 200, height: 24),
                const Spacer(),
                SkeletonBox(width: 40, height: 40),
              ],
            ),
          ),
          // Configuration cards
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150, height: 18),
                    const SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 14),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 200, height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmployeeDetailSkeleton extends StatelessWidget {
  const EmployeeDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonLoader(
    isLoading: true,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: Row(
              children: [
                SkeletonCircle(size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 18),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 120, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content cards
          ...List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 100, height: 14),
                    const SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 12),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 200, height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
