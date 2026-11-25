import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../data/models/customer_deposit_model.dart';
import '../core/events/app_events.dart';
import '../core/utils/user_friendly_error.dart';

class CustomerDepositProvider extends ChangeNotifier {
  CustomerDeposit? _balance;
  List<CustomerDepositLedgerEntry> _ledger = [];
  bool loading = false;
  bool hasLoaded = false;
  String? errorMessage;
  String? _customerId;
  int _requestVersion = 0;
  int _ledgerPage = 1;
  int _ledgerTotalPages = 0;
  DateTime? lastActivityAt;
  CustomerDeposit? get balance => _balance;
  List<CustomerDepositLedgerEntry> get ledger => List.unmodifiable(_ledger);
  bool get canUseRupiah => (_balance?.balanceRupiah ?? 0) > 0;
  bool get canUseKg => (_balance?.balanceKg ?? 0) > 0;
  bool get hasMoreLedger => _ledgerPage < _ledgerTotalPages;
  Future<void> fetch(String customerId) async {
    final requestVersion = ++_requestVersion;
    final customerChanged = _customerId != customerId;
    _customerId = customerId;
    if (customerChanged) {
      _balance = null;
      _ledger = [];
      hasLoaded = false;
    }
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final responses = await Future.wait([
        ApiClient.get('/pelanggan/$customerId/deposit', token: token),
        ApiClient.get(
          '/pelanggan/$customerId/deposit/ledger?page=1&limit=3',
          token: token,
        ),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('Gagal memuat data deposit pelanggan');
      }
      if (requestVersion != _requestVersion) return;
      _balance = CustomerDeposit.fromJson(
        jsonDecode(responses[0].body)['data'],
      );
      _applyLedgerPayload(jsonDecode(responses[1].body)['data'], append: false);
      hasLoaded = true;
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      errorMessage = userFriendlyError(error);
    } finally {
      if (requestVersion == _requestVersion) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchLedger(
    String customerId, {
    required DateTime start,
    required DateTime end,
    bool append = false,
  }) async {
    if (loading) return;
    final nextPage = append ? _ledgerPage + 1 : 1;
    loading = true;
    errorMessage = null;
    if (!append) _ledger = [];
    notifyListeners();
    try {
      final startDate = _apiDate(start);
      final endDate = _apiDate(end);
      final response = await ApiClient.get(
        '/pelanggan/$customerId/deposit/ledger?start_date=$startDate&end_date=$endDate&page=$nextPage&limit=30',
        token: AuthStorage.token,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat riwayat deposit pelanggan');
      }
      _applyLedgerPayload(jsonDecode(response.body)['data'], append: append);
      hasLoaded = true;
    } catch (error) {
      errorMessage = userFriendlyError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<CustomerDepositLedgerEntry>> fetchAllLedger(
    String customerId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = <CustomerDepositLedgerEntry>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await ApiClient.get(
        '/pelanggan/$customerId/deposit/ledger?start_date=${_apiDate(start)}&end_date=${_apiDate(end)}&page=$page&limit=100',
        token: AuthStorage.token,
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat data export deposit');
      }
      final data = jsonDecode(response.body)['data'];
      if (data is! Map) break;
      rows.addAll(
        (data['items'] as List? ?? []).map(
          (item) => CustomerDepositLedgerEntry.fromJson(item),
        ),
      );
      totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      page++;
    } while (page <= totalPages);
    return rows;
  }

  void _applyLedgerPayload(dynamic data, {required bool append}) {
    final map = data is Map ? data : null;
    final rawItems = map?['items'] as List? ?? (data is List ? data : const []);
    final items = rawItems
        .map((item) => CustomerDepositLedgerEntry.fromJson(item))
        .toList();
    _ledger = append ? [..._ledger, ...items] : items;
    _ledgerPage = (map?['page'] as num?)?.toInt() ?? 1;
    _ledgerTotalPages = (map?['total_pages'] as num?)?.toInt() ?? 1;
    lastActivityAt = DateTime.tryParse('${map?['last_activity_at'] ?? ''}');
  }

  String _apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<bool> topUp(
    String customerId, {
    required String type,
    required double value,
    required double totalPaid,
    double discountAmount = 0,
    String paymentMethod = '',
    String paymentMethodId = '',
    String note = '',
    required String requestId,
  }) async {
    errorMessage = null;
    try {
      final r = await ApiClient.post(
        '/pelanggan/$customerId/deposit/topup',
        token: AuthStorage.token,
        body: {
          'deposit_type': type,
          'value': value,
          'total_paid': totalPaid,
          'discount_amount': discountAmount,
          'payment_method_id': paymentMethodId,
          'note': note,
          'request_id': requestId,
        },
      );
      if (r.statusCode == 201) {
        await fetch(customerId);
        appEventBus.add(DepositChanged(customerId: customerId));
        return true;
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      errorMessage = userFriendlyError(
        body['message'] ?? 'Top up gagal diproses',
      );
    } catch (error) {
      errorMessage = userFriendlyError(error);
    }
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>> adjustmentState(
    String customerId,
    String topupId,
  ) async {
    final response = await ApiClient.get(
      '/pelanggan/$customerId/deposit/topup/$topupId/adjustment-state',
      token: AuthStorage.token,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['data'] is! Map) {
      throw Exception(body['message'] ?? 'Gagal memuat data koreksi');
    }
    return Map<String, dynamic>.from(body['data']);
  }

  Future<bool> adjustTopUp(
    String customerId,
    String topupId, {
    required String kind,
    required double value,
    required double totalPaid,
    String? paymentMethodId,
    required String note,
    required String requestId,
    required double expectedValue,
    required double expectedPaid,
  }) async {
    errorMessage = null;
    try {
      final response = await ApiClient.post(
        '/pelanggan/$customerId/deposit/topup/$topupId/adjust',
        token: AuthStorage.token,
        body: {
          'kind': kind,
          'value': value,
          'total_paid': totalPaid,
          'payment_method_id': ?paymentMethodId,
          'note': note.trim(),
          'request_id': requestId,
          'expected_value': expectedValue,
          'expected_paid': expectedPaid,
        },
      );
      if (response.statusCode == 201) {
        await fetch(customerId);
        appEventBus.add(DepositChanged(customerId: customerId));
        return true;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      errorMessage = userFriendlyError(body['message'] ?? 'Penyesuaian gagal');
    } catch (error) {
      errorMessage = userFriendlyError(error);
    }
    notifyListeners();
    return false;
  }
}
