import 'dart:convert';
import 'package:ayocucinew/core/config/feature_flags.dart';
import 'package:ayocucinew/data/models/metode_pembayaran_model.dart';
import 'package:flutter/material.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/constants/api_endpoints.dart';

class PaymentMethodProvider extends ChangeNotifier {
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = false;
  String _filterStatus = 'Semua';

  List<PaymentMethod> get paymentMethods => _paymentMethods;
  bool get isLoading => _isLoading;
  String get filterStatus => _filterStatus;
  String? get errorMessage => null;

  List<PaymentMethod> get filteredPaymentMethods {
    if (_filterStatus == 'Aktif') {
      return _paymentMethods.where((m) => m.isActive).toList();
    } else if (_filterStatus == 'Tidak Aktif') {
      return _paymentMethods.where((m) => !m.isActive).toList();
    }
    return _paymentMethods;
  }

  List<PaymentMethod> get methods => _paymentMethods;

  String? _getToken() => AuthStorage.token;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void resetFilter() {
    _filterStatus = 'Semua';
    notifyListeners();
  }

  Future<void> fetchMethods([String? outletId]) async {
    await fetchPaymentMethods(outletId);
  }

  Future<void> fetchPaymentMethods([String? outletId]) async {
    _setLoading(true);
    try {
      final token = _getToken();

      if (token == null || token.isEmpty) {
        debugPrint('Token tidak ditemukan');
        _paymentMethods = [];
        return;
      }

      final endpoint = ApiEndpoints.paymentMethods;

      debugPrint('Fetching payment methods: $endpoint');

      final response = await ApiClient.get(endpoint, token: token);

      debugPrint('Payment Methods Response Status: ${response.statusCode}');
      debugPrint('Payment Methods Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true || data['success'] == true) {
          if (data['data'] == null || data['data'].isEmpty) {
            _paymentMethods = [];
            debugPrint('Tidak ada metode pembayaran');
          } else {
            final List rawData = data['data'];
            _paymentMethods = rawData
                .map((e) => PaymentMethod.fromJson(e))
                .where(
                  (method) => FeatureFlags.nobuQrisEnabled || !method.isNobu,
                )
                .toList();
            debugPrint('Loaded ${_paymentMethods.length} payment methods');
          }
        } else {
          _paymentMethods = [];
          debugPrint('Response status false');
        }
      } else if (response.statusCode == 404) {
        debugPrint('Endpoint not found (404)');
        _paymentMethods = [];
      } else {
        _paymentMethods = [];
        debugPrint('Failed to fetch payment methods: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      _paymentMethods = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> createPaymentMethod(
    PaymentMethodInput input, [
    int? outletId,
  ]) async {
    final validationError = input.validate();
    if (validationError != null) {
      return {'success': false, 'message': validationError};
    }

    _setLoading(true);
    try {
      final token = _getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan. Silakan login kembali.',
        };
      }

      String description = '';
      if (input.category == 'Transfer' &&
          input.bankName != null &&
          input.accountHolder != null) {
        description = '${input.bankName} ${input.accountHolder}';
      } else if (input.category == 'E-Wallet' &&
          input.ewalletProvider != null &&
          input.phoneNumber != null) {
        description = '${input.ewalletProvider} ${input.phoneNumber}';
      } else if (input.category == 'QRIS') {
        description = 'Pembayaran via QRIS';
      } else if (input.category == 'Cash') {
        description = 'Tunai';
      }

      String name = '';
      if (input.category == 'Transfer' && input.bankName != null) {
        name = '${input.bankName} - Transfer';
      } else if (input.category == 'E-Wallet' &&
          input.ewalletProvider != null) {
        name = '${input.ewalletProvider} - E-Wallet';
      } else if (input.category == 'QRIS') {
        name = 'QRIS';
      } else {
        name = input.category ?? 'Cash';
      }

      final Map<String, dynamic> requestBody = {
        'name': name,
        'description': description,
        'category': input.category,
        'is_active': input.status == 1,
      };

      if (input.category == 'Transfer') {
        requestBody['bank_name'] = input.bankName;
        requestBody['account_number'] = input.accountNumber;
        requestBody['account_holder'] = input.accountHolder;
      } else if (input.category == 'E-Wallet') {
        requestBody['ewallet_provider'] = input.ewalletProvider;
        requestBody['phone_number'] = input.phoneNumber;
        // Tambahkan nama pemilik untuk e-wallet
        if (input.accountHolder != null && input.accountHolder!.isNotEmpty) {
          requestBody['account_holder'] = input.accountHolder;
        }
      } else if (input.category == 'QRIS') {
        // Tambahkan nama pemilik untuk QRIS
        if (input.accountHolder != null && input.accountHolder!.isNotEmpty) {
          requestBody['account_holder'] = input.accountHolder;
        }
        // Tambahkan nomor QRIS jika ada
        if (input.accountNumber != null && input.accountNumber!.isNotEmpty) {
          requestBody['account_number'] = input.accountNumber;
        }
      }

      final response = await ApiClient.post(
        ApiEndpoints.paymentMethods,
        body: requestBody,
        token: token,
      );

      debugPrint(
        'Create Payment Method Response Status: ${response.statusCode}',
      );
      debugPrint(
        'Create Payment Method Request Body: ${jsonEncode(requestBody)}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchPaymentMethods();
        return {
          'success': true,
          'message': 'Metode pembayaran berhasil ditambahkan',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message':
            data['message'] ??
            data['error'] ??
            'Gagal menambahkan metode pembayaran',
      };
    } catch (e) {
      debugPrint('Error creating payment method: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updatePaymentMethod(
    String paymentMethodId,
    UpdatePaymentMethodInput input, [
    String? outletId,
  ]) async {
    final validationError = input.validate();
    if (validationError != null) {
      return {'success': false, 'message': validationError};
    }

    _setLoading(true);
    try {
      final token = _getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan. Silakan login kembali.',
        };
      }

      final Map<String, dynamic> requestBody = {};

      if (input.category != null) {
        requestBody['category'] = input.category;

        String description = '';
        String name = '';

        if (input.category == 'Transfer') {
          if (input.bankName != null && input.accountHolder != null) {
            description = '${input.bankName} ${input.accountHolder}';
            name = '${input.bankName} - Transfer';
          }
          if (input.bankName != null) requestBody['bank_name'] = input.bankName;
          if (input.accountNumber != null) {
            requestBody['account_number'] = input.accountNumber;
          }
          if (input.accountHolder != null) {
            requestBody['account_holder'] = input.accountHolder;
          }
        } else if (input.category == 'E-Wallet') {
          if (input.ewalletProvider != null && input.phoneNumber != null) {
            description = '${input.ewalletProvider} ${input.phoneNumber}';
            name = '${input.ewalletProvider} - E-Wallet';
          }
          if (input.ewalletProvider != null) {
            requestBody['ewallet_provider'] = input.ewalletProvider;
          }
          if (input.phoneNumber != null) {
            requestBody['phone_number'] = input.phoneNumber;
          }
          // Tambahkan nama pemilik untuk e-wallet
          if (input.accountHolder != null) {
            requestBody['account_holder'] = input.accountHolder;
          }
        } else if (input.category == 'QRIS') {
          description = 'Pembayaran via QRIS';
          name = 'QRIS';
          if (input.accountHolder != null && input.accountHolder!.isNotEmpty) {
            requestBody['account_holder'] = input.accountHolder;
          }
          if (input.accountNumber != null && input.accountNumber!.isNotEmpty) {
            requestBody['account_number'] = input.accountNumber;
          }
        } else if (input.category == 'Cash') {
          description = 'Tunai';
          name = 'Cash';
        }

        if (name.isNotEmpty) requestBody['name'] = name;
        if (description.isNotEmpty) requestBody['description'] = description;
      }

      if (input.status != null) {
        requestBody['is_active'] = input.status == 1;
      }

      final response = await ApiClient.put(
        '${ApiEndpoints.paymentMethods}/$paymentMethodId',
        body: requestBody,
        token: token,
      );

      debugPrint(
        'Update Payment Method Response Status: ${response.statusCode}',
      );
      debugPrint(
        'Update Payment Method Request Body: ${jsonEncode(requestBody)}',
      );

      if (response.statusCode == 200) {
        await fetchPaymentMethods();
        return {
          'success': true,
          'message': 'Metode pembayaran berhasil diperbarui',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message':
            data['message'] ??
            data['error'] ??
            'Gagal memperbarui metode pembayaran',
      };
    } catch (e) {
      debugPrint('Error updating payment method: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updatePaymentMethodStatus(
    String paymentMethodId,
    bool isActive,
  ) async {
    _setLoading(true);
    try {
      final token = _getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan. Silakan login kembali.',
        };
      }

      final Map<String, dynamic> requestBody = {'is_active': isActive};

      final response = await ApiClient.put(
        '${ApiEndpoints.paymentMethods}/$paymentMethodId',
        body: requestBody,
        token: token,
      );

      debugPrint(
        'Update Payment Method Status Response: ${response.statusCode}',
      );
      debugPrint(
        'Update Payment Method Status Request Body: ${jsonEncode(requestBody)}',
      );

      if (response.statusCode == 200) {
        await fetchPaymentMethods();
        return {
          'success': true,
          'message': 'Status metode pembayaran berhasil diubah',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? data['error'] ?? 'Gagal mengubah status',
      };
    } catch (e) {
      debugPrint('Error updating payment method status: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> deleteMethod(
    String paymentMethodId, [
    String? outletId,
  ]) async {
    return await deletePaymentMethod(paymentMethodId, outletId);
  }

  Future<Map<String, dynamic>> deletePaymentMethod(
    String paymentMethodId, [
    String? outletId,
  ]) async {
    _setLoading(true);
    try {
      final token = _getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan. Silakan login kembali.',
        };
      }

      final response = await ApiClient.delete(
        '${ApiEndpoints.paymentMethods}/$paymentMethodId',
        token: token,
      );

      debugPrint(
        'Delete Payment Method Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        await fetchPaymentMethods();
        return {
          'success': true,
          'message': 'Metode pembayaran berhasil dihapus',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message':
            data['message'] ??
            data['error'] ??
            'Gagal menghapus metode pembayaran',
      };
    } catch (e) {
      debugPrint('Error deleting payment method: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    } finally {
      _setLoading(false);
    }
  }

  PaymentMethod? getPaymentMethodById(String id) {
    try {
      return _paymentMethods.firstWhere((method) => method.id == id);
    } catch (e) {
      return null;
    }
  }

  List<PaymentMethod> getActivePaymentMethods() {
    return _paymentMethods.where((method) => method.isActive).toList();
  }

  List<PaymentMethod> getPaymentMethodsByCategory(String category) {
    return _paymentMethods
        .where((method) => method.category == category)
        .toList();
  }

  List<PaymentMethod> getActivePaymentMethodsByCategory(String category) {
    return _paymentMethods
        .where((method) => method.category == category && method.isActive)
        .toList();
  }

  bool hasCashPaymentMethod() {
    return _paymentMethods.any(
      (method) => method.category == 'Cash' && method.isActive,
    );
  }

  bool hasTransferPaymentMethod() {
    return _paymentMethods.any(
      (method) => method.category == 'Transfer' && method.isActive,
    );
  }

  bool hasEwalletPaymentMethod() {
    return _paymentMethods.any(
      (method) => method.category == 'E-Wallet' && method.isActive,
    );
  }

  bool hasQrisPaymentMethod() {
    return _paymentMethods.any(
      (method) => method.category == 'QRIS' && method.isActive,
    );
  }

  int getActiveCount() {
    return _paymentMethods.where((method) => method.isActive).length;
  }

  int getInactiveCount() {
    return _paymentMethods.where((method) => !method.isActive).length;
  }

  PaymentMethod? getCashPaymentMethod() {
    try {
      return _paymentMethods.firstWhere(
        (method) =>
            (method.category.toLowerCase() == 'cash' ||
                method.category.toLowerCase() == 'tunai') &&
            method.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  PaymentMethod? getDefaultPaymentMethod() {
    final cashMethod = getCashPaymentMethod();
    if (cashMethod != null) {
      return cashMethod;
    }

    final activeMethods = getActivePaymentMethods();
    if (activeMethods.isNotEmpty) {
      return activeMethods.first;
    }

    return null;
  }

  void clearData() {
    _paymentMethods = [];
    _filterStatus = 'Semua';
    notifyListeners();
  }

  Future<Map<String, dynamic>> togglePaymentMethodStatus(
    String paymentMethodId,
    int currentStatus, [
    String? outletId,
  ]) async {
    final newStatus = currentStatus == 1 ? 0 : 1;
    final isActive = newStatus == 1;

    return await updatePaymentMethodStatus(paymentMethodId, isActive);
  }

  Future<Map<String, dynamic>> saveMethod(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    try {
      _setLoading(true);

      final token = _getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan. Silahkan login ulang.',
        };
      }

      final Map<String, dynamic> requestBody = {};

      if (payload['category'] != null) {
        requestBody['category'] = payload['category'];
      }

      if (payload['status'] != null) {
        requestBody['is_active'] = payload['status'] == 1;
      }

      String description = '';
      String name = '';

      if (payload['category'] == 'Transfer') {
        if (payload['bank_name'] != null) {
          requestBody['bank_name'] = payload['bank_name'];
          name = '${payload['bank_name']} - Transfer';
        }
        if (payload['account_number'] != null) {
          requestBody['account_number'] = payload['account_number'];
        }
        if (payload['account_holder'] != null) {
          requestBody['account_holder'] = payload['account_holder'];
        }
        if (payload['bank_name'] != null && payload['account_holder'] != null) {
          description = '${payload['bank_name']} ${payload['account_holder']}';
        }
      } else if (payload['category'] == 'E-Wallet') {
        if (payload['ewallet_provider'] != null) {
          requestBody['ewallet_provider'] = payload['ewallet_provider'];
          name = '${payload['ewallet_provider']} - E-Wallet';
        }
        if (payload['phone_number'] != null) {
          requestBody['phone_number'] = payload['phone_number'];
        }
        // Tambahkan nama pemilik untuk e-wallet
        if (payload['account_holder'] != null &&
            payload['account_holder'].toString().isNotEmpty) {
          requestBody['account_holder'] = payload['account_holder'];
        }
        if (payload['ewallet_provider'] != null &&
            payload['phone_number'] != null) {
          description =
              '${payload['ewallet_provider']} ${payload['phone_number']}';
        }
      } else if (payload['category'] == 'QRIS') {
        final isNobu = payload['qris_type'] == 'QRIS Nobu';
        name = isNobu ? 'QRIS Nobu' : 'QRIS';
        description = isNobu
            ? 'Pembayaran QRIS otomatis via Nobu'
            : 'Pembayaran QRIS outlet statis';
        // Hanya tambahkan jika ada
        if (payload['account_holder'] != null &&
            payload['account_holder'].toString().isNotEmpty) {
          requestBody['account_holder'] = payload['account_holder'];
        }
        if (payload['account_number'] != null &&
            payload['account_number'].toString().isNotEmpty) {
          requestBody['account_number'] = payload['account_number'];
        }
      } else if (payload['category'] == 'Cash') {
        name = 'Cash';
        description = 'Tunai';
      }

      // Nobu is provisioned by the backend; update that record instead of
      // creating a second payment method.
      if (id == null && payload['qris_type'] == 'QRIS Nobu') {
        final existingNobu = _paymentMethods.where((method) => method.isNobu);
        if (existingNobu.isNotEmpty) id = existingNobu.first.id;
      }

      if (name.isNotEmpty) requestBody['name'] = name;
      if (description.isNotEmpty) requestBody['description'] = description;

      if (id != null && id.isNotEmpty) {
        final response = await ApiClient.put(
          '${ApiEndpoints.paymentMethods}/$id',
          body: requestBody,
          token: token,
        );

        debugPrint(
          'Save Method (Update) Response Status: ${response.statusCode}',
        );
        debugPrint(
          'Save Method (Update) Request Body: ${jsonEncode(requestBody)}',
        );

        if (response.statusCode == 200) {
          await fetchPaymentMethods();
          return {
            'success': true,
            'message': 'Metode pembayaran berhasil diperbarui',
          };
        }

        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              data['message'] ??
              data['error'] ??
              'Gagal memperbarui metode pembayaran',
        };
      }

      final response = await ApiClient.post(
        ApiEndpoints.paymentMethods,
        body: requestBody,
        token: token,
      );

      debugPrint(
        'Save Method (Create) Response Status: ${response.statusCode}',
      );
      debugPrint(
        'Save Method (Create) Request Body: ${jsonEncode(requestBody)}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchPaymentMethods();
        return {
          'success': true,
          'message': 'Metode pembayaran berhasil ditambahkan',
        };
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message':
            data['message'] ??
            data['error'] ??
            'Gagal menambahkan metode pembayaran',
      };
    } catch (e) {
      debugPrint('Error saving payment method: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    } finally {
      _setLoading(false);
    }
  }
}
