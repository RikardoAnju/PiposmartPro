import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class ReferralHeroBanner extends StatelessWidget {
  final int bonusPercent;

  const ReferralHeroBanner({super.key, required this.bonusPercent});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.84,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppPalette.referralHeroGradient,
              stops: AppPalette.referralHeroStops,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const _HeroDecorations(),
              Positioned(
                right: -14,
                top: 34,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/maskot/referral_hero_mascot.png',
                    width: 248,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                right: 18,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: AppFont.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 208,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: AppFont.w900,
                            height: 1.0,
                          ),
                          children: [
                            TextSpan(
                              text: 'UNDANG TEMAN\n',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'DAPAT JUTAAN RUPIAH',
                              style: TextStyle(color: Color(0xFFFFF2AC)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 188,
                      child: Text(
                        'Semakin banyak teman bergabung\nsemakin besar hadiah untukmu.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (bonusPercent > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BonusTilePlaceholder(percent: bonusPercent),
                      ),
                    const SizedBox(height: 8),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDecorations extends StatelessWidget {
  const _HeroDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -58,
          top: -56,
          child: _GlowBlob(
            size: 180,
            color: Colors.white.withValues(alpha: 0.09),
          ),
        ),
        Positioned(
          right: -36,
          top: 84,
          child: _GlowBlob(
            size: 128,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        Positioned(
          left: 22,
          top: 130,
          child: _CoinChip(
            icon: Icons.payments_rounded,
            rotate: -0.2,
            scale: 0.9,
          ),
        ),
        Positioned(
          left: 110,
          top: 88,
          child: _CoinChip(
            icon: Icons.monetization_on_rounded,
            rotate: 0.18,
            scale: 0.86,
          ),
        ),
        Positioned(
          right: 100,
          top: 96,
          child: _CoinChip(
            icon: Icons.currency_exchange_rounded,
            rotate: -0.22,
            scale: 0.94,
          ),
        ),
        Positioned(
          right: 26,
          top: 172,
          child: _CoinChip(
            icon: Icons.savings_rounded,
            rotate: 0.12,
            scale: 0.82,
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final IconData icon;
  final double rotate;
  final double scale;

  const _CoinChip({
    required this.icon,
    required this.rotate,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: const Color(0xFFFFE39E), size: 21),
        ),
      ),
    );
  }
}

class _BonusTilePlaceholder extends StatelessWidget {
  final int percent;

  const _BonusTilePlaceholder({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: AppPalette.primary,
                  size: 19,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dapatkan Bonus',
                      style: TextStyle(
                        color: Color(0xFF1F1F1F),
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: AppPalette.primary,
                        fontSize: 18,
                        fontWeight: AppFont.w900,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'dari top up pertama\nteman kamu!',
                      style: TextStyle(
                        color: Color(0xFF6F6F6F),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
