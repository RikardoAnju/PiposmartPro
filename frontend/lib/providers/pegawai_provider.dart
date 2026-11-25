import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/pegawai_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class PegawaiProvider extends ChangeNotifier {
  List<Pegawai> _employees = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Status khusus untuk handle UI "Gembok" atau "Beli Slot"
  // Sesuai logic backend yang mengizinkan simpan tapi status=0 jika kuota habis
  bool _isLimitReached = false;
  int _employeeFetchGeneration = 0;

  List<Pegawai> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLimitReached => _isLimitReached;

  String _normalizeErrorMessage(dynamic rawMessage) {
    final message = rawMessage?.toString().trim() ?? '';
    final lower = message.toLowerCase();

    if (lower.contains('duplicate entry')) {
      if (lower.contains('pg_email') || lower.contains('email')) {
        return 'Email login sudah digunakan. Gunakan email lain.';
      }
      if (lower.contains('pg_nohp') ||
          lower.contains('nohp') ||
          lower.contains('nomor')) {
        return 'Nomor HP sudah digunakan. Gunakan nomor lain.';
      }
      return 'Data tersebut sudah pernah terdaftar.';
    }

    if (lower.contains('error 1062')) {
      return 'Data tersebut sudah pernah terdaftar.';
    }

    if (message.isEmpty) return 'Terjadi kesalahan. Coba lagi.';
    return message;
  }

  // 1. Fetch List Pegawai
  Future<void> fetchEmployees() async {
    final requestGeneration = ++_employeeFetchGeneration;
    _isLoading = true;
    _errorMessage = null;
    _isLimitReached = false;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/employees', token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        if (requestGeneration != _employeeFetchGeneration) return;
        final List data = body['data'] ?? [];
        _employees = data.map((e) => Pegawai.fromJson(e)).toList();
      } else {
        if (requestGeneration != _employeeFetchGeneration) return;
        _errorMessage = body['message'] ?? "Gagal mengambil data pegawai";
        _employees = [];
      }
    } catch (e) {
      _errorMessage = "Terjadi kesalahan sistem koneksi";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Pegawai?> fetchCurrentEmployee() async {
    try {
      final response = await ApiClient.get(
        '/employees/me',
        token: AuthStorage.token,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        return Pegawai.fromJson(body['data']);
      }
      _errorMessage = body['message'] ?? 'Gagal mengambil profil karyawan';
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan sistem koneksi';
    }
    return null;
  }

  // 2. Save/Update Pegawai
  Future<Map<String, dynamic>> saveEmployee({
    String? id,
    required String nama,
    required String email,
    required String roleId,
    String? nohp,
    DateTime? tanggalLahir,
    String? password,
    int? status,
    bool? allOutletAccess,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;

      final Map<String, dynamic> payload = {
        "nama": nama,
        "email": email,
        "role_id": roleId,
        if (nohp?.isNotEmpty == true) "nohp": nohp,
        if (tanggalLahir != null)
          "tanggal_lahir": tanggalLahir.toIso8601String().split('T').first,
        if (password?.isNotEmpty ?? false) "password": password,
        if (id != null && status != null) "status": status,
        "all_outlet_access": ?allOutletAccess,
      };

      final response = id == null
          ? await ApiClient.post('/employees', body: payload, token: token)
          : await ApiClient.put('/employees/$id', body: payload, token: token);

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['status'] == true) {
          await fetchEmployees();

          // Cek apakah pegawai yang baru dibuat bertipe 'addon' tapi statusnya 0 (karena belum bayar)
          // Ini sesuai logic backend: p.Type = "addon" -> p.Status = 0
          final bool isNewAddonPending =
              id == null &&
              body['data'] != null &&
              body['data']['type'] == 'addon' &&
              body['data']['status'] == 0;

          return {
            'success': true,
            'data': body['data'],
            'message': isNewAddonPending
                ? "Pegawai berhasil disimpan sebagai 'Add-on', namun status non-aktif. Silakan lakukan aktivasi/pembayaran."
                : body['message'],
          };
        }
      }

      // Handle error spesifik dari backend (misal: kuota penuh atau masa aktif habis)
      return {
        'success': false,
        'message': _normalizeErrorMessage(
          body['message'] ?? 'Gagal menyimpan data',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateEmployeeStatus({
    required Pegawai employee,
    required bool isActive,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.put(
        '/employees/${employee.id}',
        body: {
          "nama": employee.nama,
          "email": employee.email,
          "role_id": employee.roleId,
          "nohp": employee.nohp,
          if (employee.tanggalLahir != null)
            "tanggal_lahir": employee.tanggalLahir!
                .toIso8601String()
                .split('T')
                .first,
          "status": isActive ? 1 : 0,
        },
        token: token,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        await fetchEmployees();
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'message': _normalizeErrorMessage(
          body['message'] ?? 'Gagal memperbarui status pegawai',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Delete Pegawai
  Future<Map<String, dynamic>> deleteEmployee(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete('/employees/$id', token: token);
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        await fetchEmployees();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus pegawai',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> forceLogoutEmployee(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        '/employees/$id/force-logout',
        token: token,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Gagal memaksa logout pegawai',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGIC HELPER UNTUK UI ---

  // Menghitung berapa banyak pegawai tipe base yang sudah terpakai
  int get baseStaffCount => _employees.where((e) => e.type == 'base').length;

  // Cek apakah pegawai butuh perpanjangan
  bool isEmployeeExpired(Pegawai emp) {
    if (emp.type == 'base') return false;
    if (emp.activeUntil == null) return true;
    return emp.activeUntil!.isBefore(DateTime.now());
  }

  /// Format tanggal ala Indonesia (mis. "05 Sep 2026").
  static String formatTanggalIndo(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  /// Sama seperti [formatTanggalIndo] tapi aman untuk nilai null → "-".
  static String formatDateOrDash(DateTime? date) =>
      date == null ? '-' : formatTanggalIndo(date);

  /// Ambil data pegawai terkini dari list (by id); fallback ke [fallback]
  /// bila belum ada di list. Dipakai layar detail agar selalu tampil terbaru.
  Pegawai employeeByIdOr(String id, Pegawai fallback) {
    for (final e in _employees) {
      if (e.id == id) return e;
    }
    return fallback;
  }

  /// Aktif = benar-benar bisa dipakai: pg_status aktif (tidak dimatikan manual)
  /// DAN kuota/add-on-nya aktif (base atau add-on aktif). Sisanya inactive.
  static bool isActiveEmployee(Pegawai e) =>
      e.status == 1 &&
      (e.statusType == EmployeeStatusType.base ||
          e.statusType == EmployeeStatusType.addonActive);

  int get activeEmployeeCount => _employees.where(isActiveEmployee).length;
  int get inactiveEmployeeCount => _employees.length - activeEmployeeCount;
}
