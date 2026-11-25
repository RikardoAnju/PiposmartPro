import 'package:ayocucinew/core/utils/unit_label.dart';
import 'customer_model.dart';

class FinanceSummary {
  final double totalOmset;
  final double totalPendapatan;
  final double totalPengeluaran;
  final double labaRugi;
  final int totalTransaksi;
  final double totalPiutang;
  final double transaksiTrend;

  FinanceSummary({
    required this.totalOmset,
    required this.totalPendapatan,
    required this.totalPengeluaran,
    required this.labaRugi,
    required this.totalTransaksi,
    required this.totalPiutang,
    required this.transaksiTrend,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
    totalOmset: (json['total_omset'] ?? 0).toDouble(),
    totalPendapatan: (json['total_income'] ?? 0).toDouble(),
    totalPengeluaran: (json['total_expense'] ?? 0).toDouble(),
    labaRugi: (json['profit_loss'] ?? 0).toDouble(),
    totalTransaksi: (json['total_transaksi'] ?? 0).toInt(),
    totalPiutang: (json['total_piutang'] ?? 0).toDouble(),
    transaksiTrend: (json['transaksi_trend'] ?? 0).toDouble(),
  );
}

DateTime? parseReportDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dateOnly = raw.contains('T') ? raw.split('T').first : raw;
  final parts = dateOnly.split('-');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

class TransactionHeader {
  final int totalTransaksi;
  final double totalPendapatan;
  final String trend;

  const TransactionHeader({
    required this.totalTransaksi,
    required this.totalPendapatan,
    required this.trend,
  });

  factory TransactionHeader.fromJson(Map<String, dynamic> json) {
    return TransactionHeader(
      totalTransaksi: (json['total_transaksi'] ?? 0).toInt(),
      totalPendapatan: (json['total_pendapatan'] ?? 0).toDouble(),
      trend: (json['trend'] ?? '').toString(),
    );
  }
}

class PiutangFilter {
  final String filterBerdasarkan;
  final String? namaPelanggan;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;

  const PiutangFilter({
    this.filterBerdasarkan = 'Minggu Ini',
    this.namaPelanggan,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  bool get isEmpty =>
      namaPelanggan == null && tanggalMulai == null && tanggalSelesai == null;

  PiutangFilter copyWith({
    String? filterBerdasarkan,
    String? namaPelanggan,
    DateTime? tanggalMulai,
    DateTime? tanggalSelesai,
  }) {
    return PiutangFilter(
      filterBerdasarkan: filterBerdasarkan ?? this.filterBerdasarkan,
      namaPelanggan: namaPelanggan ?? this.namaPelanggan,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalSelesai: tanggalSelesai ?? this.tanggalSelesai,
    );
  }
}

class FinanceChartData {
  final String tanggal;
  final double omset;
  final double pendapatan;
  final double pengeluaran;

  FinanceChartData({
    required this.tanggal,
    required this.omset,
    required this.pendapatan,
    required this.pengeluaran,
  });

  factory FinanceChartData.fromJson(Map<String, dynamic> json) =>
      FinanceChartData(
        tanggal: json['date'] ?? '',
        omset: (json['omset'] ?? 0).toDouble(),
        pendapatan: (json['income'] ?? 0).toDouble(),
        pengeluaran: (json['expense'] ?? 0).toDouble(),
      );
}

class OmsetReport {
  final String tanggal;
  final double totalOmset;
  final int jumlahTransaksi;

  OmsetReport({
    required this.tanggal,
    required this.totalOmset,
    required this.jumlahTransaksi,
  });

  factory OmsetReport.fromJson(Map<String, dynamic> json) {
    final raw = (json['tanggal'] ?? '') as String;
    return OmsetReport(
      tanggal: raw.isNotEmpty ? raw.split('T').first : '',
      totalOmset: (json['total_omset'] ?? 0).toDouble(),
      jumlahTransaksi:
          (json['total_transaksi'] ?? json['jumlah_transaksi'] ?? 0).toInt(),
    );
  }
}

class OmsetDetail {
  final String id;
  final String nomorNota;
  final String namaPelanggan;
  final double totalHarga;
  final String statusPembayaran;
  final String tanggal;
  final String tanggalMasuk;
  final String tanggalPembayaran;
  final String tanggalSelesai;
  final String statusOrder;
  final String kasirName;
  final double totalKotor;
  final double potonganDiskon;
  final double roundingAmount;
  final double dpAmount;
  final double sisaBayar;
  final String? jemputAlamat;
  final double? jemputBiaya;
  final double? antarBiaya;
  final String catatan;
  final String outletId;
  final String? metodePembayaran;

  OmsetDetail({
    required this.id,
    required this.nomorNota,
    required this.namaPelanggan,
    required this.totalHarga,
    required this.statusPembayaran,
    required this.tanggal,
    required this.tanggalMasuk,
    required this.tanggalPembayaran,
    required this.tanggalSelesai,
    required this.statusOrder,
    required this.kasirName,
    required this.totalKotor,
    required this.potonganDiskon,
    required this.roundingAmount,
    required this.dpAmount,
    required this.sisaBayar,
    this.jemputAlamat,
    this.jemputBiaya,
    this.antarBiaya,
    required this.catatan,
    required this.outletId,
    this.metodePembayaran,
  });

  static String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    try {
      final dt = parseReportDate(raw);
      if (dt == null) return raw;
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  static String _cleanDisplayText(String? raw, {String fallback = '-'}) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return fallback;

    final cleaned = text
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  factory OmsetDetail.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    Map<String, dynamic> pelanggan = {};
    if (json['pelanggan'] is Map<String, dynamic>) {
      pelanggan = json['pelanggan'] as Map<String, dynamic>;
    }

    final rawMasuk = json['created_at'] ?? json['tr_created'] ?? '';
    final rawSelesai =
        json['tr_estimate'] ??
        json['estimate_date'] ??
        json['tanggal_selesai'] ??
        '-';

    final rawNamaPelanggan = (pelanggan['nama'] as String? ?? '').isNotEmpty
        ? pelanggan['nama'] as String
        : (json['pelanggan_nama'] as String? ?? '').isNotEmpty
        ? json['pelanggan_nama'] as String
        : 'Tanpa Nama';
    final namaPelanggan = _cleanDisplayText(
      rawNamaPelanggan,
      fallback: 'Tanpa Nama',
    );

    String? deepSearchMetode(Map<String, dynamic> data) {
      // 0. Check payment history first (to handle split/DP payments accurately - use last payment method)
      final historyRaw =
          data['payment_history'] ?? data['payment_history_full'];
      if (historyRaw is List && historyRaw.isNotEmpty) {
        final entry = historyRaw.last;
        if (entry is Map) {
          final nestedMetode =
              entry['metode_pembayaran'] ?? entry['payment_method'];
          if (nestedMetode is Map) {
            final name =
                nestedMetode['nama'] ??
                nestedMetode['Nama'] ??
                nestedMetode['name'] ??
                nestedMetode['Name'] ??
                nestedMetode['nama_metode'] ??
                nestedMetode['metode_nama'] ??
                nestedMetode['NamaPembayaran'];
            if (name != null && name.toString().trim().isNotEmpty) {
              final upper = name.toString().trim().toUpperCase();
              return upper == 'CASH' ? 'TUNAI / CASH' : upper;
            }
          }
          final nameDirect =
              entry['nama_metode'] ??
              entry['metode'] ??
              entry['kategori'] ??
              entry['Nama'] ??
              entry['name'];
          if (nameDirect != null && nameDirect.toString().trim().isNotEmpty) {
            final upper = nameDirect.toString().trim().toUpperCase();
            return upper == 'CASH' ? 'TUNAI / CASH' : upper;
          }
        }
      }

      // 1. Priority known keys (including variations)
      final priorityKeys = [
        'metode_pembayaran',
        'tr_metode_pembayaran',
        'payment_method',
        'payment_name',
        'metode',
        'tr_payment_method',
        'payment_type',
        'tr_metode_bayar',
        'metode_bayar',
        'payment_mode',
        'method_name',
        'tr_payment_method_name',
        'payment_method_nama',
        'tr_payment_type',
      ];

      for (final key in priorityKeys) {
        final val = data[key];
        if (val == null) continue;
        if (val is String && val.isNotEmpty) {
          final upper = val.toUpperCase();
          return upper == 'CASH' ? 'TUNAI / CASH' : upper;
        }
        if (val is Map) {
          final name =
              val['nama'] ??
              val['name'] ??
              val['Nama'] ??
              val['Name'] ??
              val['nama_metode'] ??
              val['metode_nama'] ??
              val['NamaPembayaran'];
          if (name != null) {
            final upper = name.toString().toUpperCase();
            return upper == 'CASH' ? 'TUNAI / CASH' : upper;
          }
        }
      }

      // 2. Fallback: Search all keys for something that looks like a payment name
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        if ((key.contains('metode') || key.contains('payment')) &&
            !key.contains('status') &&
            !key.contains('id')) {
          final val = entry.value;
          if (val is String && val.isNotEmpty && val.length < 30) {
            final upper = val.toUpperCase();
            return upper == 'CASH' ? 'TUNAI / CASH' : upper;
          }
        }
      }

      return null;
    }

    String? deepSearchPaymentDate(Map<String, dynamic> data) {
      final historyRaw =
          data['payment_history'] ?? data['payment_history_full'];
      if (historyRaw is List && historyRaw.isNotEmpty) {
        final entry = historyRaw.last;
        if (entry is Map) {
          final val =
              entry['created_at'] ??
              entry['paid_at'] ??
              entry['payment_date'] ??
              entry['tanggal_pembayaran'] ??
              entry['tanggal_bayar'] ??
              entry['tanggal'];
          if (val != null && val.toString().trim().isNotEmpty) {
            return val.toString();
          }
        }
      }

      final priorityKeys = [
        'tanggal_pembayaran',
        'tanggal_bayar',
        'payment_date',
        'paid_at',
        'payment_at',
        'last_payment_at',
        'tr_paid_at',
      ];

      for (final key in priorityKeys) {
        final val = data[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString();
        }
      }
      return null;
    }

    final metode = deepSearchMetode(json);
    final rawPaymentDate = deepSearchPaymentDate(json);

    return OmsetDetail(
      id: (json['id'] ?? '').toString(),
      nomorNota: (json['tr_invoice'] ?? json['id'] ?? '-').toString(),
      namaPelanggan: namaPelanggan,
      totalHarga: (json['total_akhir'] ?? json['tr_total'] ?? 0).toDouble(),
      statusPembayaran:
          json['status_pembayaran'] ??
          json['tr_status_pembayaran'] ??
          'Belum Lunas',
      tanggal: rawMasuk,
      tanggalMasuk: _formatTanggal(rawMasuk),
      tanggalPembayaran: _formatTanggal(rawPaymentDate),
      tanggalSelesai: _formatTanggal(rawSelesai),
      statusOrder: json['status_order'] ?? '-',
      kasirName: json['kasir_name'] ?? '-',
      totalKotor: toDouble(json['total_kotor'] ?? json['tr_total']),
      potonganDiskon: toDouble(json['potongan_diskon']),
      roundingAmount: toDouble(json['rounding_amount']),
      dpAmount: toDouble(json['dp_amount']),
      sisaBayar: toDouble(json['sisa_bayar']),
      jemputAlamat: json['jemput_alamat'] as String?,
      jemputBiaya: json['jemput_biaya'] != null
          ? toDouble(json['jemput_biaya'])
          : null,
      antarBiaya: json['antar_biaya'] != null
          ? toDouble(json['antar_biaya'])
          : null,
      catatan: json['catatan'] ?? '',
      outletId: json['outlet_id'] ?? '',
      metodePembayaran: metode,
    );
  }
}

class ExpenseSummary {
  final String kategoriTerbesar;
  final double nominalKategoriTerbesar;
  final double totalExpense;
  final int totalTransaksi;

  ExpenseSummary({
    required this.kategoriTerbesar,
    required this.nominalKategoriTerbesar,
    required this.totalExpense,
    required this.totalTransaksi,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) => ExpenseSummary(
    kategoriTerbesar: json['kategori_terbesar'] ?? '-',
    nominalKategoriTerbesar: (json['nominal_kategori_terbesar'] ?? 0)
        .toDouble(),
    totalExpense: (json['total_expense'] ?? 0).toDouble(),
    totalTransaksi: (json['total_transaksi'] ?? 0).toInt(),
  );
}

class ExpenseAnalisa {
  final String tanggal;
  final String tanggalRaw;
  final double totalPengeluaran;
  final int jumlahTransaksi;

  ExpenseAnalisa({
    required this.tanggal,
    required this.tanggalRaw,
    required this.totalPengeluaran,
    required this.jumlahTransaksi,
  });

  static String _formatTanggal(String dateOnly) {
    if (dateOnly.isEmpty) return '-';
    try {
      final parts = dateOnly.split('-');
      if (parts.length != 3) return dateOnly;
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[0]);
      const bulan = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${day.toString().padLeft(2, '0')} ${bulan[month - 1]} $year';
    } catch (_) {
      return dateOnly;
    }
  }

  factory ExpenseAnalisa.fromJson(Map<String, dynamic> json) {
    final raw = json['tanggal'] ?? '';
    final rawDate = raw.split('T').first;
    return ExpenseAnalisa(
      tanggal: _formatTanggal(rawDate),
      tanggalRaw: rawDate,
      totalPengeluaran: (json['total'] ?? 0).toDouble(),
      jumlahTransaksi: (json['total_transaksi'] ?? 0).toInt(),
    );
  }
}

class ExpenseByCategory {
  final String kategoriId;
  final String kategoriNama;
  final double totalPengeluaran;

  ExpenseByCategory({
    required this.kategoriId,
    required this.kategoriNama,
    required this.totalPengeluaran,
  });

  factory ExpenseByCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseByCategory(
        kategoriId: json['kategori_id']?.toString() ?? '',
        kategoriNama: json['kategori_nama'] ?? '',
        totalPengeluaran: (json['total_pengeluaran'] ?? 0).toDouble(),
      );
}

class ExpenseDetail {
  final String id;
  final String nama;
  final double jumlah;
  final String kategoriNama;
  final String tanggal;
  final String? keterangan;

  ExpenseDetail({
    required this.id,
    required this.nama,
    required this.jumlah,
    required this.kategoriNama,
    required this.tanggal,
    this.keterangan,
  });

  factory ExpenseDetail.fromJson(Map<String, dynamic> json) => ExpenseDetail(
    id: json['id']?.toString() ?? '',
    nama: json['keterangan'] ?? json['nama'] ?? '',
    jumlah: (json['total'] ?? json['jumlah'] ?? 0).toDouble(),
    kategoriNama: json['kategori_nama'] ?? '',
    tanggal: json['tanggal'] ?? '',
    keterangan: json['keterangan'],
  );
}

class ProfitLossReport {
  final double totalOmset;
  final double totalPendapatan;
  final double totalKasMasuk;
  final double totalTopUpDeposit;
  final double totalPengeluaran;
  final double labaRugi;
  final List<dynamic> detailMetode;
  final List<dynamic> detailPengeluaran;
  final List<dynamic> detailHarian;
  final int totalTransaksi;
  final int totalPembayaran;

  ProfitLossReport({
    required this.totalOmset,
    required this.totalPendapatan,
    this.totalKasMasuk = 0,
    this.totalTopUpDeposit = 0,
    required this.totalPengeluaran,
    required this.labaRugi,
    required this.detailMetode,
    required this.detailPengeluaran,
    required this.detailHarian,
    this.totalTransaksi = 0,
    this.totalPembayaran = 0,
  });

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary = json['summary'] ?? {};
    final List detail = json['detail_pendapatan'] ?? [];

    if (summary.containsKey('total_income')) {
      return ProfitLossReport(
        totalOmset: _parseDouble(summary['total_omset']),
        totalPendapatan: _parseDouble(summary['total_income']),
        totalKasMasuk: _parseDouble(summary['total_cash_income']),
        totalTopUpDeposit: _parseDouble(summary['total_deposit_topup']),
        totalPengeluaran: _parseDouble(summary['total_expense']),
        labaRugi: _parseDouble(summary['profit_loss']),
        detailMetode: json['metode_pembayaran'] ?? [],
        detailPengeluaran: json['detail_pengeluaran'] ?? [],
        detailHarian: json['detail_pendapatan'] ?? [],
        totalTransaksi: (summary['total_transaksi'] ?? 0).toInt(),
        totalPembayaran: (summary['total_payments'] ?? 0).toInt(),
      );
    }

    double totalOmset = 0;
    double totalIncome = 0;
    double totalPengeluaran = 0;

    for (final item in detail) {
      totalOmset += (item['omset'] ?? 0).toDouble();
      totalIncome += (item['income'] ?? item['omset'] ?? 0).toDouble();
      totalPengeluaran += (item['expense'] ?? 0).toDouble();
    }

    return ProfitLossReport(
      totalOmset: totalOmset,
      totalPendapatan: totalIncome,
      totalKasMasuk: totalIncome,
      totalPengeluaran: totalPengeluaran,
      labaRugi: totalIncome - totalPengeluaran,
      detailMetode: json['metode_pembayaran'] ?? [],
      detailPengeluaran: json['detail_pengeluaran'] ?? [],
      detailHarian: json['detail_pendapatan'] ?? [],
      totalTransaksi: (summary['total_transaksi'] ?? 0).toInt(),
      totalPembayaran: (summary['total_payments'] ?? 0).toInt(),
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class ProfitLossDetailMetode {
  final String metodeId;
  final String metodeNama;
  final double total;

  ProfitLossDetailMetode({
    required this.metodeId,
    required this.metodeNama,
    required this.total,
  });

  factory ProfitLossDetailMetode.fromJson(Map<String, dynamic> json) =>
      ProfitLossDetailMetode(
        metodeId: json['id']?.toString() ?? '',
        metodeNama: json['nama'] ?? json['metode_nama'] ?? '',
        total: (json['nominal'] ?? json['total'] ?? 0).toDouble(),
      );
}

class ProfitLossDetailPengeluaran {
  final String kategoriId;
  final String kategoriNama;
  final double total;

  ProfitLossDetailPengeluaran({
    required this.kategoriId,
    required this.kategoriNama,
    required this.total,
  });

  factory ProfitLossDetailPengeluaran.fromJson(Map<String, dynamic> json) =>
      ProfitLossDetailPengeluaran(
        kategoriId: json['id']?.toString() ?? '',
        kategoriNama: json['nama'] ?? json['kategori_nama'] ?? '',
        total: (json['nominal'] ?? json['total'] ?? 0).toDouble(),
      );
}

class IncomeBreakdown {
  final String nama;
  final double nominal;

  IncomeBreakdown({required this.nama, required this.nominal});

  factory IncomeBreakdown.fromJson(Map<String, dynamic> json) =>
      IncomeBreakdown(
        nama: json['nama'] ?? '',
        nominal: (json['nominal'] ?? 0).toDouble(),
      );
}

class IncomeReport {
  final String tanggal;
  final double totalHarian;
  final List<IncomeBreakdown> breakdown;

  IncomeReport({
    required this.tanggal,
    required this.totalHarian,
    required this.breakdown,
  });

  factory IncomeReport.fromJson(Map<String, dynamic> json) {
    final breakdownByMethod = <String, IncomeBreakdown>{};
    for (final raw in json['breakdown'] as List? ?? const []) {
      final item = IncomeBreakdown.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      final normalizedName = item.nama.trim().toLowerCase();
      final existing = breakdownByMethod[normalizedName];
      breakdownByMethod[normalizedName] = IncomeBreakdown(
        nama: existing?.nama ?? item.nama.trim(),
        nominal: (existing?.nominal ?? 0) + item.nominal,
      );
    }

    return IncomeReport(
      tanggal: json['tanggal'] ?? '',
      totalHarian: (json['total_harian'] ?? 0).toDouble(),
      breakdown: breakdownByMethod.values.toList(),
    );
  }
}

class PaymentMethod {
  final String id;
  final String nama;
  final double total;

  PaymentMethod({required this.id, required this.nama, required this.total});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id']?.toString() ?? '',
    nama: json['nama'] ?? '',
    total: (json['total'] ?? 0).toDouble(),
  );
}

class PengeluaranHarian {
  final int jumlahPengeluaran;
  final String tanggal;
  final String tanggalRaw;
  final double totalJumlah;

  const PengeluaranHarian({
    required this.jumlahPengeluaran,
    required this.tanggal,
    required this.tanggalRaw,
    required this.totalJumlah,
  });

  factory PengeluaranHarian.fromExpenseAnalisa(ExpenseAnalisa e) =>
      PengeluaranHarian(
        jumlahPengeluaran: e.jumlahTransaksi,
        tanggal: e.tanggal,
        tanggalRaw: e.tanggalRaw,
        totalJumlah: e.totalPengeluaran,
      );
}

class PiutangReport {
  final String nomorNota;
  final String namaPelanggan;
  final double totalHarga;
  final double sisaPiutang;
  final String statusPembayaran;
  final String tanggalMasuk;
  final String tanggalEstimasi;
  final bool isJatuhTempo;

  PiutangReport({
    required this.nomorNota,
    required this.namaPelanggan,
    required this.totalHarga,
    required this.sisaPiutang,
    required this.statusPembayaran,
    required this.tanggalMasuk,
    required this.tanggalEstimasi,
    required this.isJatuhTempo,
  });

  factory PiutangReport.fromJson(
    Map<String, dynamic> json, {
    bool isJatuhTempo = false,
  }) {
    final pelanggan = json['pelanggan'];
    final sisaBayar =
        json['sisa_bayar'] ??
        json['sisa_piutang'] ??
        json['remaining_payment'] ??
        0;
    final tanggalMasuk =
        json['tr_tanggal_masuk'] ??
        json['tanggal_masuk'] ??
        json['created_at'] ??
        json['tr_created_at'] ??
        '';
    final tanggalEst =
        json['tr_estimate'] ??
        json['estimate_date'] ??
        json['tanggal_selesai'] ??
        json['created_at'] ??
        '';

    return PiutangReport(
      nomorNota: json['tr_invoice'] ?? json['id']?.toString() ?? '-',
      namaPelanggan: sanitizeCustomerName(
        pelanggan != null
            ? (pelanggan['nama'] ?? '').toString()
            : (json['pelanggan_nama'] ?? '').toString(),
      ),
      totalHarga: (json['total_akhir'] ?? json['tr_total'] ?? 0).toDouble(),
      sisaPiutang: sisaBayar.toDouble(),
      statusPembayaran:
          json['status_pembayaran'] ?? json['tr_status_pembayaran'] ?? '',
      tanggalMasuk: tanggalMasuk,
      tanggalEstimasi: tanggalEst,
      isJatuhTempo: isJatuhTempo,
    );
  }
}

class PiutangSummary {
  final int countBelumJatuhTempo;
  final int countJatuhTempo;
  final double totalBelumJatuhTempo;
  final double totalJatuhTempo;

  PiutangSummary({
    required this.countBelumJatuhTempo,
    required this.countJatuhTempo,
    required this.totalBelumJatuhTempo,
    required this.totalJatuhTempo,
  });

  factory PiutangSummary.fromJson(Map<String, dynamic> json) => PiutangSummary(
    countBelumJatuhTempo: (json['count_belum_jatuh_tempo'] ?? 0).toInt(),
    countJatuhTempo: (json['count_jatuh_tempo'] ?? 0).toInt(),
    totalBelumJatuhTempo: (json['total_belum_jatuh_tempo'] ?? 0).toDouble(),
    totalJatuhTempo: (json['total_jatuh_tempo'] ?? 0).toDouble(),
  );
}

class TransaksiPerLayananHeader {
  final int totalLayanan;
  final int totalPesanan;
  final double totalHarga;
  final Map<String, double> totalQuantity;

  const TransaksiPerLayananHeader({
    required this.totalLayanan,
    required this.totalPesanan,
    required this.totalHarga,
    required this.totalQuantity,
  });

  factory TransaksiPerLayananHeader.fromJson(Map<String, dynamic> json) {
    final tq = json['total_quantity'];

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val) ?? 0.0;
        return double.parse(parsed.toStringAsFixed(2));
      }
      return 0.0;
    }

    return TransaksiPerLayananHeader(
      totalLayanan: (json['total_layanan'] ?? 0).toInt(),
      totalPesanan: (json['total_pesanan'] ?? json['total_transaksi'] ?? 0)
          .toInt(),
      totalHarga: (json['total_harga'] ?? json['total_omset'] ?? 0).toDouble(),
      totalQuantity: tq is Map<String, dynamic>
          ? {
              'kg': parseDouble(tq['kg']),
              'pcs': parseDouble(tq['pcs']),
              'm': parseDouble(tq['m']),
              'koin': parseDouble(tq['koin']),
            }
          : {'kg': 0.0, 'pcs': 0.0, 'm': 0.0, 'koin': 0.0},
    );
  }

  String get totalQuantityText {
    final kg = totalQuantity['kg'] ?? 0;
    final pcs = totalQuantity['pcs'] ?? 0;
    final m = totalQuantity['m'] ?? 0;
    final koin = totalQuantity['koin'] ?? 0;

    String clean(double value, {bool whole = false}) {
      if (whole || value == value.truncateToDouble()) {
        return value.toInt().toString();
      }
      return value
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    return '${clean(kg)}Kg/'
        '${clean(pcs, whole: true)}Pcs/'
        '${clean(m)}M/'
        '${clean(koin, whole: true)}Koin';
  }
}

class TransaksiLayananItem {
  final String namaLayanan;
  final String subLabel;
  final int totalPesanan;
  final String totalQty;
  final double totalHarga;

  const TransaksiLayananItem({
    required this.namaLayanan,
    required this.subLabel,
    required this.totalPesanan,
    required this.totalQty,
    required this.totalHarga,
  });

  factory TransaksiLayananItem.fromJson(Map<String, dynamic> json) {
    final rawQty = json['total_qty'] ?? json['qty'] ?? 0;
    final satuan = displayUnitLabel(
      (json['satuan'] ?? json['unit'] ?? '').toString(),
    );

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    String formatQty(dynamic val) {
      final d = (val is num)
          ? val.toDouble()
          : double.tryParse(val.toString()) ?? 0.0;
      if (d == d.truncateToDouble()) return d.toInt().toString();
      return d
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    final qtyStr = satuan.toString().isNotEmpty
        ? '${formatQty(rawQty)} $satuan'
        : formatQty(rawQty);

    return TransaksiLayananItem(
      namaLayanan:
          json['nama_layanan'] ?? json['layanan_nama'] ?? json['name'] ?? '-',
      subLabel:
          json['sub_label'] ??
          json['kategori'] ??
          json['tipe'] ??
          json['nama_kategori'] ??
          '',
      totalPesanan:
          (json['total_pesanan'] ??
                  json['total_transaksi'] ??
                  json['jumlah'] ??
                  0)
              .toInt(),
      totalQty: qtyStr,
      totalHarga: parseDouble(
        json['total_harga'] ?? json['total_omset'] ?? json['nominal'],
      ).roundToDouble(),
    );
  }
}

class CustomerGrowthSummary {
  final int totalPelanggan;
  final int totalPria;
  final int totalWanita;
  final int totalTransactingCustomers;
  final int transactingPria;
  final int transactingWanita;
  final int totalOrder;
  final double totalNominal;
  final List<CustomerChartData> chartData;
  final List<CustomerGrowthTableRow> detailTable;
  final List<CustomerGrowthCustomer> newCustomers;

  CustomerGrowthSummary({
    required this.totalPelanggan,
    required this.totalPria,
    required this.totalWanita,
    required this.totalTransactingCustomers,
    required this.transactingPria,
    required this.transactingWanita,
    required this.totalOrder,
    required this.totalNominal,
    required this.chartData,
    required this.detailTable,
    required this.newCustomers,
  });

  factory CustomerGrowthSummary.fromJson(Map<String, dynamic> json) {
    return CustomerGrowthSummary(
      totalPelanggan: (json['total_pelanggan'] ?? 0).toInt(),
      totalPria: (json['total_pria'] ?? 0).toInt(),
      totalWanita: (json['total_wanita'] ?? 0).toInt(),
      totalTransactingCustomers:
          (json['total_transacting_customers'] ?? json['total_pelanggan'] ?? 0)
              .toInt(),
      transactingPria: (json['transacting_pria'] ?? json['total_pria'] ?? 0)
          .toInt(),
      transactingWanita:
          (json['transacting_wanita'] ?? json['total_wanita'] ?? 0).toInt(),
      totalOrder: (json['total_order'] ?? 0).toInt(),
      totalNominal: (json['total_nominal'] ?? 0).toDouble(),
      chartData: (json['chart_data'] as List? ?? [])
          .map((e) => CustomerChartData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      detailTable: (json['detail_table'] as List? ?? [])
          .map(
            (e) =>
                CustomerGrowthTableRow.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      newCustomers: (json['new_customers'] as List? ?? [])
          .map(
            (e) =>
                CustomerGrowthCustomer.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class CustomerGrowthCustomer {
  final String tanggal;
  final String nama;
  final String noHp;
  final String jenisKelamin;

  CustomerGrowthCustomer({
    required this.tanggal,
    required this.nama,
    required this.noHp,
    required this.jenisKelamin,
  });

  factory CustomerGrowthCustomer.fromJson(Map<String, dynamic> json) {
    return CustomerGrowthCustomer(
      tanggal: json['tanggal']?.toString() ?? '',
      nama: sanitizeCustomerName(json['nama']?.toString() ?? ''),
      noHp: json['no_hp']?.toString() ?? '-',
      jenisKelamin: json['jenis_kelamin']?.toString() ?? '-',
    );
  }

  String get tanggalFormatted {
    final parsed = parseReportDate(tanggal);
    if (parsed == null) return tanggal;
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${bulan[parsed.month - 1]} ${parsed.year}';
  }

  String get genderLabel {
    final normalized = jenisKelamin.toLowerCase();
    if (normalized == 'p' ||
        normalized == 'perempuan' ||
        normalized == 'wanita') {
      return 'Perempuan';
    }
    if (normalized == 'l' ||
        normalized == 'laki-laki' ||
        normalized == 'pria') {
      return 'Laki-laki';
    }
    return '-';
  }
}

class CustomerChartData {
  final String date;
  final int value;

  CustomerChartData({required this.date, required this.value});

  factory CustomerChartData.fromJson(Map<String, dynamic> json) {
    return CustomerChartData(
      date: json['date'] ?? '',
      value: (json['value'] ?? 0).toInt(),
    );
  }
}

class CustomerGrowthTableRow {
  final String tanggal;
  final int perempuan;
  final int lakiLaki;
  final int total;

  CustomerGrowthTableRow({
    required this.tanggal,
    required this.perempuan,
    required this.lakiLaki,
    required this.total,
  });

  factory CustomerGrowthTableRow.fromJson(Map<String, dynamic> json) {
    return CustomerGrowthTableRow(
      tanggal: json['tanggal']?.toString() ?? '',
      perempuan: int.tryParse(json['perempuan'].toString()) ?? 0,
      lakiLaki: int.tryParse(json['laki_laki'].toString()) ?? 0,
      total: int.tryParse(json['total'].toString()) ?? 0,
    );
  }

  DateTime get tanggalDate {
    return parseReportDate(tanggal) ?? DateTime(1970, 1, 1);
  }

  String get tanggalFormatted {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final dt = tanggalDate;
    return '${dt.day.toString().padLeft(2, '0')} ${bulan[dt.month - 1]} ${dt.year}';
  }
}

class TopCustomerPodiumData {
  final List<TopCustomerItem> podium;
  final List<TopCustomerItem> others;
  final int totalCustomers;
  final int totalOrder;
  final double totalNominal;
  final int page;
  final bool hasMore;

  TopCustomerPodiumData({
    required this.podium,
    required this.others,
    this.totalCustomers = 0,
    this.totalOrder = 0,
    this.totalNominal = 0,
    this.page = 1,
    this.hasMore = false,
  });

  factory TopCustomerPodiumData.fromJson(Map<String, dynamic> json) {
    final allItems = (json['podium'] as List? ?? [])
        .map((e) => TopCustomerItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    allItems.addAll(
      (json['others'] as List? ?? []).map(
        (e) => TopCustomerItem.fromJson(Map<String, dynamic>.from(e)),
      ),
    );
    allItems.sort((a, b) {
      final nominal = b.totalNominal.compareTo(a.totalNominal);
      if (nominal != 0) return nominal;
      final orders = b.totalOrder.compareTo(a.totalOrder);
      if (orders != 0) return orders;
      return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
    });

    return TopCustomerPodiumData(
      podium: allItems.take(3).toList(),
      others: allItems.length > 3 ? allItems.sublist(3) : <TopCustomerItem>[],
      totalCustomers:
          ((json['summary'] as Map?)?['total_customers'] as num?)?.toInt() ??
          allItems.length,
      totalOrder:
          ((json['summary'] as Map?)?['total_order'] as num?)?.toInt() ??
          allItems.fold(0, (sum, item) => sum + item.totalOrder),
      totalNominal:
          ((json['summary'] as Map?)?['total_nominal'] as num?)?.toDouble() ??
          allItems.fold(0, (sum, item) => sum + item.totalNominal),
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['has_more'] == true,
    );
  }

  TopCustomerPodiumData append(TopCustomerPodiumData next) =>
      TopCustomerPodiumData(
        podium: podium,
        others: [...others, ...next.others],
        totalCustomers: next.totalCustomers,
        totalOrder: next.totalOrder,
        totalNominal: next.totalNominal,
        page: next.page,
        hasMore: next.hasMore,
      );
}

class TopCustomerItem {
  final String id;
  final String nama;
  final String noHp;
  final String jenisKelamin;
  final int totalOrder;
  final double totalNominal;

  TopCustomerItem({
    required this.id,
    required this.nama,
    required this.noHp,
    required this.jenisKelamin,
    required this.totalOrder,
    required this.totalNominal,
  });

  factory TopCustomerItem.fromJson(Map<String, dynamic> json) {
    return TopCustomerItem(
      id: json['id']?.toString() ?? '',
      nama: sanitizeCustomerName(json['nama']?.toString() ?? '', fallback: '-'),
      noHp: json['no_hp'] ?? '',
      jenisKelamin: json['jenis_kelamin'] ?? '',
      totalOrder: (json['total_order'] ?? 0).toInt(),
      totalNominal: (json['total_nominal'] ?? 0).toDouble(),
    );
  }
}

class PengeluaranFilter {
  final String filterBerdasarkan;
  final int bulan;
  final int tahun;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;

  const PengeluaranFilter({
    this.filterBerdasarkan = 'Bulanan',
    this.bulan = 1,
    this.tahun = 2024,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  PengeluaranFilter copyWith({
    String? filterBerdasarkan,
    int? bulan,
    int? tahun,
    DateTime? tanggalMulai,
    DateTime? tanggalSelesai,
    bool clearCustomRange = false,
  }) {
    return PengeluaranFilter(
      filterBerdasarkan: filterBerdasarkan ?? this.filterBerdasarkan,
      bulan: bulan ?? this.bulan,
      tahun: tahun ?? this.tahun,
      tanggalMulai: clearCustomRange
          ? null
          : (tanggalMulai ?? this.tanggalMulai),
      tanggalSelesai: clearCustomRange
          ? null
          : (tanggalSelesai ?? this.tanggalSelesai),
    );
  }
}
