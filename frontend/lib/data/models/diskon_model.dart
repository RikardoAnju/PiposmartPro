/// Helper jadwal diskon (dipakai lintas model & UI).
const String kJadwalRentangTanggal = 'rentang_tanggal';
const String kJadwalHariBerulang = 'hari_berulang';

/// Nama hari berdasarkan DateTime.weekday (1=Senin .. 7=Minggu).
const List<String> kNamaHari = [
  '',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// Ubah CSV "5,6" → [5,6]. Aman terhadap spasi & nilai kosong.
List<int> parseHariCsv(dynamic raw) {
  if (raw == null) return const [];
  return raw
      .toString()
      .split(',')
      .map((e) => int.tryParse(e.trim()) ?? 0)
      .where((d) => d >= 1 && d <= 7)
      .toList();
}

/// Ubah [5,6] → "5,6".
String hariToCsv(List<int> hari) {
  final sorted = hari.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  return sorted.join(',');
}

class Diskon {
  final String id;
  final String outletId;
  final String nama;
  final double nilai;
  final String tipe; // 'Persen' atau 'Nominal'
  final String jadwalTipe; // 'rentang_tanggal' | 'hari_berulang'
  final List<int> hari; // hari aktif untuk 'hari_berulang' (1=Senin..7=Minggu)
  final DateTime tanggalMulai;
  final DateTime tanggalAkhir;
  final int status; // 1 = active, 0 = inactive
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userUpdate;
  final String userUpdateType;

  Diskon({
    required this.id,
    required this.outletId,
    required this.nama,
    required this.nilai,
    required this.tipe,
    this.jadwalTipe = kJadwalRentangTanggal,
    this.hari = const [],
    required this.tanggalMulai,
    required this.tanggalAkhir,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.userUpdate,
    required this.userUpdateType,
  });

  factory Diskon.fromJson(Map<String, dynamic> json) {
    return Diskon(
      id: json['id']?.toString() ?? '',
      outletId: json['outlet_id']?.toString() ?? '',
      nama: json['nama'] ?? '',
      nilai: (json['nilai'] is int)
          ? (json['nilai'] as int).toDouble()
          : (json['nilai'] ?? 0.0).toDouble(),
      tipe: json['tipe'] ?? 'Nominal',
      jadwalTipe: (json['jadwal_tipe']?.toString().isNotEmpty ?? false)
          ? json['jadwal_tipe'].toString()
          : kJadwalRentangTanggal,
      hari: parseHariCsv(json['hari']),
      tanggalMulai: json['tanggal_mulai'] != null
          ? DateTime.parse(json['tanggal_mulai']).toLocal()
          : DateTime.now(),
      tanggalAkhir: json['tanggal_akhir'] != null
          ? DateTime.parse(json['tanggal_akhir']).toLocal()
          : DateTime.now(),
      status: json['status'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : null,
      userUpdate: json['user_update']?.toString() ?? '',
      userUpdateType: json['user_update_type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'outlet_id': outletId,
      'nama': nama,
      'nilai': nilai,
      'tipe': tipe,
      'jadwal_tipe': jadwalTipe,
      'hari': hariToCsv(hari),
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'tanggal_akhir': tanggalAkhir.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'user_update': userUpdate,
      'user_update_type': userUpdateType,
    };

    if (updatedAt != null) {
      data['updated_at'] = updatedAt!.toIso8601String();
    }

    return data;
  }

  Diskon copyWith({
    String? id,
    String? outletId,
    String? nama,
    double? nilai,
    String? tipe,
    String? jadwalTipe,
    List<int>? hari,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userUpdate,
    String? userUpdateType,
  }) {
    return Diskon(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      nama: nama ?? this.nama,
      nilai: nilai ?? this.nilai,
      tipe: tipe ?? this.tipe,
      jadwalTipe: jadwalTipe ?? this.jadwalTipe,
      hari: hari ?? this.hari,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalAkhir: tanggalAkhir ?? this.tanggalAkhir,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userUpdate: userUpdate ?? this.userUpdate,
      userUpdateType: userUpdateType ?? this.userUpdateType,
    );
  }

  // Helper getters
  bool get isActive => status == 1;

  bool get isPercentage =>
      tipe.toLowerCase() == 'persen' ||
      tipe.toLowerCase() == 'percentage' ||
      tipe.toLowerCase() == '%';

  bool get isNominal =>
      tipe.toLowerCase() == 'nominal' ||
      tipe.toLowerCase() == 'fixed' ||
      tipe.toLowerCase() == 'rupiah';

  String get formattedPercentage {
    final text = nilai
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return '$text%';
  }

  bool get isRecurring => jadwalTipe == kJadwalHariBerulang;

  /// Teks hari untuk diskon berulang, mis. "Jumat" atau "Sabtu, Minggu".
  String get hariText {
    if (hari.isEmpty) return '-';
    final sorted = hari.toSet().toList()..sort();
    return sorted
        .where((d) => d >= 1 && d <= 7)
        .map((d) => kNamaHari[d])
        .join(', ');
  }

  /// Check if discount is currently valid (schedule-aware).
  bool get isValidNow {
    final now = DateTime.now();
    if (isRecurring) {
      return hari.contains(now.weekday);
    }
    return now.isAfter(tanggalMulai) && now.isBefore(tanggalAkhir);
  }

  /// Check if discount is expired
  bool get isExpired => DateTime.now().isAfter(tanggalAkhir);

  /// Check if discount is not yet started
  bool get isUpcoming => DateTime.now().isBefore(tanggalMulai);

  /// Calculate discount amount based on subtotal
  double calculateDiscount(double subtotal) {
    if (isPercentage) {
      return subtotal * nilai / 100;
    }
    return nilai;
  }

  /// Get display name with type indicator
  String get displayName {
    if (isPercentage) {
      return '$nama ($formattedPercentage)';
    }
    return '$nama (Rp ${nilai.toStringAsFixed(0)})';
  }

  /// Get short display text
  String get shortDisplay {
    if (isPercentage) {
      return formattedPercentage;
    }
    return 'Rp ${nilai.toStringAsFixed(0)}';
  }

  String get paymentLabel {
    if (isPercentage) {
      return 'Diskon ($formattedPercentage)';
    }
    return 'Diskon';
  }

  /// Get status text
  String get statusText {
    if (!isActive) return 'Tidak Aktif';
    if (isRecurring) return 'Aktif';
    if (isExpired) return 'Kadaluarsa';
    if (isUpcoming) return 'Akan Datang';
    return 'Aktif';
  }

  /// Get validity info text
  String get validityInfo {
    if (isRecurring) {
      return 'Berlaku setiap: $hariText';
    }
    final startDate =
        '${tanggalMulai.day}/${tanggalMulai.month}/${tanggalMulai.year}';
    final endDate =
        '${tanggalAkhir.day}/${tanggalAkhir.month}/${tanggalAkhir.year}';
    return 'Berlaku: $startDate - $endDate';
  }
}

/// Input model for creating discount
class DiskonInput {
  final String outletId;
  final String nama;
  final double nilai;
  final String tipe;
  final DateTime tanggalMulai;
  final DateTime tanggalAkhir;
  final int status;
  final String userUpdate;
  final String userUpdateType;

  DiskonInput({
    required this.outletId,
    required this.nama,
    required this.nilai,
    required this.tipe,
    required this.tanggalMulai,
    required this.tanggalAkhir,
    this.status = 1,
    required this.userUpdate,
    required this.userUpdateType,
  });

  Map<String, dynamic> toJson() {
    return {
      'outlet_id': outletId,
      'nama': nama,
      'nilai': nilai,
      'tipe': tipe,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'tanggal_akhir': tanggalAkhir.toIso8601String(),
      'status': status,
      'user_update': userUpdate,
      'user_update_type': userUpdateType,
    };
  }

  String? validate() {
    if (nama.isEmpty) {
      return 'Nama diskon harus diisi';
    }

    if (nilai <= 0) {
      return 'Nilai diskon harus lebih dari 0';
    }

    if (tipe != 'Persen' && tipe != 'Nominal') {
      return 'Tipe diskon harus Persen atau Nominal';
    }

    if (tipe == 'Persen' && nilai > 100) {
      return 'Nilai persentase tidak boleh lebih dari 100';
    }

    if (tanggalAkhir.isBefore(tanggalMulai)) {
      return 'Tanggal akhir harus setelah tanggal mulai';
    }

    return null;
  }
}

/// Input model for updating discount
class UpdateDiskonInput {
  final String? nama;
  final double? nilai;
  final String? tipe;
  final DateTime? tanggalMulai;
  final DateTime? tanggalAkhir;
  final int? status;
  final String userUpdate;
  final String userUpdateType;

  UpdateDiskonInput({
    this.nama,
    this.nilai,
    this.tipe,
    this.tanggalMulai,
    this.tanggalAkhir,
    this.status,
    required this.userUpdate,
    required this.userUpdateType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'user_update': userUpdate,
      'user_update_type': userUpdateType,
    };

    if (nama != null) data['nama'] = nama;
    if (nilai != null) data['nilai'] = nilai;
    if (tipe != null) data['tipe'] = tipe;
    if (tanggalMulai != null) {
      data['tanggal_mulai'] = tanggalMulai!.toIso8601String();
    }
    if (tanggalAkhir != null) {
      data['tanggal_akhir'] = tanggalAkhir!.toIso8601String();
    }
    if (status != null) data['status'] = status;

    return data;
  }

  String? validate() {
    if (nama != null && nama!.isEmpty) {
      return 'Nama diskon tidak boleh kosong';
    }

    if (nilai != null && nilai! <= 0) {
      return 'Nilai diskon harus lebih dari 0';
    }

    if (tipe != null && tipe != 'Persen' && tipe != 'Nominal') {
      return 'Tipe diskon harus Persen atau Nominal';
    }

    if (tipe == 'Persen' && nilai != null && nilai! > 100) {
      return 'Nilai persentase tidak boleh lebih dari 100';
    }

    if (tanggalMulai != null && tanggalAkhir != null) {
      if (tanggalAkhir!.isBefore(tanggalMulai!)) {
        return 'Tanggal akhir harus setelah tanggal mulai';
      }
    }

    return null;
  }
}

/// Response model for single discount
class DiskonResponse {
  final bool success;
  final String message;
  final Diskon? data;

  DiskonResponse({required this.success, required this.message, this.data});

  factory DiskonResponse.fromJson(Map<String, dynamic> json) {
    return DiskonResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? Diskon.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message, 'data': data?.toJson()};
  }
}

/// Response model for list of discounts
class DiskonListResponse {
  final bool success;
  final String message;
  final List<Diskon> data;
  final int? total;

  DiskonListResponse({
    required this.success,
    required this.message,
    required this.data,
    this.total,
  });

  factory DiskonListResponse.fromJson(Map<String, dynamic> json) {
    return DiskonListResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? (json['data'] as List).map((item) => Diskon.fromJson(item)).toList()
          : [],
      total: json['total'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.map((item) => item.toJson()).toList(),
      'total': total,
    };
  }
}

/// Enum for discount type
enum DiskonType {
  persen('Persen'),
  nominal('Nominal');

  final String value;
  const DiskonType(this.value);

  static DiskonType fromString(String value) {
    return DiskonType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => DiskonType.nominal,
    );
  }
}

/// Extension for Diskon list
extension DiskonListExtension on List<Diskon> {
  /// Get only active discounts
  List<Diskon> get activeOnly => where((d) => d.isActive).toList();

  /// Get only valid discounts (active and within date range)
  List<Diskon> get validOnly =>
      where((d) => d.isActive && d.isValidNow).toList();

  /// Get percentage discounts
  List<Diskon> get percentageOnly => where((d) => d.isPercentage).toList();

  /// Get nominal discounts
  List<Diskon> get nominalOnly => where((d) => d.isNominal).toList();

  /// Sort by nilai descending
  List<Diskon> sortByNilaiDesc() {
    final sorted = List<Diskon>.from(this);
    sorted.sort((a, b) => b.nilai.compareTo(a.nilai));
    return sorted;
  }

  /// Sort by tanggal akhir ascending
  List<Diskon> sortByExpiry() {
    final sorted = List<Diskon>.from(this);
    sorted.sort((a, b) => a.tanggalAkhir.compareTo(b.tanggalAkhir));
    return sorted;
  }
}
