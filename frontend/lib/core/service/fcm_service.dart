import 'dart:io';
import 'dart:convert';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_navigation_service.dart';

enum NotificationPermissionFlowState { authorized, notDetermined, denied }

class FCMService {
  static const String _channelId = 'ayocuci_brand_alerts_v2';
  static const String _channelSound = 'notif';
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _tokenRetrievalStarted = false;
  static bool _foregroundListenerAttached = false;
  static bool _tapListenerAttached = false;
  static bool _tokenRefreshListenerAttached = false;
  static bool _notificationDialogVisible = false;
  static DateTime? _lastPermissionPromptAt;
  static Future<String?>? _ongoingTokenResolution;

  static void configureNavigation(GlobalKey<NavigatorState> navigatorKey) {
    NotificationNavigationService.configure(navigatorKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      processPendingNavigation();
    });
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Inisialisasi Local Notification tanpa memunculkan prompt permission.
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _queueNavigation(decoded);
          } else if (decoded is Map) {
            _queueNavigation(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('⚠️ Payload notifikasi tidak valid: $e');
        }
      },
    );

    final launchDetails = await _local.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(launchPayload);
        if (decoded is Map) {
          NotificationNavigationService.queue(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Payload initial local notification tidak valid: $e');
      }
    }

    // 2. Setup Android Channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        'Aktivitas penting',
        description:
            'Status top up, add-on, aktivasi outlet, referral, dan informasi akun.',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_channelSound),
      );

      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    if (Platform.isIOS) {

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final settings = await _messaging.getNotificationSettings();
    if (_isAuthorized(settings.authorizationStatus)) {
      _setupTokenRetrieval();
    }

    _attachMessageListeners();

    _isInitialized = true;
  }

  static Future<NotificationPermissionFlowState> getPermissionState() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapPermissionState(settings.authorizationStatus);
  }

  static Future<NotificationPermissionFlowState>
  requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidPermission = await _requestAndroidNotificationPermission();
      debugPrint(
        '🔔 Android notification permission result: $androidPermission',
      );
      if (androidPermission != NotificationPermissionFlowState.authorized) {
        return androidPermission;
      }
    }

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (_isAuthorized(settings.authorizationStatus)) {
      _setupTokenRetrieval();
    }

    return _mapPermissionState(settings.authorizationStatus);
  }

  static Future<NotificationPermissionFlowState>
  _requestAndroidNotificationPermission() async {
    var status = await Permission.notification.status;
    debugPrint(
      '🔔 Android notification permission status before request: $status',
    );

    if (status.isGranted) {
      return NotificationPermissionFlowState.authorized;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return NotificationPermissionFlowState.denied;
    }

    status = await Permission.notification.request();
    debugPrint(
      '🔔 Android notification permission status after request: $status',
    );

    if (status.isGranted) {
      return NotificationPermissionFlowState.authorized;
    }

    return NotificationPermissionFlowState.denied;
  }

  static Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  static Future<Map<String, dynamic>?> getTokenStatus({
    String? tokenOverride,
  }) async {
    try {
      final authToken = AuthStorage.token;
      if (authToken == null || authToken.isEmpty) return null;

      final pushToken = tokenOverride ?? await _messaging.getToken();
      final suffix = pushToken != null && pushToken.isNotEmpty
          ? '?token=${Uri.encodeQueryComponent(pushToken)}'
          : '';
      final response = await ApiClient.get(
        '/auth/push-token/status$suffix',
        token: authToken,
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data']);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Gagal mengambil status token push: $e');
      return null;
    }
  }

  static bool _shouldPromptPermission() {
    final lastPromptAt = _lastPermissionPromptAt;
    if (lastPromptAt == null) return true;
    return DateTime.now().difference(lastPromptAt) > const Duration(minutes: 2);
  }

  static Future<void> ensureNotificationReadiness({
    BuildContext? context,
    bool promptIfNeeded = true,
    String reason = 'general',
  }) async {
    try {
      await init();
      var state = await getPermissionState();

      if (state == NotificationPermissionFlowState.authorized) {
        _setupTokenRetrieval();
        final token = await _resolvePushToken();
        if (token != null && token.isNotEmpty) {
          await syncTokenToBackend(tokenOverride: token);
          final status = await getTokenStatus(tokenOverride: token);
          if (status?['current_token_active'] != true) {
            debugPrint(
              '🔁 FCM token belum aktif di backend, sync ulang ($reason)',
            );
            await syncTokenToBackend(tokenOverride: token);
          }
        }
        return;
      }

      if (!promptIfNeeded || context == null || !context.mounted) {
        return;
      }
      if (_notificationDialogVisible || !_shouldPromptPermission()) {
        return;
      }

      _lastPermissionPromptAt = DateTime.now();

      // Android can report a non-authorized state before the first runtime
      // prompt is shown, so always attempt the platform request first.
      if (Platform.isAndroid &&
          state != NotificationPermissionFlowState.authorized) {
        state = await requestNotificationPermission();
        if (state == NotificationPermissionFlowState.authorized) {
          final token = await _resolvePushToken();
          if (token != null && token.isNotEmpty) {
            await syncTokenToBackend(tokenOverride: token);
          }
          return;
        }
      } else if (state == NotificationPermissionFlowState.notDetermined) {
        state = await requestNotificationPermission();
        if (state == NotificationPermissionFlowState.authorized) {
          final token = await _resolvePushToken();
          if (token != null && token.isNotEmpty) {
            await syncTokenToBackend(tokenOverride: token);
          }
          return;
        }
      }

      if (!context.mounted) return;
      _notificationDialogVisible = true;
      final openSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Notifikasi Belum Aktif'),
            content: const Text(
              'Aktifkan notifikasi AyoCuci agar status pesanan dan broadcast admin tidak terlewat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          );
        },
      );
      _notificationDialogVisible = false;

      if (openSettings == true) {
        await openNotificationSettings();
      }
    } catch (e) {
      _notificationDialogVisible = false;
      debugPrint('⚠️ ensureNotificationReadiness gagal: $e');
    }
  }

  static void _setupTokenRetrieval() async {
    if (_tokenRetrievalStarted) return;
    _tokenRetrievalStarted = true;

    try {
      final token = await _resolvePushToken();
      debugPrint("🚀 FCM TOKEN: $token");
      if (token != null && token.isNotEmpty) {
        await syncTokenToBackend(tokenOverride: token);
      }
    } catch (e) {
      _tokenRetrievalStarted = false;
      debugPrint("❌ Token Error: $e");
    }
  }

  static void _attachMessageListeners() {
    if (!_foregroundListenerAttached) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 FCM foreground: ${message.messageId}');
        _emitEventsFromRemoteMessage(message);
        _showNotification(message);
      });
      _foregroundListenerAttached = true;
    }

    if (!_tapListenerAttached) {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👉 Notification opened app: ${message.messageId}');
        _emitEventsFromRemoteMessage(message);
        _queueNavigation(message.data);
      });
      _tapListenerAttached = true;
    }

    if (!_tokenRefreshListenerAttached) {
      _messaging.onTokenRefresh.listen((token) async {
        debugPrint('🔄 FCM TOKEN REFRESH: $token');
        await syncTokenToBackend(tokenOverride: token);
      });
      _tokenRefreshListenerAttached = true;
    }
  }

  static Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      debugPrint(
        '🚀 App opened from terminated state by notification: ${message.messageId}',
      );
      _emitEventsFromRemoteMessage(message);
      _queueNavigation(message.data);
    }
  }

  static void _emitEventsFromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['message']?.toString();
    _emitEventsFromPayload(message.data, title: title, body: body);
  }

  static void _emitEventsFromPayload(
    Map<String, dynamic> rawData, {
    String? title,
    String? body,
  }) {
    if (rawData.isEmpty &&
        (title == null || title.isEmpty) &&
        (body == null || body.isEmpty)) {
      return;
    }

    final data = Map<String, dynamic>.from(rawData);
    final category = data['category']?.toString().toUpperCase();
    final status = data['status']?.toString().toUpperCase();
    final outletId = data['outlet_id']?.toString() ?? '';
    final entityId = data['id']?.toString() ?? '';
    final resolvedTitle = title ?? 'Notifikasi AyoCuci';
    final resolvedBody = body ?? 'Ada pembaruan data dari AyoCuci.';

    appEventBus.add(
      SystemNotificationReceived(
        title: resolvedTitle,
        message: resolvedBody,
        extraData: data,
      ),
    );

    if (category == 'ADDON' && status != null && status.isNotEmpty) {
      appEventBus.add(
        AddonPaymentStatusChanged(addonId: entityId, status: status),
      );

      if (status == 'SUCCESS') {
        if (entityId.toUpperCase().startsWith('PRO-') || outletId.isNotEmpty) {
          appEventBus.add(OutletActivated(outletId: outletId));
        } else {
          appEventBus.add(AddonActivated());
        }
      }
    }
  }

  static void _queueNavigation(Map<String, dynamic> data) {
    NotificationNavigationService.queue(data);
  }

  static Future<void> processPendingNavigation() async {
    await NotificationNavigationService.processPending();
  }

  static bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static Future<void> syncTokenToBackend({String? tokenOverride}) async {
    try {
      final authToken = AuthStorage.token;
      if (authToken == null || authToken.isEmpty) return;

      final settings = await _messaging.getNotificationSettings();
      if (!_isAuthorized(settings.authorizationStatus)) return;

      final pushToken = tokenOverride ?? await _resolvePushToken();
      if (pushToken == null || pushToken.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final version = '${packageInfo.version}+${packageInfo.buildNumber}';

      final response = await ApiClient.post(
        '/auth/push-token',
        token: authToken,
        body: {
          'token': pushToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'app_version': version,
        },
      );

      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final data = body['data'];
          if (data is Map) {
            final currentActive = data['current_token_active'];
            final activeCount = data['active_token_count'];
            debugPrint(
              '✅ FCM token sync success: active=$currentActive count=$activeCount version=$version',
            );
          } else {
            debugPrint('✅ FCM token sync success: version=$version');
          }
        }
      } catch (_) {
        debugPrint('✅ FCM token sync success: version=$version');
      }
      await processPendingNavigation();
    } catch (e) {
      debugPrint('⚠️ Sync FCM token gagal: $e');
    }
  }

  static Future<void> unregisterTokenFromBackend({
    String? authTokenOverride,
  }) async {
    try {
      final authToken = authTokenOverride ?? AuthStorage.token;
      if (authToken == null || authToken.isEmpty) return;

      final pushToken = await _resolvePushToken(
        waitForApnsOnIOS: false,
        attempts: 1,
      );
      if (pushToken == null || pushToken.isEmpty) return;

      await ApiClient.post(
        '/auth/push-token/unregister',
        token: authToken,
        body: {'token': pushToken},
      );
    } catch (e) {
      debugPrint('⚠️ Unregister FCM token gagal: $e');
    }
  }

  static NotificationPermissionFlowState _mapPermissionState(
    AuthorizationStatus status,
  ) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return NotificationPermissionFlowState.authorized;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionFlowState.notDetermined;
      case AuthorizationStatus.denied:
      case AuthorizationStatus.deniedPermanently:
        return NotificationPermissionFlowState.denied;
    }
  }

  static Future<String?> _resolvePushToken({
    bool waitForApnsOnIOS = true,
    int attempts = 5,
  }) async {
    final ongoing = _ongoingTokenResolution;
    if (ongoing != null) return ongoing;

    final future = _resolvePushTokenInternal(
      waitForApnsOnIOS: waitForApnsOnIOS,
      attempts: attempts,
    );
    _ongoingTokenResolution = future;
    try {
      return await future;
    } finally {
      if (identical(_ongoingTokenResolution, future)) {
        _ongoingTokenResolution = null;
      }
    }
  }

  static Future<String?> _resolvePushTokenInternal({
    required bool waitForApnsOnIOS,
    required int attempts,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if (Platform.isIOS && waitForApnsOnIOS) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null || apnsToken.isEmpty) {
            await Future<void>.delayed(
              Duration(milliseconds: 450 + (attempt * 250)),
            );
            continue;
          }
        }

        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } catch (e) {
        final message = e.toString();
        if (Platform.isIOS &&
            message.contains('apns-token-not-set') &&
            waitForApnsOnIOS) {
          await Future<void>.delayed(
            Duration(milliseconds: 450 + (attempt * 250)),
          );
          continue;
        }
        rethrow;
      }
    }

    if (Platform.isIOS && waitForApnsOnIOS) {
      debugPrint('ℹ️ APNS token belum siap, tunda sync FCM sebentar');
    }
    return null;
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    // iOS foreground pushes are presented natively by the OS (see
    // setForegroundNotificationPresentationOptions in init()) — calling
    // _local.show() here too would duplicate the banner.
    if (Platform.isIOS) return;

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      final styleInformation = await _resolveAndroidStyleInformation(message);

      await _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Aktivitas penting',
            channelDescription:
                'Status top up, add-on, aktivasi outlet, referral, dan informasi akun.',
            icon: android?.smallIcon ?? 'ic_notification',
            sound: const RawResourceAndroidNotificationSound(_channelSound),
            color: const Color(0xFFFF5A36),
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.status,
            styleInformation: styleInformation,
            groupKey: 'id.co.ayocuci.apps.ACTIVITY',
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  static Future<StyleInformation> _resolveAndroidStyleInformation(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final imageUrl = (message.data['image_url'] ?? '').trim();

    if (imageUrl.isEmpty) {
      return BigTextStyleInformation(
        notification?.body ?? '',
        contentTitle: notification?.title,
      );
    }

    try {
      final filePath = await _downloadNotificationImage(imageUrl);
      if (filePath != null) {
        return BigPictureStyleInformation(
          FilePathAndroidBitmap(filePath),
          contentTitle: notification?.title,
          summaryText: notification?.body,
          hideExpandedLargeIcon: true,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Gagal memuat gambar notifikasi: $e');
    }

    return BigTextStyleInformation(
      notification?.body ?? '',
      contentTitle: notification?.title,
    );
  }

  static Future<String?> _downloadNotificationImage(String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final extension = _notificationImageExtension(
      response.headers['content-type'],
      uri.path,
    );
    final file = File(
      '${tempDir.path}/notif_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  static String _notificationImageExtension(String? contentType, String path) {
    final normalizedType = (contentType ?? '').toLowerCase();
    if (normalizedType.contains('png')) return 'png';
    if (normalizedType.contains('webp')) return 'webp';
    if (normalizedType.contains('gif')) return 'gif';

    final uriExtension = path.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(uriExtension)) {
      return uriExtension == 'jpeg' ? 'jpg' : uriExtension;
    }
    return 'jpg';
  }
}
