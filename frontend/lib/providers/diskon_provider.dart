import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/diskon_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class DiskonProvider extends ChangeNotifier {
  List<Diskon> _discounts = [];
  bool _isLoading = false;

  List<Diskon> get discounts => _discounts;
  bool get isLoading => _isLoading;

  Future<void> fetchDiscounts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/discounts', token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        final List data = body['data'] ?? [];
        _discounts = data.map((e) => Diskon.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetch discounts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveDiscount({
    String? id,
    required String nama,
    required double nilai,
    required String tipe,
    required DateTime mulai,
    required DateTime akhir,
    String jadwalTipe = 'rentang_tanggal',
    String hari = '',
    int status = 1,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final formatter = DateFormat('yyyy-MM-dd');

      // Gunakan snake_case agar sesuai dengan binding backend Go Anda
      final Map<String, dynamic> payload = {
        "nama": nama,
        "nilai": nilai,
        "tipe": tipe,
        "jadwal_tipe": jadwalTipe,
        "hari": hari,
        "tanggal_mulai": formatter.format(mulai),
        "tanggal_akhir": formatter.format(akhir),
        if (id != null) "status": status,
      };

      final response = id == null
          ? await ApiClient.post('/discounts', body: payload, token: token)
          : await ApiClient.put('/discounts/$id', body: payload, token: token);

      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchDiscounts();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menyimpan diskon',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteDiscount(String id) async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete('/discounts/$id', token: token);
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        await fetchDiscounts();
        return {'success': true, 'message': body['message']};
      }
      return {'success': false, 'message': body['message']};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    }
  }
}
