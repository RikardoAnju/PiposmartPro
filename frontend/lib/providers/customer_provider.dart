import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models/customer_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/utils/user_friendly_error.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];

  List<Customer> get customers => _filteredCustomers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool hasLoaded = false;
  String? errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // 1. FETCH CUSTOMERS
  Future<void> fetchCustomers() async {
    errorMessage = null;
    _setLoading(true);

    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get("/pelanggan", token: token);

      final body = jsonDecode(response.body);

      // Backend menggunakan key "status"
      if (response.statusCode == 200 && body['status'] == true) {
        final List rawData = body['data'] ?? [];
        _customers = rawData.map((e) => Customer.fromJson(e)).toList();

        // DEFAULT SORT: Urutkan Alfabet A-Z
        _sortCustomers();
        _applySearchFilter();
        hasLoaded = true;
      } else {
        throw Exception(body['message'] ?? 'Gagal memuat data pelanggan');
      }
    } catch (e) {
      errorMessage = userFriendlyError(e);
      debugPrint("Error fetching customers: $e");
    } finally {
      _setLoading(false);
    }
  }

  // 2. SAVE NEW CUSTOMER
  Future<Map<String, dynamic>> saveCustomer(
    Map<String, dynamic> payload,
  ) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final sanitizedPayload = _sanitizePayload(payload);
      final response = await ApiClient.post(
        "/pelanggan",
        body: sanitizedPayload,
        token: token,
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchCustomers(); // Refresh & Sort otomatis
        return {
          'success': true,
          'message': body['message'],
          'data': body['data'] != null ? Customer.fromJson(body['data']) : null,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal menyimpan data',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _setLoading(false);
    }
  }

  // 3. UPDATE CUSTOMER
  Future<Map<String, dynamic>> updateCustomer(
    String id,
    Map<String, dynamic> payload,
  ) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final sanitizedPayload = _sanitizePayload(payload);
      final response = await ApiClient.put(
        "/pelanggan/$id",
        body: sanitizedPayload,
        token: token,
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await fetchCustomers(); // Refresh & Sort otomatis
        Customer? updated;
        for (final customer in _customers) {
          if (customer.id == id) {
            updated = customer;
            break;
          }
        }
        return {'success': true, 'message': body['message'], 'data': updated};
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal memperbarui data',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _setLoading(false);
    }
  }

  // 4. DELETE CUSTOMER
  Future<Map<String, dynamic>> deleteCustomer(String id) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete("/pelanggan/$id", token: token);

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await fetchCustomers(); // Refresh & Sort otomatis
        return {'success': true, 'message': body['message']};
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal menghapus data',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> deleteCustomersBulk(List<String> ids) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        "/pelanggan/bulk-delete",
        body: {'ids': ids},
        token: token,
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await fetchCustomers();
        return {
          'success': true,
          'message': body['message'] ?? 'Hapus pelanggan massal selesai',
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus pelanggan terpilih',
        'data': body['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> importCustomersBulk(
    List<Map<String, dynamic>> items,
  ) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final payload = {'items': items.map(_sanitizePayload).toList()};
      final response = await ApiClient.post(
        "/pelanggan/import",
        body: payload,
        token: token,
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchCustomers();
        return {
          'success': true,
          'message': body['message'] ?? 'Import pelanggan selesai',
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Gagal import pelanggan',
        'data': body['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _setLoading(false);
    }
  }

  // --- LOGIKA LOKAL (Search & Sort) ---

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload);
    final rawName = sanitized['nama']?.toString() ?? '';
    sanitized['nama'] = sanitizeCustomerName(rawName);
    return sanitized;
  }

  // Mengurutkan berdasarkan alfabet nama A-Z
  void _sortCustomers() {
    _customers.sort((a, b) {
      final nameA = (a.name).toLowerCase();
      final nameB = (b.name).toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  void searchCustomers(String query) {
    _searchQuery = query;
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = List.from(_customers);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredCustomers = _customers.where((customer) {
        final name = (customer.name).toLowerCase();
        final phone = (customer.phone).toLowerCase();
        final kode = (customer.kode).toLowerCase(); // Menggunakan kode singkat

        return name.contains(query) ||
            phone.contains(query) ||
            kode.contains(query);
      }).toList();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _applySearchFilter();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
