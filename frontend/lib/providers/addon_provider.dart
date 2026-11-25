import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/utils/upload_image_helper.dart';
import '../data/models/addon_model.dart';
import '../core/events/app_events.dart';

class AddonProvider extends ChangeNotifier {
  StreamSubscription? _eventSub;

  // State Lists
  List<Addon> _katalogAddons = [];
  List<ActiveAddon> _activeAddons = [];
  List<TransaksiAddon> _pendingOrders = [];
  List<TransaksiAddon> _fullHistory = [];

  // UI States
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Addon> get katalogAddons => _katalogAddons;
  List<ActiveAddon> get activeAddons => _activeAddons;

  // ✅ Transaksi Aktif: PENDING, PENDING_VALIDATION, FAILED (untuk re-upload)
  List<TransaksiAddon> get pendingOrders => _pendingOrders;

  // ✅ Riwayat Final: SUCCESS, CANCELED
  List<TransaksiAddon> get fullHistory => _fullHistory;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AddonProvider() {
    debugPrint("🏗️ AddonProvider: Initialized & Listening to Events");
    _listenToEvents();
  }

  // --- 📡 EVENT LISTENER (REAL-TIME SYNC VIA WEBSOCKET) ---
  void _listenToEvents() {
    _eventSub?.cancel();
    _eventSub = appEventBus.stream.listen((event) async {
      // 1. Sinyal: Outlet berhasil jadi PRO
      if (event is OutletActivated) {
        debugPrint("🔔 AddonProvider: Sinyal Outlet PRO diterima!");
        await refreshData();
      }

      // 2. Sinyal: Fitur Addon baru saja diaktifkan (Success)
      if (event is AddonActivated) {
        debugPrint("🔔 AddonProvider: Sinyal Addon Aktif diterima!");
        await refreshData();
      }

      // 3. Sinyal: Status Pembayaran Berubah (PENDING -> SUCCESS/FAILED/CANCELED)
      if (event is AddonPaymentStatusChanged) {
        debugPrint(
          "🔔 AddonProvider: Status Pembayaran ${event.addonId} -> ${event.status}",
        );
        // Langsung refresh list transaksi biar UI update posisi card (pindah section)
        await fetchPendingOrders();
        await fetchFullHistory();

        // Jika statusnya SUCCESS, sekalian update list fitur aktif
        if (event.status.toUpperCase() == 'SUCCESS') {
          await fetchActiveAddons();
        }
      }
    });
  }

  // ✅ FUNGSI SAKTI: Refresh semua data addon sekaligus secara paralel
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        fetchKatalog(),
        fetchActiveAddons(),
        fetchPendingOrders(),
        fetchFullHistory(),
      ]);
    } catch (e) {
      debugPrint("❌ AddonProvider Error refreshData: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- 🛠️ API CALLS (DENGAN REAKTIF NOTIFY) ---

  Future<void> fetchKatalog() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/addons/katalog', token: token);
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        final List data = body['data'] ?? [];
        _katalogAddons = data.map((e) => Addon.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ fetchKatalog Error: $e");
    }
  }

  Future<void> fetchActiveAddons() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/addons/active', token: token);
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        final List data = body['data'] ?? [];
        _activeAddons = data.map((e) => ActiveAddon.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ fetchActiveAddons Error: $e");
    }
  }

  Future<void> fetchPendingOrders() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '/addons/pending-orders',
        token: token,
      );
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        final List data = body['data'] ?? [];
        _pendingOrders = data.map((e) => TransaksiAddon.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ fetchPendingOrders Error: $e");
    }
  }

  Future<void> fetchFullHistory() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/addons/history-all', token: token);
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        final List data = body['data'] ?? [];
        _fullHistory = data.map((e) => TransaksiAddon.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ fetchFullHistory Error: $e");
    }
  }

  // --- 💸 ACTIONS (PEMBAYARAN & ORDER) ---

  // 1. Upgrade ke PRO (Permanen)
  Future<Map<String, dynamic>> activateOutlet(
    String metode, {
    int? bankId,
    String? voucherCode,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/addons/activate-outlet',
        body: {
          'metode': metode,
          ...?(bankId == null ? null : {'bank_id': bankId}),
          ...?(voucherCode == null ? null : {'voucher_code': voucherCode}),
        },
        token: token,
      );
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchPendingOrders();

        // ✅ Jika aktivasi instan (gratis), tembak event lokal biar UI lain (SettingProvider dsb) langsung refresh
        final data = body['data'];
        if (data is Map<String, dynamic> &&
            data['status'] == 'INSTANT_SUCCESS') {
          appEventBus.add(OutletActivated(outletId: ''));
        }
      }

      return {
        'success': body['status'] ?? false,
        'message': body['message'],
        'data': body['data'],
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Beli Addon instan potong Koin
  Future<Map<String, dynamic>> purchaseWithKoin({
    required List<String> addonIds,
    Map<String, String>? targetIds,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/addons/buy-koin',
        body: {'addon_ids': addonIds, 'target_ids': targetIds ?? {}},
        token: token,
      );
      final body = jsonDecode(response.body);
      if (body['status'] == true) await refreshData();
      return {'success': body['status'] ?? false, 'message': body['message']};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Buat Tagihan Addon (Transfer/Midtrans)
  Future<Map<String, dynamic>> checkoutAddons({
    required List<String> addonIds,
    required String metode,
    Map<String, String>? targetIds,
    int? bankId,
    String? voucherCode,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/addons/request',
        body: {
          'addon_ids': addonIds,
          'metode': metode,
          'target_ids': targetIds ?? {},
          ...?(bankId == null ? null : {'bank_id': bankId}),
          ...?(voucherCode == null ? null : {'voucher_code': voucherCode}),
        },
        token: token,
      );
      final body = jsonDecode(response.body);
      if (body['status'] == true) await fetchPendingOrders();
      return {
        'success': body['status'] ?? false,
        'message': body['message'],
        'data': body['data'],
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4. Upload Bukti (Retryable: Bisa untuk PENDING atau FAILED rejected)
  Future<Map<String, dynamic>> uploadBuktiTransferAddon(
    String trxId,
    File imageFile,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/addons/upload-bukti'),
      );
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.fields['ha_id'] = trxId;
      final compressed = await UploadImageHelper.compressImage(
        imageFile,
        maxWidth: 1280,
        quality: 80,
        prefix: 'addon',
      );
      request.files.add(
        await http.MultipartFile.fromPath('bukti', compressed.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        await fetchPendingOrders(); // Refresh status ke PENDING_VALIDATION
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal upload bukti',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengirim file: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 5. Batalkan Tagihan (User Cancel)
  Future<Map<String, dynamic>> cancelOrder(String trxId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/addons/cancel-order',
        body: {'ha_id': trxId},
        token: token,
      );
      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchPendingOrders();
        await fetchFullHistory();
      }
      return {'success': body['status'] ?? false, 'message': body['message']};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 6. Validasi Voucher
  Future<Map<String, dynamic>> validateVoucher(String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '/addons/validate-voucher?code=$code',
        token: token,
      );
      final body = jsonDecode(response.body);
      return {
        'success': body['status'] ?? false,
        'message': body['message'],
        'data': body['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal validasi voucher: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- 🔍 HELPER SAKTI ---

  Addon? _findAddonById(String addonId) {
    for (final addon in _katalogAddons) {
      if (addon.id == addonId) return addon;
    }
    return null;
  }

  String? _resolveFeatureLink(ActiveAddon addon) {
    final detailLink = addon.detail?.link;
    if (detailLink != null && detailLink.isNotEmpty) {
      return detailLink;
    }
    return _findAddonById(addon.addonId)?.link;
  }

  // Cek apakah fitur tertentu aktif & belum expired
  bool isFeatureActive(String link) {
    return _activeAddons.any(
      (a) => _resolveFeatureLink(a) == link && !a.isExpired,
    );
  }

  // Ambil sisa hari fitur tertentu
  int getRemainingDays(String link) {
    try {
      final addon = _activeAddons.firstWhere(
        (a) => _resolveFeatureLink(a) == link,
      );
      return addon.berakhir.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }

  // Dapatkan detail addon dari katalog berdasarkan link
  Addon? getAddonByLink(String link) {
    try {
      return _katalogAddons.firstWhere((a) => a.link == link);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
