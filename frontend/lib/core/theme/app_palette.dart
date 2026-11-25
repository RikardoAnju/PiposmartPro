import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const primary = Color(0xFFFF5F2E);
  static const primaryDeep = Color(0xFFFF4500);
  static const primaryWarm = Color(0xFFFF9F43);
  static const primaryAccent = Color(0xFFFF8A6B);
  static const primarySoft = Color(0xFFFFF1EC);
  static const primaryPale = Color(0xFFFFF8F5);
  static const primaryBorder = Color(0xFFFFD8CD);
  static const primaryBorderStrong = Color(0xFFFFB8AE);

  static const ink = Color(0xFF2C3E50);
  static const muted = Color(0xFF8B98A8);
  static const surface = Color(0xFFF8FAFC);

  static const danger = Color(0xFFE03131);
  static const warning = Color(0xFFFFA12B);
  static const success = Color(0xFF15B86A);
  static const info = Color(0xFF31B8EF);

  static const primaryHex = '#FF5F2E';
  static const primaryDeepHex = '#FF4500';
  static const primaryAccentHex = '#FF8A6B';
  static const primarySoftHex = '#FFF1EC';
  static const primaryPaleHex = '#FFF8F5';
  static const primaryBorderHex = '#FFD8CD';

  static const brandGradient = [primary, primaryWarm];
  static const heroGradient = [primaryDeep, primary];
  static const softGradient = [primarySoft, primaryPale];

  // Gradient hero kanonik untuk seluruh modul referral (warm orange → peach).
  // Dipakai bersama oleh hero utama & kartu-kartu di dalamnya agar seragam.
  // Mengikuti gaya header standar (brandGradient) — oranye pekat tanpa
  // fade terang, supaya konsisten dengan header lain di aplikasi.
  static const referralHeroGradient = [primary, primaryWarm];
  static const referralHeroStops = [0.0, 1.0];
}

class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  static const cardSoft = [
    BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> colored(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppBorders {
  const AppBorders._();

  static final card = Border.all(color: const Color(0xFFEDEFF3), width: 1.2);
}

class AppBorderSides {
  const AppBorderSides._();

  static const card = BorderSide(color: Color(0xFFEDEFF3), width: 1.2);
}

class AppDecorations {
  const AppDecorations._();

  static BoxDecoration card({
    double radius = 16,
    List<BoxShadow>? shadow,
    Border? border,
    Color color = Colors.white,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? AppBorders.card,
      boxShadow: shadow ?? AppShadows.cardSoft,
    );
  }
}
