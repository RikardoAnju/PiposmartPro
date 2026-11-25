import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/api_client.dart';
import '../../data/models/content_banner_model.dart';
import '../../shared/widgets/app_cached_network_image.dart';
import '../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ContentDetailScreen extends StatelessWidget {
  final ContentBannerModel content;

  const ContentDetailScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(content.imageUrl);
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          content.category == 'PROMO' ? 'Detail Promo' : 'Detail Informasi',
          style: const TextStyle(fontWeight: AppFont.w800, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppCachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 1280,
                  maxWidthDiskCache: 1280,
                  placeholder: const ColoredBox(color: Color(0xFFF3F4F6)),
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat(
                      'EEEE, dd MMM yyyy',
                      'id_ID',
                    ).format(content.publishedAt),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Text(
                content.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: AppFont.w900,
                  height: 1.25,
                ),
              ),
            ),
            if (content.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  content.summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                    fontWeight: AppFont.w600,
                  ),
                ),
              ),
            // Kartu salin kode voucher — hanya untuk promo yang punya kode.
            if (content.category == 'PROMO' && content.voucherCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: _VoucherCopyCard(code: content.voucherCode),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: LinkifiedContentText(
                text: content.body,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveImageUrl(String path) {
    if (path.isEmpty) return null;
    return ApiClient.resolveImageVariantUrl(path, width: 1280, quality: 82);
  }
}

/// Kartu kode promo yang bisa disalin (mirip pola voucher tiket.com):
/// label + kode besar di kiri, tombol Salin di kanan. Setelah disalin,
/// tombol berubah jadi "Tersalin" sementara + snackbar konfirmasi.
class _VoucherCopyCard extends StatefulWidget {
  final String code;
  const _VoucherCopyCard({required this.code});

  @override
  State<_VoucherCopyCard> createState() => _VoucherCopyCardState();
}

class _VoucherCopyCardState extends State<_VoucherCopyCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    CustomToast.show(
      context,
      message: 'Kode promo berhasil disalin',
      duration: const Duration(seconds: 2),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KODE PROMO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: AppFont.w700,
                    letterSpacing: 1,
                    color: AppPalette.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: AppFont.w900,
                    letterSpacing: 2,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _copied ? null : _copy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _copied ? Colors.white : AppPalette.primary,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _copied ? AppPalette.primary : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 15,
                    color: _copied ? AppPalette.primary : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _copied ? 'Tersalin' : 'Salin',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.w700,
                      color: _copied ? AppPalette.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LinkifiedContentText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const LinkifiedContentText({super.key, required this.text, this.style});

  @override
  State<LinkifiedContentText> createState() => _LinkifiedContentTextState();
}

class _LinkifiedContentTextState extends State<LinkifiedContentText> {
  static final RegExp _urlRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s<]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = baseStyle.copyWith(
      color: AppPalette.primary,
      fontWeight: AppFont.w800,
      decoration: TextDecoration.underline,
      decorationColor: AppPalette.primary,
    );

    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: _buildSpans(widget.text, baseStyle, linkStyle),
      ),
    );
  }

  List<TextSpan> _buildSpans(
    String text,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final spans = <TextSpan>[];
    var currentIndex = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }

      final rawUrl = match.group(0) ?? '';
      final trimmedUrl = _trimTrailingPunctuation(rawUrl);
      final trailing = rawUrl.substring(trimmedUrl.length);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openUrl(trimmedUrl);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(text: trimmedUrl, style: linkStyle, recognizer: recognizer),
      );
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: baseStyle));
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }

  String _trimTrailingPunctuation(String value) {
    return value.replaceFirst(RegExp(r'[),.;:!?]+$'), '');
  }

  Future<void> _openUrl(String value) async {
    final normalized = value.startsWith('www.') ? 'https://$value' : value;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
