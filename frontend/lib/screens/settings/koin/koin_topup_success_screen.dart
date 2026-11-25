import 'package:flutter/material.dart';

import 'package:ayocucinew/shared/widgets/ceremonial_success_screen.dart';

enum KoinTopupSuccessKind { processed, completed }

class KoinTopupSuccessScreen extends StatelessWidget {
  const KoinTopupSuccessScreen({
    super.key,
    required this.onPrimary,
    this.kind = KoinTopupSuccessKind.processed,
  });

  final VoidCallback onPrimary;
  final KoinTopupSuccessKind kind;

  @override
  Widget build(BuildContext context) {
    final config = switch (kind) {
      KoinTopupSuccessKind.processed => (
        badge: 'Top Up Diproses',
        title: 'Top Up Terkirim',
        subtitle: 'Tunggu verifikasi pembayaran.',
        primaryLabel: 'Lihat Status Top Up',
        chips: const [
          CelebrationChipData(icon: Icons.send_rounded, text: 'Terkirim'),
          CelebrationChipData(icon: Icons.schedule_rounded, text: 'Proses'),
          CelebrationChipData(
            icon: Icons.monetization_on_rounded,
            text: 'Koin',
          ),
        ],
      ),
      KoinTopupSuccessKind.completed => (
        badge: 'Top Up Berhasil',
        title: 'Koin Bertambah',
        subtitle: 'Saldo koin sudah masuk.',
        primaryLabel: 'Lihat Detail Top Up',
        chips: const [
          CelebrationChipData(
            icon: Icons.check_circle_rounded,
            text: 'Berhasil',
          ),
          CelebrationChipData(
            icon: Icons.account_balance_wallet_rounded,
            text: 'Saldo',
          ),
          CelebrationChipData(
            icon: Icons.monetization_on_rounded,
            text: 'Koin',
          ),
        ],
      ),
    };

    return CeremonialSuccessScreen(
      badge: config.badge,
      title: config.title,
      subtitle: config.subtitle,
      primaryLabel: config.primaryLabel,
      onPrimary: onPrimary,
      chips: config.chips,
      mascotAsset: switch (kind) {
        KoinTopupSuccessKind.processed => 'assets/maskot/4 1.webp',
        KoinTopupSuccessKind.completed => 'assets/maskot/3 1.webp',
      },
      soundAsset: 'assets/sounds/success_warm.wav',
    );
  }
}
