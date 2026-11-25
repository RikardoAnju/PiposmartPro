import 'package:flutter/material.dart';

import 'package:ayocucinew/shared/widgets/ceremonial_success_screen.dart';

class OutletProSuccessScreen extends StatelessWidget {
  const OutletProSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CeremonialSuccessScreen(
      badge: 'Outlet PRO Aktif',
      title: 'Outlet Siap Dipakai',
      subtitle:
          'Outlet aktif permanen dan semua fitur premium untuk outlet ini sudah bisa digunakan.',
      primaryLabel: 'Lihat Aktivasi',
      onPrimary: () => Navigator.of(context).pushNamedAndRemoveUntil(
        '/aktivasi-akun',
        (route) => route.isFirst,
      ),
      chips: const [
        CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
        CelebrationChipData(icon: Icons.bolt_rounded, text: 'Premium'),
        CelebrationChipData(icon: Icons.storefront_rounded, text: 'Outlet'),
      ],
      soundAsset: 'assets/sounds/success_bright_1.wav',
    );
  }
}
