import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReportAccessPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? caption;
  final List<String>? highlights;
  final String? accessNote;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool compact;

  const ReportAccessPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.caption,
    this.highlights,
    this.accessNote,
    this.actionLabel,
    this.onActionTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardRadius = compact ? 18.0 : 22.0;
    final padding = compact
        ? const EdgeInsets.all(16)
        : const EdgeInsets.fromLTRB(18, 18, 18, 16);
    final previewLabels = _resolvedPreviewLabels;

    return Container(
      width: double.infinity,
      margin: compact
          ? const EdgeInsets.symmetric(horizontal: 16)
          : const EdgeInsets.symmetric(vertical: 8),
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), AppPalette.primaryPale],
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppPalette.primaryBorder),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              Icons.lock_rounded,
              size: compact ? 86 : 108,
              color: AppPalette.primary.withValues(alpha: 0.045),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: AppPalette.primary,
                      size: compact ? 21 : 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: AppFont.w800,
                                  color: Color(0xFF202434),
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _lockBadge(),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Color(0xFF827A87),
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (compact)
                _compactAccessNote()
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _maskedMetric(previewLabels[0]),
                          const SizedBox(width: 8),
                          _maskedMetric(previewLabels[1]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _maskedMetric(previewLabels[2]),
                          const SizedBox(width: 8),
                          _maskedMetric(previewLabels[3]),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_effectiveAccessNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color(0xFFB2A7AF),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _effectiveAccessNote,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Color(0xFF9A8F98),
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (actionLabel != null &&
                  actionLabel!.trim().isNotEmpty &&
                  onActionTap != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onActionTap,
                  icon: const Icon(
                    Icons.lock_open_rounded,
                    size: 16,
                    color: AppPalette.primary,
                  ),
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppPalette.primary,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: AppPalette.primary),
          SizedBox(width: 4),
          Text(
            'Terkunci',
            style: TextStyle(
              fontSize: 10,
              fontWeight: AppFont.w800,
              color: AppPalette.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactAccessNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 18,
            color: AppPalette.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _effectiveAccessNote,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: Color(0xFF827A87),
                fontWeight: AppFont.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _previewLabels {
    final lowerTitle = title.toLowerCase();
    final isFinance =
        lowerTitle.contains('keuangan') ||
        lowerTitle.contains('omset') ||
        lowerTitle.contains('penjualan') ||
        lowerTitle.contains('pendapatan') ||
        lowerTitle.contains('pengeluaran') ||
        lowerTitle.contains('laba') ||
        lowerTitle.contains('piutang');

    if (isFinance) {
      return const ['Penjualan', 'Pendapatan', 'Pengeluaran', 'Laba/Rugi'];
    }
    return const ['Ringkasan', 'Detail', 'Periode', 'Total'];
  }

  List<String> get _resolvedPreviewLabels {
    final custom = highlights
        ?.where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toList();
    if (custom == null || custom.isEmpty) return _previewLabels;

    final padded = [...custom];
    while (padded.length < 4) {
      padded.add(_previewLabels[padded.length]);
    }
    return padded.take(4).toList();
  }

  String get _effectiveAccessNote {
    final note = accessNote ?? caption;
    if (note != null && note.trim().isNotEmpty) return note.trim();
    return 'Hubungi owner untuk membuka akses laporan ini.';
  }

  Widget _maskedMetric(String label) {
    return Expanded(
      child: Container(
        height: compact ? 54 : 58,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppPalette.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF9D939A),
                fontWeight: AppFont.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  compact ? '∗∗∗∗' : 'Rp ∗∗∗∗',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.primary,
                    fontWeight: AppFont.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
