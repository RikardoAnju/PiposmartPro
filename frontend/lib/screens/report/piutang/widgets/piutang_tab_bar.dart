import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

enum PiutangTab { jatuhTempo, belumJatuhTempo }

class PiutangTabBar extends StatelessWidget {
  final PiutangTab activeTab;
  final ValueChanged<PiutangTab> onTabChanged;

  const PiutangTabBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  static const _activeGradient = [AppPalette.primary, AppPalette.primaryAccent];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double segmentWidth = constraints.maxWidth / 2;
          final isJatuhTempo = activeTab == PiutangTab.jatuhTempo;

          return Stack(
            children: [
              // Sliding Orange Card
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: isJatuhTempo ? 0 : segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _activeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: [
                  _buildTabLabel('Jatuh Tempo', PiutangTab.jatuhTempo),
                  _buildTabLabel(
                    'Belum Jatuh Tempo',
                    PiutangTab.belumJatuhTempo,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabLabel(String label, PiutangTab tab) {
    final isActive = activeTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isActive) onTabChanged(tab);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? AppFont.w900 : AppFont.w700,
              color: isActive ? Colors.white : const Color(0xFF999999),
              letterSpacing: 0.1,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
