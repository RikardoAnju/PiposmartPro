import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TutorialStepData {
  final GlobalKey targetKey;
  final IconData icon;
  final String title;
  final String description;

  const TutorialStepData({
    required this.targetKey,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class FirstHomeTutorialOverlay extends StatefulWidget {
  final List<TutorialStepData> steps;
  final Future<void> Function() onCompleted;

  const FirstHomeTutorialOverlay({
    super.key,
    required this.steps,
    required this.onCompleted,
  });

  @override
  State<FirstHomeTutorialOverlay> createState() =>
      _FirstHomeTutorialOverlayState();
}

class _FirstHomeTutorialOverlayState extends State<FirstHomeTutorialOverlay> {
  static const _primary = AppPalette.primary;
  int _index = 0;
  Rect? _targetRect;

  TutorialStepData get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;
  bool get _isFirst => _index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  @override
  void didUpdateWidget(covariant FirstHomeTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  void _updateTargetRect() {
    final context = _step.targetKey.currentContext;
    if (context == null) return;

    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final rect = offset & renderBox.size;
    if (mounted) {
      setState(() => _targetRect = rect.inflate(10));
    }
  }

  Future<void> _next() async {
    HapticFeedback.lightImpact();
    if (_isLast) {
      await widget.onCompleted();
      return;
    }

    setState(() {
      _index++;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  void _back() {
    if (_isFirst) return;
    HapticFeedback.lightImpact();
    setState(() {
      _index--;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safe = MediaQuery.of(context).padding;
    final targetRect = _targetRect;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_isFirst) _back();
        },
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => HapticFeedback.selectionClick(),
                  child: CustomPaint(
                    painter: _CoachmarkPainter(targetRect: targetRect),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              _buildCard(context, size, safe, targetRect),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Size screenSize,
    EdgeInsets safe,
    Rect? targetRect,
  ) {
    const cardWidth = 328.0;
    const cardHeight = 260.0;
    final availableWidth = screenSize.width - 32;
    final width = availableWidth < cardWidth ? availableWidth : cardWidth;
    final left = ((screenSize.width - width) / 2).clamp(16.0, screenSize.width);

    double top;
    if (targetRect == null) {
      top = safe.top + 88;
    } else {
      final spaceBelow = screenSize.height - targetRect.bottom - safe.bottom;
      final preferredBelow = targetRect.bottom + 24;
      final preferredAbove = targetRect.top - cardHeight - 24;
      top = spaceBelow > cardHeight + 24
          ? preferredBelow
          : preferredAbove.clamp(safe.top + 18, screenSize.height - cardHeight);
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        ignoring: false,
        child: AbsorbPointer(
          absorbing: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Container(
              key: ValueKey(_index),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_step.icon, color: _primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan Awal',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: AppFont.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _step.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF253040),
                                fontSize: 18,
                                fontWeight: AppFont.w900,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _step.description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: AppFont.w500,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ...List.generate(widget.steps.length, (dotIndex) {
                        final active = dotIndex == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? _primary : AppPalette.primaryBorder,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                      const Spacer(),
                      // Tombol Back — muncul jika bukan step pertama
                      if (!_isFirst) ...[
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: AppFont.w700,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          _isLast ? 'Mulai' : 'Lanjut',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachmarkPainter extends CustomPainter {
  final Rect? targetRect;

  _CoachmarkPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    // Background gelap semi-transparan
    canvas.drawRect(bounds, Paint()..color = const Color(0xCC000000));

    final rect = targetRect;
    if (rect != null) {
      // Bolong transparan — tidak ada efek tambahan
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(35)),
        Paint()..blendMode = ui.BlendMode.clear,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoachmarkPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
