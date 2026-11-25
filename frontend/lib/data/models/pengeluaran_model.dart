class Pengeluaran {
  final String id;
  final String kategoriId;
  final String outletId;
  final DateTime tanggal;
  final DateTime? dueDate;
  final DateTime createdAt;
  final double total;
  final String keterangan;
  final List<String> bukti;
  final String userUpdate;
  final String userUpdateType;
  final String userUpdateNama; // Field baru untuk nama penginput
  final String kategoriNama; // Diambil langsung dari root
  final String sourceType;
  final String sourceId;

  Pengeluaran({
    required this.id,
    required this.kategoriId,
    required this.outletId,
    required this.tanggal,
    this.dueDate,
    required this.createdAt,
    required this.total,
    required this.keterangan,
    required this.bukti,
    required this.userUpdate,
    required this.userUpdateType,
    required this.userUpdateNama,
    required this.kategoriNama,
    required this.sourceType,
    required this.sourceId,
  });

  factory Pengeluaran.fromJson(Map<String, dynamic> json) {
    return Pengeluaran(
      id: json['id'] ?? '',
      kategoriId: json['kategori_id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      tanggal: DateTime.parse(json['tanggal']),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at']),
      total: (json['total'] as num).toDouble(),
      keterangan: json['keterangan'] ?? '',
      bukti: json['bukti'] != null ? List<String>.from(json['bukti']) : [],
      userUpdate: json['user_update'] ?? '',
      userUpdateType: json['user_update_type'] ?? '',
      // Ambil dari root JSON sesuai update backend terbaru
      userUpdateNama: json['user_update_nama'] ?? 'System',
      kategoriNama: json['kategori_nama'] ?? 'Umum',
      sourceType: json['source_type'] ?? '',
      sourceId: json['source_id'] ?? '',
    );
  }

  bool get isPayrollSource => sourceType.toLowerCase().trim() == 'payroll';

  bool get isLatePayrollSource =>
      isPayrollSource &&
      dueDate != null &&
      tanggal.toLocal().isAfter(dueDate!.toLocal());

  int? get lateDays => isLatePayrollSource
      ? tanggal.toLocal().difference(dueDate!.toLocal()).inDays
      : null;
}
