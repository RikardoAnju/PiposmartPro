import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;
  bool _torchOn = false; // ← ganti pakai state biasa

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _extractId(String raw) {
    debugPrint('=== QR RAW VALUE: $raw');

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      try {
        final uri = Uri.tryParse(raw);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          try {
            final normalized = base64Url.normalize(lastSegment);
            final decoded = utf8.decode(base64Url.decode(normalized));
            debugPrint('=== BASE64 DECODED: $decoded');
            return decoded.split('/').last.trim();
          } catch (_) {
            debugPrint('=== BUKAN BASE64, pakai segment: $lastSegment');
            return lastSegment.trim();
          }
        }
      } catch (e) {
        debugPrint('=== URL PARSE ERROR: $e');
      }
    }

    return raw.trim();
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final candidates = capture.barcodes
        .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
        .toList();

    if (candidates.isEmpty) return;

    final barcode = candidates.first;
    setState(() => _hasScanned = true);

    final result = _extractId(barcode.rawValue!);
    debugPrint('=== FINAL RESULT DIKIRIM: $result');

    if (result.isEmpty) {
      setState(() => _hasScanned = false);
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Scan QR Struk',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? AppPalette.primary : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppPalette.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_hasScanned)
            const Center(
              child: CircularProgressIndicator(color: AppPalette.primary),
            ),
          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR Code pada struk',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
