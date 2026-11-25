class HistoryKoinModel {
  final String id;
  final String outletId;
  final String jenis;
  final int jumlah;
  final String keterangan;
  final DateTime createdAt;

  HistoryKoinModel({
    required this.id,
    required this.outletId,
    required this.jenis,
    required this.jumlah,
    required this.keterangan,
    required this.createdAt,
  });

  factory HistoryKoinModel.fromJson(Map<String, dynamic> json) {
    return HistoryKoinModel(
      id: json['hk_id'] ?? '',
      outletId: json['hk_outlet'] ?? '',
      jenis: json['hk_jenis_transaksi'] ?? 'keluar',
      jumlah: json['hk_jumlah'] is int
          ? json['hk_jumlah']
          : int.tryParse(json['hk_jumlah'].toString()) ?? 0,
      keterangan: json['hk_keterangan'] ?? '',
      // Parsing ISO8601 dengan timezone offset
      createdAt: DateTime.parse(json['hk_created']).toLocal(),
    );
  }
}
