import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/utils/user_friendly_error.dart';
import '../core/events/app_events.dart';
import '../data/models/deposit_analytics_model.dart';

class DepositAnalyticsProvider extends ChangeNotifier {
  DepositAnalytics analytics = const DepositAnalytics();
  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;
  StreamSubscription<AppEvent>? _eventSubscription;
  String? _customerId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _refreshQueued = false;

  DepositAnalyticsProvider() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is DepositChanged || event is OutletSwitched) {
        _refreshAfterDataChange();
      }
    });
  }

  Future<void> fetch({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _customerId = customerId;
    _startDate = startDate;
    _endDate = endDate;
    if (isLoading) {
      _refreshQueued = true;
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final params = <String, String>{};
      if (customerId != null && customerId.isNotEmpty) {
        params['customer_id'] = customerId;
      }
      if (startDate != null && endDate != null) {
        String date(DateTime value) =>
            '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
        params['start_date'] = date(startDate);
        params['end_date'] = date(endDate);
      }
      final query = params.isEmpty
          ? ''
          : '?${Uri(queryParameters: params).query}';
      final response = await ApiClient.get(
        '/finance/report-deposit/analytics$query',
        token: AuthStorage.token,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat analitik deposit');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      analytics = DepositAnalytics.fromJson(
        Map<String, dynamic>.from(data['analytics'] ?? {}),
      );
      hasLoaded = true;
    } catch (error) {
      errorMessage = userFriendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
      if (_refreshQueued) {
        _refreshQueued = false;
        _refreshAfterDataChange();
      }
    }
  }

  void _refreshAfterDataChange() =>
      fetch(customerId: _customerId, startDate: _startDate, endDate: _endDate);

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
