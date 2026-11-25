
class OmsetFilter {
  final String filterBerdasarkan;
  final String? statusPembayaran;
  final int bulan;
  final int tahun;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;

  const OmsetFilter({
    required this.filterBerdasarkan,
    this.statusPembayaran,
    required this.bulan,
    required this.tahun,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  String get startDate {
    if (filterBerdasarkan == 'Custom' && tanggalMulai != null) return _fmt(tanggalMulai!);
    if (filterBerdasarkan == 'Harian') return _fmt(DateTime.now());
    if (filterBerdasarkan == 'Minggu Ini') return _fmt(DateTime.now().subtract(const Duration(days: 6)));
    if (filterBerdasarkan == 'Tahunan') return _fmt(DateTime(tahun, 1, 1));
    return _fmt(DateTime(tahun, bulan, 1));
  }

  String get endDate {
    if (filterBerdasarkan == 'Custom' && tanggalSelesai != null) return _fmt(tanggalSelesai!);
    if (filterBerdasarkan == 'Harian') return _fmt(DateTime.now());
    if (filterBerdasarkan == 'Minggu Ini') return _fmt(DateTime.now());
    if (filterBerdasarkan == 'Tahunan') return _fmt(DateTime(tahun, 12, 31));
    return _fmt(DateTime(tahun, bulan + 1, 0));
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  OmsetFilter copyWith({
    String? filterBerdasarkan,
    String? statusPembayaran,
    bool clearStatus = false,
    int? bulan,
    int? tahun,
    DateTime? tanggalMulai,
    DateTime? tanggalSelesai,
    bool clearCustomRange = false,
  }) {
    return OmsetFilter(
      filterBerdasarkan: filterBerdasarkan ?? this.filterBerdasarkan,
      statusPembayaran: clearStatus ? null : (statusPembayaran ?? this.statusPembayaran),
      bulan: bulan ?? this.bulan,  
      tahun: tahun ?? this.tahun,     
      tanggalMulai: clearCustomRange ? null : (tanggalMulai ?? this.tanggalMulai),
      tanggalSelesai: clearCustomRange ? null : (tanggalSelesai ?? this.tanggalSelesai),
    );
  }
}