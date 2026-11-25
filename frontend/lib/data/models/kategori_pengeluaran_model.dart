class KategoriPengeluaran {
  final String id;
  final String kategori; // <--- PASTIKAN NAMA VARIABEL INI ADALAH 'kategori'
  final int status;

  KategoriPengeluaran({
    required this.id,
    required this.kategori,
    required this.status,
  });

  factory KategoriPengeluaran.fromJson(Map<String, dynamic> json) {
    return KategoriPengeluaran(
      id: json['id'] ?? '',
      kategori: json['kategori'] ?? '', // Pastikan key JSON sesuai backend
      status: json['status'] ?? 1,
    );
  }
}
