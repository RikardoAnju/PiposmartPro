import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../shared/widgets/custom_toast.dart';
import '../utils/auth_storage.dart';
import '../utils/api_client.dart';
import '../../screens/status/detail/detail_orderan_sereen.dart';
import '../../data/models/addon_model.dart';
import '../../data/models/customer_model.dart';
import '../../screens/operational/customer/customer_deposit_screen.dart';
import '../../screens/operational/customer/customer_deposit_history_screen.dart';
import '../../data/models/customer_deposit_model.dart';
import '../../screens/operational/customer/customer_detail_screen.dart';
import '../../screens/settings/aktivasi/widgets/detail_addon_trx_screen.dart';
import '../../screens/settings/koin/detail_topup_screen.dart';
import '../../screens/settings/referral/hadiah/reward_history_screen.dart';
import '../../data/models/pengeluaran_model.dart';
import '../../screens/operational/pengeluaran/pengeluaran_item_detail_screen.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Map<String, dynamic>? _pendingPayload;
  static String? _currentRouteName;
  static const _dedupKeyPreference = 'notification_last_navigation_key';
  static const _dedupTimePreference = 'notification_last_navigation_time';
  static const _dedupWindow = Duration(seconds: 8);
  static const _bootstrapRoutes = {'/', '/login', '/onboarding', '/register'};

  static NavigatorObserver get observer => _NotificationNavigationObserver();

  static void configure(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final result = Map<String, dynamic>.from(raw);
    final nested = result['payload'];
    if (nested is String && nested.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(nested);
        if (decoded is Map) result.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    } else if (nested is Map) {
      result.addAll(Map<String, dynamic>.from(nested));
    }

    result['target'] ??= _legacyTarget(result);
    result['schema_version'] ??= 0;
    return result;
  }

  static void queue(Map<String, dynamic> raw) {
    if (raw.isEmpty) return;
    _pendingPayload = normalize(raw);
    processPending();
  }

  static Future<bool> open(Map<String, dynamic> raw) async {
    _pendingPayload = normalize(raw);
    return processPending();
  }

  /// Only entity notifications with an explicit destination can skip the inbox detail.
  static bool canOpenDirectly(Map<String, dynamic> raw) {
    final payload = normalize(raw);
    final target = payload['target']?.toString();
    return target != null &&
        (target == 'transaction_detail' ||
            target == 'referral_payout_detail' ||
            _isResolvedEntityTarget(target)) &&
        _entityID(payload) != null;
  }

  static bool hasUsefulAction(Map<String, dynamic> raw) {
    final payload = normalize(raw);
    final target = payload['target']?.toString();
    if (target == null ||
        target.isEmpty ||
        target == 'home' ||
        target == 'notification_detail' ||
        target == 'notification_inbox') {
      return false;
    }
    return _routeForTarget(target) != null &&
        (!(_isResolvedEntityTarget(target) ||
                target == 'transaction_detail' ||
                target == 'referral_payout_detail') ||
            _entityID(payload) != null);
  }

  static Future<bool> processPending() async {
    final payload = _pendingPayload;
    final navigator = _navigatorKey?.currentState;
    if (payload == null || navigator == null) return false;
    if (AuthStorage.token == null || AuthStorage.token!.isEmpty) return false;
    final currentRoute = _currentRouteName;
    if (currentRoute == null || _bootstrapRoutes.contains(currentRoute)) {
      debugPrint(
        '⏸️ Deeplink notifikasi ditahan sampai aplikasi siap: $currentRoute',
      );
      return false;
    }

    final navigationKey = [
      payload['master_id'],
      payload['target'],
      _entityID(payload),
    ].join(':');
    if (await _isDuplicateNavigation(navigationKey)) {
      _pendingPayload = null;
      return true;
    }

    if (!navigator.mounted) return false;
    final context = navigator.context;
    if (!context.mounted) return false;
    final target = payload['target']?.toString() ?? 'notification_detail';
    debugPrint(
      '🧭 Deeplink notifikasi: target=$target entity=${_entityID(payload)} route=$currentRoute',
    );
    unawaited(_recordEvent(payload, 'opened'));
    if (!await _ensureOutlet(context, payload)) {
      _pendingPayload = null;
      unawaited(
        _recordEvent(
          payload,
          'navigation_fallback',
          reason: 'outlet_switch_failed',
        ),
      );
      return false;
    }
    if (!_hasTargetAccess(navigator, target)) {
      _pendingPayload = null;
      _showPermissionDenied(navigator);
      unawaited(
        _recordEvent(payload, 'navigation_denied', reason: 'permission_denied'),
      );
      await navigator.pushNamed('/notifications');
      return false;
    }

    final route = _routeForTarget(target);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _pendingPayload = null;
    if (target == 'transaction_detail') {
      final transactionID = _entityID(payload);
      if (transactionID != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => DetailPesananScreen(transactionId: transactionID),
          ),
        );
        await _rememberNavigation(navigationKey);
        unawaited(_recordEvent(payload, 'navigation_success'));
        return true;
      }
    }
    if (target == 'referral_payout_detail') {
      final payoutID = _entityID(payload);
      if (payoutID != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => RewardHistoryScreen(initialPayoutId: payoutID),
          ),
        );
        await _rememberNavigation(navigationKey);
        unawaited(_recordEvent(payload, 'navigation_success'));
        return true;
      }
    }
    if (_isResolvedEntityTarget(target)) {
      final navigated = await _navigateResolvedEntity(
        navigator,
        payload,
        target,
      );
      if (navigated) {
        await _rememberNavigation(navigationKey);
        unawaited(_recordEvent(payload, 'navigation_success'));
        return true;
      }
      unawaited(
        _recordEvent(payload, 'navigation_fallback', reason: 'entity_missing'),
      );
      return false;
    }
    if (route == null) {
      unawaited(
        _recordEvent(payload, 'navigation_fallback', reason: 'unknown_target'),
      );
      navigator.pushNamed('/notifications');
      return false;
    }
    navigator.pushNamed(route, arguments: payload);
    await _rememberNavigation(navigationKey);
    unawaited(_recordEvent(payload, 'navigation_success'));
    return true;
  }

  static Future<bool> _isDuplicateNavigation(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final previousKey = preferences.getString(_dedupKeyPreference);
    final previousTime = preferences.getInt(_dedupTimePreference);
    if (previousKey != key || previousTime == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(previousTime),
    );
    return !elapsed.isNegative && elapsed <= _dedupWindow;
  }

  static Future<void> _rememberNavigation(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_dedupKeyPreference, key),
      preferences.setInt(
        _dedupTimePreference,
        DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
  }

  static bool _hasTargetAccess(NavigatorState navigator, String target) {
    if (!navigator.mounted) return false;
    return _hasAccess(navigator.context.read<AuthProvider>(), target);
  }

  static void _showPermissionDenied(NavigatorState navigator) {
    if (!navigator.mounted) return;
    CustomToast.show(
      navigator.context,
      message: 'Akun ini tidak memiliki akses ke tujuan notifikasi.',
      isError: true,
    );
  }

  static Future<bool> _ensureOutlet(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final targetOutletID = payload['outlet_id']?.toString().trim();
    if (targetOutletID == null || targetOutletID.isEmpty) return true;

    final app = context.read<AppProvider>();
    final currentOutletID = app.outlet?.id.trim();
    if (currentOutletID == targetOutletID) return true;

    final available = app.outlets.any((outlet) => outlet.id == targetOutletID);
    if (!available) {
      CustomToast.show(
        context,
        message: 'Outlet tujuan notifikasi tidak tersedia untuk akun ini.',
        isError: true,
      );
      return false;
    }

    final result = await app.switchOutlet(targetOutletID);
    if (result['success'] == true) return true;
    if (context.mounted) {
      CustomToast.show(
        context,
        message:
            result['message']?.toString() ?? 'Gagal membuka outlet tujuan.',
        isError: true,
      );
    }
    return false;
  }

  static String _legacyTarget(Map<String, dynamic> data) {
    if (data.containsKey('topup_id')) return 'coin_topup_detail';
    if (data.containsKey('payout_id')) return 'referral_payout_detail';
    final category = data['category']?.toString().toUpperCase();
    switch (category) {
      case 'KOIN':
        return 'coin_management';
      case 'ADDON':
        return 'addon_purchases';
      case 'REFERRAL':
        return 'referral_dashboard';
      default:
        return 'notification_detail';
    }
  }

  static String? _routeForTarget(String target) {
    switch (target) {
      case 'home':
        return '/home';
      case 'service-list':
        return '/service-list';
      case 'notification_detail':
      case 'notification_inbox':
        return '/notifications';
      case 'coin_management':
      case 'coin_topup_detail':
        return '/coin-management';
      case 'addon_purchases':
      case 'addon_purchase_detail':
        return '/addon-purchases';
      case 'pro_activation':
        return '/aktivasi-akun';
      case 'referral_dashboard':
      case 'referral_payout_detail':
        return '/referral';
      case 'transaction_list':
      case 'transaction_detail':
        return '/all-transactions';
      case 'customer_list':
      case 'customer_detail':
      case 'customer_deposit':
      case 'customer_deposit_entry':
        return '/customer-list';
      case 'expense_list':
      case 'expense_detail':
        return '/expense-list';
      case 'report_dashboard':
        return '/laporan';
      default:
        return null;
    }
  }

  static bool _hasAccess(AuthProvider auth, String target) {
    switch (target) {
      case 'customer_list':
      case 'customer_detail':
      case 'customer_deposit':
      case 'customer_deposit_entry':
        return auth.canAccess('pelanggan', 'read');
      case 'expense_list':
      case 'expense_detail':
        return auth.canAccess('pengeluaran', 'read');
      case 'report_dashboard':
        return auth.canReadAnyReport;
      case 'transaction_list':
      case 'transaction_detail':
        return auth.canAccess('transaksi', 'read');
      case 'referral_dashboard':
      case 'referral_payout_detail':
      case 'coin_management':
      case 'coin_topup_detail':
      case 'addon_purchases':
      case 'addon_purchase_detail':
      case 'pro_activation':
        return auth.isOwnerOrAdmin;
      default:
        return true;
    }
  }

  static String? _entityID(Map<String, dynamic> payload) {
    final value =
        payload['entity_id'] ??
        payload['transaction_id'] ??
        payload['topup_id'] ??
        payload['payout_id'] ??
        payload['id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  static bool _isResolvedEntityTarget(String target) => const {
    'customer_detail',
    'customer_deposit',
    'customer_deposit_entry',
    'coin_topup_detail',
    'addon_purchase_detail',
    'expense_detail',
  }.contains(target);

  static Future<bool> _navigateResolvedEntity(
    NavigatorState navigator,
    Map<String, dynamic> payload,
    String target,
  ) async {
    final entityID = _entityID(payload);
    final token = AuthStorage.token;
    if (entityID == null || token == null) return false;
    try {
      if (target == 'customer_detail' ||
          target == 'customer_deposit' ||
          (target == 'customer_deposit_entry' &&
              payload['parent_id'] == null)) {
        final response = await ApiClient.get(
          '/pelanggan/$entityID',
          token: token,
        );
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body);
        if (body['data'] is! Map) return false;
        final customer = Customer.fromJson(
          Map<String, dynamic>.from(body['data']),
        );
        navigator.push(
          MaterialPageRoute(
            builder: (_) => target == 'customer_detail'
                ? CustomerDetailScreen(customer: customer)
                : CustomerDepositScreen(customer: customer),
          ),
        );
        return true;
      }

      if (target == 'customer_deposit_entry') {
        final customerID = payload['parent_id']?.toString().trim();
        if (customerID == null || customerID.isEmpty) return false;
        final responses = await Future.wait([
          ApiClient.get('/pelanggan/$customerID', token: token),
          ApiClient.get(
            '/pelanggan/$customerID/deposit/ledger/$entityID',
            token: token,
          ),
        ]);
        if (responses.any((response) => response.statusCode != 200)) {
          return false;
        }
        final customerBody = jsonDecode(responses[0].body);
        final ledgerBody = jsonDecode(responses[1].body);
        if (customerBody['data'] is! Map || ledgerBody['data'] is! Map) {
          return false;
        }
        final customer = Customer.fromJson(
          Map<String, dynamic>.from(customerBody['data']),
        );
        final entry = CustomerDepositLedgerEntry.fromJson(
          Map<String, dynamic>.from(ledgerBody['data']),
        );
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                CustomerDepositDetailScreen(customer: customer, entry: entry),
          ),
        );
        return true;
      }

      if (target == 'addon_purchase_detail') {
        final response = await ApiClient.get(
          '/addons/history/$entityID',
          token: token,
        );
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data is! Map || data['header'] is! Map) return false;
        final transaction = TransaksiAddon.fromJson(
          Map<String, dynamic>.from(data['header']),
        );
        final expectedStatus = payload['status']?.toString().toUpperCase();
        if (transaction.id != entityID ||
            transaction.metodeBayar.trim().isEmpty ||
            (expectedStatus != null &&
                expectedStatus.isNotEmpty &&
                transaction.status.toUpperCase() != expectedStatus)) {
          return false;
        }
        navigator.push(
          MaterialPageRoute(
            builder: (_) => DetailAddonTrxScreen(transaction: transaction),
          ),
        );
        return true;
      }

      if (target == 'coin_topup_detail') {
        final response = await ApiClient.get('/koin/all-topups', token: token);
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body);
        final rows = body['data'];
        if (rows is! List) return false;
        final match = rows.cast<dynamic>().whereType<Map>().firstWhere(
          (row) => row['tk_id']?.toString() == entityID,
          orElse: () => <String, dynamic>{},
        );
        if (match.isEmpty) return false;
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                DetailTopupScreen(topup: Map<String, dynamic>.from(match)),
          ),
        );
        return true;
      }

      if (target == 'expense_detail') {
        final response = await ApiClient.get(
          '/expenses/$entityID',
          token: token,
        );
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body);
        if (body['data'] is! Map) return false;
        final expense = Pengeluaran.fromJson(
          Map<String, dynamic>.from(body['data']),
        );
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PengeluaranItemDetailScreen(item: expense),
          ),
        );
        return true;
      }
    } catch (error) {
      debugPrint('⚠️ Gagal resolve entity notifikasi: $error');
    }
    return false;
  }

  static Future<void> _recordEvent(
    Map<String, dynamic> payload,
    String eventType, {
    String reason = '',
  }) async {
    final masterID = payload['master_id']?.toString().trim();
    final token = AuthStorage.token;
    if (masterID == null ||
        masterID.isEmpty ||
        token == null ||
        token.isEmpty) {
      return;
    }
    try {
      final package = await PackageInfo.fromPlatform();
      await ApiClient.post(
        '/notifications/events',
        token: token,
        body: {
          'master_id': masterID,
          'event_type': eventType,
          'target': payload['target']?.toString() ?? '',
          'reason': reason,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app_version': '${package.version}+${package.buildNumber}',
        },
      );
    } catch (error) {
      debugPrint('⚠️ Gagal mencatat event notifikasi: $error');
    }
  }
}

class _NotificationNavigationObserver extends NavigatorObserver {
  void _resume(Route<dynamic>? route) {
    final name = route?.settings.name ?? '<unnamed>';
    NotificationNavigationService._currentRouteName = name;
    if (NotificationNavigationService._bootstrapRoutes.contains(name)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationNavigationService.processPending());
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _resume(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _resume(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _resume(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _resume(previousRoute);
  }
}
