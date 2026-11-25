import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ayocucinew/core/service/socket_service.dart';
import 'package:ayocucinew/core/service/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/utils/user_friendly_error.dart';
import '../core/utils/upload_image_helper.dart';
import '../core/events/app_events.dart';
import '../data/models/outlet_model.dart';
import './notification_provider.dart';
import './auth_provider.dart';
import './addon_provider.dart';

class AppProvider extends ChangeNotifier {
  // FlutterSecureStorage dipertahankan hanya untuk write (current_outlet_id & token switch)
  final _storage = const FlutterSecureStorage();
  final SocketService _socketService = SocketService();

  BuildContext? _context;
  void setContext(BuildContext context) => _context = context;

  // --- DATA STATES ---
  Outlet? _outlet;
  Map<String, dynamic>? _summaryData;
  List<Outlet> _userOutlets = [];
  String _locationName = "Lokasi memuat...";

  // States untuk User Info (Diambil dari AuthProvider)
  String? _userName;
  String? _userRole;

  // --- UI STATES ---
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _eventSubscription;
  Future<void>? _appDataFuture;
  Future<void>? _outletProfileFuture;
  Future<void>? _dashboardSummaryFuture;

  // --- GETTERS ---
  Outlet? get outlet => _outlet;
  Map<String, dynamic>? get summaryData => _summaryData;
  List<Outlet> get outlets => _userOutlets;
  String get locationName => _locationName;
  String? get userName => _userName;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AppProvider() {
    _listenToEvents();
  }

  void resetSessionState({bool notify = true}) {
    _socketService.disconnect();
    _outlet = null;
    _summaryData = null;
    _userOutlets = [];
    _locationName = "Lokasi memuat...";
    _userName = null;
    _userRole = null;
    _errorMessage = null;
    _isLoading = false;
    _appDataFuture = null;
    _outletProfileFuture = null;
    _dashboardSummaryFuture = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OrderStatusChanged ||
          event is ExpenseChanged ||
          event is DepositChanged) {
        fetchDashboardSummary(forceRefresh: true);
      } else if (event is CoinBalanceChanged) {
        fetchOutletProfile(force: true);
      } else if (event is OutletActivated || event is AddonActivated) {
        fetchAppData(force: true);
        if (_context != null) {
          FCMService.ensureNotificationReadiness(
            context: _context!,
            promptIfNeeded: false,
            reason: event.runtimeType.toString(),
          );
        }
      } else if (event is AddonPaymentStatusChanged &&
          event.status.toUpperCase() == 'SUCCESS') {
        fetchAppData(force: true);
      } else if (event is OutletSwitched ||
          event is SystemNotificationReceived) {
        fetchAppData(force: true);
        if (_context != null) {
          FCMService.ensureNotificationReadiness(
            context: _context!,
            promptIfNeeded: false,
            reason: event.runtimeType.toString(),
          );
        }
      }
    });
  }

  /// Sinkronisasi Data User dari AuthProvider ke AppProvider
  void syncUserInfo() {
    if (_context != null) {
      final auth = _context!.read<AuthProvider>();
      _userName = auth.userName;
      _userRole = auth.userRole;
      notifyListeners();
    }
  }

  void initRealtime(String outletId) {
    _socketService.connect(
      outletId,
      onResult: (success, error) {
        if (success) {
          debugPrint("✅ Real-time Terhubung: Outlet $outletId");
        } else {
          debugPrint("⚠️ Real-time Gagal: $error");
        }
      },
    );
  }

  // ==========================================
  // CORE DATA METHODS (DASHBOARD)
  // ==========================================

  Future<void> fetchAppData({bool force = false}) async {
    if (!force && _outlet != null && _summaryData != null) return;
    if (_appDataFuture != null) return _appDataFuture!;

    _appDataFuture = _fetchAppData(force: force);
    try {
      return await _appDataFuture!;
    } finally {
      _appDataFuture = null;
    }
  }

  Future<void> _fetchAppData({required bool force}) async {
    _isLoading = true;
    _errorMessage = null;

    if (!force) notifyListeners();

    try {
      final token = AuthStorage.token;
      if (token == null) return;

      if (_context != null) {
        _context!.read<NotificationProvider>().setToken(token);
        syncUserInfo();
      }

      await FCMService.ensureNotificationReadiness(
        context: _context,
        promptIfNeeded: false,
        reason: 'fetch_app_data',
      );

      await Future.wait([
        fetchOutletProfile(force: true),
        fetchDashboardSummary(),
        if (_context != null)
          _context!.read<NotificationProvider>().fetchNotifications(),
        if (_context != null)
          _context!.read<AddonProvider>().fetchActiveAddons(),
      ]);
      appEventBus.add(AppDataReady());
    } catch (e) {
      _errorMessage = userFriendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOutletProfile({bool force = false}) async {
    if (_outlet != null && !force) return;
    if (_outletProfileFuture != null) return _outletProfileFuture!;

    _outletProfileFuture = _fetchOutletProfile(useCacheFallback: !force);
    try {
      return await _outletProfileFuture!;
    } finally {
      _outletProfileFuture = null;
    }
  }

  Future<void> _fetchOutletProfile({bool useCacheFallback = true}) async {
    try {
      final token = AuthStorage.token;
      final response = useCacheFallback
          ? await ApiClient.getWithCache("/outlet/profile", token: token)
          : await ApiClient.get("/outlet/profile", token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        _outlet = Outlet.fromJson(body['data']);
        _locationName = _outlet?.alamat ?? "Alamat belum diatur";

        await Future.wait([
          _storage.write(key: 'current_outlet_id', value: _outlet!.id),
          _storage.write(key: 'outlet_id', value: _outlet!.id),
          _storage.write(key: 'current_outlet_name', value: _outlet!.nama),
          _storage.write(
            key: 'current_outlet_address',
            value: _outlet!.alamat ?? '',
          ),
          _storage.write(
            key: 'current_outlet_phone',
            value: _outlet!.noHp ?? '',
          ),
        ]);
        initRealtime(_outlet!.id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetchOutletProfile: $e");
    }
  }

  Future<void> fetchDashboardSummary({bool forceRefresh = false}) async {
    if (_dashboardSummaryFuture != null) {
      final inFlight = _dashboardSummaryFuture!;
      await inFlight;
      if (!forceRefresh) return;
    }

    _dashboardSummaryFuture = _fetchDashboardSummary(
      forceRefresh: forceRefresh,
    );
    try {
      return await _dashboardSummaryFuture!;
    } finally {
      _dashboardSummaryFuture = null;
    }
  }

  Future<void> _fetchDashboardSummary({bool forceRefresh = false}) async {
    try {
      if (_context != null) {
        final auth = _context!.read<AuthProvider>();
        if (!auth.canReadAnyReport) {
          _summaryData = null;
          notifyListeners();
          return;
        }
      }
      final token = AuthStorage.token;
      final response = forceRefresh
          ? await ApiClient.get('/dashboard/summary', token: token)
          : await ApiClient.getWithCache('/dashboard/summary', token: token);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        _summaryData = body['data'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetchDashboardSummary: $e");
    }
  }

  // ==========================================
  // OUTLET MANAGEMENT METHODS
  // ==========================================

  Future<Map<String, dynamic>> switchOutlet(String outletId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        "/outlet/switch",
        body: {'outlet_id': outletId},
        token: token,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        final newToken = body['data']['token'];
        await _storage.write(key: 'access_token', value: newToken);
        AuthStorage.setToken(newToken); // Sync fallback jika context belum siap
        await FCMService.syncTokenToBackend();

        if (_context != null) {
          await _context!.read<AuthProvider>().syncAccessToken(newToken);
          _context!.read<NotificationProvider>().setToken(newToken);
        }

        _socketService.connect(outletId);
        _outlet = null;
        _summaryData = null;

        syncUserInfo();
        appEventBus.add(OutletSwitched());
        return {'success': true, 'message': body['message']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal pindah'};
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan sistem: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateOutletProfile({
    String? nama,
    String? noHp,
    String? alamat,
    String? provinsi,
    String? kota,
    String? kecamatan,
    double? latitude,
    double? longitude,
    int? locationRadiusMeters,
    int? skipProses,
    int? isMetodePembayaran,
    int? isFiturDiskon,
    File? imageFile,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final request = http.MultipartRequest(
        'PUT',
        ApiClient.buildUri("/outlet/profile"),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (nama != null) {
        request.fields['nama'] = nama;
      }
      if (noHp != null) {
        request.fields['no_hp'] = noHp;
      }
      if (alamat != null) {
        request.fields['alamat'] = alamat;
      }
      if (provinsi != null) {
        request.fields['provinsi'] = provinsi;
      }
      if (kota != null) {
        request.fields['kota'] = kota;
      }
      if (kecamatan != null) {
        request.fields['kecamatan'] = kecamatan;
      }
      if (latitude != null) {
        request.fields['latitude'] = latitude.toString();
      }
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }
      if (locationRadiusMeters != null) {
        request.fields['location_radius_meters'] = locationRadiusMeters
            .toString();
      }
      if (skipProses != null) {
        request.fields['skip_proses'] = skipProses.toString();
      }
      if (isMetodePembayaran != null) {
        request.fields['metode_pembayaran'] = isMetodePembayaran.toString();
      }
      if (isFiturDiskon != null) {
        request.fields['fitur_diskon'] = isFiturDiskon.toString();
      }

      if (imageFile != null) {
        final compressedImage = await UploadImageHelper.compressImage(
          imageFile,
          maxWidth: 1000,
          quality: 82,
          prefix: 'outlet',
        );
        request.files.add(
          await http.MultipartFile.fromPath('gambar', compressedImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      debugPrint('📤 [PUT] /outlet/profile status: ${response.statusCode}');
      debugPrint('📤 [PUT] /outlet/profile body: ${response.body}');

      if (response.statusCode == 200 && body['status'] == true) {
        _outlet = Outlet.fromJson(body['data']);
        notifyListeners();
        return {'success': true, 'message': body['message']};
      }

      debugPrint('❌ updateOutletProfile gagal: ${body['message']}');
      return {'success': false, 'message': body['message'] ?? 'Gagal update'};
    } catch (e) {
      debugPrint('❌ updateOutletProfile exception: $e');
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void fireOutletSwitched() {
    appEventBus.add(OutletSwitched());
  }

  Future<void> fetchUserOutlets() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.getWithCache(
        "/outlet/list",
        token: token,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        final List data = body['data'];
        _userOutlets = data.map((e) => Outlet.fromJson(e)).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createOutlet({
    required String nama,
    required String noHp,
    required String alamat,
    required String provinsi,
    required String kota,
    required String kecamatan,
    String? tipeLokasiUsaha,
    String? modalUsaha,
    String? jumlahKaryawan,
    String? jumlahMesin,
    String? tanggalBerjalan,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final bool isAdditionalOutlet = _userOutlets.isNotEmpty;
      final response = await ApiClient.post(
        "/outlet/create",
        token: token,
        body: {
          'nama': nama,
          'no_hp': noHp,
          'alamat': alamat,
          'provinsi': provinsi,
          'kota': kota,
          'kecamatan': kecamatan,
          'tipe_lokasi_usaha': tipeLokasiUsaha,
          'modal_usaha': modalUsaha,
          'jumlah_karyawan': jumlahKaryawan,
          'jumlah_mesin': jumlahMesin,
          'tanggal_berjalan': tanggalBerjalan,
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || body['status'] == true) {
        await fetchUserOutlets();
        return {
          'success': true,
          'message': body['message'],
          'isAdditionalOutlet': isAdditionalOutlet,
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal membuat outlet',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGOUT & CLEAR ---
  void logout() {
    resetSessionState();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
