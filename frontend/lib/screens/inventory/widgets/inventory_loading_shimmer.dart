import 'package:flutter/material.dart';

class InventoryLoadingShimmer extends StatefulWidget {
  const InventoryLoadingShimmer({super.key});

  @override
  State<InventoryLoadingShimmer> createState() =>
      _InventoryLoadingShimmerState();
}

class _InventoryLoadingShimmerState extends State<InventoryLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1.4 + (_controller.value * 2.8), 0),
        end: Alignment(-.4 + (_controller.value * 2.8), 0),
        colors: const [Color(0xFFF1F3F5), Colors.white, Color(0xFFF1F3F5)],
      ).createShader(bounds),
      child: child,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        _bar(185, 22),
        const SizedBox(height: 14),
        _card(84),
        const SizedBox(height: 12),
        _card(84),
        const SizedBox(height: 28),
        _bar(165, 22),
        const SizedBox(height: 14),
        _card(74),
        const SizedBox(height: 10),
        _card(74),
      ],
    ),
  );

  static Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(8),
    ),
  );
  static Widget _card(double height) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(20),
    ),
  );
}
