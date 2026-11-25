import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';

class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onExport;
  final bool isExporting;
  final String exportTooltip;
  final List<Widget>? actions;

  const AppPageBar({
    super.key,
    required this.title,
    this.onBack,
    this.onExport,
    this.isExporting = false,
    this.exportTooltip = 'Export laporan',
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
      onPressed: onBack ?? () => Navigator.maybePop(context),
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: AppFont.w800,
        letterSpacing: -.2,
      ),
    ),
    centerTitle: true,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    actions:
        actions ??
        (onExport == null
            ? null
            : [
                IconButton(
                  tooltip: exportTooltip,
                  onPressed: isExporting ? null : onExport,
                  icon: isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Image.asset(
                          'assets/icons/ic_download.webp',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.download_rounded,
                                size: 22,
                                color: Colors.black87,
                              ),
                        ),
                ),
                const SizedBox(width: 4),
              ]),
  );
}
