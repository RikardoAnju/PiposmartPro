import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 74,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 0,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, "Home_nav.png", "Beranda"),
            _buildNavItem(1, "Status_nav.png", "Status"),

            // Spacer untuk FAB
            SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 26),
                  const SizedBox(height: 4),
                  Text(
                    'Order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: AppFont.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            _buildNavItem(2, "Ringkasan_nav.png", "Ringkasan"),
            _buildNavItem(3, "Profile_nav.png", "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String iconName, String label) {
    bool isActive = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ikon "melompat" saat aktif, tanpa pill tambahan
              // (ikon asset sudah punya bentuk badge bulat sendiri)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: isActive ? 1.18 : 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Transform.translate(
                      offset: Offset(0, isActive ? -2 : 0),
                      child: child,
                    ),
                  );
                },
                child: ImageIcon(
                  AssetImage('assets/icons/home/$iconName'),
                  size: 24,
                  color: isActive ? AppPalette.primary : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? AppPalette.primary : Colors.grey.shade400,
                  fontWeight: isActive ? AppFont.w600 : AppFont.w500,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
