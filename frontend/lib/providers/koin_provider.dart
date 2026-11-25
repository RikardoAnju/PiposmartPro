import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/models/koin_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/events/app_events.dart';
import '../core/utils/upload_image_helper.dart';

class KoinProvider with ChangeNotifier {
  List<HistoryKoinModel> _history = [];
  List<dynamic> _activeTopups = [];
  List<dynamic> _allTopups = [];
  List<dynamic> _bankAccounts = [];
  Map<String, dynamic>? _selectedBank;

  bool _isLoading = false;
  StreamSubscription? _eventSub;

  // --- STATE CONFIG EKONOMI ---
  double _pricePerCoin = 100.0;
  int _coinPerTransaction = 5;

  // [NEW] Config untuk Aktivasi PRO
  double _activationFee = 1500000.0;
  double _activationDiscount = 0.0;
  String _activationMode = 'paid';

  List<HistoryKoinModel> get history => _history;
  List<dynamic> get activeTopups => _activeTopups;
  List<dynamic> get allTopups => _allTopups;
  List<dynamic> get bankAccounts => _bankAccounts;
  Map<String, dynamic>? get selectedBank => _selectedBank;
  bool get isLoading => _isLoading;

  double get pricePerCoin => _pricePerCoin;
  int get coinPerTransaction => _coinPerTransaction;

  // [NEW] Getters PRO Config
  double get activationFee => _activationFee;
  double get activationDiscount => _activationDiscount;
  String get activationMode => _activationMode;
  double get totalAktivasiPRO =>
      _activationFee - (_activationFee * _activationDiscount / 100);
  bool get isActivationCampaignFree {
    final mode = _activationMode.trim().toLowerCase();
    return mode == 'free' || mode == 'gratis' || mode == '0' || mode == 'false';
  }

  bool get isActivationFree =>
      isActivationCampaignFree || totalAktivasiPRO <= 0;

  List<Map<String, dynamic>> _koinPackages = [];
  List<Map<String, dynamic>> get koinPackages => _koinPackages;

  bool _isFetchingPackages = false;
  bool get isFetchingPackages => _isFetchingPackages;

  KoinProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSub = appEventBus.stream.listen((event) {
      if (event is CoinBalanceChanged || event is TopupSucceeded) {
        refreshKoinData();
        fetchAllTopupRequests();
      }
      if (event is TopupStatusChanged) {
        fetchAllTopupRequests();
        fetchActiveTopups();
        if (event.status.toLowerCase() == 'success') {
          refreshKoinData();
        }
      }
    });
  }

  // ==========================================
  // 1. WRAPPER REFRESH DATA
  // ==========================================

  Future<void> refreshKoinData({
    bool showLoader = false,
    Function? syncBalanceCallback,
  }) async {
    if (showLoader) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      List<Future> tasks = [
        fetchEconomyConfig(),
        fetchHistoryKoin(),
        fetchActiveTopups(),
        fetchAllTopupRequests(),
      ];

      if (syncBalanceCallback != null) {
        tasks.add(syncBalanceCallback());
      }

      await Future.wait(tasks);
    } catch (e) {
      debugPrint("⛔ Error refreshing koin data: $e");
    } finally {
      if (showLoader) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ==========================================
  // 2. FETCH METHODS
  // ==========================================

  Future<void> fetchEconomyConfig() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '/koin/economy-config',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final Map<String, dynamic> configs = data['data'];

        // 1. Config Koin
        _pricePerCoin =
            double.tryParse(configs['price_per_coin']?.toString() ?? "100.0") ??
            100.0;
        _coinPerTransaction =
            int.tryParse(configs['coin_per_transaction']?.toString() ?? "5") ??
            5;

        // 2. [NEW] Config Aktivasi PRO
        _activationFee =
            double.tryParse(
              configs['activation_fee']?.toString() ?? "1500000.0",
            ) ??
            1500000.0;
        _activationDiscount =
            double.tryParse(
              configs['activation_discount_pct']?.toString() ?? "0.0",
            ) ??
            0.0;
        _activationMode = configs['activation_mode']?.toString() ?? 'paid';

        notifyListeners();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch economy config: $e");
    }
  }

  Future<void> fetchHistoryKoin() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/koin/history', token: token);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final List rawData = data['data'] ?? [];
        _history = rawData.map((e) => HistoryKoinModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch history koin: $e");
    }
  }

  Future<void> fetchActiveTopups() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/koin/active-topups', token: token);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        _activeTopups = data['data'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch active topups: $e");
    }
  }

  Future<void> fetchAllTopupRequests() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/koin/all-topups', token: token);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        _allTopups = data['data'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch all topups: $e");
    }
  }

  Future<void> fetchBankAccounts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/koin/bank-accounts', token: token);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final List rawBanks = data['data'] ?? [];
        _bankAccounts = rawBanks.where((b) => b['is_active'] == true).toList();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch bank accounts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 3. ACTION METHODS
  // ==========================================

  Future<Map<String, dynamic>> regeneratePaymentLink(String topupId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '/koin/regenerate-snap/$topupId',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        await fetchAllTopupRequests();
        return {'success': true, 'snap_url': data['data']['snap_url']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memproses ulang',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan sistem: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectBank(Map<String, dynamic> bank) {
    _selectedBank = bank;
    notifyListeners();
  }

  Future<Map<String, dynamic>> checkVoucher(String code, int jumlahKoin) async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '/koin/check-voucher?code=$code&jumlah=$jumlahKoin',
        token: token,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': false, 'message': 'Gagal memvalidasi voucher'};
    }
  }

  Future<Map<String, dynamic>> requestTopup({
    required int jumlahKoin,
    required double nominalBayar,
    required String metodeBayar,
    int? bankId,
    String? kodeVoucher,
    int? kodeUnik,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/koin/request-topup',
        token: token,
        body: {
          'jumlah_koin': jumlahKoin,
          'nominal_bayar': nominalBayar,
          'metode_bayar': metodeBayar,
          'bank_id': bankId,
          'kode_voucher': kodeVoucher,
          'kode_unik': kodeUnik,
        },
      );

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['status'] == true) {
        await refreshKoinData();
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal membuat permintaan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> uploadBuktiTransfer(
    String topupId,
    File imageFile,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/koin/upload-bukti'),
      );
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.fields['topup_id'] = topupId;
      final compressed = await UploadImageHelper.compressImage(
        imageFile,
        maxWidth: 1280,
        quality: 80,
        prefix: 'topup',
      );
      request.files.add(
        await http.MultipartFile.fromPath('bukti', compressed.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        await refreshKoinData();
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

  Future<Map<String, dynamic>> cancelTopup(String topupId) async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/koin/cancel-topup',
        token: token,
        body: {'topup_id': topupId},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await fetchAllTopupRequests();
        await fetchActiveTopups();
        return {'success': true};
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> fetchKoinPackages() async {
    _isFetchingPackages = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/koin/packages', token: token);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final List rawPackages = data['data'] ?? [];
        _koinPackages = rawPackages.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⛔ Error fetch packages: $e");
    } finally {
      _isFetchingPackages = false;
      notifyListeners();
    }
  }

  void clearData() {
    _history = [];
    _activeTopups = [];
    _allTopups = [];
    _bankAccounts = [];
    _selectedBank = null;
    _pricePerCoin = 100.0;
    _coinPerTransaction = 5;
    _activationFee = 1500000.0;
    _activationDiscount = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
