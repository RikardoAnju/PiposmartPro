// lib/providers/service_provider.dart

import 'dart:convert';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:flutter/material.dart';
import '../data/models/service_model.dart';

class ServiceProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ServiceCategory> _categories = [];
  List<ServiceCategory> get categories => _categories;

  // Ranking layanan tersering se-outlet (productId -> jumlah order) dari backend.
  Map<String, int> _popularity = {};
  Map<String, int> get popularity => _popularity;

  // State Form Input (Temporary)
  String _categoryName = "";
  List<String> _selectedProcesses = [];
  List<ServiceProduct> _tempProducts = [];

  String get categoryName => _categoryName;
  List<String> get selectedProcesses => _selectedProcesses;
  List<ServiceProduct> get tempProducts => _tempProducts;

  // --- Getters ---
  List<ServiceProduct> get allProducts {
    return _categories.expand((cat) => cat.products).toList();
  }

  ServiceCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- State Actions (Update to return Map for UI Error Handling) ---

  /// Mengganti 'void' menjadi Map agar bisa diproses oleh CustomToast di UI
  Map<String, dynamic> addProduct(ServiceProduct product) {
    _tempProducts.add(product);
    notifyListeners();
    return {'success': true, 'message': 'Produk ditambahkan sementara'};
  }

  Map<String, dynamic> updateProduct(ServiceProduct updatedProduct) {
    final index = _tempProducts.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _tempProducts[index] = updatedProduct;
      notifyListeners();
      return {'success': true, 'message': 'Produk diperbarui sementara'};
    }
    return {'success': false, 'message': 'Produk tidak ditemukan'};
  }

  void removeProduct(String id) {
    _tempProducts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void updateCategoryInfo(String name, List<String> processes) {
    _categoryName = name;
    _selectedProcesses = processes;
    notifyListeners();
  }

  void loadCategoryForEdit(ServiceCategory category) {
    _categoryName = category.name;
    _selectedProcesses = List.from(category.processes);
    _tempProducts = List.from(category.products);
    notifyListeners();
  }

  void clearState() {
    _categoryName = "";
    _selectedProcesses = [];
    _tempProducts = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // API ACTIONS (Sinkron dengan Go Backend)
  // ==========================================

  /// Ambil ranking layanan tersering se-outlet (untuk chip "Tambah Cepat").
  /// Gagal diam-diam — fitur tetap jalan pakai fallback lokal/priority.
  Future<void> fetchPopularServices() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get('/layanan/popular', token: token);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        final List raw = body['data'] ?? [];
        final map = <String, int>{};
        for (final item in raw) {
          final id = item['product_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          map[id] = (item['order_count'] as num?)?.toInt() ?? 0;
        }
        _popularity = map;
        notifyListeners();
      }
    } catch (_) {
      // Abaikan: chip tetap berfungsi dengan urutan fallback.
    }
  }

  Future<void> fetchServices() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      String? token = AuthStorage.token;
      final response = await ApiClient.get('/layanan', token: token);
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        final List rawData = responseBody['data'] ?? [];

        _categories = rawData.map((item) {
          List<String> processList = [];
          if (item['proses'] != null && item['proses'].toString().isNotEmpty) {
            processList = (item['proses'] as String)
                .split(',')
                .map((e) => e.trim())
                .toList();
          }

          List<ServiceProduct> productList = [];
          if (item['products'] != null) {
            productList = (item['products'] as List)
                .map(
                  (p) => ServiceProduct.fromJson(
                    Map<String, dynamic>.from(p as Map),
                  ),
                )
                .toList();
          }

          return ServiceCategory(
            id: item['id'].toString(),
            name: item['nama'] ?? '',
            processes: processList,
            products: productList,
          );
        }).toList();
      } else {
        _errorMessage = responseBody['message'] ?? 'Gagal mengambil data';
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan koneksi';
      debugPrint("Provider Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> saveFullService() async {
    if (_categoryName.trim().isEmpty) {
      return {'success': false, 'message': 'Nama kategori wajib diisi'};
    }
    if (_tempProducts.isEmpty) {
      return {'success': false, 'message': 'Minimal satu produk diperlukan'};
    }

    _setLoading(true);
    try {
      final Map<String, dynamic> payload = {
        "name": _categoryName,
        "processes": _selectedProcesses,
        "products": _tempProducts.map((p) => p.toJson()).toList(),
      };

      String? token = AuthStorage.token;
      final response = await ApiClient.post(
        '/layanan',
        body: payload,
        token: token,
      );
      final resBody = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        clearState();
        await fetchServices();
        return {'success': true, 'message': resBody['message']};
      }
      return {
        'success': false,
        'message': resBody['message'] ?? 'Gagal menyimpan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan sistem: $e'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updateFullService(String categoryId) async {
    _setLoading(true);
    try {
      final Map<String, dynamic> payload = {
        "name": _categoryName,
        "processes": _selectedProcesses,
        "products": _tempProducts.map((p) => p.toJson()).toList(),
      };

      String? token = AuthStorage.token;
      final response = await ApiClient.put(
        '/layanan/$categoryId',
        body: payload,
        token: token,
      );
      final resBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        clearState();
        await fetchServices();
        return {'success': true, 'message': resBody['message']};
      }
      return {
        'success': false,
        'message': resBody['message'] ?? 'Gagal update',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> deleteService(String categoryId) async {
    _setLoading(true);
    try {
      String? token = AuthStorage.token;
      final response = await ApiClient.delete(
        '/layanan/$categoryId',
        token: token,
      );
      final resBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await fetchServices();
        return {'success': true, 'message': resBody['message']};
      }
      return {
        'success': false,
        'message': resBody['message'] ?? 'Gagal menghapus',
      };
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal'};
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
