import 'package:flutter/material.dart';

import 'package:ayocucinew/shared/widgets/ceremonial_success_screen.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key, required this.onPrimary});

  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return CeremonialSuccessScreen(
      badge: 'Akun Siap Dipakai',
      title: 'Registrasi Berhasil',
      subtitle: 'Masuk dan mulai kelola outlet pertamamu.',
      primaryLabel: 'Masuk ke AyoCuci',
      onPrimary: onPrimary,
      chips: const [
        CelebrationChipData(icon: Icons.verified_user_rounded, text: 'Akun'),
        CelebrationChipData(icon: Icons.storefront_rounded, text: 'Outlet'),
        CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Siap'),
      ],
      mascotAsset: 'assets/maskot/2 10.png',
      soundAsset: 'assets/sounds/success_warm.wav',
    );
  }
}
