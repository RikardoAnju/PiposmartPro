class IncomeDetailTransaction {
  final String id;
  final String sourceType;
  final String transactionId;
  final DateTime tanggalPembayaran;
  final double nominalBayar;
  final double totalAkhir;
  final String statusPembayaranAkhir;
  final String pelangganNama;
  final String customerId;
  final String metodeNama;
  final String metodeKategori;
  final String depositType;
  final String referenceId;
  final double balanceAfter;
  final String createdBy;
  final String createdByName;
  final DateTime tanggalTransaksi;
  final int paymentIndex;
  final String paymentType; // "DP", "Pelunasan", or "Lunas"

  IncomeDetailTransaction({
    required this.id,
    required this.sourceType,
    required this.transactionId,
    required this.tanggalPembayaran,
    required this.nominalBayar,
    required this.totalAkhir,
    required this.statusPembayaranAkhir,
    required this.pelangganNama,
    required this.customerId,
    required this.metodeNama,
    required this.metodeKategori,
    required this.depositType,
    required this.referenceId,
    required this.balanceAfter,
    required this.createdBy,
    required this.createdByName,
    required this.tanggalTransaksi,
    required this.paymentIndex,
    required this.paymentType,
  });

  factory IncomeDetailTransaction.fromJson(Map<String, dynamic> json) {
    return IncomeDetailTransaction(
      id: json['id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      tanggalPembayaran:
          DateTime.tryParse(
            json['tanggal_pembayaran']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      nominalBayar: ((json['nominal_bayar'] ?? 0) as num).toDouble(),
      totalAkhir: ((json['total_akhir'] ?? 0) as num).toDouble(),
      statusPembayaranAkhir:
          json['status_pembayaran_akhir']?.toString() ?? 'Belum Lunas',
      pelangganNama: json['pelanggan_nama']?.toString() ?? 'Tanpa Nama',
      customerId: json['customer_id']?.toString() ?? '',
      metodeNama: json['metode_nama']?.toString() ?? '',
      metodeKategori: json['metode_kategori']?.toString() ?? 'Cash',
      depositType: json['deposit_type']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      balanceAfter: ((json['balance_after'] ?? 0) as num).toDouble(),
      createdBy: json['created_by']?.toString() ?? '',
      createdByName: json['created_by_name']?.toString() ?? '',
      tanggalTransaksi:
          DateTime.tryParse(
            json['tanggal_transaksi']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      paymentIndex: int.tryParse(json['payment_index']?.toString() ?? '0') ?? 0,
      paymentType: json['payment_type']?.toString() ?? 'Lunas',
    );
  }
}
