import 'package:intl/intl.dart';

String sanitizeCustomerName(String raw, {String fallback = ''}) {
  final cleaned = raw
      .replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s.,:/@+\-()&]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

class Customer {
  final String id;
  final String outletId;
  final String kode;
  final String name;
  final String phone;
  final String gender;
  final DateTime? birthDate;
  final String address;
  final int status;
  final DateTime? createdAt;
  final DateTime? lastTransactionAt;
  final String? lastTransactionId;
  final double depositRupiah;
  final double depositKg;

  Customer({
    required this.id,
    required this.outletId,
    required this.kode,
    required this.name,
    required this.phone,
    required this.gender,
    this.birthDate,
    required this.address,
    required this.status,
    this.createdAt,
    this.lastTransactionAt,
    this.lastTransactionId,
    this.depositRupiah = 0,
    this.depositKg = 0,
  });

  // Factory untuk mapping dari JSON backend
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      kode: json['kode'] ?? '',
      name: sanitizeCustomerName(
        json['nama']?.toString() ?? '',
      ), // Mapping dari "nama"
      phone: json['no_hp'] ?? '', // Mapping dari "no_hp"
      gender: json['jenis_kelamin']?.toString() ?? '',
      birthDate: json['tanggal_lahir'] != null
          ? DateTime.tryParse(json['tanggal_lahir'])
          : null,
      address: json['alamat'] ?? '',
      status: json['status'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      lastTransactionAt: json['last_transaction_at'] != null
          ? DateTime.tryParse(json['last_transaction_at'].toString())
          : null,
      lastTransactionId: json['last_transaction_id']?.toString(),
      depositRupiah: (json['deposit_rupiah'] as num?)?.toDouble() ?? 0,
      depositKg: (json['deposit_kg'] as num?)?.toDouble() ?? 0,
    );
  }

  // Digunakan untuk payload update/save ke backend
  Map<String, dynamic> toJson() {
    return {
      'nama': sanitizeCustomerName(name),
      'no_hp': phone,
      'alamat': address,
      'jenis_kelamin': gender,
      'tanggal_lahir': birthDate != null
          ? DateFormat('yyyy-MM-dd').format(birthDate!)
          : null,
    };
  }

  Customer copyWith({
    String? id,
    String? outletId,
    String? kode,
    String? name,
    String? phone,
    String? gender,
    DateTime? birthDate,
    String? address,
    int? status,
    DateTime? createdAt,
    DateTime? lastTransactionAt,
    String? lastTransactionId,
    double? depositRupiah,
    double? depositKg,
  }) {
    return Customer(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      kode: kode ?? this.kode,
      name: name != null ? sanitizeCustomerName(name) : this.name,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastTransactionAt: lastTransactionAt ?? this.lastTransactionAt,
      lastTransactionId: lastTransactionId ?? this.lastTransactionId,
      depositRupiah: depositRupiah ?? this.depositRupiah,
      depositKg: depositKg ?? this.depositKg,
    );
  }

  // --- GETTERS & HELPERS ---

  String get formattedPhone {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    return cleanPhone
        .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)}-')
        .replaceAll(RegExp(r'-$'), '');
  }

  String get displayName =>
      '#$kode | $name'; // Menggunakan "kode" pendek dari backend

  bool get hasDeposit => depositRupiah > 0 || depositKg > 0;

  String get depositSummary {
    final parts = <String>[];
    if (depositRupiah > 0) {
      parts.add(
        'Rp ${NumberFormat.decimalPattern('id_ID').format(depositRupiah)}',
      );
    }
    if (depositKg > 0) {
      final kg = depositKg == depositKg.roundToDouble()
          ? depositKg.toStringAsFixed(0)
          : depositKg.toStringAsFixed(2);
      parts.add('$kg Kg');
    }
    return parts.join(' • ');
  }

  bool get hasGender => gender.trim().isNotEmpty;

  bool get isBirthdayToday {
    final birthday = birthDate;
    if (birthday == null) return false;
    final now = DateTime.now();
    return birthday.month == now.month && birthday.day == now.day;
  }

  // Cek gender berdasarkan nilai string "L" atau "P"
  bool get isWanita => gender.toUpperCase() == 'P';
  bool get isPria => gender.toUpperCase() == 'L';

  String get genderLong {
    if (isWanita) return "Wanita";
    if (isPria) return "Laki-laki";
    return "-";
  }

  String get formattedBirthDate {
    if (birthDate == null) return '-';
    return DateFormat('dd/MM/yyyy').format(birthDate!);
  }

  String get formattedRegisteredAt {
    if (createdAt == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(createdAt!.toLocal());
  }

  String get formattedLastTransactionAt {
    if (lastTransactionAt == null) return 'Belum pernah transaksi';
    return DateFormat(
      'dd MMM yyyy, HH:mm',
      'id_ID',
    ).format(lastTransactionAt!.toLocal());
  }

  // Kalkulasi umur dari DateTime
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  String get displayAge {
    final calculatedAge = age;
    return calculatedAge != null ? '$calculatedAge tahun' : '-';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
