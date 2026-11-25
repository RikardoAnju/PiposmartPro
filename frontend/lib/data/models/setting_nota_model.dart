class NotaSettings {
  final String cnId;
  final String cnOutlet;
  final String cnNamaOutlet;
  final String cnAlamat;
  final String cnKontak;
  final String cnLogo;
  final String cnFooterNota;
  final String cnFooterWhatsapp;
  final bool cnSettLogo;
  final bool cnSettQr;
  final bool cnSettKasir;
  final bool cnSettKeterangan;
  final bool cnSettNota;
  final bool cnSettWhatsapp;
  final bool cnSettRounding;
  final bool cnSettDurasi;
  final int cnUkuran;
  final DateTime cnLastupdate;
  final String cnUserupdate;
  final String cnUserupdateType;

  NotaSettings({
    required this.cnId,
    required this.cnOutlet,
    required this.cnNamaOutlet,
    required this.cnAlamat,
    required this.cnKontak,
    required this.cnLogo,
    required this.cnFooterNota,
    required this.cnFooterWhatsapp,
    required this.cnSettLogo,
    required this.cnSettQr,
    required this.cnSettKasir,
    required this.cnSettKeterangan,
    required this.cnSettNota,
    required this.cnSettWhatsapp,
    required this.cnSettRounding,
    required this.cnSettDurasi,
    required this.cnUkuran,
    required this.cnLastupdate,
    required this.cnUserupdate,
    required this.cnUserupdateType,
  });

  /// Template default footer WhatsApp bila belum diisi outlet.
  static const String defaultWhatsappFooter =
      'Terima kasih telah menggunakan jasa kami.';

  /// Footer WhatsApp siap-pakai. Kalau toggle mati → kosong (tidak ditampilkan).
  /// Kalau isinya kosong atau cuma tanda hubung/garis ("-", "—", dst) → jatuh ke
  /// template default, supaya footer tidak pernah tampil hanya sebagai "-".
  String get whatsappFooterText {
    if (!cnSettWhatsapp) return '';
    final raw = cnFooterWhatsapp.trim();
    final isDashOnly = raw.isNotEmpty && RegExp(r'^[-–—_.\s]+$').hasMatch(raw);
    if (raw.isEmpty || isDashOnly) return defaultWhatsappFooter;
    return raw;
  }

  factory NotaSettings.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value == 'true';
      return false;
    }

    return NotaSettings(
      cnId: json['cn_id'] ?? '',
      cnOutlet: json['cn_outlet'] ?? '',
      cnNamaOutlet: json['cn_nama_outlet'] ?? '',
      cnAlamat: json['cn_alamat'] ?? '',
      cnKontak: json['cn_kontak'] ?? '',
      cnLogo: json['cn_logo'] ?? '',
      cnFooterNota: json['cn_footer_nota'] ?? '',
      cnFooterWhatsapp: json['cn_footer_whatsapp'] ?? '',
      cnSettLogo: parseBool(json['cn_sett_logo']),
      cnSettQr: parseBool(json['cn_sett_qr']),
      cnSettKasir: parseBool(json['cn_sett_kasir']),
      cnSettKeterangan: parseBool(json['cn_sett_keterangan']),
      cnSettNota: parseBool(json['cn_sett_nota']),
      cnSettWhatsapp: parseBool(json['cn_sett_whatsapp']),
      cnSettRounding: json['cn_sett_rounding'] == null
          ? true
          : parseBool(json['cn_sett_rounding']),
      cnSettDurasi: json['cn_sett_durasi'] == null
          ? true
          : parseBool(json['cn_sett_durasi']),
      cnUkuran: json['cn_ukuran'] ?? 58,
      cnLastupdate: json['cn_lastupdate'] != null
          ? DateTime.parse(json['cn_lastupdate'])
          : DateTime.now(),
      cnUserupdate: json['cn_userupdate'] ?? '',
      cnUserupdateType: json['cn_userupdate_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cn_id': cnId,
      'cn_outlet': cnOutlet,
      'cn_nama_outlet': cnNamaOutlet,
      'cn_alamat': cnAlamat,
      'cn_kontak': cnKontak,
      'cn_logo': cnLogo,
      'cn_footer_nota': cnFooterNota,
      'cn_footer_whatsapp': cnFooterWhatsapp,
      'cn_sett_logo': cnSettLogo,
      'cn_sett_qr': cnSettQr,
      'cn_sett_kasir': cnSettKasir,
      'cn_sett_keterangan': cnSettKeterangan,
      'cn_sett_nota': cnSettNota,
      'cn_sett_whatsapp': cnSettWhatsapp,
      'cn_sett_rounding': cnSettRounding,
      'cn_sett_durasi': cnSettDurasi,
      'cn_ukuran': cnUkuran,
      'cn_lastupdate': cnLastupdate.toIso8601String(),
      'cn_userupdate': cnUserupdate,
      'cn_userupdate_type': cnUserupdateType,
    };
  }

  NotaSettings copyWith({
    String? cnId,
    String? cnOutlet,
    String? cnNamaOutlet,
    String? cnAlamat,
    String? cnKontak,
    String? cnLogo,
    String? cnFooterNota,
    String? cnFooterWhatsapp,
    bool? cnSettLogo,
    bool? cnSettQr,
    bool? cnSettKasir,
    bool? cnSettKeterangan,
    bool? cnSettNota,
    bool? cnSettWhatsapp,
    bool? cnSettRounding,
    bool? cnSettDurasi,
    int? cnUkuran,
    DateTime? cnLastupdate,
    String? cnUserupdate,
    String? cnUserupdateType,
  }) {
    return NotaSettings(
      cnId: cnId ?? this.cnId,
      cnOutlet: cnOutlet ?? this.cnOutlet,
      cnNamaOutlet: cnNamaOutlet ?? this.cnNamaOutlet,
      cnAlamat: cnAlamat ?? this.cnAlamat,
      cnKontak: cnKontak ?? this.cnKontak,
      cnLogo: cnLogo ?? this.cnLogo,
      cnFooterNota: cnFooterNota ?? this.cnFooterNota,
      cnFooterWhatsapp: cnFooterWhatsapp ?? this.cnFooterWhatsapp,
      cnSettLogo: cnSettLogo ?? this.cnSettLogo,
      cnSettQr: cnSettQr ?? this.cnSettQr,
      cnSettKasir: cnSettKasir ?? this.cnSettKasir,
      cnSettKeterangan: cnSettKeterangan ?? this.cnSettKeterangan,
      cnSettNota: cnSettNota ?? this.cnSettNota,
      cnSettWhatsapp: cnSettWhatsapp ?? this.cnSettWhatsapp,
      cnSettRounding: cnSettRounding ?? this.cnSettRounding,
      cnSettDurasi: cnSettDurasi ?? this.cnSettDurasi,
      cnUkuran: cnUkuran ?? this.cnUkuran,
      cnLastupdate: cnLastupdate ?? this.cnLastupdate,
      cnUserupdate: cnUserupdate ?? this.cnUserupdate,
      cnUserupdateType: cnUserupdateType ?? this.cnUserupdateType,
    );
  }
}

class NotaSettingsInput {
  final String? cnNamaOutlet;
  final String? cnAlamat;
  final String? cnKontak;
  final String? cnFooterNota;
  final String? cnFooterWhatsapp;
  final bool cnSettLogo;
  final bool cnSettQr;
  final bool cnSettKasir;
  final bool cnSettKeterangan;
  final bool cnSettNota;
  final bool cnSettWhatsapp;
  final bool cnSettRounding;
  final bool cnSettDurasi;
  final int cnUkuran;

  NotaSettingsInput({
    this.cnNamaOutlet,
    this.cnAlamat,
    this.cnKontak,
    this.cnFooterNota,
    this.cnFooterWhatsapp,
    this.cnSettLogo = false,
    this.cnSettQr = true,
    this.cnSettKasir = false,
    this.cnSettKeterangan = true,
    this.cnSettNota = true,
    this.cnSettWhatsapp = true,
    this.cnSettRounding = true,
    this.cnSettDurasi = true,
    this.cnUkuran = 58,
  });

  Map<String, dynamic> toJson() {
    return {
      if (cnNamaOutlet != null) 'cn_nama_outlet': cnNamaOutlet,
      if (cnAlamat != null) 'cn_alamat': cnAlamat,
      if (cnKontak != null) 'cn_kontak': cnKontak,
      if (cnFooterNota != null) 'cn_footer_nota': cnFooterNota,
      if (cnFooterWhatsapp != null) 'cn_footer_whatsapp': cnFooterWhatsapp,
      'cn_sett_logo': cnSettLogo,
      'cn_sett_qr': cnSettQr,
      'cn_sett_kasir': cnSettKasir,
      'cn_sett_keterangan': cnSettKeterangan,
      'cn_sett_nota': cnSettNota,
      'cn_sett_whatsapp': cnSettWhatsapp,
      'cn_sett_rounding': cnSettRounding,
      'cn_sett_durasi': cnSettDurasi,
      'cn_ukuran': cnUkuran,
    };
  }
}

class NotaSettingsResponse {
  final bool status;
  final String message;
  final NotaSettings? data;

  NotaSettingsResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory NotaSettingsResponse.fromJson(Map<String, dynamic> json) {
    return NotaSettingsResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? NotaSettings.fromJson(json['data']) : null,
    );
  }
}
