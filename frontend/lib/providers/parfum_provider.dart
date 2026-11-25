import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models/parfum_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class ParfumProvider extends ChangeNotifier {
  List<Parfum> _parfums = [];
  bool _isLoading = false;

  List<Parfum> get parfums => _parfums;
  bool get isLoading => _isLoading;

  // 1. Fetch List Parfum
  Future<void> fetchParfums() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/parfums', token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        final List data = body['data'] ?? [];
        _parfums = data.map((e) => Parfum.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetch parfums: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Save/Update Parfum
  Future<Map<String, dynamic>> saveParfum({
    required String nama,
    String? id,
    int status = 1,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;

      // Request Body disesuaikan dengan ParfumController
      final Map<String, dynamic> payload = {
        "nama": nama,
        if (id != null) "status": status,
      };

      final response = id == null
          ? await ApiClient.post('/parfums', body: payload, token: token)
          : await ApiClient.put('/parfums/$id', body: payload, token: token);

      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchParfums(); // Refresh data setelah simpan
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menyimpan data',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Delete Parfum
  Future<Map<String, dynamic>> deleteParfum(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete('/parfums/$id', token: token);
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        await fetchParfums();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus parfum',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
