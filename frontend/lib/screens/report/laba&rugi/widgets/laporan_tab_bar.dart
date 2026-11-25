import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LaporanTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const LaporanTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  static const List<String> tabs = ['Pendapatan', 'Pembayaran', 'Pengeluaran'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double segmentWidth = (constraints.maxWidth) / tabs.length;

          return Stack(
            children: [
              // Sliding Orange Card
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.primary, AppPalette.primaryAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: List.generate(tabs.length, (index) {
                  final isActive = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTabChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? AppFont.w900
                                : AppFont.w700,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF999999),
                            letterSpacing: 0.1,
                          ),
                          child: Text(tabs[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
