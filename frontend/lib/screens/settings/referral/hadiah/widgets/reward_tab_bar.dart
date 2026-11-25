import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RewardTabBar extends StatelessWidget {
  final TabController tabController;
  final int selectedIndex;

  const RewardTabBar({
    super.key,
    required this.tabController,
    required this.selectedIndex,
  });

  static const Color kPrimary = AppPalette.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(14),
        labelColor: Colors.white,
        unselectedLabelColor: AppPalette.primaryAccent,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: AppFont.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: AppFont.w600,
        ),
        tabs: const [
          SizedBox(
            height: double.infinity,
            child: Center(child: Text('Hadiah')),
          ),
          SizedBox(
            height: double.infinity,
            child: Center(child: Text('Riwayat')),
          ),
        ],
      ),
    );
  }
}
