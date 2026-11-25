import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TukarHeaderCard extends StatelessWidget {
  const TukarHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.referralHeroGradient,
          stops: AppPalette.referralHeroStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallDevice = constraints.maxWidth < 340;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tukar saldo mu ke koin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallDevice ? 14 : 16,
                  fontWeight: AppFont.w700,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Pilih outlet tujuan koin lalu tentukan nominal saldo referral yang ingin diubah.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: isSmallDevice ? 11 : 12,
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
