import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/events/app_events.dart';

class SettingProvider extends ChangeNotifier {
  Map<String, dynamic>? _outletData;
  Map<String, dynamic>? _appSettings;
  bool _isLoading = false;
  String? _currentOutletId; // ✅ Track outlet ID aktif
  final _storage = const FlutterSecureStorage();

  StreamSubscription? _eventSubscription;

  Map<String, dynamic>? get outletData => _outletData;
  Map<String, dynamic>? get appSettings => _appSettings;
  bool get isLoading => _isLoading;

  int _totalPegawaiRiil = 0;
  int get totalPegawaiRiil => _totalPegawaiRiil;

  SettingProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched) {
        debugPrint("SettingProvider: Outlet switched, clearing stale data...");
        // ✅ Clear data lama dulu supaya UI tidak tampil data outlet lama
        _outletData = null;
        _currentOutletId = null;
        notifyListeners();

        // ✅ Delay kecil untuk pastikan storage sudah ditulis oleh proses switch
        Future.delayed(const Duration(milliseconds: 200), () {
          fetchSettingsData();
        });
      } else if (event is AppDataReady ||
          event is OutletProfileUpdated ||
          event is OutletActivated) {
        debugPrint("SettingProvider: App data ready, syncing settings...");
        fetchSettingsData(silent: _outletData != null);
      } else if (event is SystemNotificationReceived) {
        debugPrint("SettingProvider: Refreshing full data...");
        fetchSettingsData(silent: true);
      }

      if (event is CoinBalanceChanged) {
        debugPrint("💰 SettingProvider: Real-time balance update triggered!");
        refreshBalanceOnly();
      }
    });
  }

  // --- GETTERS ---

  String get formattedKoin {
    final koin = _outletData?['ot_koin'] ?? 0;
    return NumberFormat.currency(
      locale: 'id',
      symbol: '',
      decimalDigits: 0,
    ).format(koin).trim();
  }

  String get daysLeft {
    if (_outletData == null) return "-";

    if (_outletData?['ot_activated_at'] != null) {
      return "PRO Permanen";
    }

    final trialAtStr = _outletData?['ot_trial_at'];
    if (trialAtStr != null) {
      try {
        final trialDate = DateTime.parse(trialAtStr);
        final now = DateTime.now();
        final difference = math.max(0, trialDate.difference(now).inDays);

        if (difference == 0) return "Trial Habis";
        return "$difference Hari (Trial)";
      } catch (e) {
        return "-";
      }
    }

    return "Belum Aktivasi";
  }

  bool get isTrialAccount => _outletData?['ot_activated_at'] == null;

  int get maxPegawai => _outletData?['ot_max_pegawai'] ?? 2;

  // --- ACTIONS ---

  Future<void> refreshBalanceOnly() async {
    try {
      final token = AuthStorage.token;
      if (token == null) return;

      final outletId = await _storage.read(key: 'current_outlet_id');
      // ✅ Guard: jangan update kalau outlet sudah berbeda
      if (_currentOutletId != null && _currentOutletId != outletId) {
        debugPrint(
          "SettingProvider: Skipping balance refresh, outlet mismatch.",
        );
        return;
      }

      final response = await ApiClient.get(
        '/outlet/profile',
        token: token,
        // ✅ Kirim outlet ID eksplisit jika API support query param
        // queryParams: {'outlet_id': outletId},
      );
      final profileRes = jsonDecode(response.body);

      if (response.statusCode == 200 && profileRes['status'] == true) {
        // ✅ Pastikan response untuk outlet yang sama
        final responseOutletId = profileRes['data']?['ot_id']?.toString();
        if (responseOutletId != null && responseOutletId != outletId) {
          debugPrint("SettingProvider: Stale balance response, ignoring.");
          return;
        }

        _outletData = profileRes['data'];
        notifyListeners();
        debugPrint("✅ SettingProvider: Balance Synced.");
      }
    } catch (e) {
      debugPrint("SettingProvider Balance Sync Error: $e");
    }
  }

  /// Load Full Settings (Kini hanya perlu hit profile outlet karena data addon ada di sana)
  // Update fungsi fetchSettingsData
  Future<void> fetchSettingsData({bool silent = false}) async {
    // Baca outlet ID terbaru jika sudah ada. Pada first login nilainya bisa
    // belum tertulis, jadi profile response tetap dipakai sebagai source of truth.
    final outletId = await _storage.read(key: 'current_outlet_id');

    if (outletId != null && outletId.trim().isNotEmpty) {
      _currentOutletId = outletId;
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final token = AuthStorage.token;
      if (token == null) return;

      // 1. Fetch Profile Outlet
      final response = await ApiClient.get('/outlet/profile', token: token);
      final profileRes = jsonDecode(response.body);

      // 2. Fetch List Pegawai buat dapet total riil (Nggak cuma limit)
      final empResponse = await ApiClient.get('/employees', token: token);
      final empRes = jsonDecode(empResponse.body);

      // 3. Fetch App Settings (Global)
      final appSettingsResponse = await ApiClient.get(
        '/app-settings',
        token: token,
      );
      final appSettingsRes = jsonDecode(appSettingsResponse.body);

      if (appSettingsResponse.statusCode == 200 &&
          appSettingsRes['status'] == true) {
        _appSettings = appSettingsRes['data'];
      }

      if (response.statusCode == 200 && profileRes['status'] == true) {
        final responseOutletId = profileRes['data']?['ot_id']?.toString();

        // ✅ Guard: jika outlet sudah ganti lagi saat request in-flight, abaikan response
        final latestOutletId = await _storage.read(key: 'current_outlet_id');
        if (outletId != null &&
            outletId.trim().isNotEmpty &&
            latestOutletId != outletId) {
          debugPrint(
            "SettingProvider: Outlet changed during fetch, discarding stale response.",
          );
          return;
        }

        _outletData = profileRes['data'];
        if (responseOutletId != null && responseOutletId.isNotEmpty) {
          _currentOutletId = responseOutletId;
          await _storage.write(
            key: 'current_outlet_id',
            value: responseOutletId,
          );
          await _storage.write(key: 'outlet_id', value: responseOutletId);
        }
        debugPrint(
          "✅ SettingProvider: Settings loaded for outlet ${responseOutletId ?? outletId}",
        );
      }

      if (empResponse.statusCode == 200 && empRes['status'] == true) {
        final List emps = empRes['data'] ?? [];
        _totalPegawaiRiil = emps.length; // ✅ Ini total aslinya
      }
    } catch (e) {
      debugPrint("SettingProvider Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _outletData = null;
    _currentOutletId = null; // ✅ Reset juga
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
