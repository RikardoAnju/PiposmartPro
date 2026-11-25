class Parfum {
  final String id;
  final String outletId;
  final String nama;
  final int status;

  Parfum({
    required this.id,
    required this.outletId,
    required this.nama,
    required this.status,
  });

  factory Parfum.fromJson(Map<String, dynamic> json) {
    int parseStatus(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return Parfum(
      id:
          json['ID']?.toString() ??
          json['id']?.toString() ??
          json['pf_id']?.toString() ??
          json['parfum_id']?.toString() ??
          '',
      outletId:
          json['OutletID']?.toString() ??
          json['outlet_id']?.toString() ??
          json['pf_outlet']?.toString() ??
          '',
      nama:
          json['Nama']?.toString() ??
          json['nama']?.toString() ??
          json['pf_nama']?.toString() ??
          '',
      status: parseStatus(
        json['Status'] ?? json['status'] ?? json['pf_status'],
      ),
    );
  }
}
