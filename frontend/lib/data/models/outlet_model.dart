class Outlet {
  final String id;
  final int userId;
  final String nama;
  final String? noHp;
  final String? provinsi;
  final String? kota;
  final String? kecamatan;
  final String? alamat;
  final double? latitude;
  final double? longitude;
  final int locationRadiusMeters;
  final String? gambar;
  final String? tipeLokasiUsaha;
  final String? modalUsaha;
  final String? jumlahKaryawan;
  final String? jumlahMesin;
  final String? tanggalBerjalan;
  final int status;
  final int koin;

  // Fitur Aktivasi & Trial
  final DateTime? activatedAt;
  final DateTime trialExpiresAt;
  final int maxPegawaiBase;

  // Konfigurasi Fitur
  final int skipProses;
  final int isMetodePembayaran;
  final int isFiturDiskon;

  final DateTime createdAt;

  Outlet({
    required this.id,
    required this.userId,
    required this.nama,
    this.noHp,
    this.provinsi,
    this.kota,
    this.kecamatan,
    this.alamat,
    this.latitude,
    this.longitude,
    this.locationRadiusMeters = 5,
    this.gambar,
    this.tipeLokasiUsaha,
    this.modalUsaha,
    this.jumlahKaryawan,
    this.jumlahMesin,
    this.tanggalBerjalan,
    required this.status,
    required this.koin,
    this.activatedAt,
    required this.trialExpiresAt,
    required this.maxPegawaiBase,
    required this.skipProses,
    required this.isMetodePembayaran,
    required this.isFiturDiskon,
    required this.createdAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['ot_id']?.toString() ?? '',
      userId: json['ot_user'] ?? 0,
      nama: json['ot_nama'] ?? '',
      noHp: json['ot_nohp'],
      provinsi: json['ot_provinsi'],
      kota: json['ot_kota'],
      kecamatan: json['ot_kecamatan'],
      alamat: json['ot_alamat'],
      latitude: (json['ot_latitude'] as num?)?.toDouble(),
      longitude: (json['ot_longitude'] as num?)?.toDouble(),
      locationRadiusMeters:
          ((json['ot_location_radius_meters'] as num?)?.toInt() ?? 0) > 0
          ? (json['ot_location_radius_meters'] as num).toInt()
          : 5,
      gambar: json['ot_gambar'],
      tipeLokasiUsaha: json['ot_tipe_lokasi_usaha'],
      modalUsaha: json['ot_modal_usaha'],
      jumlahKaryawan: json['ot_jumlah_karyawan'],
      jumlahMesin: json['ot_jumlah_mesin'],
      tanggalBerjalan: json['ot_tanggal_berjalan'],
      status: json['ot_status'] ?? 1,
      koin: json['ot_koin'] ?? 0,
      activatedAt: json['ot_activated_at'] != null
          ? DateTime.parse(json['ot_activated_at']).toLocal()
          : null,
      trialExpiresAt: DateTime.parse(
        json['ot_trial_at'] ?? DateTime.now().toString(),
      ).toLocal(),
      maxPegawaiBase: json['ot_max_pegawai_base'] ?? 2,
      skipProses: json['ot_skip_proses'] ?? 0,
      isMetodePembayaran: json['ot_metode_pembayaran'] ?? 1,
      isFiturDiskon: json['ot_fitur_diskon'] ?? 1,
      createdAt: DateTime.parse(
        json['ot_created'] ?? DateTime.now().toString(),
      ).toLocal(),
    );
  }

  bool get isPro => activatedAt != null;
}
