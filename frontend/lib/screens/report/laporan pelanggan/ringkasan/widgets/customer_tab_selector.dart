import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CustomerTabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const CustomerTabSelector({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  static const Color activeColor = AppPalette.primary;
  static const Color inactiveColor = Color(0xFF8D807A);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / 2;

        return Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2EF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth - 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7B4E), Color(0xFFF5A623)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  _TabText(
                    label: 'Pelanggan Baru',
                    isSelected: selectedIndex == 0,
                    onTap: () => onTabChanged(0),
                  ),
                  _TabText(
                    label: 'Top Pelanggan',
                    isSelected: selectedIndex == 1,
                    onTap: () => onTabChanged(1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabText extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabText({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: AppFont.w800,
              color: isSelected
                  ? Colors.white
                  : CustomerTabSelector.inactiveColor,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
