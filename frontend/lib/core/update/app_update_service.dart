import 'dart:convert';

import 'package:ayocucinew/core/update/app_version.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateAvailability { upToDate, optional, mandatory }

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.availability,
    required this.currentVersion,
    required this.currentVersionLabel,
    this.latestVersion,
    this.minimumSupportedVersion,
    this.playStoreUrl,
    this.appStoreUrl,
  });

  final AppUpdateAvailability availability;
  final AppVersion currentVersion;
  final String currentVersionLabel;
  final AppVersion? latestVersion;
  final AppVersion? minimumSupportedVersion;
  final String? playStoreUrl;
  final String? appStoreUrl;

  bool get isOptional => availability == AppUpdateAvailability.optional;
  bool get isMandatory => availability == AppUpdateAvailability.mandatory;
  bool get isUpToDate => availability == AppUpdateAvailability.upToDate;

  String? get latestVersionLabel => latestVersion?.normalizedLabel;
  String? get minimumSupportedVersionLabel =>
      minimumSupportedVersion?.normalizedLabel;
}

class AppUpdateService {
  static const String _fallbackAndroidPackageId = 'id.co.ayocuci.apps';
  static const String _fallbackAppleAppId = '6783661811';
  static const String _dismissedVersionKey = 'dismissed_optional_update_v1';

  static Future<AppUpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = AppVersion.tryParse(
      '${packageInfo.version}+${packageInfo.buildNumber}',
    );
    final current =
        currentVersion ??
        const AppVersion(major: 0, minor: 0, patch: 0, build: 0, raw: '0.0.0');

    try {
      final response = await ApiClient.getWithCache(
        '/app-settings',
        timeout: const Duration(seconds: 8),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};

      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

      // Field iOS terpisah; fallback ke field shared bila iOS belum diisi admin.
      String? pickPlatform(String iosKey, String sharedKey) {
        if (isIOS) {
          final ios = data[iosKey]?.toString().trim();
          if (ios != null && ios.isNotEmpty) return ios;
        }
        return data[sharedKey]?.toString();
      }

      final latest = AppVersion.tryParse(
        pickPlatform('app_version_ios', 'app_version'),
      );
      final minimum = AppVersion.tryParse(
        pickPlatform(
          'minimum_supported_version_ios',
          'minimum_supported_version',
        ),
      );
      final playStoreUrl = data['playstore_url']?.toString().trim();
      final appStoreUrl = data['appstore_url']?.toString().trim();

      if (minimum != null && current.compareTo(minimum) < 0) {
        return AppUpdateCheckResult(
          availability: AppUpdateAvailability.mandatory,
          currentVersion: current,
          currentVersionLabel: current.normalizedLabel,
          latestVersion: latest,
          minimumSupportedVersion: minimum,
          playStoreUrl: playStoreUrl,
          appStoreUrl: appStoreUrl,
        );
      }

      if (latest != null && current.compareTo(latest) < 0) {
        return AppUpdateCheckResult(
          availability: AppUpdateAvailability.optional,
          currentVersion: current,
          currentVersionLabel: current.normalizedLabel,
          latestVersion: latest,
          minimumSupportedVersion: minimum,
          playStoreUrl: playStoreUrl,
          appStoreUrl: appStoreUrl,
        );
      }
    } catch (error) {
      debugPrint('AppUpdateService checkForUpdate error: $error');
    }

    return AppUpdateCheckResult(
      availability: AppUpdateAvailability.upToDate,
      currentVersion: current,
      currentVersionLabel: current.normalizedLabel,
    );
  }

  static Future<bool> shouldShowOptionalPrompt(
    AppUpdateCheckResult result,
  ) async {
    if (!result.isOptional || result.latestVersionLabel == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedVersionKey);
    return dismissed != result.latestVersionLabel;
  }

  static Future<void> dismissOptionalPrompt(AppUpdateCheckResult result) async {
    final latest = result.latestVersionLabel;
    if (latest == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, latest);
  }

  static Future<void> launchStore(
    String? configuredPlayStoreUrl, {
    String? configuredAppStoreUrl,
  }) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    final androidMarketUri = Uri.parse(
      'market://details?id=$_fallbackAndroidPackageId',
    );
    final androidWebUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_fallbackAndroidPackageId',
    );
    final appleWebUri = Uri.parse(
      'https://apps.apple.com/app/id$_fallbackAppleAppId',
    );

    final configuredAndroidUri = _tryParseHttpUri(configuredPlayStoreUrl);
    final configuredAppleUri = _tryParseHttpUri(configuredAppStoreUrl);

    if (isIOS) {
      final target = configuredAppleUri ?? appleWebUri;
      await launchUrl(target, mode: LaunchMode.externalApplication);
      return;
    }

    if (isAndroid && await canLaunchUrl(androidMarketUri)) {
      await launchUrl(androidMarketUri, mode: LaunchMode.externalApplication);
      return;
    }

    final target = configuredAndroidUri ?? androidWebUri;
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }

  static Uri? _tryParseHttpUri(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }
}
