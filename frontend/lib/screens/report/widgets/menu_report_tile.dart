import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class MenuReportTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget image;
  final VoidCallback? onTap;
  final bool isExpandable;
  final List<Widget>? children;
  final bool isLocked;

  const MenuReportTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    this.onTap,
    this.isExpandable = false,
    this.children,
    this.isLocked = false,
  });

  @override
  State<MenuReportTile> createState() => _MenuReportTileState();
}

class _MenuReportTileState extends State<MenuReportTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppDecorations.card(radius: 24, shadow: AppShadows.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isExpandable
                  ? () => setState(() => _isExpanded = !_isExpanded)
                  : widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: widget.image,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: AppFont.w600,
                                    color: Color(0xFF1F1F1F),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (widget.isLocked)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.primarySoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        size: 11,
                                        color: AppPalette.primary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Terkunci',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: AppFont.w700,
                                          color: AppPalette.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.isLocked
                                ? 'Minta owner membuka izin untuk melihat laporan ini.'
                                : widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.42),
                              fontWeight: AppFont.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.isExpandable && _isExpanded
                              ? AppPalette.primary
                              : const Color(0xFFF4F4F4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isExpandable
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: widget.isExpandable && _isExpanded
                              ? Colors.white
                              : const Color(0xFF9A9A9A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _isExpanded && widget.children != null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(children: [...widget.children!]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class SubMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLocked;
  final bool showAddonLock;

  const SubMenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLocked = false,
    this.showAddonLock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.w600,
                      color: isLocked
                          ? const Color(0xFF8C8792)
                          : const Color(0xFF4F4F4F),
                    ),
                  ),
                ),
                if (isLocked || showAddonLock)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppPalette.primary,
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
