import 'dart:async';
import 'dart:convert';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:flutter/material.dart';
import '../../data/models/notif_model.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotifModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _token;
  Future<void>? _fetchFuture;

  StreamSubscription? _eventSubscription;

  List<NotifModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  NotificationProvider() {
    _listenToEvents();
  }

  // Setup token TANPA auto-fetch untuk menghindari double request saat startup
  void setToken(String? token) {
    if (token == null) return;
    _token = token;
    // fetchNotifications() dihapus dari sini karena sudah dipanggil paralel di AppProvider
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      debugPrint("🎯 Step 3: Provider nangkep event: ${event.runtimeType}");
      if (event is SystemNotificationReceived) {
        debugPrint("🎯 Step 4: Menjalankan fetchNotifications()");
        fetchNotifications();
        Future.delayed(const Duration(milliseconds: 800), fetchNotifications);
      } else if (event is SocketStatusChanged) {
        debugPrint("🎯 Step 4: Socket status changed: ${event.isConnected}");
        // Opsional: Bisa tambahkan logika khusus saat socket connect/disconnect
      } else if (event is OutletSwitched) {
        debugPrint("🎯 Step 4: App data refreshed, fetch notifications...");
        fetchNotifications();
      }
    });
  }

  Future<void> fetchNotifications() async {
    if (_token == null) return;
    if (_fetchFuture != null) return _fetchFuture!;

    _fetchFuture = _fetchNotifications();
    try {
      return await _fetchFuture!;
    } finally {
      _fetchFuture = null;
    }
  }

  Future<void> _fetchNotifications() async {
    if (_notifications.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // FIX: Hapus trailing slash "/" agar tidak kena redirect 301
      final res = await ApiClient.getWithCache("/notifications", token: _token);

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        final List data = body['data'] ?? [];
        _notifications = data.map((e) => NotifModel.fromJson(e)).toList();
        _updateUnreadCount();
      }
    } catch (e) {
      debugPrint("❌ Fetch Notif Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int nrId) async {
    if (_token == null) return;
    try {
      // FIX: Pastikan endpoint bersih dari slash di akhir
      final res = await ApiClient.patch(
        "/notifications/read/$nrId",
        token: _token,
      );
      if (res.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == nrId);
        if (index != -1 && _notifications[index].status == 0) {
          _notifications[index] = _notifications[index].copyWith(status: 1);
          _updateUnreadCount();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ Read Notif Error: $e");
    }
  }

  Future<void> markAllRead() async {
    if (_token == null || _unreadCount == 0) return;
    try {
      // FIX: Bersihkan endpoint
      final res = await ApiClient.patch(
        "/notifications/read-all",
        token: _token,
      );
      if (res.statusCode == 200) {
        _notifications = _notifications
            .map((n) => n.copyWith(status: 1))
            .toList();
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Read All Error: $e");
    }
  }

  Future<void> markSelectedRead(Set<int> ids) async {
    if (_token == null || ids.isEmpty) return;
    try {
      final res = await ApiClient.patch(
        "/notifications/read-selected",
        token: _token,
        body: {"ids": ids.toList()},
      );
      if (res.statusCode == 200) {
        _notifications = _notifications.map((n) {
          return ids.contains(n.id) ? n.copyWith(status: 1) : n;
        }).toList();
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Read Selected Error: $e");
    }
  }

  Future<void> deleteSelected(Set<int> ids) async {
    if (_token == null || ids.isEmpty) return;
    try {
      final res = await ApiClient.patch(
        "/notifications/delete-selected",
        token: _token,
        body: {"ids": ids.toList()},
      );
      if (res.statusCode == 200) {
        _notifications = _notifications
            .where((n) => !ids.contains(n.id))
            .toList();
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Delete Selected Error: $e");
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => n.status == 0).length;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

extension NotifModelX on NotifModel {
  NotifModel copyWith({int? status}) {
    return NotifModel(
      id: id,
      masterId: masterId,
      judul: judul,
      pesan: pesan,
      kategori: kategori,
      imageUrl: imageUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      notificationType: notificationType,
      ctaLabel: ctaLabel,
      schemaVersion: schemaVersion,
      payload: payload,
    );
  }
}
