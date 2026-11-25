import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

class CustomToast {
  static OverlayEntry? _currentToast;

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isError: isError,
        icon: icon,
        onDismiss: () {
          if (_currentToast == overlayEntry) {
            overlayEntry.remove();
            _currentToast = null;
          }
        },
      ),
    );

    _currentToast = overlayEntry;
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      if (_currentToast == overlayEntry) {
        overlayEntry.remove();
        _currentToast = null;
      }
    });
  }

  static void dismiss() {
    _currentToast?.remove();
    _currentToast = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isError,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Animasi muncul dari atas (Y: -1 ke 0)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambil padding atas (notch/status bar)
    final double safeAreaTop = MediaQuery.of(context).padding.top;

    // Berikan jarak 20px dari safe area
    final double topPosition = safeAreaTop + 10;

    final Color statusColor = widget.isError
        ? const Color(0xFFE74C3C)
        : const Color(0xFF2ECC71);

    final IconData statusIcon = widget.icon ??
        (widget.isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);

    return Positioned(
      top: topPosition,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 400,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors
                        .white, // Ganti ke putih biar lebih elegan di atas
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 24),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 14,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
