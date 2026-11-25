// lib/screens/auth/splash_screen.dart

import 'dart:async';

import 'package:ayocucinew/core/update/app_update_service.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/app_image_cache.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/content_provider.dart';
import 'package:ayocucinew/screens/auth/onboarding_screen.dart';
import 'package:ayocucinew/shared/widgets/app_update_prompt_card.dart';
import 'package:ayocucinew/shared/widgets/update_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  AppUpdateCheckResult? _blockingUpdate;
  bool _isChecking = false;
  bool _isRetryingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  /// Logika pengecekan status login dan inisialisasi data awal
  Future<void> _checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;
    final authProv = context.read<AuthProvider>();
    final appProv = context.read<AppProvider>();
    final contentProv = context.read<ContentProvider>();
    try {
      final updateCheck = await AppUpdateService.checkForUpdate();
      if (!mounted) return;

      if (updateCheck.isMandatory) {
        setState(() => _blockingUpdate = updateCheck);
        return;
      }

      if (_blockingUpdate != null) {
        setState(() => _blockingUpdate = null);
      }

      if (updateCheck.isOptional &&
          await AppUpdateService.shouldShowOptionalPrompt(updateCheck)) {
        if (!mounted) return;
        await _showOptionalUpdatePrompt(updateCheck);
      }
      if (!mounted) return;

      appProv.setContext(context);

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final hasSeenOnboarding =
          prefs.getBool(OnboardingScreen.seenKey) ?? false;

      if (!hasSeenOnboarding) {
        await Future.wait([
          _bestEffort(
            AppImageCache.precacheAuthAssets(context),
            timeout: const Duration(milliseconds: 1200),
          ),
          _bestEffort(
            AppImageCache.precacheShellAssets(context),
            timeout: const Duration(milliseconds: 1500),
          ),
        ]);
        if (!mounted) return;

        await AppImageCache.precacheHeaderBrandAsset(context);
        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }

      final isLoggedIn = await Future.wait([
        _restoreAndCheckLogin(authProv),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ]).then((results) => results.first as bool);
      if (!mounted) return;

      if (!isLoggedIn) {
        await Future.wait([
          _bestEffort(
            AppImageCache.precacheAuthAssets(context),
            timeout: const Duration(milliseconds: 1200),
          ),
          _bestEffort(
            AppImageCache.precacheShellAssets(context),
            timeout: const Duration(milliseconds: 1500),
          ),
        ]);
        if (!mounted) return;

        await AppImageCache.precacheHeaderBrandAsset(context);
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/login',
        );
        return;
      }

      debugPrint("🚀 Auto Login Success, preparing home shell...");

      await Future.wait([
        _bestEffort(
          appProv.fetchAppData(force: true),
          timeout: const Duration(milliseconds: 2800),
        ),
        _bestEffort(
          AppImageCache.precacheShellAssets(context),
          timeout: const Duration(milliseconds: 1200),
        ),
      ]);
      if (!mounted) return;

      // Header brand must already be decoded before the first home frame.
      await AppImageCache.precacheHeaderBrandAsset(context);
      if (!mounted) return;

      AppImageCache.warmSecondaryAssets(context);
      unawaited(_warmHomeContentImages(contentProv));

      final String? outletId = appProv.outlet?.id.toString();
      if (outletId != null && outletId.isNotEmpty) {
        appProv.initRealtime(outletId);
      }

      Navigator.pushReplacementNamed(context, '/home');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showOptionalUpdatePrompt(AppUpdateCheckResult result) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'update-optional',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, animation) {
        return AppUpdatePromptView(
          kind: AppUpdatePromptKind.optional,
          currentVersion: result.currentVersionLabel,
          targetVersion: result.latestVersionLabel ?? '-',
          primaryLabel: defaultTargetPlatform == TargetPlatform.iOS
              ? 'Buka App Store'
              : 'Update Sekarang',
          onPrimaryPressed: () async {
            await AppUpdateService.launchStore(
              result.playStoreUrl,
              configuredAppStoreUrl: result.appStoreUrl,
            );
            await AppUpdateService.dismissOptionalPrompt(result);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          secondaryLabel: 'Nanti',
          onSecondaryPressed: () async {
            await AppUpdateService.dismissOptionalPrompt(result);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _retryAfterUpdate() async {
    if (_isRetryingUpdate) return;
    setState(() => _isRetryingUpdate = true);
    _isChecking = false;
    try {
      await _checkStatus();
    } finally {
      if (mounted) {
        setState(() => _isRetryingUpdate = false);
      } else {
        _isRetryingUpdate = false;
      }
    }
  }

  Future<bool> _restoreAndCheckLogin(AuthProvider authProv) async {
    await authProv.restoreSession();
    return authProv.tryAutoLogin().timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
  }

  Future<void> _warmHomeContentImages(ContentProvider contentProv) async {
    await _bestEffort(
      contentProv.fetchContent(),
      timeout: const Duration(seconds: 5),
    );
    if (!mounted) return;

    await _bestEffort(
      AppImageCache.precacheNetworkImages(
        context,
        _homeContentImageUrls(contentProv),
      ),
      timeout: const Duration(seconds: 4),
    );
  }

  Future<void> _bestEffort(
    Future<void> future, {
    required Duration timeout,
  }) async {
    try {
      await future.timeout(timeout);
    } catch (_) {
      // Startup should continue even when preload is slow or offline.
    }
  }

  Iterable<String> _homeContentImageUrls(ContentProvider contentProv) {
    return [
      ...contentProv.promos
          .take(3)
          .map(
            (item) =>
                ApiClient.resolveImageVariantUrl(item.imageUrl, width: 720),
          ),
      ...contentProv.infos
          .take(3)
          .map(
            (item) =>
                ApiClient.resolveImageVariantUrl(item.imageUrl, width: 720),
          ),
    ].where((url) => url.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final blockingUpdate = _blockingUpdate;
    if (blockingUpdate != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: UpdateRequiredView(
          currentVersion: blockingUpdate.currentVersionLabel,
          minimumVersion:
              blockingUpdate.minimumSupportedVersionLabel ??
              blockingUpdate.latestVersionLabel ??
              '-',
          isRetrying: _isRetryingUpdate,
          onUpdatePressed: () => AppUpdateService.launchStore(
            blockingUpdate.playStoreUrl,
            configuredAppStoreUrl: blockingUpdate.appStoreUrl,
          ),
          onRetryPressed: _retryAfterUpdate,
        ),
      );
    }

    // Mengunci status bar agar teks berwarna putih di atas background oranye
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        // Menggunakan warna branding primer AyoCuci
        backgroundColor: AppPalette.primaryDeep,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/icons/ic_splascreen.webp',
                  width: 250,
                  // Fallback jika file asset hilang/error
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.wash_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
