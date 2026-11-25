import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/service/fcm_service.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ✅ Token di-cache di memory agar bisa diakses tanpa async
  String? _token;
  String? get token => _token;

  String? _actorType;
  String? get actorType => _actorType;

  String? _actorId;
  String? get actorId => _actorId;

  String? _userName;
  String? _userRole;
  bool _allOutletAccess = false;
  String? get userName => _userName;
  String? get userRole => _userRole;
  bool get allOutletAccess => _allOutletAccess;

  Map<String, dynamic> _userPermissions = {};
  Map<String, dynamic> get userPermissions => _userPermissions;

  Future<void> syncAccessToken(String accessToken) async {
    _token = accessToken;
    await _storage.write(key: 'access_token', value: accessToken);
    AuthStorage.setToken(accessToken);
    await FCMService.syncTokenToBackend();
    notifyListeners();
  }

  // ==========================================
  // RBAC HELPERS
  // ==========================================

  bool hasAccess(String module, String action) {
    if (_userPermissions.containsKey("all")) return true;
    if (_userPermissions.containsKey(module)) {
      List actions = _userPermissions[module] ?? [];
      return actions.contains(action) || actions.contains("all");
    }
    return false;
  }

  bool get isOwnerOrAdmin => _actorType == 'user' || _actorType == 'admin';

  /// Single policy entry-point for operational modules. Owners/admins retain
  /// full access, while employees must have the exact module action.
  bool canAccess(String module, String action) {
    return isOwnerOrAdmin || hasAccess(module, action);
  }

  bool get canUpdateDeliveryFee {
    return isOwnerOrAdmin || hasAccess('transaksi', 'update_delivery_fee');
  }

  bool canReadReportAction(String action) {
    return isOwnerOrAdmin || hasAccess('laporan', action);
  }

  bool get canReadAnyReport {
    const reportActions = [
      'read_home_summary',
      'read_daily_summary',
      'read_omset',
      'read_pengeluaran',
      'read_pendapatan',
      'read_profit_loss',
      'read_transaction',
      'read_service_summary',
      'read_customer',
      'read_debt',
    ];
    return reportActions.any(canReadReportAction);
  }

  bool get canReadFinanceOverview {
    return isOwnerOrAdmin ||
        (canReadReportAction('read_omset') &&
            canReadReportAction('read_pengeluaran') &&
            canReadReportAction('read_pendapatan') &&
            canReadReportAction('read_profit_loss'));
  }

  bool get canReadHomeSummary {
    return canReadReportAction('read_home_summary');
  }

  bool get canReadDailyReportSummary {
    return canReadReportAction('read_daily_summary');
  }

  // ==========================================
  // SESSION MANAGEMENT
  // ==========================================

  Future<bool> silentRefreshToken() async {
    debugPrint("📡 Memulai Silent Refresh Token...");
    try {
      final storedToken = await _storage.read(key: 'access_token');
      if (storedToken == null) return false;

      final response = await ApiClient.post(
        '/auth/refresh-token',
        token: storedToken,
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = responseBody['data'];
        final newToken = data['access_token'];

        await syncAccessToken(newToken);

        final userResponse = await ApiClient.get('/auth/me', token: newToken);
        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(userResponse.body)['data'];
          final storedActorType =
              _actorType ?? await _storage.read(key: 'actor_type') ?? 'pegawai';
          final roleData = userData['role'] is Map
              ? Map<String, dynamic>.from(userData['role'])
              : <String, dynamic>{};
          _userName = userData['nama'] ?? userData['usr_nama'];
          await _setAllOutletAccess(userData);
          final roleName =
              userData['role_name'] ??
              roleData['nama'] ??
              (storedActorType == 'user' ? 'Owner' : 'Pegawai');

          await _setSessionData(
            storedActorType == 'user' ? null : roleData['permission'],
            storedActorType,
            roleName.toString(),
          );

          await _storage.write(key: 'user_name', value: _userName!);
        }

        notifyListeners();
        debugPrint("✅ Refresh & Sync Berhasil: $_userName ($_userRole)");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Gagal Silent Refresh: $e");
      return false;
    }
  }

  Future<void> _setSessionData(
    dynamic rawPermissions,
    String actorType,
    String? roleName,
  ) async {
    _actorId = await _storage.read(key: 'actor_id');
    _actorType = actorType;
    _userRole = roleName ?? (actorType == 'user' ? 'Owner' : 'Pegawai');

    if (actorType == 'user') {
      _userPermissions = {
        "all": ["*"],
      };
    } else {
      if (rawPermissions != null) {
        _userPermissions = rawPermissions is String
            ? jsonDecode(rawPermissions)
            : Map<String, dynamic>.from(rawPermissions);
      } else {
        _userPermissions = {};
      }
    }

    await _storage.write(key: 'actor_type', value: actorType);
    await _storage.write(key: 'user_role', value: _userRole!);
    await _storage.write(
      key: 'user_permissions',
      value: jsonEncode(_userPermissions),
    );
    notifyListeners();
  }

  Future<void> _setAllOutletAccess(dynamic userData) async {
    _allOutletAccess = userData is Map && userData['all_outlet_access'] == true;
    await _storage.write(
      key: 'all_outlet_access',
      value: _allOutletAccess.toString(),
    );
  }

  Future<bool> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'access_token');
    if (storedToken == null) return false;
    try {
      await restoreSession();
      if (await silentRefreshToken()) {
        return true;
      }
      await logout();
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> restoreSession() async {
    final storedToken = await _storage.read(key: 'access_token');
    final permStr = await _storage.read(key: 'user_permissions');
    final type = await _storage.read(key: 'actor_type');
    final actorId = await _storage.read(key: 'actor_id');
    final name = await _storage.read(key: 'user_name');
    final role = await _storage.read(key: 'user_role');
    final allOutletAccess = await _storage.read(key: 'all_outlet_access');

    if (storedToken != null) {
      _token = storedToken; // ✅ Restore memory cache
      AuthStorage.setToken(storedToken); // ✅ Sync ke singleton cache
    }
    if (type != null) _actorType = type;
    if (actorId != null) _actorId = actorId;
    if (name != null) _userName = name;
    if (role != null) _userRole = role;
    _allOutletAccess = allOutletAccess == 'true';
    if (permStr != null) _userPermissions = jsonDecode(permStr);

    notifyListeners();
  }

  // ==========================================
  // AUTHENTICATION (Login & Google)
  // ==========================================

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = responseBody['data'];
        final user = data['user'];

        final accessToken = data['access_token'];
        await syncAccessToken(accessToken);

        await _storage.write(
          key: 'actor_id',
          value: data['actor_id'].toString(),
        );

        final String? lastOutlet = data['last_outlet_id'] ?? data['outlet_id'];
        await _storage.write(key: 'outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'current_outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'remember_me', value: rememberMe.toString());

        final String type =
            data['actor_type'] ??
            (user.containsKey('usr_id') ? 'user' : 'pegawai');
        final String roleName =
            user['role_name'] ?? (type == 'user' ? 'Owner' : 'Pegawai');

        _userName = user['usr_nama'] ?? user['nama'] ?? 'User';
        _userRole = roleName;
        await _setAllOutletAccess(user);

        await _setSessionData(data['permissions'], type, roleName);
        await _storage.write(key: 'user_name', value: _userName!);

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'has_outlet': data['has_outlet'] ?? false};
      }
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': responseBody['message'] ?? 'Login Gagal',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  /// Login sebagai user via email + secret (khusus build internal impersonation).
  /// Endpoint backend digate env IMPERSONATION_SECRET (mati di prod).
  Future<Map<String, dynamic>> impersonate(String email, String secret) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/impersonate',
        body: {'email': email.trim(), 'secret': secret},
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = responseBody['data'];
        final user = data['user'];

        await syncAccessToken(data['access_token']);
        await _storage.write(
          key: 'actor_id',
          value: data['actor_id'].toString(),
        );

        final String? lastOutlet = data['last_outlet_id'] ?? data['outlet_id'];
        await _storage.write(key: 'outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'current_outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'remember_me', value: 'false');

        final String type = data['actor_type'] ?? 'user';
        final String roleName = user['role_name'] ?? 'Owner';
        _userName = user['usr_nama'] ?? user['nama'] ?? 'User';
        _userRole = roleName;

        await _setSessionData(data['permissions'], type, roleName);
        await _storage.write(key: 'user_name', value: _userName!);

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'has_outlet': data['has_outlet'] ?? false};
      }
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': responseBody['message'] ?? 'Impersonation gagal',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  static const String _defaultWebClientId =
      '92161657227-9gd09ggs835ntp1k926vt2q142qek50h.apps.googleusercontent.com';
  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleClientId,
    scopes: ['email'],
  );

  Future<Map<String, dynamic>> signInWithGoogle({
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': 'Proses masuk dibatalkan'};
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Google belum mengirim token. Coba masuk ulang.',
        };
      }
      final response = await ApiClient.post(
        '/auth/google',
        body: {'idToken': googleAuth.idToken},
      );
      final responseBody = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        final data = responseBody['data'] ?? {};
        if (data['is_registered'] == false) {
          return {
            'success': true,
            'is_registered': false,
            'google_data': {
              'email': data['email'] ?? '',
              'name': data['name'] ?? '',
              'google_id': data['google_id'] ?? '',
              'registration_token': data['registration_token'] ?? '',
            },
          };
        }

        final accessToken = data['access_token']?.toString() ?? "";
        await syncAccessToken(accessToken);

        await _storage.write(
          key: 'actor_id',
          value: data['actor_id']?.toString() ?? "",
        );

        final String? lastOutlet = data['last_outlet_id'] ?? data['outlet_id'];
        await _storage.write(key: 'outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'current_outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'remember_me', value: rememberMe.toString());

        final String type = data['actor_type'] ?? 'user';
        final userData = data['user'];
        final String roleName = userData['role_name'] ?? 'Owner';

        _userName = userData['usr_nama'] ?? userData['nama'] ?? 'User';
        _userRole = roleName;

        await _setSessionData(data['permissions'], type, roleName);
        await _storage.write(key: 'user_name', value: _userName!);

        return {
          'success': true,
          'is_registered': true,
          'has_outlet': data['has_outlet'] ?? false,
        };
      }
      return {
        'success': false,
        'message': responseBody['message'] ?? 'Gagal verifikasi Google',
      };
    } catch (e) {
      debugPrint("Google SignIn Error: $e");
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Google login belum bisa dipakai. Coba lagi sebentar.',
      };
    }
  }

  Future<Map<String, dynamic>> signInWithApple({
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Apple belum mengirim token login. Coba lagi.',
        };
      }

      final fullName = [
        credential.givenName?.trim(),
        credential.familyName?.trim(),
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ').trim();

      final response = await ApiClient.post(
        '/auth/apple',
        body: {
          'idToken': idToken,
          'email': credential.email ?? '',
          'name': fullName,
        },
      );
      final responseBody = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        final data = responseBody['data'] ?? {};
        if (data['is_registered'] == false) {
          return {
            'success': true,
            'is_registered': false,
            'apple_data': {
              'email': data['email'] ?? credential.email ?? '',
              'name': data['name'] ?? fullName,
              'apple_id': data['apple_id'] ?? credential.userIdentifier ?? '',
              'registration_token': data['registration_token'] ?? '',
            },
          };
        }

        final accessToken = data['access_token']?.toString() ?? "";
        await syncAccessToken(accessToken);
        await _storage.write(
          key: 'actor_id',
          value: data['actor_id']?.toString() ?? "",
        );

        final String? lastOutlet = data['last_outlet_id'] ?? data['outlet_id'];
        await _storage.write(key: 'outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'current_outlet_id', value: lastOutlet ?? "");
        await _storage.write(key: 'remember_me', value: rememberMe.toString());

        final String type = data['actor_type'] ?? 'user';
        final userData = data['user'];
        final String roleName = userData['role_name'] ?? 'Owner';

        _userName = userData['usr_nama'] ?? userData['nama'] ?? 'User';
        _userRole = roleName;

        await _setSessionData(data['permissions'], type, roleName);
        await _storage.write(key: 'user_name', value: _userName!);

        return {
          'success': true,
          'is_registered': true,
          'has_outlet': data['has_outlet'] ?? false,
        };
      }

      return {
        'success': false,
        'message': responseBody['message'] ?? 'Gagal verifikasi Apple',
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == AuthorizationErrorCode.canceled) {
        return {'success': false, 'message': 'Proses masuk dibatalkan'};
      }
      if (e.code == AuthorizationErrorCode.unknown) {
        return {
          'success': false,
          'message':
              'Apple login gagal. Biasanya karena capability Sign in with Apple belum aktif, build lama belum terpasang ulang, atau sedang dites di environment yang tidak didukung.',
        };
      }
      return {'success': false, 'message': 'Apple login gagal: ${e.code.name}'};
    } on PlatformException catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': e.message ?? 'Apple login belum tersedia di perangkat ini.',
      };
    } catch (e) {
      debugPrint("Apple SignIn Error: $e");
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Apple login belum bisa dipakai. Coba lagi sebentar.',
      };
    }
  }

  Future<void> logout() async {
    await FCMService.unregisterTokenFromBackend(authTokenOverride: _token);

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("Google SignOut Error: $e");
    }

    _token = null; // ✅ Clear memory cache
    AuthStorage.clear(); // ✅ Clear singleton cache
    _userPermissions = {};
    _actorId = null;
    _actorType = null;
    _allOutletAccess = false;
    _userName = null;
    _userRole = null;

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'actor_id');
    await _storage.delete(key: 'actor_type');
    await _storage.delete(key: 'all_outlet_access');
    await _storage.delete(key: 'user_permissions');
    await _storage.delete(key: 'outlet_id');
    await _storage.delete(key: 'current_outlet_id');
    await _storage.delete(key: 'current_outlet_name');
    await _storage.delete(key: 'current_outlet_address');
    await _storage.delete(key: 'current_outlet_phone');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'saved_email');
    await _storage.delete(key: 'remember_me');
    await _storage.delete(key: 'pending_first_home_tutorial');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_first_home_tutorial');
    await ApiClient.clearCache(); // ✅ Purge cached API responses (shared/kiosk device safety)

    notifyListeners();
    debugPrint("🚪 Logout berhasil.");
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String reason,
    String? reasonDetail,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.delete(
        '/auth/delete-account',
        token: _token,
        body: {
          'reason': reason,
          'reason_detail': reasonDetail ?? 'Tanpa penjelasan tambahan',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await logout();
        return {'success': true, 'message': 'Akun berhasil dihapus'};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal menghapus akun',
      };
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // FORGOT PASSWORD
  // ==========================================

  Future<Map<String, dynamic>> forgotPasswordLookupAccount({
    required String method,
    required String value,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/forgot-password/lookup-account',
        body: {'method': method, 'value': value},
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'],
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> forgotPasswordSendOtp(
    String email,
    String phone, {
    required String channel,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/forgot-password/send-otp',
        body: {'email': email, 'phone': phone, 'channel': channel},
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'],
        'channel': data['data']?['channel'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> forgotPasswordVerifyOtp(
    String email,
    String phone,
    String otp,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/forgot-password/verify-otp',
        body: {'email': email, 'phone': phone, 'otp': otp},
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'email': responseBody['data']['email']};
      }
      return {'success': false, 'message': responseBody['message']};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> forgotPasswordReset({
    required String email,
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/forgot-password/reset',
        body: {
          'email': email,
          'phone': phone,
          'otp': otp,
          'new_password': newPassword,
        },
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal mereset password'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // REGISTRATION & LOCATION
  // ==========================================

  Future<Map<String, dynamic>> checkPhone(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/check-phone',
        body: {'usr_nohp': phone},
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) return {'success': true};
      return {
        'success': false,
        'message': data['message'] ?? 'Nomor sudah terdaftar',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Koneksi gagal'};
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/send-otp',
        body: {'usr_nohp': phone},
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim OTP',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Koneksi error'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/verify-otp',
        body: {'usr_nohp': phone, 'otp_code': code},
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) {
        return {
          'success': true,
          'verification_token': data['data']?['verification_token'],
          'message': data['message'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'OTP Salah atau Kedaluwarsa',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal verifikasi'};
    }
  }

  Future<Map<String, dynamic>> validateReferral(String code) async {
    try {
      final response = await ApiClient.post(
        '/auth/register/validate-referral?code=$code',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> validateAccount({
    required String nama,
    required String email,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/validate-account',
        body: {'usr_nama': nama, 'usr_email': email},
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) return {'success': true};
      return {
        'success': false,
        'message': data['message'] ?? 'Email sudah digunakan',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal validasi akun'};
    }
  }

  Future<Map<String, dynamic>> validateOutlet({
    required String namaOutlet,
    required String alamat,
    required String provinsi,
    required String kota,
    String? tipeLokasiUsaha,
    String? modalUsaha,
    String? jumlahKaryawan,
    String? jumlahMesin,
    String? tanggalBerjalan,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/validate-outlet',
        body: {
          'ot_nama': namaOutlet,
          'ot_alamat': alamat,
          'ot_provinsi': provinsi,
          'ot_kota': kota,
          'ot_tipe_lokasi_usaha': tipeLokasiUsaha,
          'ot_modal_usaha': modalUsaha,
          'ot_jumlah_karyawan': jumlahKaryawan,
          'ot_jumlah_mesin': jumlahMesin,
          'ot_tanggal_berjalan': tanggalBerjalan,
        },
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) return {'success': true};
      return {
        'success': false,
        'message': data['message'] ?? 'Data outlet tidak valid',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Koneksi error'};
    }
  }

  Future<Map<String, dynamic>> finalRegister(
    Map<String, dynamic> payload,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.post(
        '/auth/register/final',
        body: payload,
      );
      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Pendaftaran Berhasil'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mendaftar',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    }
  }

  Future<List<dynamic>> getProvinces() async {
    try {
      final response = await ApiClient.get('/location/provinces');
      if (response.statusCode == 200) return jsonDecode(response.body)['data'];
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getCities(String provinceId) async {
    try {
      final response = await ApiClient.get(
        '/location/cities?province_id=$provinceId',
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['data'];
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getDistricts(String cityId) async {
    try {
      final response = await ApiClient.get(
        '/location/districts?city_id=$cityId',
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['data'];
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await ApiClient.get('/auth/me', token: _token);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {'success': false, 'message': body['message']};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    }
  }

  Future<Map<String, dynamic>> updateOwnerProfile({
    required String nama,
    required String email,
    required String noHp,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.put(
        '/auth/profile',
        body: {"nama": nama, "email": email, "no_hp": noHp},
        token: _token,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        _userName = nama;
        await _storage.write(key: 'user_name', value: nama);
        notifyListeners();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal update profil',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.put(
        '/auth/change-password',
        token: _token,
        body: {'old_password': oldPassword, 'new_password': newPassword},
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal memperbarui kata sandi',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
