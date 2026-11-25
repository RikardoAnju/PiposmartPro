import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/events/app_events.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../data/models/iap_product_model.dart';

class IapProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _pendingOutletKey = 'iap_pending_outlet_id';
  static const String _pendingProductIdKey = 'iap_pending_product_id';
  static const String _pendingProductTypeKey = 'iap_pending_product_type';

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Timer? _purchaseWatchdog;
  bool _isAvailable = false;
  bool _isLoading = false;
  // Dipisah dari _isLoading: hanya true saat user menekan "Beli" sampai
  // transaksi tuntas. Stream latar (transaksi yang di-redeliver saat app
  // dibuka) TIDAK boleh menyetel flag ini agar tombol Beli tak terkunci.
  bool _isPurchasing = false;
  String? _errorMessage;

  List<IapProductModel> _backendProducts = [];
  List<ProductDetails> _storeProducts = [];

  String? _pendingOutletId;
  String? _pendingProductId;
  String? _pendingProductType;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  String? get errorMessage => _errorMessage;
  List<IapProductModel> get backendProducts => _backendProducts;
  List<ProductDetails> get storeProducts => _storeProducts;
  List<ProductDetails> get coinStoreProducts {
    final coinIds = _backendProducts
        .where((item) => item.productType == 'COIN')
        .map((item) => item.productId)
        .toSet();
    return _storeProducts.where((item) => coinIds.contains(item.id)).toList();
  }

  String _productLabel(String productType) {
    switch (productType) {
      case 'OUTLET_PRO':
        return 'aktivasi PRO';
      case 'COIN':
      default:
        return 'top up koin';
    }
  }

  String _storeUnavailableMessage(String productType) {
    return 'Produk App Store untuk ${_productLabel(productType)} belum tersedia.';
  }

  String _networkVerificationMessage(String productType) {
    return 'Pembelian ${_productLabel(productType)} berhasil diproses App Store, tapi verifikasi ke server belum selesai. Periksa koneksi lalu buka lagi halaman ini.';
  }

  String _startPurchaseErrorMessage(
    Object error, {
    required String productType,
  }) {
    final raw = error.toString().toLowerCase();

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      final combined = '$code $message $raw';

      if (combined.contains('usercancelled') ||
          combined.contains('cancelled') ||
          combined.contains('canceled')) {
        return 'Pembelian ${_productLabel(productType)} belum dilanjutkan di App Store. Coba buka lagi lalu selesaikan konfirmasi pembeliannya.';
      }

      if (combined.contains('storekit') &&
          (combined.contains('network') ||
              combined.contains('timeout') ||
              combined.contains('connection'))) {
        return 'App Store sedang bermasalah atau koneksi kurang stabil. Coba lagi beberapa saat.';
      }
    }

    if (raw.contains('network') ||
        raw.contains('internet') ||
        raw.contains('connection') ||
        raw.contains('timeout')) {
      return 'Koneksi sedang bermasalah. Coba ulang ${_productLabel(productType)} saat jaringan stabil.';
    }

    return 'Gagal memulai pembelian ${_productLabel(productType)} di App Store.';
  }

  String _purchaseErrorMessage(
    PurchaseDetails purchase, {
    required String productType,
  }) {
    final details = purchase.error;
    final rawCode = details?.code.toString().toLowerCase() ?? '';
    final rawMessage = details?.message.toLowerCase() ?? '';
    final combined = '$rawCode $rawMessage';

    if (combined.contains('cancel')) {
      return 'Pembelian ${_productLabel(productType)} dibatalkan.';
    }

    if (combined.contains('network') ||
        combined.contains('internet') ||
        combined.contains('connection') ||
        combined.contains('timeout') ||
        combined.contains('timed out')) {
      return 'Koneksi sedang bermasalah. Coba ulang ${_productLabel(productType)} saat jaringan stabil.';
    }

    return details != null && details.message.trim().isNotEmpty
        ? details.message
        : 'Pembelian ${_productLabel(productType)} gagal.';
  }

  IapProvider() {
    if (Platform.isIOS) {
      _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdated);
    }
  }

  Future<void> _persistPendingPurchaseContext({
    required String outletId,
    required String productId,
    required String productType,
  }) async {
    await Future.wait([
      _storage.write(key: _pendingOutletKey, value: outletId),
      _storage.write(key: _pendingProductIdKey, value: productId),
      _storage.write(key: _pendingProductTypeKey, value: productType),
    ]);
  }

  Future<void> _restorePendingPurchaseContext() async {
    _pendingOutletId ??= await _storage.read(key: _pendingOutletKey);
    _pendingProductId ??= await _storage.read(key: _pendingProductIdKey);
    _pendingProductType ??= await _storage.read(key: _pendingProductTypeKey);
  }

  Future<void> _clearPendingPurchaseContext() async {
    _pendingOutletId = null;
    _pendingProductId = null;
    _pendingProductType = null;
    await Future.wait([
      _storage.delete(key: _pendingOutletKey),
      _storage.delete(key: _pendingProductIdKey),
      _storage.delete(key: _pendingProductTypeKey),
    ]);
  }

  ProductDetails? getStoreProduct(String productId) {
    try {
      return _storeProducts.firstWhere((item) => item.id == productId);
    } catch (_) {
      return null;
    }
  }

  ProductDetails? getStoreProductByType(String productType) {
    try {
      final backend = _backendProducts.firstWhere(
        (item) => item.productType == productType,
      );
      return getStoreProduct(backend.productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> initializeIosTopupProducts() async {
    if (!Platform.isIOS) return;

    _isLoading = true;
    _errorMessage = null;
    _storeProducts = [];
    _backendProducts = [];
    notifyListeners();

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        _errorMessage =
            'Apple In-App Purchase tidak tersedia di perangkat ini.';
        return;
      }

      final token = AuthStorage.token;
      final response = await ApiClient.get('/iap/ios/products', token: token);
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 || body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal memuat produk iOS');
      }

      final List rawProducts = body['data'] ?? [];
      _backendProducts = rawProducts
          .map(
            (item) => IapProductModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      final ids = _backendProducts.map((item) => item.productId).toSet();
      final responseStore = await _iap.queryProductDetails(ids);
      if (responseStore.error != null) {
        throw Exception(responseStore.error!.message);
      }

      _storeProducts = responseStore.productDetails.toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      // Produk yang tidak ditemukan di App Store (biasanya: belum "Ready to
      // Submit", agreement/Paid Apps belum aktif, atau bundle/product id salah).
      // Surface sebagai pesan jelas alih-alih tombol Beli mati diam-diam.
      if (responseStore.notFoundIDs.isNotEmpty) {
        debugPrint(
          'IAP product tidak ditemukan di App Store: ${responseStore.notFoundIDs}',
        );
        if (_storeProducts.isEmpty) {
          _errorMessage =
              'Produk pembelian belum tersedia di App Store. Pastikan perjanjian '
              '(Paid Apps) aktif dan produk sudah siap, lalu coba lagi.';
        }
      }
    } on PlatformException catch (e) {
      _errorMessage = _purchaseStartHintFromPlatformException(e);
      debugPrint('Gagal memuat produk iOS: $e');
    } catch (e) {
      _errorMessage = 'Gagal memuat produk iOS: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _purchaseStartHintFromPlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    final combined = '$code $message';

    if (combined.contains('storekit') &&
        (combined.contains('failed to get response') ||
            combined.contains('no products') ||
            combined.contains('product'))) {
      return 'StoreKit belum merespons. Pastikan produk App Store sudah dibuat, statusnya aktif, dan Paid Apps Agreement sudah disetujui.';
    }

    return 'Gagal memuat produk iOS: ${error.message ?? error.code}';
  }

  IapProductModel? getBackendProduct(String productId) {
    try {
      return _backendProducts.firstWhere((item) => item.productId == productId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> purchaseCoinProduct({
    required String productId,
    required String outletId,
  }) async {
    return _purchaseProduct(
      productId: productId,
      outletId: outletId,
      productType: 'COIN',
    );
  }

  Future<Map<String, dynamic>> purchaseOutletPro({
    required String outletId,
  }) async {
    if (_backendProducts.isEmpty || _storeProducts.isEmpty) {
      await initializeIosTopupProducts();
    }

    final product = getStoreProductByType('OUTLET_PRO');
    if (product == null) {
      return {
        'success': false,
        'message':
            _errorMessage ?? 'Produk aktivasi PRO App Store belum tersedia.',
      };
    }

    return _purchaseProduct(
      productId: product.id,
      outletId: outletId,
      productType: 'OUTLET_PRO',
    );
  }

  Future<Map<String, dynamic>> _purchaseProduct({
    required String productId,
    required String outletId,
    required String productType,
  }) async {
    if (!Platform.isIOS) {
      return {
        'success': false,
        'message': 'Pembelian iOS hanya tersedia di iPhone.',
      };
    }

    if (_isPurchasing) {
      return {
        'success': false,
        'message': 'Pembelian lain sedang diproses. Tunggu sebentar.',
      };
    }

    final product = getStoreProduct(productId);
    if (product == null) {
      return {
        'success': false,
        'message': _storeUnavailableMessage(productType),
      };
    }

    _pendingOutletId = outletId;
    _pendingProductId = productId;
    _pendingProductType = productType;
    _errorMessage = null;
    _setPurchasing(true);

    try {
      await _persistPendingPurchaseContext(
        outletId: outletId,
        productId: productId,
        productType: productType,
      );
      final ok = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!ok) {
        await _clearPendingPurchaseContext();
        _setPurchasing(false);
        return {
          'success': false,
          'message': 'Gagal memulai pembelian App Store.',
        };
      }
      return {'success': true, 'message': 'Pembelian sedang diproses.'};
    } catch (e) {
      await _clearPendingPurchaseContext();
      _setPurchasing(false);
      return {
        'success': false,
        'message': _startPurchaseErrorMessage(e, productType: productType),
      };
    }
  }

  /// Set status "sedang membeli" + watchdog: kalau tak ada update dari
  /// purchaseStream dalam 2 menit, reset otomatis supaya tombol Beli tak
  /// terkunci selamanya bila StoreKit tidak mengirim status akhir.
  void _setPurchasing(bool value) {
    _isPurchasing = value;
    _purchaseWatchdog?.cancel();
    if (value) {
      _purchaseWatchdog = Timer(const Duration(minutes: 2), () {
        if (_isPurchasing) {
          _isPurchasing = false;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  /// Memicu App Store mengirim ulang transaksi yang belum tuntas (mis. verifikasi
  /// sempat gagal) agar bisa diproses lagi — dipakai tombol "Pulihkan Pembelian".
  Future<void> recoverPurchases() async {
    if (!Platform.isIOS) return;
    _errorMessage = null;
    _setPurchasing(false); // lepaskan kunci bila ada yang nyangkut
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _errorMessage = 'Gagal memulihkan pembelian: $e';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        // Hanya perpanjang watchdog bila memang ada pembelian aktif user.
        // Transaksi latar yang pending TIDAK mengunci tombol Beli.
        if (_isPurchasing) {
          _setPurchasing(true);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        final productType = _pendingProductType ?? 'COIN';
        _errorMessage = purchase.status == PurchaseStatus.canceled
            ? 'Pembelian ${_productLabel(productType)} dibatalkan.'
            : _purchaseErrorMessage(purchase, productType: productType);
        await _clearPendingPurchaseContext();
        _setPurchasing(false);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchaseWithBackend(purchase);
      }
    }
  }

  Future<void> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    await _restorePendingPurchaseContext();

    final productType = _pendingProductType ?? 'COIN';
    final productId = _pendingProductId ?? purchase.productID;
    final outletId =
        _pendingOutletId ?? await _storage.read(key: 'current_outlet_id');
    if (outletId == null || outletId.isEmpty) {
      _errorMessage =
          'Outlet aktif belum terbaca. Koin mungkin sudah diproses, silakan buka lagi halaman Dompet Koin.';
      _setPurchasing(false);
      return;
    }

    // Only finish the StoreKit transaction once the backend has given a
    // definitive answer (granted, or explicitly rejected). On a transport
    // failure (no response reached the server) we must NOT complete the
    // purchase: StoreKit will keep it in the queue and redeliver it via
    // `purchaseStream` on next launch/restore, so it can be retried. The
    // backend's verify endpoint is idempotent on transaction_id, so a retry
    // is safe and won't double-grant.
    var backendRespondedDefinitively = false;
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        productType == 'OUTLET_PRO'
            ? '/iap/ios/verify-outlet-pro'
            : '/iap/ios/verify-coin-topup',
        token: token,
        body: {
          'product_id': productId,
          'transaction_id': purchase.purchaseID,
          'original_transaction_id': purchase.purchaseID,
          'receipt_data': purchase.verificationData.serverVerificationData,
          'outlet_id': outletId,
          'environment_hint': kDebugMode ? 'Sandbox' : 'Production',
        },
      );
      final body = jsonDecode(response.body);
      backendRespondedDefinitively = true;
      if (response.statusCode == 200 && body['status'] == true) {
        _errorMessage = null;
        if (productType == 'OUTLET_PRO') {
          appEventBus.add(OutletActivated(outletId: outletId));
        } else {
          final topupId =
              body['data']?['store_transaction_id']?.toString() ??
              body['data']?['topup_id']?.toString();
          appEventBus.add(TopupSucceeded(topupId: topupId));
          appEventBus.add(CoinBalanceChanged());
        }
      } else {
        _errorMessage = body['message']?.toString().trim().isNotEmpty == true
            ? body['message'].toString()
            : _networkVerificationMessage(productType);
      }
    } catch (e) {
      // Transport/parsing failure — the backend may or may not have
      // received the request. Leave the transaction unfinished so it's
      // retried on next launch instead of silently losing the purchase.
      _errorMessage = _networkVerificationMessage(productType);
    } finally {
      _setPurchasing(false);
      if (backendRespondedDefinitively) {
        await _clearPendingPurchaseContext();
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  @override
  void dispose() {
    _purchaseWatchdog?.cancel();
    _purchaseSub?.cancel();
    super.dispose();
  }
}
