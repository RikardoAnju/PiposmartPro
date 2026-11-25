import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LoadingButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;

  /// Durasi minimum loading terlihat (default 1.5 detik)
  final Duration minLoadingDuration;

  const LoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.isDisabled = false,
    this.onPressed,
    this.backgroundColor = AppPalette.primary,
    this.height = 50,
    this.borderRadius = 12,
    this.minLoadingDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  bool _showLoading = false;
  DateTime? _loadingStartedAt;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LoadingButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Mulai loading
    if (widget.isLoading && !oldWidget.isLoading) {
      _loadingStartedAt = DateTime.now();
      setState(() => _showLoading = true);
    }

    // Selesai loading — tunggu minimum duration dulu
    if (!widget.isLoading && oldWidget.isLoading) {
      final elapsed = DateTime.now().difference(
        _loadingStartedAt ?? DateTime.now(),
      );
      final remaining = widget.minLoadingDuration - elapsed;

      if (remaining <= Duration.zero) {
        setState(() => _showLoading = false);
      } else {
        Future.delayed(remaining, () {
          if (mounted) setState(() => _showLoading = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isActuallyDisabled => widget.isDisabled || _showLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!_isActuallyDisabled) _scaleController.forward();
      },
      onTapUp: (_) {
        if (!_isActuallyDisabled) _scaleController.reverse();
      },
      onTapCancel: () => _scaleController.reverse(),
      onTap: _isActuallyDisabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: _isActuallyDisabled
                ? (widget.backgroundColor ?? AppPalette.primary).withValues(alpha: 0.7,)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 24,
                    height: 24,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    key: ValueKey(widget.label),
                    widget.label,
                    style: TextStyle(
                      color: _isActuallyDisabled
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: AppFont.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
