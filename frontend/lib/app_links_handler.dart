// lib/app_links_handler.dart
//
// Menangani deep link masuk (custom scheme: ayocuci://).
// Dipisahkan dari main.dart agar mudah dimaintain dan dites.

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';

class AppLinksHandler {
  final GlobalKey<NavigatorState> navigatorKey;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  AppLinksHandler({required this.navigatorKey});

  /// Mulai mendengarkan deep link. Panggil di initState().
  Future<void> init() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handle(initialUri);
      }
    } catch (e) {
      debugPrint('⛔ Error initial deep link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (err) => debugPrint('⛔ Error deep link stream: $err'),
    );
  }

  /// Hentikan listener. Panggil di dispose().
  void dispose() {
    _linkSubscription?.cancel();
  }

  void _handle(Uri uri) {
    debugPrint('🔗 Deep Link Terdeteksi: $uri');
    if (uri.scheme != 'ayocuci') return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (uri.host == 'payment') {
      if (uri.path == '/finish') {
        CustomToast.show(context, message: 'Pembayaran Berhasil Diproses');

        context.read<KoinProvider>().fetchHistoryKoin();
        context.read<KoinProvider>().fetchActiveTopups();
        context.read<AddonProvider>().fetchActiveAddons();
        context.read<AddonProvider>().refreshData();
        context.read<AppProvider>().fetchAppData(force: true);

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/settings', (route) => false);
      } else if (uri.path == '/error') {
        CustomToast.show(
          context,
          message: 'Pembayaran Gagal atau Dibatalkan',
          isError: true,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
