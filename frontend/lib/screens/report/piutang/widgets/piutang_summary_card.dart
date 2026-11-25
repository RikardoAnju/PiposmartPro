import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';

class PiutangSummaryCard extends StatelessWidget {
  final double jatuhTempo;
  final int jumlahPelangganJatuhTempo;
  final double belumJatuhTempo;
  final int jumlahPelangganBelumJatuhTempo;

  const PiutangSummaryCard({
    super.key,
    required this.jatuhTempo,
    required this.jumlahPelangganJatuhTempo,
    required this.belumJatuhTempo,
    required this.jumlahPelangganBelumJatuhTempo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PiutangCard(
            title: 'Jatuh Tempo',
            amount: CurrencyFormatter.formatToRupiah(jatuhTempo),
            colors: const [Color(0xFFFF5B6E), Color(0xFFFF3F4F)],
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _PiutangCard(
            title: 'Belum\nJatuh Tempo',
            amount: CurrencyFormatter.formatToRupiah(belumJatuhTempo),
            colors: const [Color(0xFFFFA24D), Color(0xFFFF6A3D)],
            icon: Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }
}

class _PiutangCard extends StatelessWidget {
  final String title;
  final String amount;
  final List<Color> colors;
  final IconData icon;

  const _PiutangCard({
    required this.title,
    required this.amount,
    required this.colors,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: AppFont.w800,
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                  ],
                ),

                const Spacer(),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: AppFont.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
