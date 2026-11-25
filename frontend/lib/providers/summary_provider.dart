// lib/providers/summary_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../data/models/queue_item_model.dart';
import '../core/events/app_events.dart'; // Import event bus

class SummaryProvider extends ChangeNotifier {
  // Menyimpan list item per kategori ringkasan
  final Map<String, List<QueueItem>> _summaryData = {};
  Map<String, int> _counts = {};
  bool _isLoading = false;

  // Subscription untuk mendengarkan event global
  StreamSubscription? _eventSubscription;

  bool get isLoading => _isLoading;
  Map<String, int> get counts => _counts;

  SummaryProvider() {
    _listenToEvents();
  }

  /// Mendengarkan sinyal perubahan status atau perpindahan outlet
  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OrderStatusChanged) {
        debugPrint(
          "SummaryProvider: Perubahan status terdeteksi, refreshing...",
        );
        fetchSummaryData();
      } else if (event is OutletSwitched) {
        debugPrint(
          "SummaryProvider: Outlet berpindah, mereset dan memuat data baru...",
        );
        _resetAndFetch(); // Reset total untuk mencegah data lama terlihat
      }
    });
  }

  /// Menghapus data lama sebelum mengambil data dari outlet baru
  Future<void> _resetAndFetch() async {
    _summaryData.clear();
    _counts = {};
    notifyListeners();
    await fetchSummaryData();
  }

  List<QueueItem> getItemsByCategory(String category) =>
      _summaryData[category] ?? [];

  List<QueueItem> _sanitizeCategoryItems(
    String category,
    List<QueueItem> items,
  ) {
    switch (category) {
      case 'Baru Masuk':
        return items
            .where(
              (item) =>
                  item.statusOrder != 'Selesai' && item.statusOrder != 'Batal',
            )
            .toList();
      default:
        return items;
    }
  }

  /// Ambil data ringkasan (Counts & Agregat Data)
  Future<void> fetchSummaryData() async {
    // Hindari multiple loading jika sudah dalam proses
    _isLoading = true;
    notifyListeners();

    try {
      final token = AuthStorage.token;
      if (token == null) return;

      // Hit endpoint ringkasan: Terlambat, Harus Selesai, Baru Masuk, Selesai.
      final res = await ApiClient.getWithCache(
        '/summary/aggregated',
        token: token,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];

        // Update counts untuk UI badge
        _counts = Map<String, int>.from(data['counts']);

        // Mapping data list per kategori
        final Map<String, dynamic> items = data['items'];
        items.forEach((key, value) {
          final List rawList = value ?? [];
          _summaryData[key] = _sanitizeCategoryItems(
            key,
            rawList.map((e) => QueueItem.fromJson(e)).toList(),
          );
        });
      }
    } catch (e) {
      debugPrint("Error Summary fetch: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel(); // Mencegah memory leak
    super.dispose();
  }
}
