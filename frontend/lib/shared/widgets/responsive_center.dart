import 'package:flutter/material.dart';

/// Membatasi lebar konten pada layar lebar (tablet/iPad) lalu menengahkannya,
/// sehingga UI phone-first tidak "melar" saat dijalankan di layar besar.
///
/// Di HP (lebar < [maxContentWidth]) konten memakai lebar penuh seperti biasa.
/// Di tablet konten dikunci selebar [maxContentWidth] dan diletakkan di tengah.
///
/// Pakai sebagai pembungkus body layar utama:
/// ```dart
/// body: ResponsiveCenter(child: ...)
/// ```
class ResponsiveCenter extends StatelessWidget {
  final Widget child;

  /// Lebar maksimum konten. Default ~500 agar terasa seperti layout ponsel
  /// (sedikit lebih lega dari iPhone Pro Max) tanpa melebar berlebihan.
  final double maxContentWidth;

  /// Padding horizontal saat tampil di layar lebar (agar tak menempel tepi).
  final double tabletHorizontalPadding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxContentWidth = 500,
    this.tabletHorizontalPadding = 16,
  });

  /// Ambang lebar yang dianggap "tablet".
  static const double tabletBreakpoint = 600;

  /// Helper cek apakah context sedang di layar lebar.
  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < tabletBreakpoint) return child;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tabletHorizontalPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}
