class ItemLaundry {
  final String id;
  final String outletId;
  final String nama;
  final int status;
  final int qty;

  ItemLaundry({
    required this.id,
    required this.outletId,
    required this.nama,
    required this.status,
    required this.qty,
  });

  bool get isActive => status == 1;

  factory ItemLaundry.fromJson(Map<String, dynamic> json) {
    return ItemLaundry(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      outletId: (json['outlet_id'] ?? json['OutletID'] ?? '').toString(),
      nama: (json['nama'] ?? json['Nama'] ?? '').toString(),
      status: _toInt(json['status'] ?? json['Status']),
      qty: _toInt(json['qty'] ?? json['Qty']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
