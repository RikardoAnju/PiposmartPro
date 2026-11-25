import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AktivasiBannerWidget extends StatelessWidget {
  final String masaAktif;
  final VoidCallback onAktifkan;
  final VoidCallback? onProTap;
  final bool isPro;
  final bool hasPending; // ✅ Tambahkan flag untuk cek order gantung
  final bool isFree;

  const AktivasiBannerWidget({
    super.key,
    required this.masaAktif,
    required this.onAktifkan,
    this.onProTap,
    this.isPro = false,
    this.hasPending = false, // ✅ Default false
    this.isFree = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isPro ? onProTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPro
                  ? [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)]
                  : [AppPalette.primary, AppPalette.primaryWarm],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (isPro ? const Color(0xFF2C3E50) : AppPalette.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -10,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isPro ? 'Status Akun' : 'Masa Aktif Trial',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  masaAktif,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                  ),
                                ),
                                if (isPro) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (!isPro)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onAktifkan,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      // ✅ Jika ada pending, warna tombol jadi Amber agar kontras
                                      color: hasPending
                                          ? Colors.amber[50]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ✅ Tambahkan icon penanda jika pending
                                        if (hasPending) ...[
                                          const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 14,
                                            color: Color(0xFFD35400),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          hasPending
                                              ? 'Lihat Transaksi'
                                              : (isFree ? 'Aktifkan (GRATIS)' : 'Aktifkan PRO'),
                                          style: TextStyle(
                                            // ✅ Warnanya juga disesuaikan
                                            color: hasPending
                                                ? const Color(0xFFD35400)
                                                : AppPalette.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'Akses Fitur Premium Aktif',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 110,
                        child: Hero(
                          tag: 'aktivasi_img',
                          child: Image.asset(
                            'assets/images/aktivasi_acc.webp',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 40,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
