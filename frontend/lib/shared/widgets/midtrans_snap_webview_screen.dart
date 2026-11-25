import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MidtransSnapWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String title;

  const MidtransSnapWebViewScreen({
    super.key,
    required this.initialUrl,
    this.title = 'Pembayaran',
  });

  @override
  State<MidtransSnapWebViewScreen> createState() =>
      _MidtransSnapWebViewScreenState();
}

class _MidtransSnapWebViewScreenState extends State<MidtransSnapWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const _externalSchemes = <String>{
    'gojek',
    'gopay',
    'shopeeid',
    'intent',
    'upi',
    'dana',
    'ovo',
    'linkaja',
    'mbs',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }

            // 🏁 Deteksi redirect "finish/unfinish/error" dari Snap Midtrans.
            // Finish URL default dashboard adalah http://example.com (cleartext,
            // diblokir Android → ERR_CLEARTEXT_NOT_PERMITTED). Begitu Snap
            // me-redirect ke sana kita cukup tutup webview; status transaksi
            // sudah diperbarui reaktif lewat webhook backend.
            final isFinishRedirect =
                uri.host.contains('example.com') ||
                (uri.queryParameters.containsKey('order_id') &&
                    uri.queryParameters.containsKey('status_code'));
            if (isFinishRedirect) {
              if (mounted) Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }

            final scheme = uri.scheme.toLowerCase();
            final shouldOpenExternal =
                _externalSchemes.contains(scheme) ||
                scheme == 'https' &&
                    (uri.host.contains('play.google.com') ||
                        uri.host.contains('apps.apple.com') ||
                        uri.host.contains('wa.me'));

            if (shouldOpenExternal) {
              _launchExternalUrl(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(() {
        final uri = Uri.parse(widget.initialUrl);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams['language'] = 'id';
        return uri.replace(queryParameters: queryParams);
      }());
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _handleLaunchFailure(url);
      }
    } catch (e) {
      await _handleLaunchFailure(url);
    }
  }

  Future<void> _handleLaunchFailure(String url) async {
    if (url.startsWith('intent://')) {
      final fallbackMatch = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
      if (fallbackMatch != null) {
        final fallbackUrl = Uri.decodeComponent(fallbackMatch.group(1)!);
        final fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aplikasi tidak ditemukan di perangkat Anda.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
