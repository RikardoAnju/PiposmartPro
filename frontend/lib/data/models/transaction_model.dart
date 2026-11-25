import 'customer_model.dart';
import 'parfum_model.dart';
import 'diskon_model.dart';
import 'metode_pembayaran_model.dart';

const _layananBasePath = 'assets/images/layanan/';

const _iconList = [
  "bantal.webp",
  "bed cover.webp",
  "bikini.webp",
  "blouse.webp",
  "boneka.webp",
  "celana.webp",
  "dress.webp",
  "express.webp",
  "gaun.webp",
  "handuk.webp",
  "hanger.webp",
  "helm.webp",
  "hijab.webp",
  "jaket.webp",
  "jas.webp",
  "kaos kaki.webp",
  "kaos.webp",
  "karpet.webp",
  "kemeja.webp",
  "pakaian bayi.webp",
  "parfume.webp",
  "premium.webp",
  "rok.webp",
  "sajadah.webp",
  "selimut.webp",
  "setrika.webp",
  "snikers.webp",
  "sofa.webp",
  "syal.webp",
  "tas.webp",
  "tirai.webp",
];

String? _matchToLayananAsset(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final cleaned = raw.trim().toLowerCase();

  if (cleaned.startsWith(_layananBasePath)) return raw.trim();

  for (final icon in _iconList) {
    if (icon.toLowerCase() == cleaned) {
      return '$_layananBasePath$icon';
    }
  }

  final withoutExt = cleaned.replaceAll(RegExp(r'\.\w+$'), '');
  for (final icon in _iconList) {
    final iconWithoutExt = icon.toLowerCase().replaceAll(RegExp(r'\.\w+$'), '');
    if (iconWithoutExt == withoutExt) {
      return '$_layananBasePath$icon';
    }
  }

  return null;
}

String _resolveCartIconPath(
  String categoryName,
  String serviceName,
  String? rawPath, {
  String? masterIcon,
}) {
  for (final p in [rawPath, masterIcon]) {
    final candidate = (p ?? '').trim();
    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      return candidate;
    }
  }

  for (final p in [rawPath, masterIcon]) {
    final matched = _matchToLayananAsset(p);
    if (matched != null) return matched;
  }

  final lookup = '$categoryName $serviceName'.toLowerCase();

  const keywordMap = {
    'karpet': 'karpet.webp',
    'bed cover': 'bed cover.webp',
    'bedcover': 'bed cover.webp',
    'selimut': 'selimut.webp',
    'bantal': 'bantal.webp',
    'handuk': 'handuk.webp',
    'sajadah': 'sajadah.webp',
    'tirai': 'tirai.webp',
    'sofa': 'sofa.webp',
    'sepatu': 'snikers.webp',
    'snikers': 'snikers.webp',
    'sneaker': 'snikers.webp',
    'tas': 'tas.webp',
    'helm': 'helm.webp',
    'boneka': 'boneka.webp',
    'gaun': 'gaun.webp',
    'dress': 'dress.webp',
    'jas': 'jas.webp',
    'jaket': 'jaket.webp',
    'hijab': 'hijab.webp',
    'kerudung': 'hijab.webp',
    'rok': 'rok.webp',
    'bikini': 'bikini.webp',
    'blouse': 'blouse.webp',
    'kemeja': 'kemeja.webp',
    'kaos kaki': 'kaos kaki.webp',
    'syal': 'syal.webp',
    'pakaian bayi': 'pakaian bayi.webp',
    'bayi': 'pakaian bayi.webp',
    'celana': 'celana.webp',
    'setrika': 'setrika.webp',
    'parfum': 'parfume.webp',
    'parfume': 'parfume.webp',
    'premium': 'premium.webp',
    'express': 'express.webp',
    'ekspres': 'express.webp',
    'hanger': 'hanger.webp',
    'kaos': 'kaos.webp',
    'kiloan': 'kaos.webp',
    'cuci': 'kaos.webp',
    'laundry': 'kaos.webp',
  };

  for (final entry in keywordMap.entries) {
    if (lookup.contains(entry.key)) {
      return '$_layananBasePath${entry.value}';
    }
  }

  return 'assets/icons/ic_baju.png';
}

class CartItem {
  final int? id;
  final String categoryName;
  final String serviceName;
  final double price;
  double qty;
  final int duration;
  final String durationUnit;
  final String unit;
  final double potonganDiskon;
  final double totalKotor;
  final List<Map<String, dynamic>> paymentHistoryFull;
  final String iconPath;
  String orderStatus;
  String paymentStatus;
  DateTime? readyAt;
  final String? productId;
  final String? masterItemId;
  final String? groupKey;

  CartItem({
    this.id,
    required this.categoryName,
    required this.serviceName,
    required this.price,
    required this.qty,
    required this.duration,
    required this.durationUnit,
    required this.unit,
    required this.iconPath,
    this.potonganDiskon = 0.0,
    this.totalKotor = 0.0,
    this.paymentHistoryFull = const [],
    this.orderStatus = 'Antrian',
    this.paymentStatus = 'Belum Bayar',
    this.readyAt,
    this.productId,
    this.masterItemId,
    this.groupKey,
  });

  double get subtotal => price * qty;
  String get displayName => '$categoryName ( $serviceName )';
  bool get isDue => readyAt != null && DateTime.now().isAfter(readyAt!);

  factory CartItem.fromMap(Map<String, dynamic> map) {
    String categoryName;
    String serviceName;

    final meta = map['product_metadata'] as Map<String, dynamic>? ?? {};

    final rawName =
        (map['nama_layanan'] ??
                map['service_name'] ??
                map['dtr_nama_layanan'] ??
                '')
            .toString()
            .trim();
    final rawCategory = (map['category_name'] ?? map['nama_kategori'] ?? '')
        .toString()
        .trim();
    final rawService =
        (map['nama_layanan'] ??
                map['product_name'] ??
                map['nama_produk'] ??
                map['nama'] ??
                meta['nama'] ??
                '')
            .toString()
            .trim();

    if (rawCategory.isNotEmpty) {
      categoryName = rawCategory;
      serviceName = rawService.isNotEmpty ? rawService : rawName;
    } else if (rawName.contains('(') && rawName.contains(')')) {
      categoryName = rawName.split('(').first.trim();
      serviceName = rawName.split('(').last.replaceAll(')', '').trim();
    } else {
      categoryName = rawName;
      serviceName = (meta['nama'] ?? map['nama'] ?? '').toString().trim();
    }

    final price =
        double.tryParse(
          map['harga']?.toString() ??
              map['price']?.toString() ??
              map['dtr_harga']?.toString() ??
              '0',
        ) ??
        0.0;
    final qty =
        double.tryParse(
          map['qty']?.toString() ?? map['dtr_qty']?.toString() ?? '0',
        ) ??
        0.0;

    ({int value, String unit})? estimateDurationFromReadyAt() {
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

    final estimatedDuration = estimateDurationFromReadyAt();
    final durationRaw =
        map['dtr_durasi'] ??
        map['jp_durasi'] ??
        map['durasi'] ??
        map['duration'] ??
        meta['durasi'] ??
        estimatedDuration?.value ??
        0;
    final duration = int.tryParse(durationRaw.toString()) ?? 0;

    final durationUnitRaw =
        (map['dtr_durasi_satuan'] ??
                map['jp_durasi_satuan'] ??
                map['durasi_satuan'] ??
                map['duration_unit'] ??
                meta['durasi_satuan'] ??
                estimatedDuration?.unit ??
                (duration > 0 ? 'Hari' : ''))
            .toString();
    final durationUnit = _normalizeDurationUnit(durationUnitRaw);

    final unit =
        (map['satuan'] ??
                map['unit'] ??
                map['dtr_satuan'] ??
                map['jp_satuan'] ??
                'Pcs')
            .toString();

    final rawIconPath =
        (map['icon_path'] ??
                map['dtr_icon'] ??
                map['jp_gambar'] ??
                map['icon'] ??
                meta['icon'])
            ?.toString();

    final masterIcon = map['master_icon']?.toString();

    final iconPath = _resolveCartIconPath(
      categoryName,
      serviceName,
      rawIconPath,
      masterIcon: masterIcon,
    );

    final orderStatus = (map['order_status'] ?? map['dtr_status'] ?? 'Antrian')
        .toString();
    final paymentStatus = (map['payment_status'] ?? 'Belum Bayar').toString();

    final readyAtRaw = map['ready_at'] ?? map['dtr_ready_at'];
    final readyAt = readyAtRaw != null
        ? DateTime.tryParse(readyAtRaw.toString())?.toLocal()
        : null;

    final potonganDiskon =
        double.tryParse(map['potongan_diskon']?.toString() ?? '0') ?? 0.0;
    final totalKotor =
        double.tryParse(map['total_kotor']?.toString() ?? '0') ?? 0.0;

    final paymentHistoryFull =
        (map['payment_history_full'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    return CartItem(
      categoryName: categoryName,
      serviceName: serviceName,
      price: price,
      qty: qty,
      duration: duration,
      durationUnit: durationUnit,
      unit: unit,
      iconPath: iconPath,
      potonganDiskon: potonganDiskon,
      totalKotor: totalKotor,
      paymentHistoryFull: paymentHistoryFull,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      readyAt: readyAt,
      productId: (map['product_id'] ?? map['dtr_produk'] ?? map['jp_id'])
          ?.toString(),
      masterItemId: (map['item_id'] ?? map['dtr_item'])?.toString(),
      groupKey: map['group_key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama_layanan': serviceName, // ← ganti jadi serviceName
    'nama_kategori': categoryName,
    'dtr_nama_layanan': serviceName, // ← ganti jadi serviceName
    'dtr_nama_kategori': categoryName,
    'qty': qty,
    'dtr_qty': qty,
    'satuan': unit,
    'dtr_satuan': unit,
    'subtotal': price * qty,
    'dtr_subtotal': price * qty,
    'dtr_durasi': duration,
    'duration': duration,
    'duration_unit': durationUnit,
    'durasi_satuan': durationUnit,
    'ready_at': readyAt?.toIso8601String(),
    'dtr_ready_at': readyAt?.toIso8601String(),
    'service_name': serviceName,
    'price': price,
    'harga': price,
    'unit': unit,
    'icon_path': iconPath,
    'order_status': orderStatus,
    'payment_status': paymentStatus,
    'product_id': productId,
    'item_id': masterItemId,
    'group_key': groupKey,
  };
}

String _normalizeDurationUnit(String value) {
  final lower = value.toLowerCase().trim();
  if (lower == 'jam' || lower == 'hour' || lower == 'hours') return 'Jam';
  if (lower == 'hari' || lower == 'day' || lower == 'days') return 'Hari';
  return value;
}

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

class OrderLog {
  final String status;
  final String adminName;
  final DateTime createdAt;
  final String field;
  final String? newValue;

  const OrderLog({
    required this.status,
    required this.adminName,
    required this.createdAt,
    this.field = '',
    this.newValue,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    String valueOf(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString();
        if (value != null && value.trim().isNotEmpty) return value;
      }
      return '';
    }

    return OrderLog(
      status: valueOf(const ['NewValue', 'newValue', 'new_value']),
      adminName:
          valueOf(const [
            'ActorName',
            'actorName',
            'actor_name',
            'ActorID',
            'actorId',
            'actor_id',
          ]).isNotEmpty
          ? valueOf(const [
              'ActorName',
              'actorName',
              'actor_name',
              'ActorID',
              'actorId',
              'actor_id',
            ])
          : 'Admin',
      createdAt:
          DateTime.tryParse(
            valueOf(const ['CreatedAt', 'createdAt', 'created_at']),
          )?.toLocal() ??
          DateTime.now(),
      field: valueOf(const ['Field', 'field']),
      newValue: valueOf(const ['NewValue', 'newValue', 'new_value']),
    );
  }

  bool get isStatusLog => {
    'Nota Dibuat',
    'Antrian',
    'Proses',
    'Siap Ambil',
    'Selesai',
    'Batal',
  }.contains(status);

  bool get isPaymentLog => field == 'payment';
  bool get isValid => isStatusLog || isPaymentLog;
}

class TransactionModel {
  final String? id;
  final String? outletId;
  final String? invoiceNumber;
  final Customer? customer;
  final List<CartItem> items;
  final Parfum? parfum;
  final Diskon? diskon;
  final double totalPrice;
  final double potonganDiskon;
  final double totalKotor;
  final double roundingAmount;
  final String orderStatus;
  final String paymentStatus;
  final String notes;
  final List<Map<String, dynamic>> optionalItems;
  final List<Map<String, dynamic>> paymentHistoryFull;
  final List<OrderLog> logs;
  final DateTime? createdAt;
  final double dpAmount;
  final double? sisaBayar;
  final PaymentMethod? paymentMethod;
  final DateTime? paidAt;
  final String? kasirName;
  final String? alasanBatal;
  final DateTime? completedAt;
  final DateTime? estimateAt;
  final String? jemputAlamat;
  final double jemputBiaya;
  final String? antarAlamat;
  final double antarBiaya;

  const TransactionModel({
    this.id,
    this.outletId,
    this.invoiceNumber,
    this.customer,
    required this.items,
    this.parfum,
    this.diskon,
    required this.totalPrice,
    this.potonganDiskon = 0.0,
    this.totalKotor = 0.0,
    this.roundingAmount = 0.0,
    this.orderStatus = 'Antrian',
    this.paymentStatus = 'Belum Bayar',
    this.notes = '',
    this.optionalItems = const [],
    this.paymentHistoryFull = const [],
    this.logs = const [],
    this.createdAt,
    this.dpAmount = 0.0,
    this.sisaBayar,
    this.paymentMethod,
    this.paidAt,
    this.kasirName,
    this.alasanBatal,
    this.completedAt,
    this.estimateAt,
    this.jemputAlamat,
    this.jemputBiaya = 0.0,
    this.antarAlamat,
    this.antarBiaya = 0.0,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawLogs =
        (json['logs'] as List?)
            ?.map((l) => OrderLog.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];

    return TransactionModel(
      id: json['tr_id']?.toString() ?? json['id']?.toString(),
      outletId: json['outlet_id']?.toString() ?? json['tr_outlet']?.toString(),
      invoiceNumber:
          json['invoice_number']?.toString() ??
          json['tr_id']?.toString() ??
          json['id']?.toString(),
      customer: json['customer'] != null
          ? Customer.fromJson(json['customer'] as Map<String, dynamic>)
          : json['pelanggan'] != null
          ? Customer.fromJson(json['pelanggan'] as Map<String, dynamic>)
          : null,
      items:
          (json['details'] as List? ?? json['items'] as List?)
              ?.map((i) => CartItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      logs: rawLogs.where((l) => l.isValid).toList(),
      totalPrice:
          double.tryParse(
            json['tr_total']?.toString() ??
                json['total_akhir']?.toString() ??
                json['total_price']?.toString() ??
                '0',
          ) ??
          0.0,
      potonganDiskon:
          double.tryParse(
            json['tr_diskon']?.toString() ??
                json['potongan_diskon']?.toString() ??
                '0',
          ) ??
          0.0,
      totalKotor:
          double.tryParse(
            json['tr_subtotal']?.toString() ??
                json['total_kotor']?.toString() ??
                '0',
          ) ??
          0.0,
      roundingAmount:
          double.tryParse(
            json['rounding_amount']?.toString() ??
                json['tr_rounding']?.toString() ??
                '0',
          ) ??
          0.0,
      orderStatus: (json['order_status'] ?? json['status_order'] ?? 'Antrian')
          .toString(),
      paymentStatus:
          (json['payment_status'] ?? json['status_pembayaran'] ?? 'Belum Bayar')
              .toString(),
      notes: (json['notes'] ?? json['catatan'] ?? '').toString(),
      optionalItems:
          (json['optional_items'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      paymentHistoryFull:
          (json['payment_history_full'] as List? ??
                  json['payment_history'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      parfum: json['parfum'] != null
          ? Parfum.fromJson(json['parfum'] as Map<String, dynamic>)
          : null,
      diskon: json['diskon'] != null
          ? Diskon.fromJson(json['diskon'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
      dpAmount:
          double.tryParse(
            json['dp_amount']?.toString() ?? json['tr_dp']?.toString() ?? '0',
          ) ??
          0.0,
      sisaBayar: json['sisa_bayar'] != null
          ? double.tryParse(json['sisa_bayar'].toString())
          : null,
      paymentMethod: json['payment_method'] != null
          ? PaymentMethod.fromJson(
              json['payment_method'] as Map<String, dynamic>,
            )
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())?.toLocal()
          : null,
      kasirName:
          json['kasir_name']?.toString() ?? json['tr_userupdate']?.toString(),
      alasanBatal:
          rawLogs
              .where((l) => l.field == 'alasan_batal')
              .map((l) => l.newValue)
              .firstOrNull ??
          json['alasan_batal']?.toString(),
      completedAt: _resolveCompletedAt(json, rawLogs),
      estimateAt: _resolveEstimateAt(json),
      jemputAlamat: json['jemput_alamat']?.toString(),
      jemputBiaya:
          double.tryParse(json['jemput_biaya']?.toString() ?? '0') ?? 0.0,
      antarAlamat: json['antar_alamat']?.toString(),
      antarBiaya:
          double.tryParse(json['antar_biaya']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'tr_id': id,
    'outlet_id': outletId,
    'tr_total': totalPrice,
    'tr_subtotal': totalKotor,
    'tr_diskon': potonganDiskon,
    'tr_rounding': roundingAmount,
    'tr_dp': dpAmount,
    'tr_sisa': sisaBayar,
    'tr_status_pembayaran': paymentStatus,
    'payment_status': paymentStatus,
    'status_pembayaran': paymentStatus,
    'tr_status_order': orderStatus,
    'status_order': orderStatus,
    'order_status': orderStatus,
    'notes': notes,
    'catatan': notes,
    'diskon': diskon?.toJson(),
    'discount_label': diskon?.paymentLabel ?? 'Diskon',
    'created_at': createdAt?.toIso8601String(),
    'kasir_name': kasirName,
    'tr_userupdate': kasirName,
    'customer': customer?.toJson(),
    'pelanggan': customer?.toJson(),
    'alasan_batal': alasanBatal,
    'completed_at': completedAt?.toIso8601String(),
    'jemput_alamat': jemputAlamat,
    'jemput_biaya': jemputBiaya,
    'antar_alamat': antarAlamat,
    'antar_biaya': antarBiaya,
    'details': items.map((e) => e.toJson()).toList(),
    'optional_items': optionalItems,
    'parfum_nama': parfum?.nama,
  };
}

DateTime? _resolveEstimateAt(Map<String, dynamic> json) {
  for (final key in ['estimate_at', 'tr_estimate', 'estimated_date']) {
    final value = json[key];
    if (value == null) continue;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

DateTime? _resolveCompletedAt(Map<String, dynamic> json, List<OrderLog> logs) {
  final rawCompleted =
      json['completed_at'] ??
      json['tanggal_selesai'] ??
      json['selesai_at'] ??
      json['finished_at'];
  if (rawCompleted != null) {
    final parsed = DateTime.tryParse(rawCompleted.toString())?.toLocal();
    if (parsed != null) return parsed;
  }

  final selesaiLogs = logs.where(
    (log) => log.status.toLowerCase() == 'selesai',
  );
  if (selesaiLogs.isEmpty) return null;

  return selesaiLogs
      .map((log) => log.createdAt)
      .reduce((latest, item) => item.isAfter(latest) ? item : latest);
}
