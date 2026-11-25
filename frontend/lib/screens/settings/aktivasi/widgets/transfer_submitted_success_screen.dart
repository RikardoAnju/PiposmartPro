import 'package:flutter/material.dart';

import 'package:ayocucinew/shared/widgets/ceremonial_success_screen.dart';

class TransferSubmittedSuccessScreen extends StatelessWidget {
  const TransferSubmittedSuccessScreen({
    super.key,
    required this.nextBuilder,
  });

  final WidgetBuilder nextBuilder;

  @override
  Widget build(BuildContext context) {
    return CeremonialSuccessScreen(
      badge: 'Bukti Terkirim',
      title: 'Siap Diverifikasi',
      subtitle: 'Admin akan memeriksa pembayaran Anda.',
      primaryLabel: 'Lihat Status Pembayaran',
      onPrimary: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: nextBuilder),
        );
      },
      chips: const [
        CelebrationChipData(icon: Icons.upload_rounded, text: 'Struk'),
        CelebrationChipData(icon: Icons.schedule_rounded, text: 'Review'),
        CelebrationChipData(icon: Icons.verified_rounded, text: 'Aktivasi'),
      ],
      mascotAsset: 'assets/maskot/4 1.webp',
      soundAsset: 'assets/sounds/success_warm.wav',
    );
  }
}
