import 'dart:convert';

class Role {
  final String id;
  final String outletId;
  final String nama;
  // Kita simpan sebagai Map agar mudah diakses: permissions['transaksi'] -> ["create", "read"]
  final Map<String, dynamic> permissions;

  Role({
    required this.id,
    required this.outletId,
    required this.nama,
    required this.permissions,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    // Backend mengirim permission sebagai JSON Object karena json.RawMessage
    Map<String, dynamic> parsedPermissions = {};

    if (json['permission'] != null) {
      if (json['permission'] is Map) {
        parsedPermissions = Map<String, dynamic>.from(json['permission']);
      } else if (json['permission'] is String) {
        parsedPermissions = jsonDecode(json['permission']);
      }
    }

    return Role(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      nama: json['nama'] ?? '',
      permissions: parsedPermissions,
    );
  }

  // Helper untuk cek apakah role punya akses tertentu
  bool hasPermission(String module, String action) {
    if (permissions.containsKey(module)) {
      List actions = permissions[module] ?? [];
      return actions.contains(action) || actions.contains("all");
    }
    return false;
  }
}
