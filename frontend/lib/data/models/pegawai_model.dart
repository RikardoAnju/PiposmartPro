import 'role_model.dart';

enum EmployeeStatusType { base, addonActive, addonInactive, addonExpired }

class Pegawai {
  final String id;
  final String outletId;
  final String roleId;
  final String nama;
  final String email;
  final String nohp;
  final DateTime? tanggalLahir;
  final int status;
  final String type; // 'base' atau 'addon'
  final DateTime? activeUntil;
  final DateTime createdAt;
  final Role? role;
  final bool allOutletAccess;

  Pegawai({
    required this.id,
    required this.outletId,
    required this.roleId,
    required this.nama,
    required this.email,
    required this.nohp,
    this.tanggalLahir,
    required this.status,
    required this.type,
    this.activeUntil,
    required this.createdAt,
    this.role,
    this.allOutletAccess = false,
  });

  // ✅ Getter Status Logic Terpusat
  EmployeeStatusType get statusType {
    if (type == 'base') return EmployeeStatusType.base;
    if (activeUntil == null) return EmployeeStatusType.addonInactive;
    if (activeUntil!.isBefore(DateTime.now())) {
      return EmployeeStatusType.addonExpired;
    }
    return EmployeeStatusType.addonActive;
  }

  bool get isExpired => statusType == EmployeeStatusType.addonExpired;

  factory Pegawai.fromJson(Map<String, dynamic> json) {
    return Pegawai(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      roleId: json['role_id'] ?? '',
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      nohp: json['nohp'] ?? '',
      tanggalLahir: json['tanggal_lahir'] != null
          ? DateTime.tryParse(json['tanggal_lahir'])?.toLocal()
          : null,
      status: json['status'] ?? 0,
      type: json['type'] ?? 'base',
      activeUntil: json['active_until'] != null
          ? DateTime.parse(json['active_until']).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      role: json['role'] != null ? Role.fromJson(json['role']) : null,
      allOutletAccess: json['all_outlet_access'] == true,
    );
  }
}
