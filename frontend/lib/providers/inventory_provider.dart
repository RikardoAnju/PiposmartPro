import 'dart:convert';

import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:flutter/foundation.dart';

class InventoryProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  int _totalItems = 0;
  int _lowStock = 0;
  int _outOfStock = 0;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _categories = const [];

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  int get totalItems => _totalItems;
  int get lowStock => _lowStock;
  int get outOfStock => _outOfStock;
  List<Map<String, dynamic>> get items => _items;
  List<Map<String, dynamic>> get categories => _categories;

  Future<void> fetchOverview({String query = '', String status = ''}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String>[];
      if (query.trim().isNotEmpty) {
        params.add('q=${Uri.encodeQueryComponent(query.trim())}');
      }
      if (status.isNotEmpty) params.add('status=$status');
      final suffix = params.isEmpty ? '' : '?${params.join('&')}';
      final response = await ApiClient.get(
        '/inventory$suffix',
        token: AuthStorage.token,
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal memuat inventory');
      }
      final data = body['data'] as Map<String, dynamic>? ?? const {};
      final summary = data['summary'] as Map<String, dynamic>? ?? const {};
      _totalItems = (summary['total_items'] as num?)?.toInt() ?? 0;
      _lowStock = (summary['low_stock'] as num?)?.toInt() ?? 0;
      _outOfStock = (summary['out_of_stock'] as num?)?.toInt() ?? 0;
      _items = List<Map<String, dynamic>>.from(data['items'] ?? const []);
      _categories = List<Map<String, dynamic>>.from(
        data['categories'] ?? const [],
      );
    } catch (error) {
      _error = error.toString();
      debugPrint('InventoryProvider: $error');
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> adjustStock({
    required String itemID,
    required String type,
    required double quantity,
    String note = '',
  }) async {
    try {
      final response = await ApiClient.post(
        '/inventory/items/$itemID/stock',
        token: AuthStorage.token,
        body: {'type': type, 'quantity': quantity, 'note': note},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != true) throw Exception(body['message']);
      await fetchOverview();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveCategory({
    String? id,
    required String name,
    required String iconKey,
  }) async {
    try {
      final response = id == null
          ? await ApiClient.post(
              '/inventory/categories',
              token: AuthStorage.token,
              body: {'name': name, 'icon_key': iconKey},
            )
          : await ApiClient.put(
              '/inventory/categories/$id',
              token: AuthStorage.token,
              body: {'name': name, 'icon_key': iconKey},
            );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal menyimpan kategori');
      }
      await fetchOverview();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final response = await ApiClient.delete(
        '/inventory/categories/$id',
        token: AuthStorage.token,
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal menghapus kategori');
      }
      await fetchOverview();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }
}
