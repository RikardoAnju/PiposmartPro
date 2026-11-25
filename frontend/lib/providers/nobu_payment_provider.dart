import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/constants/api_endpoints.dart';
import '../core/events/app_events.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../data/models/nobu_payment_model.dart';

class NobuPaymentProvider extends ChangeNotifier {
  NobuPaymentModel? _payment;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollTimer;

  NobuPaymentModel? get payment => _payment;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<NobuPaymentModel?> generate(String orderId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await ApiClient.post(
        ApiEndpoints.nobuQris,
        body: {'order_id': orderId},
        token: AuthStorage.token,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['status'] != true) {
        throw Exception(data['message'] ?? 'Gagal membuat QRIS Nobu');
      }
      _payment = NobuPaymentModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      notifyListeners();
      return _payment;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<NobuPaymentModel?> refreshStatus(String orderId) async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.nobuQris}?order_id=${Uri.encodeQueryComponent(orderId)}',
        token: AuthStorage.token,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['status'] != true) {
        throw Exception(data['message'] ?? 'Gagal mengambil status QRIS');
      }
      final wasPaid = _payment?.isPaid ?? false;
      _payment = NobuPaymentModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      // Saat pembayaran QRIS baru terkonfirmasi lunas, beri tahu daftar
      // transaksi (StatusProvider) agar lane ikut berubah jadi Lunas —
      // callback settlement Nobu tidak selalu memicu push websocket.
      if (_payment!.isPaid && !wasPaid) {
        appEventBus.add(OrderStatusChanged());
      }
      notifyListeners();
      return _payment;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  void startPolling(String orderId) {
    stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final result = await refreshStatus(orderId);
      // Berhenti polling begitu status final tercapai. `null` berarti error
      // jaringan sesaat — biarkan timer lanjut mencoba lagi.
      if (result != null && !result.isWaiting) stopPolling();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    stopPolling();
    _payment = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
