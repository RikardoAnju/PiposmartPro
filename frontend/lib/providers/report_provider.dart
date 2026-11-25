import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/report_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/events/app_events.dart';

class ReportProvider extends ChangeNotifier {
  SummaryReport? _dashboardSummary;
  SummaryReport? _financeSummary;
  List<ChartDataFinance> _chartData = [];
  Map<String, dynamic>? _outletProfile;

  bool _isLoading = false;
  bool _isChartLoading = false;

  StreamSubscription? _eventSubscription;

  SummaryReport? get dashboardSummary => _dashboardSummary;
  SummaryReport? get financeSummary => _financeSummary;
  List<ChartDataFinance> get chartData => _chartData;
  Map<String, dynamic>? get outletProfile => _outletProfile;
  bool get isLoading => _isLoading;
  bool get isChartLoading => _isChartLoading;

  ReportProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OrderStatusChanged ||
          event is ExpenseChanged ||
          event is DepositChanged) {
        fetchSummary(isDashboard: true, forceRefresh: true);
        fetchChartData(forceRefresh: true);
      } else if (event is OutletSwitched || event is OutletProfileUpdated) {
        _resetData();
      }
    });
  }

  void _resetData() {
    _dashboardSummary = null;
    _financeSummary = null;
    _chartData = [];
    _outletProfile = null;
    notifyListeners();
  }

  Future<void> fetchOutletProfile() async {
    try {
      final token = AuthStorage.token;
      if (token == null) return;
      final response = await ApiClient.getWithCache(
        '/outlet/profile',
        token: token,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        _outletProfile = body['data'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetch outlet profile: $e");
    }
  }

  Future<void> fetchSummary({
    DateTime? start,
    DateTime? end,
    bool isDashboard = false,
    bool forceRefresh = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final startDate = start ?? DateTime.now();
      final endDate = end ?? DateTime.now();
      final String formattedStart = DateFormat('yyyy-MM-dd').format(startDate);
      final String formattedEnd = DateFormat('yyyy-MM-dd').format(endDate);

      final url =
          '/finance/dashboard/summary?start_date=$formattedStart&end_date=$formattedEnd';
      final response = forceRefresh
          ? await ApiClient.get(url, token: token)
          : await ApiClient.getWithCache(url, token: token);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        if (isDashboard) {
          _dashboardSummary = SummaryReport.fromJson(body['data']);
        } else {
          _financeSummary = SummaryReport.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetch report summary: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchChartData({
    DateTime? start,
    DateTime? end,
    bool forceRefresh = false,
  }) async {
    _isChartLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final startDate =
          start ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endDate = end ?? DateTime.now();
      final String formattedStart = DateFormat('yyyy-MM-dd').format(startDate);
      final String formattedEnd = DateFormat('yyyy-MM-dd').format(endDate);

      final url =
          '/finance/dashboard/chart?start_date=$formattedStart&end_date=$formattedEnd';
      final response = forceRefresh
          ? await ApiClient.get(url, token: token)
          : await ApiClient.getWithCache(url, token: token);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        final List rawList = body['data'] ?? [];
        _chartData = rawList.map((e) => ChartDataFinance.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetch chart data: $e");
    } finally {
      _isChartLoading = false;
      notifyListeners();
    }
  }

  Future<void> initReportDashboard() async {
    if (_outletProfile == null) {
      await fetchOutletProfile();
    }
    if (_dashboardSummary == null) {
      await fetchSummary(isDashboard: true);
    }
  }

  Future<void> initFinanceChart({DateTime? month}) async {
    final date = month ?? DateTime.now();
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    await Future.wait([
      fetchSummary(start: start, end: end),
      fetchChartData(start: start, end: end),
    ]);
  }

  void clearData() {
    _dashboardSummary = null;
    _financeSummary = null;
    _chartData = [];
    _outletProfile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
