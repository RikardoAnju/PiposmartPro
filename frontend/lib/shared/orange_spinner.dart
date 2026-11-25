import 'dart:math' show cos, sin, pi;
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OrangeSpinner extends StatefulWidget {
  final double size;
  const OrangeSpinner({super.key, this.size = 64});

  @override
  State<OrangeSpinner> createState() => _OrangeSpinnerState();
}

class _OrangeSpinnerState extends State<OrangeSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(12, (i) {
              final angle = (2 * pi / 12) * i - pi / 2;
              final progress = ((i + (_controller.value * 12)) % 12) / 12.0;
              final opacity = 0.12 + progress * 0.88;
              final radius = widget.size * 0.36;
              final dotW = widget.size * 0.18;
              final dotH = widget.size * 0.10;

              return Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(radius * cos(angle), radius * sin(angle), 0, 1)
                  ..rotateZ(angle + pi / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: dotW,
                    height: dotH,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(dotH),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
