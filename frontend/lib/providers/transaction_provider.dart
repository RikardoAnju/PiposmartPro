import 'dart:convert';
import 'dart:math';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/unit_label.dart';
import 'package:ayocucinew/data/models/antar_jemput_model.dart';
import 'package:ayocucinew/data/models/metode_pembayaran_model.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';

import '../core/constants/api_endpoints.dart';
import '../core/utils/api_client.dart';
import '../data/models/customer_model.dart';
import '../data/models/diskon_model.dart';
import '../data/models/parfum_model.dart';
import '../data/models/transaction_model.dart';

// ── Rounding mode enum ──
enum RoundingMode { none, ceil, floor, round }

class OptionalItem {
  final String id;
  final String name;
  int qty;
  String keterangan;

  OptionalItem({
    required this.id,
    required this.name,
    this.qty = 1,
    this.keterangan = '',
  });

  Map<String, dynamic> toPayload() => {
    'item_id': id,
    'qty': qty,
    'keterangan': keterangan,
  };
}

class TransactionProvider extends ChangeNotifier {
  static const double maxServiceQty = 999999.9999;
  static const int serviceQtyDecimalDigits = 4;
  static const double roundingUnit = 500.0;

  static String formatServiceQty(double qty) {
    if (qty % 1 == 0) return qty.toInt().toString();
    return qty
        .toStringAsFixed(serviceQtyDecimalDigits)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static bool isWholeNumberUnit(String unit) {
    final normalized = unit.trim().toLowerCase();
    return normalized == 'pcs' ||
        normalized == 'pcs.' ||
        normalized == 'koin' ||
        normalized == 'coin' ||
        normalized == 'piece' ||
        normalized == 'item';
  }

  // Label satuan untuk ditampilkan ke user. Delegasi ke util murni
  // (lib/core/utils/unit_label.dart) yang jadi satu-satunya sumber kebenaran.
  static String displayUnit(String unit) => displayUnitLabel(unit);

  final _storage = const FlutterSecureStorage();

  Customer? _selectedCustomer;
  List<CartItem> _cartItems = [];
  Parfum? _selectedParfum;
  String? _selectedParfumId;
  Diskon? _selectedDiskon;
  PaymentMethod? _selectedPaymentMethod;
  String _notes = '';

  final Map<String, List<OptionalItem>> _optionalItemsByService = {};

  bool _isLoading = false;
  String? _errorMessage;
  TransactionModel? _currentDetail;
  List<TransactionModel> _allTransactions = [];
  String _selectedStatusFilter = 'Semua';
  Map<String, dynamic>? _pendingOrder;
  List<Diskon> _availableDiscounts = [];
  double _cashReceived = 0.0;
  double _dpAmount = 0.0;
  bool _isPaid = false;
  bool _payWithDP = false;
  Map<String, dynamic>? _notaConfig;
  Map<String, dynamic>? _lastTransactionSnapshot;
  List<Map<String, dynamic>> _masterItems = [];
  JemputAntarData _jemputAntar = const JemputAntarData();
  bool _isOrderActive = false;

  // ── Rounding ──
  RoundingMode _roundingMode = RoundingMode.none;
  RoundingMode get roundingMode => _roundingMode;

  void setRoundingMode(RoundingMode mode) {
    final previousTotalToPay = totalToPay;
    _roundingMode = mode;
    final nextTotalToPay = totalToPay;

    if (_isCashPayment &&
        (_cashReceived <= 0 ||
            _cashReceived < nextTotalToPay ||
            (_cashReceived - previousTotalToPay).abs() < 0.01)) {
      _cashReceived = nextTotalToPay;
    }
    notifyListeners();
  }

  double _round(double value) {
    const unit = roundingUnit;
    switch (_roundingMode) {
      case RoundingMode.none:
        return value;
      case RoundingMode.ceil:
        return (value / unit).ceil() * unit;
      case RoundingMode.floor:
        return (value / unit).floor() * unit;
      case RoundingMode.round:
        return (value / unit).round() * unit;
    }
  }

  bool get isOrderActive => _isOrderActive;

  void startNewOrder() {
    _isOrderActive = true;
    clearCart();
  }

  void endOrder() {
    _isOrderActive = false;
  }

  Customer? get selectedCustomer => _selectedCustomer;
  List<CartItem> get cartItems => _cartItems;
  Parfum? get selectedParfum => _selectedParfum;
  String? get selectedParfumId => _selectedParfumId;
  Diskon? get selectedDiskon => _selectedDiskon;
  PaymentMethod? get selectedPaymentMethod => _selectedPaymentMethod;
  String get notes => _notes;

  List<OptionalItem> get optionalItems =>
      _optionalItemsByService.values.expand((list) => list).toList();

  Map<String, List<OptionalItem>> get optionalItemsByService =>
      Map.unmodifiable(_optionalItemsByService);

  List<OptionalItem> get globalOptionalItems =>
      _optionalItemsByService['__global__'] ?? [];

  String? _optionalServiceName(String key) {
    if (key == '__global__' || key == '__edit__') return null;
    final value = key.trim();
    return value.isEmpty ? null : value;
  }

  List<Map<String, dynamic>> get optionalItemsPayload {
    return _optionalItemsByService.entries.expand((entry) {
      final serviceName = _optionalServiceName(entry.key);
      return entry.value.map((item) {
        final payload = item.toPayload();
        payload['name'] = item.name;
        if (serviceName != null) payload['service_name'] = serviceName;
        return payload;
      });
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get optionalItemsByServicePayload {
    return _optionalItemsByService.map((key, value) {
      return MapEntry(
        key,
        value.map((item) {
          final payload = item.toPayload();
          payload['name'] = item.name;
          return payload;
        }).toList(),
      );
    });
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TransactionModel? get currentDetail => _currentDetail;
  List<TransactionModel> get allTransactions => _allTransactions;
  String get selectedStatusFilter => _selectedStatusFilter;
  Map<String, dynamic>? get pendingOrder => _pendingOrder;
  List<Diskon> get availableDiscounts => _availableDiscounts;
  double get dpAmount => _dpAmount;
  double get cashReceived => _cashReceived;
  bool get isPaidStatus => _isPaid;
  bool get isPaid => _currentDetail?.paymentStatus == 'Lunas';
  bool get payWithDP => _payWithDP;
  Map<String, dynamic>? get notaConfig => _notaConfig;
  Map<String, dynamic>? get lastTransactionSnapshot => _lastTransactionSnapshot;
  List<Map<String, dynamic>> get masterItems => _masterItems;
  JemputAntarData get jemputAntar => _jemputAntar;

  bool get isLunasMode => _pendingOrder?['is_from_detail'] == true;
  double get sisaBayarFromDetail =>
      (_pendingOrder?['sisa_bayar'] as num?)?.toDouble() ?? 0.0;
  double get grandTotalFromDetail =>
      (_pendingOrder?['grand_total'] as num?)?.toDouble() ?? 0.0;
  double get jemputBiayaDisplay => _jemputAntar.jemputBiaya;
  double get antarBiayaDisplay => _jemputAntar.antarBiaya;

  double get dpAmountFromDetail =>
      (_pendingOrder?['dp_amount'] as num?)?.toDouble() ?? 0.0;
  double get subtotalFromDetail =>
      (_pendingOrder?['total_kotor'] as num?)?.toDouble() ??
      grandTotalFromDetail;
  double get discountAmountFromDetail =>
      (_pendingOrder?['potongan_diskon'] as num?)?.toDouble() ?? 0.0;
  String? get transactionIdFromDetail =>
      _pendingOrder?['transaction_id']?.toString();
  List<Map<String, dynamic>> get paymentHistoryFromDetail =>
      (_pendingOrder?['payment_history_full'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      [];

  // ==========================================
  // LOGIKA KALKULASI
  // ==========================================

  bool get canRoundInPelunasan {
    if (!isLunasMode) return false;
    return (sisaBayarFromDetail % roundingUnit) != 0;
  }

  double get itemsSubtotal {
    if (isLunasMode) {
      final jemputBiaya =
          (_pendingOrder?['jemput_biaya'] as num?)?.toDouble() ?? 0.0;
      final antarBiaya =
          (_pendingOrder?['antar_biaya'] as num?)?.toDouble() ?? 0.0;
      return max(0.0, subtotalFromDetail - jemputBiaya - antarBiaya);
    }
    return _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get subtotalRaw {
    if (isLunasMode) return subtotalFromDetail;
    return itemsSubtotal + _jemputAntar.totalBiaya;
  }

  double get discountAmount {
    if (isLunasMode) return discountAmountFromDetail;
    if (_selectedDiskon == null) return 0.0;
    final tipe = _selectedDiskon!.tipe.toLowerCase();
    if (tipe == 'persen' || tipe == 'percentage') {
      return subtotalRaw * _selectedDiskon!.nilai / 100;
    }
    return _selectedDiskon!.nilai;
  }

  double get totalBeforeRounding {
    if (isLunasMode) {
      // Gunakan _jemputAntar (yang sudah di-prefill atau diubah kasir)
      // bukan lagi dari pendingOrder statis
      final jemputBiayaBaru = _jemputAntar.jemputBiaya;
      final antarBiayaBaru = _jemputAntar.antarBiaya;
      final jemputBiayaLama =
          (_pendingOrder?['jemput_biaya'] as num?)?.toDouble() ?? 0.0;
      final antarBiayaLama =
          (_pendingOrder?['antar_biaya'] as num?)?.toDouble() ?? 0.0;

      // Selisih biaya jemput/antar jika kasir mengubah
      final selisihJemput = jemputBiayaBaru - jemputBiayaLama;
      final selisihAntar = antarBiayaBaru - antarBiayaLama;

      return sisaBayarFromDetail + selisihJemput + selisihAntar;
    }
    return max(0.0, subtotalRaw - discountAmount);
  }

  double get grandTotal {
    if (isLunasMode) {
      return _round(totalBeforeRounding);
    }
    return _round(totalBeforeRounding);
  }

  double get roundingAmount => grandTotal - totalBeforeRounding;

  double get totalToPay {
    if (isLunasMode) {
      return grandTotal;
    }

    if (!_isPaid && _payWithDP && _dpAmount > 0) {
      return _dpAmount;
    }
    return grandTotal;
  }

  double get sisaBayarEstimasi => max(0.0, grandTotal - _dpAmount);

  double get subtotal => itemsSubtotal;
  double get changeAmount => max(0.0, _cashReceived - totalToPay);
  double get discount => discountAmount;

  bool get canShowPaymentMethod => isLunasMode || _isPaid || (_payWithDP);
  bool get _isCashPayment =>
      _selectedPaymentMethod?.category.toLowerCase() == 'cash';

  List<TransactionModel> get filteredTransactions {
    if (_selectedStatusFilter == 'Semua') return _allTransactions;
    return _allTransactions
        .where((t) => t.orderStatus == _selectedStatusFilter)
        .toList();
  }

  DateTime get estimateCompletion {
    if (_cartItems.isEmpty) return DateTime.now();
    final maxHours = _cartItems.fold<int>(0, (max, item) {
      final hours = item.durationUnit == 'Hari'
          ? item.duration * 24
          : item.duration;
      return hours > max ? hours : max;
    });
    return DateTime.now().add(Duration(hours: maxHours));
  }

  String get customerId => _selectedCustomer?.id ?? '000';
  String get customerName => _selectedCustomer?.name ?? '-';
  DateTime? get estimatedDate => _cartItems.isEmpty ? null : estimateCompletion;

  String get paymentStatusText {
    if (_isPaid) return 'Lunas';
    if (_dpAmount > 0) return 'Belum Lunas | Bayar DP';
    return 'Belum Lunas';
  }

  List<CartItem> get displayCartItems {
    if (isLunasMode) {
      final items = _pendingOrder?['cart_items'];
      if (items is List<CartItem>) return items;
    }
    return _cartItems;
  }

  bool _isSuccess(Map<String, dynamic> data) =>
      data['success'] == true || data['status'] == true;

  String getOrderDetailString() {
    if (_cartItems.isEmpty) return '-';
    return _cartItems
        .map((item) {
          final qty = item.qty % 1 == 0
              ? item.qty.toInt().toString()
              : formatServiceQty(item.qty);
          final price = CurrencyFormatter.formatToRupiah(item.price);
          return '$qty ${displayUnitLabel(item.unit)} x $price | ${item.serviceName} (${item.duration} ${item.durationUnit})';
        })
        .join('\n');
  }

  String getPaymentDisplayText() {
    if (_selectedPaymentMethod == null) return 'Pilih Metode Pembayaran';
    final method = _selectedPaymentMethod!;
    final category = method.category.toLowerCase();
    if (category == 'transfer' && method.bankName != null) {
      return '${method.bankName} - Transfer';
    }
    if (category == 'e-wallet' && method.ewalletProvider != null) {
      return '${method.ewalletProvider} - E-Wallet';
    }
    if (category == 'cash') return 'Tunai / Cash';
    return method.name;
  }

  String getPaymentDetailText() {
    if (_selectedPaymentMethod == null) return '';
    final method = _selectedPaymentMethod!;
    final category = method.category.toLowerCase();
    if (category == 'transfer') {
      if (method.accountNumber != null && method.accountHolder != null) {
        return '${method.accountNumber} a/n ${method.accountHolder}';
      }
      return method.accountNumber ?? '';
    }
    if (category == 'e-wallet' && method.phoneNumber != null) {
      return method.phoneNumber!;
    }
    return '';
  }

  void setCustomer(Customer customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void selectParfum(Parfum? parfum) {
    _selectedParfum = parfum;
    notifyListeners();
  }

  void setSelectedParfum(String? value) {
    _selectedParfumId = value;
    notifyListeners();
  }

  void syncSelectedParfumFromList(List<Parfum> parfums) {
    final currentId = _selectedParfumId?.trim();
    final currentName = _selectedParfum?.nama.trim().toLowerCase();

    if ((currentId == null || currentId.isEmpty) &&
        (currentName == null || currentName.isEmpty)) {
      return;
    }

    final matched = parfums.cast<Parfum?>().firstWhere((parfum) {
      if (parfum == null) return false;
      final idMatches =
          currentId != null && currentId.isNotEmpty && parfum.id == currentId;
      final nameMatches =
          currentName != null &&
          currentName.isNotEmpty &&
          parfum.nama.trim().toLowerCase() == currentName;
      return idMatches || nameMatches;
    }, orElse: () => null);

    if (matched == null) return;
    if (_selectedParfumId == matched.id && _selectedParfum?.id == matched.id) {
      return;
    }

    _selectedParfum = matched;
    _selectedParfumId = matched.id;
    notifyListeners();
  }

  void selectDiskon(Diskon? diskon) {
    _selectedDiskon = diskon;
    notifyListeners();
  }

  void setNotes(String val) {
    _notes = val;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _selectedPaymentMethod = method;
    if (method.category.toLowerCase() != 'cash') _cashReceived = 0.0;
    notifyListeners();
  }

  void clearPaymentMethod() {
    _selectedPaymentMethod = null;
    notifyListeners();
  }

  void setCashReceived(double amount) {
    _cashReceived = amount;
    notifyListeners();
  }

  void setDpAmount(double amount) {
    _dpAmount = amount;
    notifyListeners();
  }

  void setPayWithDP(bool value) {
    _payWithDP = value;
    _dpAmount = value ? _dpAmount : 0.0;
    _selectedPaymentMethod = null;
    notifyListeners();
  }

  void resetPaymentDraft({bool clearDiscount = true}) {
    _pendingOrder = null;
    _selectedPaymentMethod = null;
    _cashReceived = 0.0;
    _dpAmount = 0.0;
    _isPaid = false;
    _payWithDP = false;
    _roundingMode = RoundingMode.none;
    if (clearDiscount) _selectedDiskon = null;
    notifyListeners();
  }

  void setJemputAntar(JemputAntarData data) {
    _jemputAntar = data;
    notifyListeners();
  }

  void prefillJemputAntarFromPendingOrder() {
    if (!isLunasMode) return;

    final jemputAlamat = _pendingOrder?['jemput_alamat']?.toString() ?? '';
    final antarAlamat = _pendingOrder?['antar_alamat']?.toString() ?? '';
    final jemputBiaya =
        (_pendingOrder?['jemput_biaya'] as num?)?.toDouble() ?? 0.0;
    final antarBiaya =
        (_pendingOrder?['antar_biaya'] as num?)?.toDouble() ?? 0.0;

    _jemputAntar = JemputAntarData(
      jemputEnabled: jemputBiaya > 0 || jemputAlamat.isNotEmpty,
      jemputAlamat: jemputAlamat,
      jemputBiaya: jemputBiaya,
      antarEnabled: antarBiaya > 0 || antarAlamat.isNotEmpty,
      antarAlamat: antarAlamat,
      antarBiaya: antarBiaya,
    );
    notifyListeners();
  }

  Map<String, dynamic> get _jemputAntarPayload => {
    'jemput_alamat': _jemputAntar.jemputEnabled
        ? _jemputAntar.jemputAlamat.trim()
        : '',
    'jemput_biaya': _jemputAntar.jemputEnabled ? _jemputAntar.jemputBiaya : 0,
    'antar_alamat': _jemputAntar.antarEnabled
        ? _jemputAntar.antarAlamat.trim()
        : '',
    'antar_biaya': _jemputAntar.antarEnabled ? _jemputAntar.antarBiaya : 0,
  };

  String addServiceToCart({
    required String categoryName,
    required String serviceName,
    required double price,
    required double qty,
    required int duration,
    required String durationUnit,
    required String unit,
    required String iconPath,
    double? minimalOrder,
    String? productId,
    bool mergeDuplicate = true,
  }) {
    if (isWholeNumberUnit(unit) && qty % 1 != 0) {
      throw ArgumentError('Satuan $unit hanya menerima bilangan bulat');
    }
    final maxQty = isWholeNumberUnit(unit)
        ? maxServiceQty.floorToDouble()
        : maxServiceQty;
    if (qty > maxQty) {
      throw ArgumentError(
        'Maksimal jumlah layanan adalah ${formatServiceQty(maxQty)} $unit',
      );
    }
    if (minimalOrder != null && qty < minimalOrder) {
      throw ArgumentError(
        'Minimal order untuk $serviceName adalah ${minimalOrder.toStringAsFixed(minimalOrder % 1 == 0 ? 0 : 1)} $unit',
      );
    }

    final readyAt = _calculateReadyTime(duration, durationUnit);
    final groupKey = _resolveServiceGroupKey(
      serviceName,
      productId: productId,
      mergeDuplicate: mergeDuplicate,
    );
    final index = mergeDuplicate
        ? _cartItems.indexWhere(
            (item) =>
                item.categoryName == categoryName &&
                item.serviceName == serviceName &&
                item.productId == productId,
          )
        : -1;
    if (mergeDuplicate && index != -1) {
      _cartItems[index].qty += qty;
    } else {
      _cartItems.add(
        CartItem(
          categoryName: categoryName,
          serviceName: serviceName,
          price: price,
          qty: qty,
          duration: duration,
          durationUnit: durationUnit,
          unit: unit,
          iconPath: iconPath,
          readyAt: readyAt,
          productId: productId,
          groupKey: groupKey,
        ),
      );
    }
    notifyListeners();
    return groupKey;
  }

  String _resolveServiceGroupKey(
    String serviceName, {
    String? productId,
    required bool mergeDuplicate,
  }) {
    if (mergeDuplicate) return serviceName;

    final existingKeys = _cartItems
        .where(
          (item) =>
              item.serviceName == serviceName &&
              (productId == null || item.productId == productId),
        )
        .map((item) => item.groupKey ?? item.serviceName)
        .toSet();

    var index = 1;
    while (true) {
      final candidate = index == 1 ? serviceName : '$serviceName $index';
      if (!existingKeys.contains(candidate)) return candidate;
      index++;
    }
  }

  void removeCartItem(int index) {
    final removedService = _cartItems[index].serviceName;
    _cartItems.removeAt(index);
    if (_cartItems.isEmpty) {
      _optionalItemsByService.clear();
    } else {
      _optionalItemsByService.remove(removedService);
    }
    notifyListeners();
  }

  void updateCartItemQuantity(int index, double qty) {
    if (index < 0 || index >= _cartItems.length) return;

    final item = _cartItems[index];
    if (isWholeNumberUnit(item.unit) && qty % 1 != 0) {
      throw ArgumentError('Satuan ${item.unit} hanya menerima bilangan bulat');
    }

    final maxQty = isWholeNumberUnit(item.unit)
        ? maxServiceQty.floorToDouble()
        : maxServiceQty;
    if (qty > maxQty) {
      throw ArgumentError(
        'Maksimal jumlah layanan adalah ${formatServiceQty(maxQty)} ${displayUnitLabel(item.unit)}',
      );
    }

    if (qty <= 0) {
      removeCartItem(index);
      return;
    }

    _cartItems[index].qty = qty;
    notifyListeners();
  }

  void clearCart() {
    _selectedCustomer = null;
    _cartItems = [];
    _selectedParfum = null;
    _selectedParfumId = null;
    _roundingMode = RoundingMode.none;
    _selectedDiskon = null;
    _selectedPaymentMethod = null;
    _notes = '';
    _optionalItemsByService.clear();
    _cashReceived = 0.0;
    _dpAmount = 0.0;
    _isPaid = false;
    _payWithDP = false;
    _notaConfig = null;
    _jemputAntar = const JemputAntarData();
    _errorMessage = null;
    notifyListeners();
  }

  void clearAfterSuccess() {
    clearCart();
    _pendingOrder = null;
    notifyListeners();
  }

  void loadCartFromEdit(TransactionModel trx) {
    _cartItems = trx.items
        .map(
          (item) => CartItem(
            categoryName: item.categoryName,
            serviceName: item.serviceName,
            price: item.price,
            qty: item.qty,
            duration: item.duration,
            durationUnit: item.durationUnit,
            unit: item.unit,
            iconPath: item.iconPath,
            productId: item.productId,
            groupKey: item.groupKey,
            readyAt: _calculateReadyTime(item.duration, item.durationUnit),
          ),
        )
        .toList();

    _optionalItemsByService.clear();
    for (final item in trx.optionalItems) {
      final serviceName = item['service_name']?.toString().trim();
      final key = serviceName != null && serviceName.isNotEmpty
          ? serviceName
          : '__edit__';
      _optionalItemsByService[key] ??= [];
      _optionalItemsByService[key]!.add(
        OptionalItem(
          id: item['item_id']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          qty: (item['qty'] as num?)?.toInt() ?? 1,
          keterangan: item['keterangan']?.toString() ?? '',
        ),
      );
    }

    _selectedParfumId = trx.parfum?.id;

    _jemputAntar = JemputAntarData(
      jemputEnabled: trx.jemputAlamat?.isNotEmpty ?? false,
      jemputAlamat: trx.jemputAlamat ?? '',
      jemputBiaya: trx.jemputBiaya,
      antarEnabled: trx.antarAlamat?.isNotEmpty ?? false,
      antarAlamat: trx.antarAlamat ?? '',
      antarBiaya: trx.antarBiaya,
    );

    notifyListeners();
  }

  /// "Ulangi order terakhir": ambil detail transaksi lama lalu salin item-nya ke
  /// order baru. `_currentDetail` sengaja dipulihkan agar order ini tetap
  /// dianggap order BARU (bukan mode edit transaksi lama).
  Future<bool> repeatLastOrder(String transactionId) async {
    if (transactionId.trim().isEmpty) return false;
    final preserved = _currentDetail;
    await fetchTransactionById(transactionId, silent: true);
    final fetched = _currentDetail;
    _currentDetail = preserved;
    if (fetched == null) return false;
    loadCartFromEdit(fetched);
    return true;
  }

  void addOptionalItem(String id, String nama, {int qty = 1}) {
    _optionalItemsByService['__global__'] ??= [];
    final exists = _optionalItemsByService['__global__']!.any(
      (e) => e.id == id,
    );
    if (!exists) {
      _optionalItemsByService['__global__']!.add(
        OptionalItem(id: id, name: nama, qty: qty),
      );
      notifyListeners();
    }
  }

  List<OptionalItem> getOptionalItemsForService(String serviceName) {
    return _optionalItemsByService[serviceName] ?? [];
  }

  void clearOptionalItemsForService(String serviceName) {
    _optionalItemsByService.remove(serviceName);
    notifyListeners();
  }

  void clearGlobalOptionalItems() {
    _optionalItemsByService.remove('__global__');
    notifyListeners();
  }

  /// Mengganti pilihan item global tanpa mereset jumlah/keterangan item yang
  /// sebelumnya sudah dipilih. Item yang baru dipilih mulai dari jumlah 1.
  void replaceGlobalOptionalItemSelection(
    List<Map<String, dynamic>> selectedItems,
  ) {
    final existingById = {
      for (final item in globalOptionalItems) item.id: item,
    };
    setOptionalItemsForService(
      '__global__',
      selectedItems.map((item) {
        final id = item['id']?.toString() ?? '';
        final existing = existingById[id];
        return {
          'id': id,
          'name': item['name']?.toString() ?? existing?.name ?? '',
          'qty': existing?.qty ?? 1,
          'keterangan': existing?.keterangan ?? '',
        };
      }).toList(),
    );
  }

  void setOptionalItemsForService(
    String serviceName,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      _optionalItemsByService.remove(serviceName);
    } else {
      _optionalItemsByService[serviceName] = items
          .map(
            (item) => OptionalItem(
              id: item['id']?.toString() ?? item['item_id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              qty: (item['qty'] as num?)?.toInt() ?? 1,
              keterangan: item['keterangan']?.toString() ?? '',
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
    }
    notifyListeners();
  }

  void addOptionalItemForService(
    String serviceName,
    String id,
    String nama, {
    int qty = 1,
  }) {
    _optionalItemsByService[serviceName] ??= [];
    final exists = _optionalItemsByService[serviceName]!.any((e) => e.id == id);
    if (!exists) {
      _optionalItemsByService[serviceName]!.add(
        OptionalItem(id: id, name: nama, qty: qty),
      );
      notifyListeners();
    }
  }

  List<List<OptionalItem>> _optionalTargetLists(String? serviceName) {
    if (serviceName != null) {
      final list = _optionalItemsByService[serviceName];
      return list == null ? [] : [list];
    }
    return _optionalItemsByService.values.toList();
  }

  void removeOptionalItem(String id, {String? serviceName}) {
    for (final list in _optionalTargetLists(serviceName)) {
      list.removeWhere((e) => e.id == id);
    }
    notifyListeners();
  }

  void clearOptionalItems() {
    _optionalItemsByService.clear();
    notifyListeners();
  }

  void setOptionalItems(List<Map<String, String>> items) {
    _optionalItemsByService.clear();
    _optionalItemsByService['__global__'] = items
        .map(
          (item) =>
              OptionalItem(id: item['id'] ?? '', name: item['name'] ?? ''),
        )
        .toList();
    notifyListeners();
  }

  void updateOptionalItemQuantity(
    String id,
    int quantity, {
    String? serviceName,
  }) {
    for (final list in _optionalTargetLists(serviceName)) {
      final index = list.indexWhere((e) => e.id == id);
      if (index != -1 && quantity > 0) {
        list[index].qty = quantity;
        notifyListeners();
        return;
      }
    }
  }

  void incrementOptionalItemQuantity(String id, {String? serviceName}) {
    for (final list in _optionalTargetLists(serviceName)) {
      final index = list.indexWhere((e) => e.id == id);
      if (index != -1) {
        list[index].qty++;
        notifyListeners();
        return;
      }
    }
  }

  void decrementOptionalItemQuantity(String id, {String? serviceName}) {
    for (final list in _optionalTargetLists(serviceName)) {
      final index = list.indexWhere((e) => e.id == id);
      if (index != -1 && list[index].qty > 1) {
        list[index].qty--;
        notifyListeners();
        return;
      }
    }
  }

  void setOptionalItemKeterangan(String id, String keterangan) {
    for (final list in _optionalItemsByService.values) {
      final index = list.indexWhere((e) => e.id == id);
      if (index != -1) {
        list[index].keterangan = keterangan;
        notifyListeners();
        return;
      }
    }
  }

  bool isOptionalItemAdded(String id) => optionalItems.any((e) => e.id == id);

  int getOptionalItemQty(String id) {
    for (final list in _optionalItemsByService.values) {
      final index = list.indexWhere((e) => e.id == id);
      if (index != -1) return list[index].qty;
    }
    return 0;
  }

  int getTotalOptionalItemsCount() =>
      optionalItems.fold(0, (sum, item) => sum + item.qty);

  void setPendingOrderFromDetail(TransactionModel trx) {
    final dp = trx.dpAmount;
    final sisa = trx.sisaBayar ?? (trx.totalPrice - dp);

    _pendingOrder = {
      'transaction_id': trx.id,
      'cart_items': trx.items,
      'customer': trx.customer,
      'customer_id': trx.customer?.id ?? '',
      'grand_total': trx.totalPrice,
      'total_kotor': trx.totalKotor,
      'potongan_diskon': trx.potonganDiskon,
      'rounding_amount': trx.roundingAmount,
      'dp_amount': dp,
      'sisa_bayar': sisa,
      'notes': trx.notes,
      'is_paid': false,
      'is_from_detail': true,
      'payment_history_full': trx.paymentHistoryFull,
      'jemput_biaya': trx.jemputBiaya,
      'antar_biaya': trx.antarBiaya,
      // FIX: simpan juga alamat agar bisa di-prefill ke widget
      'jemput_alamat': trx.jemputAlamat ?? '',
      'antar_alamat': trx.antarAlamat ?? '',
      'items_payload': trx.items
          .map(
            (e) => {
              'service_name': e.displayName,
              'price': e.price,
              'qty': e.qty,
              'unit': e.unit,
              'icon_path': e.iconPath,
              'duration': e.duration,
              'duration_unit': e.durationUnit,
              'group_key': e.groupKey,
            },
          )
          .toList(),
    };

    _selectedPaymentMethod = null;
    _cashReceived = 0.0;
    _dpAmount = dp;
    _isPaid = false;
    _payWithDP = false;
    notifyListeners();
  }

  void setPendingOrder({double dpAmount = 0.0, bool isPaid = true}) {
    if (_selectedCustomer == null) return;

    _dpAmount = dpAmount;
    _isPaid = isPaid;
    _pendingOrder = {
      'customer_id': _selectedCustomer!.id,
      'customer': _selectedCustomer,
      'parfum_id': _selectedParfumId ?? '',
      'discount_id': _selectedDiskon?.id,
      'diskon': _selectedDiskon,
      'payment_method_id': _selectedPaymentMethod?.id,
      'payment_method': _selectedPaymentMethod,
      'subtotal': subtotalRaw,
      'discount_amount': discountAmount,
      'rounding_amount': roundingAmount,
      'grand_total': grandTotal,
      'notes': _notes,
      'dp_amount': dpAmount,
      'is_paid': isPaid,
      'cash_received': _cashReceived,
      'change_amount': changeAmount,
      'optional_items': optionalItemsPayload,
      'optional_items_by_service': optionalItemsByServicePayload,
      'cart_items': List.from(_cartItems),
      'items_payload': _cartItems
          .map(
            (e) => {
              'service_name': e.displayName,
              'price': e.price,
              'qty': e.qty,
              'unit': e.unit,
              'icon_path': e.iconPath,
              'duration': e.duration,
              'duration_unit': e.durationUnit,
            },
          )
          .toList(),
      'jemput_antar': {
        'jemput_enabled': _jemputAntar.jemputEnabled,
        'jemput_alamat': _jemputAntar.jemputAlamat,
        'jemput_biaya': _jemputAntar.jemputBiaya,
        'antar_enabled': _jemputAntar.antarEnabled,
        'antar_alamat': _jemputAntar.antarAlamat,
        'antar_biaya': _jemputAntar.antarBiaya,
      },
    };
    notifyListeners();
  }

  Future<Map<String, dynamic>> createTransaction({
    bool forcePending = false,
  }) async {
    final validationError = _validateBeforeSubmit();
    if (validationError != null) return _error(validationError);

    final kasirName = await _storage.read(key: 'user_name') ?? '-';
    final snapshot = _buildSnapshot(kasirName: kasirName);

    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.post(
        ApiEndpoints.transactions,
        body: _buildCreatePayload(forcePending: forcePending),
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _handleCreateSuccess(data, snapshot);
        await fetchAllTransactions();
        appEventBus.add(OrderStatusChanged());
        return {
          'success': true,
          'data': data['data'],
          'transaction': data['data']['transaction'],
          'nota_config': data['data']['nota_config'],
          'message': data['message'] ?? 'Transaksi berhasil dibuat',
          'snapshot': _lastTransactionSnapshot,
        };
      }
      return _error(data['message'] ?? 'Gagal membuat transaksi');
    } catch (e) {
      return _error('Error: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updateTransaction(
    String transactionId, {
    bool isLunas = false,
  }) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final payload = {
        'parfum_id': _selectedParfumId,
        'diskon_id': _selectedDiskon?.id,
        'catatan': _notes,
        'rounding_mode': _roundingMode.name,
        if (!isLunas)
          'details': _cartItems
              .map(
                (item) => {'product_id': item.productId ?? '', 'qty': item.qty},
              )
              .toList(),
        'items': optionalItemsPayload,
        ..._jemputAntarPayload,
      };

      final response = await ApiClient.put(
        '${ApiEndpoints.transactions}/update?id=$transactionId',
        body: payload,
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await fetchAllTransactions();
        await fetchTransactionById(transactionId, silent: true);
        appEventBus.add(OrderStatusChanged());
        return _success(data['message'] ?? 'Nota berhasil diperbarui');
      }
      return _error(data['message'] ?? 'Gagal memperbarui transaksi');
    } catch (e) {
      return _error(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updateTransactionStatus(
    String transactionId,
    String status, {
    String alasan = '',
  }) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final body = <String, dynamic>{
        'ids': [transactionId],
        'status': status,
        if (status == 'Batal' && alasan.isNotEmpty) 'alasan': alasan,
      };

      final response = await ApiClient.patch(
        '/status/update',
        body: body,
        token: token,
      );

      if (response.statusCode == 200) {
        await fetchAllTransactions();
        await fetchTransactionById(transactionId, silent: true);
        appEventBus.add(OrderStatusChanged());
        return _success('Status berhasil diperbarui');
      }
      final data = jsonDecode(response.body);
      return _error(data['message'] ?? 'Gagal update status pesanan');
    } catch (e) {
      return _error(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> processPayment(
    String transactionId,
    double amount,
    String methodId,
  ) async {
    _setLoading(true);

    try {
      final token = AuthStorage.token;

      final response = await ApiClient.post(
        '${ApiEndpoints.transactions}/payment?id=$transactionId',
        body: {'amount': amount, 'method_id': methodId, ..._jemputAntarPayload},
        token: token,
      );

      if (response.statusCode == 200) {
        await fetchAllTransactions();
        await fetchTransactionById(transactionId, silent: true);
        appEventBus.add(OrderStatusChanged());
        return _success('Pembayaran Berhasil');
      }

      final data = jsonDecode(response.body);
      return _error(data['message'] ?? 'Gagal memproses pembayaran');
    } catch (e) {
      return _error(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> processLunas() async {
    if (_selectedPaymentMethod == null) {
      return _error('Pilih metode pembayaran terlebih dahulu');
    }

    final transactionId = transactionIdFromDetail;
    if (transactionId == null) return _error('ID transaksi tidak ditemukan');

    _setLoading(true);
    try {
      final token = AuthStorage.token;

      final double amountToPay = totalToPay;

      if (amountToPay <= 0) {
        return _error('Nominal pelunasan tidak boleh nol');
      }

      final response = await ApiClient.post(
        '${ApiEndpoints.transactions}/payment?id=$transactionId',
        body: {
          'amount': amountToPay,
          'method_id': _selectedPaymentMethod!.id,
          ..._jemputAntarPayload,
        },
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await fetchAllTransactions();
        await fetchTransactionById(transactionId);
        appEventBus.add(OrderStatusChanged());
        _pendingOrder = null;
        return _success(data['message'] ?? 'Pelunasan berhasil');
      }
      return _error(data['message'] ?? 'Gagal memproses pelunasan');
    } catch (e) {
      return _error(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllTransactions() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        ApiEndpoints.transactions,
        token: token,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && _isSuccess(data)) {
        _allTransactions = (data['data'] as List)
            .map((e) => TransactionModel.fromJson(e))
            .toList();
      } else {
        _errorMessage = data['message'] ?? 'Gagal mengambil daftar transaksi';
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan sistem';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchPerformanceTransactions() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await ApiClient.get(
        ApiEndpoints.performanceTransactions,
        token: AuthStorage.token,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && _isSuccess(data)) {
        _allTransactions = (data['data'] as List)
            .map((e) => TransactionModel.fromJson(e))
            .toList();
      } else {
        _errorMessage = data['message'] ?? 'Gagal mengambil data performa';
      }
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan sistem';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchDiscounts() async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(ApiEndpoints.diskon, token: token);
      final data = jsonDecode(response.body);
      _availableDiscounts = (response.statusCode == 200 && _isSuccess(data))
          ? (data['data'] as List).map((e) => Diskon.fromJson(e)).toList()
          : [];
    } catch (_) {
      _availableDiscounts = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchTransactionById(String id, {bool silent = false}) async {
    _errorMessage = null;
    if (!silent) {
      _currentDetail = null;
      _setLoading(true);
    }
    try {
      final token = AuthStorage.token;
      if (_masterItems.isEmpty) await fetchMasterItems();

      final response = await ApiClient.get(
        '${ApiEndpoints.transactions}/detail?id=$id',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && _isSuccess(data)) {
        _currentDetail = TransactionModel.fromJson(
          _remapApiFields(data['data']),
        );
      } else {
        _errorMessage = data['message'] ?? 'Detail pesanan tidak ditemukan';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat detail pesanan';
      debugPrint('fetchTransactionById error: $e');
      notifyListeners();
    } finally {
      if (!silent) _setLoading(false);
    }
  }

  Future<void> fetchMasterItems() async {
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(ApiEndpoints.items, token: token);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (_isSuccess(data)) {
          final rawItems = data['data'] is List
              ? data['data'] as List
              : data['data'] is Map && data['data']['items'] is List
              ? data['data']['items'] as List
              : const [];
          _masterItems = rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('fetchMasterItems error: $e');
    }
  }

  Future<List<TransactionModel>> fetchActiveQueue() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.get(
        '${ApiEndpoints.transactions}/queue',
        token: token,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && _isSuccess(data)) {
        return (data['data'] as List)
            .map((e) => TransactionModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Map<String, dynamic> _success(String message) => {
    'success': true,
    'message': message,
  };

  Map<String, dynamic> _error(String message) {
    _errorMessage = message;
    notifyListeners();
    return {'success': false, 'message': message};
  }

  DateTime _calculateReadyTime(int duration, String durationUnit) {
    final now = DateTime.now();
    if (durationUnit == 'Hari') return now.add(Duration(days: duration));
    if (durationUnit == 'Jam') return now.add(Duration(hours: duration));
    return now;
  }

  String? validateOrderData() {
    if (_selectedCustomer == null) return 'Pelanggan harus dipilih';
    if (_cartItems.isEmpty) return 'Keranjang kosong';

    if (_jemputAntar.jemputEnabled) {
      if (_jemputAntar.jemputAlamat.trim().isEmpty) {
        return 'Alamat penjemputan harus diisi';
      }
      if (_jemputAntar.jemputBiaya <= 0) {
        return 'Biaya penjemputan harus lebih dari 0';
      }
    }
    if (_jemputAntar.antarEnabled) {
      if (_jemputAntar.antarAlamat.trim().isEmpty) {
        return 'Alamat pengantaran harus diisi';
      }
      if (_jemputAntar.antarBiaya <= 0) {
        return 'Biaya pengantaran harus lebih dari 0';
      }
    }

    return null;
  }

  String? _validateBeforeSubmit() {
    final orderError = validateOrderData();
    if (orderError != null) return orderError;

    if (_isPaid) {
      if (_selectedPaymentMethod == null) {
        return 'Transaksi Lunas wajib memilih metode pembayaran';
      }
      if (_isCashPayment && _cashReceived < totalToPay) {
        return 'Uang yang diterima kurang dari total pembayaran';
      }
    } else if (_payWithDP && _dpAmount > 0) {
      if (_selectedPaymentMethod == null) {
        return 'Pembayaran DP wajib memilih metode pembayaran';
      }
      if (_isCashPayment && _cashReceived < _dpAmount) {
        return 'Uang yang diterima kurang dari nominal DP';
      }
    }

    return null;
  }

  Map<String, dynamic> _buildCreatePayload({bool forcePending = false}) {
    final payload = <String, dynamic>{
      'pelanggan_id': _selectedCustomer!.id,
      'parfum_id': _selectedParfumId,
      'diskon_id': _selectedDiskon?.id,
      // Dynamic QR payments are finalized by Nobu callback, not at order creation.
      'status_pembayaran': forcePending || !_isPaid ? 'Belum Lunas' : 'Lunas',
      'dp_amount': _dpAmount > 0 ? _dpAmount : 0,
      'rounding_mode': _roundingMode.name,
      'catatan': _notes,
      'details': _cartItems
          .map((item) => {'product_id': item.productId ?? '', 'qty': item.qty})
          .toList(),
      'items': optionalItemsPayload,
      ..._jemputAntarPayload,
    };

    if (_selectedPaymentMethod != null) {
      payload['metode_pembayaran_id'] = _selectedPaymentMethod!.id;
    }

    return payload;
  }

  void _handleCreateSuccess(
    Map<String, dynamic> data,
    Map<String, dynamic> snapshot,
  ) {
    if (data['data']?['nota_config'] != null) {
      _notaConfig = data['data']['nota_config'];
    }
    final trxData = data['data']?['transaction'] as Map<String, dynamic>?;
    if (trxData != null) {
      snapshot['tr_code'] = trxData['id'] ?? '';
      snapshot['tr_id'] = trxData['tr_id'] ?? trxData['id'] ?? '';
    }
    _lastTransactionSnapshot = snapshot;
    clearCart();
    _pendingOrder = null;
  }

  Map<String, dynamic> _buildSnapshot({String? kasirName}) {
    final estSelesai = estimateCompletion;
    final double sisaBayar = grandTotal - _dpAmount;

    return {
      'customer': _selectedCustomer,
      'customer_id': _selectedCustomer?.id ?? '000',
      'customer_name': _selectedCustomer?.name ?? '-',
      'kasir_name': kasirName ?? '-',
      'parfum': _selectedParfum,
      'parfum_id': _selectedParfumId,
      'parfum_nama': _selectedParfum?.nama ?? '-',
      'diskon': _selectedDiskon,
      'payment_method': _selectedPaymentMethod,
      'payment_display': getPaymentDisplayText(),
      'payment_detail': getPaymentDetailText(),
      'cart_items': List<CartItem>.from(_cartItems),
      'optional_items': optionalItemsPayload,
      'optional_items_by_service': optionalItemsByServicePayload,
      'order_detail': getOrderDetailString(),
      'details': _cartItems
          .map(
            (item) => {
              'nama_layanan': item.serviceName,
              'nama_kategori': item.categoryName,
              'dtr_nama_layanan': item.serviceName,
              'dtr_qty': item.qty,
              'qty': item.qty,
              'dtr_satuan': item.unit,
              'satuan': item.unit,
              'dtr_subtotal': item.subtotal,
              'subtotal': item.subtotal,
              'duration': item.duration,
              'duration_unit': item.durationUnit,
              'group_key': item.groupKey,
              'ready_at': (item.readyAt ?? estSelesai).toIso8601String(),
            },
          )
          .toList(),
      'subtotal': itemsSubtotal,
      'tr_subtotal': itemsSubtotal,
      'subtotal_kotor': subtotalRaw,
      'tr_total_kotor': subtotalRaw,
      'discount_amount': discountAmount,
      'tr_diskon': discountAmount,
      'rounding_amount': roundingAmount,
      'tr_rounding': roundingAmount,
      'grand_total': grandTotal,
      'tr_total': grandTotal,
      'total_to_pay': totalToPay,
      'dp_amount': _dpAmount,
      'tr_dp': _dpAmount,
      'sisa_bayar': sisaBayar,
      'tr_sisa': sisaBayar,
      'cash_received': _cashReceived,
      'tr_cash': _cashReceived,
      'change_amount': changeAmount,
      'notes': _notes,
      'payment_status': paymentStatusText,
      'tr_status_pembayaran': paymentStatusText,
      'estimated_date': estSelesai,
      'created_at': DateTime.now(),
      'tr_code': '',
      'tr_id': '',
      'jemput_alamat': _jemputAntar.jemputEnabled
          ? _jemputAntar.jemputAlamat
          : '',
      'jemput_biaya': _jemputAntar.jemputBiaya,
      'antar_alamat': _jemputAntar.antarEnabled ? _jemputAntar.antarAlamat : '',
      'antar_biaya': _jemputAntar.antarBiaya,
      'total_biaya_jemput_antar': _jemputAntar.totalBiaya,
    };
  }

  String _lookupMasterItemName(String itemId) {
    if (itemId.isEmpty) return itemId;
    final normalizedItemId = itemId.trim().toLowerCase();
    final master = _masterItems.firstWhere(
      (m) =>
          m['ID']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['id']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['item_id']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['ItemID']?.toString().trim().toLowerCase() == normalizedItemId,
      orElse: () => {},
    );
    if (master.isEmpty) return itemId;
    return master['Nama']?.toString() ??
        master['nama']?.toString() ??
        master['name']?.toString() ??
        master['item_name']?.toString() ??
        itemId;
  }

  String? _lookupMasterItemIcon(String itemId) {
    if (itemId.isEmpty) return null;
    final normalizedItemId = itemId.trim().toLowerCase();
    final master = _masterItems.firstWhere(
      (m) =>
          m['ID']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['id']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['item_id']?.toString().trim().toLowerCase() == normalizedItemId ||
          m['ItemID']?.toString().trim().toLowerCase() == normalizedItemId,
      orElse: () => {},
    );
    if (master.isEmpty) return null;

    final icon =
        master['icon']?.toString() ??
        master['Icon']?.toString() ??
        master['iconPath']?.toString() ??
        master['jp_gambar']?.toString() ??
        master['gambar']?.toString();

    if (icon == null || icon.isEmpty) return null;
    return icon;
  }

  Map<String, dynamic> _remapApiFields(Map<String, dynamic> raw) {
    ({int value, String unit})? estimateDurationFromDates(
      Map<String, dynamic> map,
    ) {
      final readyAtRaw = map['ready_at'] ?? map['dtr_ready_at'];
      final createdAtRaw = map['created_at'] ?? map['dtr_created'];
      final readyAt = readyAtRaw != null
          ? DateTime.tryParse(readyAtRaw.toString())?.toLocal()
          : null;
      final createdAt = createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw.toString())?.toLocal()
          : null;

      if (readyAt == null || createdAt == null) return null;
      final diff = readyAt.difference(createdAt);
      if (diff.inMinutes <= 0) return null;
      if (diff.inMinutes < 24 * 60) {
        return (
          value: (diff.inMinutes / 60).ceil().clamp(1, 999).toInt(),
          unit: 'Jam',
        );
      }
      return (
        value: (diff.inMinutes / (24 * 60)).ceil().clamp(1, 999).toInt(),
        unit: 'Hari',
      );
    }

    final normalizedDetails = (raw['details'] as List? ?? []).map((e) {
      final map = e as Map<String, dynamic>;
      final meta = map['product_metadata'] as Map<String, dynamic>? ?? {};
      debugPrint('=== RAW DETAIL MAP ===');
      debugPrint(map.toString());
      debugPrint('=== META ===');
      debugPrint(meta.toString());
      final productId =
          (map['product_id'] ?? map['dtr_produk'] ?? map['jp_id'] ?? '')
              .toString();
      final masterIcon = _lookupMasterItemIcon(productId);
      final estimatedDuration = estimateDurationFromDates(map);
      final duration =
          meta['durasi'] ??
          map['duration'] ??
          map['durasi'] ??
          estimatedDuration?.value;
      return {
        ...map,
        ...meta,
        'service_name':
            meta['nama'] ?? map['service_name'] ?? map['nama_layanan'] ?? '-',
        'price': meta['harga'] ?? map['price'] ?? map['harga'] ?? 0,
        'qty': map['qty'] ?? map['dtr_qty'] ?? 1,
        'unit': meta['satuan'] ?? map['unit'] ?? map['satuan'] ?? 'Pcs',
        'duration': duration,
        'duration_unit':
            meta['durasi_satuan'] ??
            map['duration_unit'] ??
            map['durasi_satuan'] ??
            estimatedDuration?.unit ??
            (duration != null ? 'Hari' : null),
        'icon_path':
            meta['icon'] ??
            map['icon_path'] ??
            masterIcon ??
            'assets/icons/ic_baju.webp',
        'product_metadata': meta,
      };
    }).toList();

    Map<String, dynamic>? paymentMethodMapped;
    DateTime? paidAt;

    final paymentHistory = raw['payment_history'] as List?;
    if (paymentHistory != null && paymentHistory.isNotEmpty) {
      final lastPayment = paymentHistory.last as Map<String, dynamic>;
      paidAt = DateTime.tryParse(
        (lastPayment['tanggal_dp'] ??
                lastPayment['created_at'] ??
                lastPayment['paid_at'] ??
                '')
            .toString(),
      )?.toLocal();

      final metode =
          lastPayment['metode_pembayaran'] as Map<String, dynamic>? ??
          lastPayment['payment_method'] as Map<String, dynamic>?;

      paymentMethodMapped = metode != null
          ? {
              'id': metode['ID'] ?? metode['id'] ?? '',
              'name': metode['Nama'] ?? metode['name'] ?? 'Cash',
              'category': metode['Kategori'] ?? metode['category'] ?? 'Cash',
              'bank_name': metode['NamaBank'] ?? metode['bank_name'],
              'ewallet_provider':
                  metode['EwalletProvider'] ?? metode['ewallet_provider'],
              'account_number': metode['NomorAkun'] ?? metode['account_number'],
              'account_holder':
                  metode['NamaPemilik'] ?? metode['account_holder'],
              'phone_number': metode['NomorHP'] ?? metode['phone_number'],
            }
          : {
              'id': lastPayment['metode_pembayaran_id'] ?? '',
              'name': lastPayment['nama_metode'] ?? 'Cash',
              'category': lastPayment['kategori'] ?? 'Cash',
              'bank_name': lastPayment['nama_bank'],
              'ewallet_provider': lastPayment['nama_ewallet'],
              'account_number': lastPayment['nomor_rekening'],
              'account_holder': lastPayment['nama_pemilik'],
              'phone_number': lastPayment['nomor_hp'],
            };
    }

    final optionalItems = (raw['items'] as List? ?? []).map((e) {
      final itemId =
          (e['item_id'] ??
                  e['ItemID'] ??
                  e['itemId'] ??
                  e['id_item'] ??
                  e['dtr_item'] ??
                  '')
              .toString()
              .trim();
      final namaFromApi =
          (e['item_name'] ??
                  e['nama_item'] ??
                  e['NamaItem'] ??
                  e['ItemName'] ??
                  e['Nama'] ??
                  e['nama'] ??
                  e['name'] ??
                  '')
              .toString()
              .trim();
      final namaFromMaster = _lookupMasterItemName(itemId);
      final resolvedName =
          (namaFromMaster != itemId && namaFromMaster.isNotEmpty)
          ? namaFromMaster
          : namaFromApi.isNotEmpty
          ? namaFromApi
          : itemId;
      return {
        'item_id': itemId,
        'name': resolvedName,
        'qty': e['qty'] ?? 1,
        'keterangan': e['keterangan']?.toString() ?? '',
        'service_name': e['service_name']?.toString() ?? '',
      };
    }).toList();

    return {
      ...raw,
      'id': raw['tr_id']?.toString() ?? raw['id']?.toString(),
      'invoice_number': raw['tr_id']?.toString() ?? raw['id']?.toString(),
      'kasir_name':
          raw['kasir_name']?.toString() ??
          raw['tr_userupdate']?.toString() ??
          raw['updated_by']?.toString() ??
          raw['created_by']?.toString(),
      'order_status': raw['order_status'] ?? raw['status_order'],
      'payment_status': raw['payment_status'] ?? raw['status_pembayaran'],
      'total_price':
          raw['total_akhir'] ?? raw['total_price'] ?? raw['total_kotor'] ?? 0,
      'potongan_diskon': raw['potongan_diskon'] ?? 0,
      'rounding_amount': raw['rounding_amount'] ?? raw['tr_rounding'] ?? 0,
      'total_kotor': raw['total_kotor'] ?? 0,
      'notes': raw['notes'] ?? raw['catatan'] ?? '',
      'customer': raw['customer'] ?? raw['pelanggan'],
      'details': normalizedDetails,
      'payment_method': paymentMethodMapped,
      'paid_at': paidAt?.toIso8601String(),
      'dp_amount': raw['dp_amount'] ?? raw['tr_dp'] ?? 0,
      'sisa_bayar': raw['sisa_bayar'] ?? raw['tr_sisa'],
      'payment_history_full': paymentHistory,
      'optional_items': optionalItems,
      'jemput_alamat': raw['jemput_alamat'],
      'jemput_biaya': (raw['jemput_biaya'] as num?)?.toDouble() ?? 0.0,
      'antar_alamat': raw['antar_alamat'],
      'antar_biaya': (raw['antar_biaya'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
