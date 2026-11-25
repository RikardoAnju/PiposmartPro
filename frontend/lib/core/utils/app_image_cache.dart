import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppImageCache {
  const AppImageCache._();

  static const List<String> shellAssets = [
    'assets/icons/ic_splascreen.webp',
    'assets/icons/Logo Ayocuci fix parah.webp',
    'assets/icons/layanan.webp',
    'assets/icons/home/pelanggan_new.webp',
    'assets/icons/home/karyawan_new.webp',
    'assets/icons/pengeluaran.webp',
    'assets/icons/laporan.webp',
    'assets/icons/outlet.webp',
    'assets/icons/home/Home_nav.png',
    'assets/icons/home/Status_nav.png',
    'assets/icons/home/Ringkasan_nav.png',
    'assets/icons/home/Profile_nav.png',
    'assets/icons/home/Setting.webp',
  ];

  static const List<String> secondaryAssets = [
    'assets/icons/ic_logo.webp',
    'assets/icons/ic_logo_home.webp',
    'assets/icons/icon_cash.webp',
    'assets/icons/icon_qris.webp',
    'assets/icons/icon_bank.webp',
    'assets/icons/icon_Ewallet.webp',
    'assets/icons/ic_koin.webp',
    'assets/icons/ic_tgl_masuk.webp',
    'assets/icons/ic_estimasi_selesai.webp',
    'assets/icons/ic_status_selesai.webp',
    'assets/icons/ic_parfume.webp',
    'assets/images/google_logo.webp',
    'assets/images/aktivasi_acc.webp',
  ];

  static void configureGlobalImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 220;
    cache.maximumSizeBytes = 96 << 20;
  }

  static Future<void> precacheShellAssets(BuildContext context) {
    return _precacheAssets(context, shellAssets, cacheWidth: 180);
  }

  static Future<void> precacheAuthAssets(BuildContext context) {
    return _precacheAssets(context, [
      'assets/icons/logo/logo_login_screen.webp',
      'assets/icons/logo/logo_ayocuci_512x512_ios.png',
      ...secondaryAssets,
    ], cacheWidth: 180);
  }

  static Future<void> precacheHeaderBrandAsset(BuildContext context) {
    return _precacheAssets(context, const [
      'assets/icons/logo/logo_login_screen.webp',
    ], cacheWidth: 220);
  }

  static void warmSecondaryAssets(BuildContext context) {
    _runAfterFirstFrame(() {
      unawaited(_precacheAssets(context, secondaryAssets, cacheWidth: 180));
    });
  }

  static Future<void> precacheNetworkImages(
    BuildContext context,
    Iterable<String> urls, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final uniqueUrls = urls.where((url) => url.trim().isNotEmpty).toSet();
    if (uniqueUrls.isEmpty) return;

    await Future.wait(
      uniqueUrls.map(
        (url) => precacheImage(CachedNetworkImageProvider(url), context),
      ),
      eagerError: false,
    ).timeout(timeout, onTimeout: () => <void>[]);
  }

  static void warmNetworkImages(BuildContext context, Iterable<String> urls) {
    _runAfterFirstFrame(() {
      unawaited(precacheNetworkImages(context, urls));
    });
  }

  static Future<void> _precacheAssets(
    BuildContext context,
    Iterable<String> assets, {
    int? cacheWidth,
  }) async {
    await Future.wait(
      assets.map((path) {
        final provider = cacheWidth == null
            ? AssetImage(path)
            : ResizeImage.resizeIfNeeded(cacheWidth, null, AssetImage(path));
        return precacheImage(provider, context);
      }),
      eagerError: false,
    );
  }

  static void _runAfterFirstFrame(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) => callback());
  }
}
