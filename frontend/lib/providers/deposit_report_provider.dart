import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/events/app_events.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/utils/user_friendly_error.dart';
import '../data/models/deposit_report_model.dart';

class DepositReportProvider extends ChangeNotifier {
  DepositReportHeader header = const DepositReportHeader();
  List<DepositReportEntry> entries = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasLoaded = false;
  String? errorMessage;
  int page = 1;
  bool hasMore = true;
  StreamSubscription<AppEvent>? _eventSubscription;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  String? _lastActivityType;
  String? _lastDepositType;
  String? _lastCustomerId;
  bool _refreshQueued = false;

  DepositReportProvider() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is DepositChanged || event is OutletSwitched) {
        _refreshAfterDataChange();
      }
    });
  }

  Future<void> fetch({
    required DateTime startDate,
    required DateTime endDate,
    String? activityType,
    String? depositType,
    String? customerId,
    bool loadMore = false,
  }) async {
    if (!loadMore) {
      _lastStartDate = startDate;
      _lastEndDate = endDate;
      _lastActivityType = activityType;
      _lastDepositType = depositType;
      _lastCustomerId = customerId;
    }
    if (isLoading) {
      if (!loadMore) _refreshQueued = true;
      return;
    }
    if (loadMore && !hasMore) return;
    final requestedPage = loadMore ? page + 1 : 1;
    isLoading = true;
    isLoadingMore = loadMore;
    errorMessage = null;
    notifyListeners();
    try {
      final params = <String, String>{
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        'page': '$requestedPage',
        'limit': '20',
        if (activityType != null && activityType.isNotEmpty)
          'activity_type': activityType,
        if (depositType != null && depositType.isNotEmpty)
          'deposit_type': depositType,
        if (customerId != null && customerId.isNotEmpty)
          'customer_id': customerId,
      };
      final query = Uri(queryParameters: params).query;
      final response = await ApiClient.get(
        '/finance/report-deposit?$query',
        token: AuthStorage.token,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat laporan deposit');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      if (!loadMore) {
        header = DepositReportHeader.fromJson(
          Map<String, dynamic>.from(data['header'] ?? {}),
        );
      }
      final raw = (data['data'] as List? ?? [])
          .map((e) => DepositReportEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (loadMore) {
        page = requestedPage;
        entries.addAll(raw);
      } else {
        page = 1;
        entries = raw;
        hasLoaded = true;
      }
      hasMore = raw.length >= 20;
    } catch (e) {
      errorMessage = userFriendlyError(e);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
      if (_refreshQueued) {
        _refreshQueued = false;
        _refreshAfterDataChange();
      }
    }
  }

  void _refreshAfterDataChange() {
    final startDate = _lastStartDate;
    final endDate = _lastEndDate;
    if (startDate == null || endDate == null) return;
    if (isLoading) {
      _refreshQueued = true;
      return;
    }
    fetch(
      startDate: startDate,
      endDate: endDate,
      activityType: _lastActivityType,
      depositType: _lastDepositType,
      customerId: _lastCustomerId,
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  /// Loads every matching ledger row without altering the screen state. Export
  /// uses this instead of the paginated list rendered on screen.
  Future<List<DepositReportEntry>> fetchAllForExport({
    required DateTime startDate,
    required DateTime endDate,
    String? activityType,
    String? depositType,
    String? customerId,
  }) async {
    final result = <DepositReportEntry>[];
    var exportPage = 1;
    while (exportPage <= 100) {
      final params = <String, String>{
        'start_date': _date(startDate),
        'end_date': _date(endDate),
        'page': '$exportPage',
        'limit': '100',
        if (activityType != null && activityType.isNotEmpty)
          'activity_type': activityType,
        if (depositType != null && depositType.isNotEmpty)
          'deposit_type': depositType,
        if (customerId != null && customerId.isNotEmpty)
          'customer_id': customerId,
      };
      final response = await ApiClient.get(
        '/finance/report-deposit?${Uri(queryParameters: params).query}',
        token: AuthStorage.token,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat data deposit untuk export');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final rows = (data['data'] as List? ?? [])
          .map(
            (item) =>
                DepositReportEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      result.addAll(rows);
      if (rows.length < 100) break;
      exportPage++;
    }
    return result;
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
