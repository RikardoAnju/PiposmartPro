import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models/item_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class ItemProvider extends ChangeNotifier {
  List<ItemLaundry> _items = [];
  bool _isLoading = false;

  List<ItemLaundry> get items => _items;
  List<ItemLaundry> get activeItems => _items.where((e) => e.isActive).toList();
  bool get isLoading => _isLoading;

  Future<void> loadItemsIfEmpty() async {
    if (_items.isNotEmpty) return;
    await fetchItems();
  }

  Future<void> fetchItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/items', token: token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        final List data = body['data'] ?? [];
        _items = data.map((e) => ItemLaundry.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetch items: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveItem({
    required String nama,
    String? id,
    int status = 1,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;

      final Map<String, dynamic> payload = {"Nama": nama, "Status": status};

      final response = id == null
          ? await ApiClient.post('/items', body: payload, token: token)
          : await ApiClient.put('/items/$id', body: payload, token: token);

      final body = jsonDecode(response.body);
      if (body['status'] == true) {
        await fetchItems();
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

  Future<Map<String, dynamic>> deleteItem(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete('/items/$id', token: token);
      final body = jsonDecode(response.body);

      if (body['status'] == true) {
        await fetchItems();
        return {'success': true, 'message': body['message']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus item',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
