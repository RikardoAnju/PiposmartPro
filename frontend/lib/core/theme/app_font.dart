import 'package:flutter/widgets.dart';
class AppFont {
  const AppFont._();

  /// Flag compile-time, di-set lewat --dart-define saat build Android.
  static const bool isAndroid = bool.fromEnvironment('APP_IS_ANDROID');

  /// Faktor ukuran font per-platform (dipakai di main.dart).
  static const double sizeFactor = isAndroid ? 1.0 : 1.0;
  static const FontWeight w400 = isAndroid ? FontWeight.w400 : FontWeight.w400;
  static const FontWeight w500 = isAndroid ? FontWeight.w500 : FontWeight.w500;
  static const FontWeight w600 = isAndroid ? FontWeight.w500 : FontWeight.w600;
  static const FontWeight w700 = isAndroid ? FontWeight.w600 : FontWeight.w700;
  static const FontWeight w800 = isAndroid ? FontWeight.w700 : FontWeight.w800;
  static const FontWeight w900 = isAndroid ? FontWeight.w800 : FontWeight.w900;
}
