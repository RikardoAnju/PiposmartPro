class QueueItem {
  final String id;
  final String invoice;
  final String pelangganNama;
  final double total;
  final String statusPembayaran;
  final String statusOrder;
  final DateTime tglMasuk;
  final DateTime tglEstimasi;

  QueueItem({
    required this.id,
    required this.invoice,
    required this.pelangganNama,
    required this.total,
    required this.statusPembayaran,
    required this.statusOrder,
    required this.tglMasuk,
    required this.tglEstimasi,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['tr_id'] ?? '',
      invoice: json['tr_invoice'] ?? '',
      pelangganNama: json['pelanggan_nama'] ?? 'Umum',
      total: (json['tr_total'] ?? 0).toDouble(),
      statusPembayaran: json['tr_status_pembayaran'] ?? '',
      statusOrder: json['tr_status_order'] ?? '',
      tglMasuk: DateTime.parse(json['tr_created']).toLocal(),
      tglEstimasi: json['tr_estimate'] != null
          ? DateTime.parse(json['tr_estimate']).toLocal()
          : DateTime.parse(json['tr_created']).toLocal().add(const Duration(days: 1)),
    );
  }
}
