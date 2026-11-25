// lib/providers/status_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../data/models/queue_item_model.dart';
import '../core/events/app_events.dart';

class StatusProvider extends ChangeNotifier {
  final Map<String, List<QueueItem>> _queueData = {};
  Map<String, int> _counts = {};
  final Map<String, int> _currentPage = {};
  final Map<String, bool> _hasMore = {};

  String? _startDate;
  String? _endDate;
  String _filterLabel = "Semua Waktu";
  String _orderBy = "newest";
  bool _isLoading = false;
  Timer? _debounce;
  Future<void>? _initialFetchFuture;
  final Map<String, Future<void>> _queueFetchFutures = {};

  List<QueueItem>? _qrSearchResults;
  String _lastQrValue = '';

  StreamSubscription? _eventSubscription;

  bool get isLoading => _isLoading;
  Map<String, int> get counts => _counts;
  String get filterLabel => _filterLabel;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  String get orderBy => _orderBy;
  List<QueueItem>? get qrSearchResults => _qrSearchResults;
  String get lastQrValue => _lastQrValue;

  StatusProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched) {
        _resetAndFetchInitial();
      } else if (event is OrderStatusChanged) {
        debugPrint(
          "🔔 StatusProvider: OrderStatusChanged detected, refreshing data...",
        );
        fetchInitialData([
          "Antrian",
          "Proses",
          "Siap Ambil",
          "Selesai",
          "Batal",
        ]);
      }
    });
  }

  Future<void> _resetAndFetchInitial() async {
    _queueData.clear();
    _currentPage.clear();
    _hasMore.clear();
    _counts = {};
    notifyListeners();
    await fetchInitialData([
      "Antrian",
      "Proses",
      "Siap Ambil",
      "Selesai",
      "Batal",
    ]);
  }

  List<QueueItem> getItemsByStatus(String status) => _queueData[status] ?? [];
  bool hasMore(String status) => _hasMore[status] ?? true;

  List<String> getAllIdsInStatus(String status) {
    return (_queueData[status] ?? []).map((e) => e.id).toList();
  }

  void setDateFilter({
    String? start,
    String? end,
    String label = "Filter Aktif",
    String? order,
  }) {
    _startDate = start;
    _endDate = end;
    _filterLabel = label;
    if (order != null) _orderBy = order;

    _queueData.clear();
    _currentPage.clear();
    _hasMore.clear();
    notifyListeners();
  }

  Future<void> fetchInitialData(List<String> statuses) async {
    if (_initialFetchFuture != null) return _initialFetchFuture!;

    _initialFetchFuture = _fetchInitialData(statuses);
    try {
      return await _initialFetchFuture!;
    } finally {
      _initialFetchFuture = null;
    }
  }

  Future<void> _fetchInitialData(List<String> statuses) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;

      String queryParams = "?order=$_orderBy";
      if (_startDate != null) queryParams += "&start=$_startDate&end=$_endDate";

      final results = await Future.wait([
        ApiClient.getWithCache('/status/counts$queryParams', token: token),
        ApiClient.getWithCache('/status/aggregated$queryParams', token: token),
      ]);

      if (results[0].statusCode == 200) {
        _counts = Map<String, int>.from(jsonDecode(results[0].body)['data']);
      }

      if (results[1].statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(results[1].body)['data'];
        for (var status in statuses) {
          final List rawList = body[status] ?? [];
          _queueData[status] = rawList
              .map((e) => QueueItem.fromJson(e))
              .toList();
          _currentPage[status] = 2;
          _hasMore[status] = rawList.length >= 20;
        }
      }
    } catch (e) {
      debugPrint("Error fetchInitialData: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchQueue(String status, {bool isRefresh = false}) async {
    final fetchKey = '$status:${isRefresh ? 'refresh' : 'page'}';
    final existingFetch = _queueFetchFutures[fetchKey];
    if (existingFetch != null) return existingFetch;

    final future = _fetchQueue(status, isRefresh: isRefresh);
    _queueFetchFutures[fetchKey] = future;
    try {
      return await future;
    } finally {
      _queueFetchFutures.remove(fetchKey);
    }
  }

  Future<void> _fetchQueue(String status, {bool isRefresh = false}) async {
    if (!isRefresh) {
      if (!(_hasMore[status] ?? true) || _isLoading) return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      int page = isRefresh ? 1 : (_currentPage[status] ?? 1);

      String url =
          '/status/queue?status=$status&page=$page&limit=20&order=$_orderBy';
      if (_startDate != null) url += '&start=$_startDate&end=$_endDate';

      final res = await ApiClient.getWithCache(url, token: token);
      if (res.statusCode == 200) {
        final List rawData = jsonDecode(res.body)['data'] ?? [];
        final List<QueueItem> newItems = rawData
            .map((e) => QueueItem.fromJson(e))
            .toList();

        _hasMore[status] = newItems.length >= 20;
        if (page == 1) {
          _queueData[status] = newItems;
          _currentPage[status] = 2;
        } else {
          _queueData[status] = [...(_queueData[status] ?? []), ...newItems];
          _currentPage[status] = page + 1;
        }
      }
    } catch (e) {
      debugPrint("Error fetchQueue: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatusBulk(
    List<String> ids,
    String newStatus,
    String currentStatus,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.patch(
        '/status/update',
        body: {'ids': ids, 'status': newStatus},
        token: token,
      );

      if (res.statusCode == 200) {
        // Refresh local data
        await fetchInitialData([
          "Antrian",
          "Proses",
          "Siap Ambil",
          "Selesai",
          "Batal",
        ]);

        // TRIGGER EVENT GLOBAL: Agar Dashboard ikut update angka counternya
        appEventBus.add(OrderStatusChanged());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error Update Bulk: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchQueue(String query, Function(List<QueueItem>) onResult) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) return;
      _isLoading = true;
      notifyListeners();
      try {
        final token = AuthStorage.token;
        final res = await ApiClient.get(
          '/status/search?q=$query',
          token: token,
        );
        if (res.statusCode == 200) {
          final List rawData = jsonDecode(res.body)['data'] ?? [];
          onResult(rawData.map((e) => QueueItem.fromJson(e)).toList());
        }
      } catch (e) {
        debugPrint("Error searchQueue: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> handleQrScan(
    String qrResult,
    Function(List<QueueItem>) onResult,
  ) async {
    if (qrResult.isEmpty) return;

    _lastQrValue = qrResult;
    _isLoading = true;
    notifyListeners();

    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get(
        '/status/search?q=$qrResult',
        token: token,
      );
      if (res.statusCode == 200) {
        final List rawData = jsonDecode(res.body)['data'] ?? [];

        // DEBUG - hapus setelah selesai testing
        debugPrint('=== TOTAL HASIL: ${rawData.length}');
        for (var item in rawData) {
          debugPrint(
            '=== ID: ${item['tr_id']} | STATUS: ${item['tr_status_order']} | NAMA: ${item['pelanggan_nama']}',
          );
        }

        _qrSearchResults = rawData.map((e) => QueueItem.fromJson(e)).toList();
        onResult(_qrSearchResults!);
        notifyListeners();
      } else {
        debugPrint('=== API ERROR: ${res.statusCode} | BODY: ${res.body}');
      }
    } catch (e) {
      debugPrint("Error handleQrScan: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearQrSearch() {
    _qrSearchResults = null;
    _lastQrValue = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
