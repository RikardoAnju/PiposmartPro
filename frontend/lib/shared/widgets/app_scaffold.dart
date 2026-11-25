import 'package:flutter/material.dart';

import 'responsive_center.dart';

/// Pengganti [Scaffold] yang otomatis membatasi lebar `body` pada layar lebar
/// (tablet/iPad) lewat [ResponsiveCenter], sementara AppBar, bottom-nav, FAB,
/// dan background tetap full-width. Cukup ganti `Scaffold(` menjadi
/// `AppScaffold(` pada layar phone-first agar tidak melar di tablet.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool primary;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final Widget? bottomSheet;
  final Widget? drawer;
  final Widget? endDrawer;
  final List<Widget>? persistentFooterButtons;

  /// Lebar maksimum konten di layar lebar.
  final double maxContentWidth;

  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.persistentFooterButtons,
    this.maxContentWidth = 500,
  });

  /// FAB gaya "bar full-width" biasanya diletakkan di tengah (centerFloat/
  /// centerDocked) — itu di-cap agar tidak melebar penuh di tablet. FAB bulat
  /// biasa (endFloat, dll) dibiarkan apa adanya.
  Widget? _wrapFab() {
    if (floatingActionButton == null) return null;
    final loc = floatingActionButtonLocation;
    final isCentered =
        loc == FloatingActionButtonLocation.centerFloat ||
        loc == FloatingActionButtonLocation.centerDocked;
    if (!isCentered) return floatingActionButton;
    // Hanya batasi LEBAR-nya (jangan pakai Center — itu menengahkan vertikal
    // sehingga FAB naik ke tengah layar). Posisi tetap di bawah via
    // FloatingActionButtonLocation.
    return Builder(
      builder: (ctx) {
        if (MediaQuery.of(ctx).size.width < ResponsiveCenter.tabletBreakpoint) {
          return floatingActionButton!;
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: floatingActionButton!,
        );
      },
    );
  }

  /// Sama seperti [_wrapFab]: JANGAN pakai [ResponsiveCenter] (yang berbasis
  /// [Center]) di sini. Scaffold memberi `bottomNavigationBar` constraints
  /// longgar dengan maxHeight besar, sehingga `Center` akan melebar mengisi
  /// tinggi itu dan menengahkan tombolnya secara vertikal — muncul sebagai
  /// tombol "mengambang" di tengah layar pada tablet/iPad. Batasi LEBAR saja.
  Widget? _wrapBottomNav() {
    if (bottomNavigationBar == null) return null;
    return Builder(
      builder: (ctx) {
        if (MediaQuery.of(ctx).size.width < ResponsiveCenter.tabletBreakpoint) {
          return bottomNavigationBar!;
        }
        return Align(
          alignment: Alignment.center,
          // heightFactor: 1 -> shrink-wrap ke tinggi child (jangan mengisi
          // maxHeight longgar yang diberikan Scaffold untuk area ini).
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: bottomNavigationBar!,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
      floatingActionButton: _wrapFab(),
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      persistentFooterButtons: persistentFooterButtons,
      bottomNavigationBar: _wrapBottomNav(),
      body: body == null
          ? null
          : ResponsiveCenter(maxContentWidth: maxContentWidth, child: body!),
    );
  }
}
