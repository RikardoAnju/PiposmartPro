import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models/role_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class RoleProvider extends ChangeNotifier {
  List<Role> _roles = [];
  bool _isLoading = false;
  String? _errorMessage; // Tambahkan untuk menyimpan pesan error

  List<Role> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ===== Label permission (dipakai layar detail pegawai & modal permission) =====

  static const Map<String, String> moduleLabels = {
    'transaksi': 'Transaksi',
    'pelanggan': 'Pelanggan',
    'pengeluaran': 'Pengeluaran',
    'layanan': 'Layanan',
    'item': 'Item',
    'parfum': 'Parfum',
    'diskon': 'Diskon',
    'pembayaran': 'Pembayaran',
    'pegawai': 'Karyawan',
    'laporan': 'Laporan',
    'outlet': 'Outlet',
  };

  static const Map<String, String> actionLabels = {
    'all': 'Semua',
    'create': 'Buat',
    'read': 'Lihat',
    'update': 'Ubah',
    'delete': 'Hapus',
    'update_status': 'Ubah Status',
    'read_home_summary': 'Ringkasan Beranda',
    'read_daily_summary': 'Ringkasan Harian',
    'read_omset': 'Lihat Penjualan',
    'read_pengeluaran': 'Lihat Pengeluaran',
    'read_pendapatan': 'Lihat Pendapatan',
    'read_profit_loss': 'Lihat Laba Rugi',
    'read_transaction': 'Lihat Transaksi',
    'read_service_summary': 'Lihat Ringkasan Layanan',
    'read_customer': 'Lihat Pelanggan',
    'read_debt': 'Lihat Piutang',
  };

  static String moduleLabel(String key) =>
      moduleLabels[key] ?? key.replaceAll('_', ' ').trim();

  static String actionLabel(String key) =>
      actionLabels[key] ?? key.replaceAll('_', ' ').trim();

  Future<void> fetchRoles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/roles', token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        final List data = body['data'] ?? [];
        _roles = data.map((e) => Role.fromJson(e)).toList();
      } else {
        // Menangkap pesan: "Fitur ini (EMP_MANAGEMENT) tidak tersedia..."
        _errorMessage = body['message'] ?? "Gagal mengambil data role";
        _roles = [];
      }
    } catch (e) {
      _errorMessage = "Terjadi kesalahan koneksi";
      debugPrint("Error fetch roles: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Simpan atau Update Role
  Future<Map<String, dynamic>> saveRole({
    String? id,
    required String nama,
    required Map<String, List<String>> permissions,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;

      // Payload sesuai ekspektasi c.ShouldBindJSON backend
      final Map<String, dynamic> payload = {
        "nama": nama,
        "permission": permissions, // Dikirim sebagai Object JSON
      };

      final response = id == null
          ? await ApiClient.post('/roles', body: payload, token: token)
          : await ApiClient.put('/roles/$id', body: payload, token: token);

      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchRoles();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menyimpan role',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Hapus Role
  Future<Map<String, dynamic>> deleteRole(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete('/roles/$id', token: token);
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        await fetchRoles();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus role',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
