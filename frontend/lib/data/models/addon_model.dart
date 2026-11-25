class Addon {
  final String id;
  final String nama;
  final String link;
  final int harga;
  final String keterangan;
  final int status;

  Addon({
    required this.id,
    required this.nama,
    required this.link,
    required this.harga,
    required this.keterangan,
    this.status = 1,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['ad_id'] ?? '',
      nama: json['ad_nama'] ?? '',
      link: json['ad_link'] ?? '',
      harga: (json['ad_harga'] ?? 0).toInt(),
      keterangan: json['ad_keterangan'] ?? '',
      status: json['ad_status'] ?? 1,
    );
  }
}

class ActiveAddon {
  final String id;
  final String addonId;
  final DateTime mulai;
  final DateTime berakhir;
  final DateTime createdAt;
  final String? targetId;
  final Addon? detail;

  ActiveAddon({
    required this.id,
    required this.addonId,
    required this.mulai,
    required this.berakhir,
    required this.createdAt,
    this.targetId,
    this.detail,
  });

  bool get isExpired => berakhir.isBefore(DateTime.now());

  factory ActiveAddon.fromJson(Map<String, dynamic> json) {
    return ActiveAddon(
      id: json['ha_id'] ?? '',
      addonId: json['ha_addons'] ?? '',
      mulai:
          DateTime.tryParse(
            json['ha_mulai']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      berakhir:
          DateTime.tryParse(
            json['ha_berakhir']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(
            json['ha_created']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      targetId: json['target_id'],
      detail: json['addon'] != null
          ? Addon.fromJson(json['addon'])
          : (json['detail'] != null ? Addon.fromJson(json['detail']) : null),
    );
  }
}

class TransaksiAddon {
  final String id;
  final double total;
  final String metodeBayar;
  final String status;
  final String? snapUrl;
  final String? bukti;
  final int? bankId; // ✅ Sesuai dengan kolom ha_bank_id
  final DateTime createdAt;
  final DateTime? tanggalValidasi;
  final String? itemNames;

  TransaksiAddon({
    required this.id,
    required this.total,
    required this.metodeBayar,
    required this.status,
    this.snapUrl,
    this.bukti,
    this.bankId,
    required this.createdAt,
    this.tanggalValidasi,
    this.itemNames,
  });

  factory TransaksiAddon.fromJson(Map<String, dynamic> json) {
    return TransaksiAddon(
      id: json['ha_id'] ?? '',
      total: (json['ha_total'] ?? 0).toDouble(),
      metodeBayar: json['ha_metode_bayar'] ?? '',
      status: json['ha_status'] ?? 'PENDING',
      snapUrl: json['ha_snap_url'],
      bukti: json['ha_bukti'],
      // ✅ Perhatikan mapping key-nya harus sama dengan JSON response backend
      bankId: json['bank_id'] != null
          ? int.tryParse(json['bank_id'].toString())
          : null,
      createdAt:
          DateTime.tryParse(
            json['ha_created']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      tanggalValidasi: json['ha_tanggal_validasi'] != null &&
              json['ha_tanggal_validasi'].toString().isNotEmpty
          ? DateTime.tryParse(
              json['ha_tanggal_validasi'].toString(),
            )?.toLocal()
          : null,
      itemNames: json['item_names'],
    );
  }
}
