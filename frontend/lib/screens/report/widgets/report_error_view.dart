import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/user_friendly_error.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReportErrorView extends StatefulWidget {
  final Object? message;
  final VoidCallback onRetry;
  final Color color;

  const ReportErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.color = AppPalette.primary,
  });

  @override
  State<ReportErrorView> createState() => _ReportErrorViewState();
}

class _ReportErrorViewState extends State<ReportErrorView> {
  late String _message;

  // Pesan "butuh add-on" sudah dijelaskan lewat tampilan in-screen (placeholder
  // / teks). Jangan munculkan toast melayang untuk kasus ini karena toast
  // adalah overlay yang bertahan lintas-navigasi sehingga bisa muncul menutupi
  // layar lain (mis. Laporan Omset) dan membingungkan pengguna.
  bool _isAddonLockedMessage(String message) {
    final n = message.toLowerCase();
    return n.contains('memerlukan add-on aktif') ||
        n.contains('silakan lakukan aktivasi terlebih dahulu');
  }

  void _maybeToast(String message) {
    if (_isAddonLockedMessage(message)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CustomToast.show(context, message: message, isError: true);
    });
  }

  @override
  void initState() {
    super.initState();
    _message = userFriendlyError(widget.message);
    _maybeToast(_message);
  }

  @override
  void didUpdateWidget(covariant ReportErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextMessage = userFriendlyError(widget.message);
    if (nextMessage == _message) return;

    _message = nextMessage;
    _maybeToast(_message);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: widget.color),
            const SizedBox(height: 16),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: AppFont.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
