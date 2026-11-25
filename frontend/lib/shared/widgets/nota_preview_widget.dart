import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

// Warna teks nota — sengaja pekat & tebal karena nota dibagikan sebagai GAMBAR
// dan dibaca pelanggan (mayoritas ibu-ibu) di layar HP. Tolak ukur legibility
// adalah mata pelanggan, bukan estetika. Jangan diturunkan tanpa alasan kuat.
const Color _kNotaText = Color(0xFF111111); // teks utama (hampir hitam pekat)
const Color _kNotaMuted = Color(
  0xFF555555,
); // teks sekunder (tetap pekat, bukan abu tipis)

class NotaPreviewWidget extends StatelessWidget {
  final Map snapshot;
  final Customer? customer;
  final NotaSettings? nota;

  const NotaPreviewWidget({
    super.key,
    required this.snapshot,
    required this.customer,
    this.nota,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (nota?.cnLogo.isNotEmpty ?? false)
        ? ApiClient.resolveImageVariantUrl(nota!.cnLogo, width: 240)
        : null;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id');
    final outletName = nota?.cnNamaOutlet ?? 'AyoCuci Laundry';
    final outletAddress = nota?.cnAlamat ?? '';
    final kontak = nota?.cnKontak ?? '';

    // ── Kode transaksi ──
    final trxCode =
        snapshot['tr_id']?.toString() ??
        snapshot['tr_code']?.toString() ??
        snapshot['transaction_code']?.toString() ??
        '-';

    // ── Info dasar ──
    final customerName =
        customer?.name ??
        snapshot['customer_name']?.toString() ??
        snapshot['pelanggan']?.toString() ??
        '-';

    final kasir =
        snapshot['tr_userupdate']?.toString() ??
        snapshot['kasir_name']?.toString() ??
        '-';

    final showKasir = nota?.cnSettKasir ?? true;
    final showKeterangan = nota?.cnSettKeterangan ?? true;

    final catatan =
        snapshot['catatan']?.toString() ?? snapshot['notes']?.toString() ?? '';

    // ── Parfum (sinkron dengan nota_text_builder) ──
    final parfumNama = () {
      final direct = snapshot['parfum_nama']?.toString() ?? '';
      if (direct.isNotEmpty && direct != '-') return direct;

      final parfumObj = snapshot['parfum'];
      if (parfumObj is Map) {
        final name = (parfumObj['nama'] ?? parfumObj['name'] ?? '').toString();
        if (name.isNotEmpty && name != '-') return name;
      }

      final alt = snapshot['nama_parfum']?.toString() ?? '';
      if (alt.isNotEmpty && alt != '-') return alt;

      return '';
    }();

    // ── Angka keuangan ──
    final grandTotal = _toDouble(
      snapshot['tr_total'] ??
          snapshot['grand_total'] ??
          snapshot['total_akhir'],
    );
    final nominalDP = _toDouble(
      snapshot['tr_dp'] ?? snapshot['dp_amount'] ?? snapshot['nominal_dp'],
    );
    final discount = _toDouble(
      snapshot['tr_diskon'] ??
          snapshot['discount_amount'] ??
          snapshot['potongan_diskon'],
    );
    final cashAmount = _toDouble(
      snapshot['tr_cash'] ?? snapshot['cash_received'] ?? snapshot['cash'],
    );
    final roundingAmount = _toDouble(
      snapshot['rounding_amount'] ?? snapshot['tr_rounding'] ?? 0,
    );
    final sisaBayar = _toDouble(
      snapshot['tr_sisa'] ??
          snapshot['sisa_bayar'] ??
          (nominalDP > 0 ? grandTotal - nominalDP : 0.0),
    );

    // ── Jemput & Antar ──
    final jemputAlamat = (snapshot['jemput_alamat'] ?? '').toString().trim();
    final antarAlamat = (snapshot['antar_alamat'] ?? '').toString().trim();
    final jemputBiaya = _toDouble(snapshot['jemput_biaya']);
    final antarBiaya = _toDouble(snapshot['antar_biaya']);
    final totalJemputAntar = jemputBiaya + antarBiaya;
    final hasJemput = jemputAlamat.isNotEmpty;
    final hasAntar = antarAlamat.isNotEmpty;
    final details = snapshot['details'] as List? ?? [];

    // ── SubTotal: prioritas details.fold (sinkron dengan nota_text_builder) ──
    final totalOrder = () {
      if (details.isNotEmpty) {
        final fromDetails = details.fold<double>(
          0.0,
          (sum, d) => sum + _toDouble(d['dtr_subtotal'] ?? d['subtotal']),
        );
        if (fromDetails > 0) return fromDetails;
      }

      final directSubtotal =
          snapshot['tr_subtotal'] ??
          snapshot['subtotal'] ??
          snapshot['total_order'];
      if (directSubtotal != null) {
        final val = _toDouble(directSubtotal);
        if (val > 0) return val;
      }

      // 3. Fallback: dari total_kotor
      final rawTotalKotor = _toDouble(
        snapshot['total_kotor'] ??
            snapshot['subtotal_kotor'] ??
            snapshot['tr_total_kotor'],
      );
      if (rawTotalKotor > 0) {
        final val = rawTotalKotor - totalJemputAntar;
        if (val >= 0) return val;
      }
      return (grandTotal + discount - totalJemputAntar - roundingAmount).clamp(
        0.0,
        double.infinity,
      );
    }();

    // ── Status pembayaran ──
    final paymentStatusText =
        snapshot['tr_status_pembayaran']?.toString() ??
        snapshot['payment_status']?.toString() ??
        snapshot['status_pembayaran']?.toString() ??
        '-';
    final paymentStatus = paymentStatusText.toLowerCase();
    final isLunas = paymentStatus == 'lunas';
    final isBelumLunasWithoutDP = !isLunas && nominalDP <= 0;
    final isDPBelumLunas = !isLunas && nominalDP > 0;

    // ── Status order ──
    final orderStatusText =
        snapshot['tr_status']?.toString() ??
        snapshot['tr_status_order']?.toString() ??
        snapshot['status_order']?.toString() ??
        snapshot['status']?.toString() ??
        snapshot['order_status']?.toString() ??
        snapshot['status_pesanan']?.toString() ??
        '';
    final orderStatus = orderStatusText.toLowerCase().trim();

    final isSelesai =
        orderStatus == 'selesai' ||
        orderStatus == 'siap ambil' ||
        orderStatus == 'siap diambil' ||
        orderStatus == 'completed' ||
        orderStatus == 'done' ||
        orderStatus == 'finish' ||
        orderStatus == 'finished';

    // ── Status banner (prioritas selesai > status bayar) ──
    final statusBayarLabel = isLunas
        ? 'LUNAS'
        : isBelumLunasWithoutDP
        ? 'BELUM LUNAS'
        : 'DP / BELUM LUNAS';
    final statusLabel = isSelesai ? 'CUCIAN SUDAH SELESAI' : statusBayarLabel;

    final statusColor = isSelesai
        ? Colors.blue
        : isLunas
        ? Colors.green
        : Colors.red;

    // ── Tanggal ──
    DateTime createdAt;
    try {
      final raw = snapshot['tr_created'] ?? snapshot['created_at'];
      createdAt = raw is DateTime ? raw : DateTime.parse(raw.toString());
    } catch (_) {
      createdAt = DateTime.now();
    }

    String estDate = '-';
    if (details.isNotEmpty) {
      try {
        final readyAt =
            details.first['ready_at'] ?? details.first['dtr_ready_at'];
        if (readyAt != null) {
          final dt = readyAt is DateTime
              ? readyAt
              : DateTime.parse(readyAt.toString());
          estDate = dateFormat.format(dt);
        }
      } catch (_) {}
    }

    // ── Optional items (sinkron dengan nota_text_builder) ──
    final optionalItems = snapshot['optional_items'];
    final hasOptionalItems = optionalItems is List && optionalItems.isNotEmpty;

    // Footer nota gambar memakai footer WhatsApp ("Terima Kasih"), BUKAN footer
    // fisik ("Harap membawa bon…") yang hanya relevan untuk cetak thermal.
    final waFooter = nota?.whatsappFooterText ?? '';

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo outlet ──
              if (nota?.cnSettLogo == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageUrl != null
                          ? AppCachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.store,
                                size: 34,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.store,
                              size: 34,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                ),

              // ── Header teks outlet ──
              Center(
                child: Text(
                  outletName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kNotaText,
                  ),
                ),
              ),
              if (outletAddress.isNotEmpty)
                Center(
                  child: Text(
                    outletAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kNotaText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (kontak.isNotEmpty)
                Center(
                  child: Text(
                    kontak,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kNotaText,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  trxCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kNotaMuted,
                  ),
                ),
              ),
              const Divider(height: 16),

              // ── Pelanggan (di text builder posisinya tepat setelah header/divider pertama) ──
              _row('Pelanggan', customerName, bold: true),
              const Divider(height: 12),

              // ── Info transaksi ──
              if (showKasir) _row('Kasir', kasir),
              _row('Tgl Masuk', dateFormat.format(createdAt)),
              _row('Est Selesai', estDate),

              // ── Parfum ──
              if (parfumNama.isNotEmpty) _row('Parfum', parfumNama),

              // ── Status cucian & bayar ──
              if (orderStatusText.isNotEmpty && orderStatusText != '-')
                _row('Status Cucian', orderStatusText.toUpperCase()),
              _row('Status Bayar', paymentStatusText.toUpperCase()),

              // ── Alamat jemput & antar (tanpa section label, langsung inline — sinkron text builder) ──
              if (hasJemput) _row('Alamat Jemput', jemputAlamat),
              if (hasAntar) _row('Alamat Antar', antarAlamat),

              // ── Catatan ──
              if (showKeterangan && catatan.isNotEmpty)
                _rowWrapValue('Catatan', catatan),

              const Divider(height: 16),

              // ── Detail pesanan ──
              const _SectionLabel('DETAIL PESANAN:'),
              const SizedBox(height: 6),

              ...details.map(
                (d) =>
                    _DetailItem(d: d, showDuration: nota?.cnSettDurasi ?? true),
              ),

              // ── Optional items (sinkron dengan nota_text_builder) ──
              if (hasOptionalItems) ...[
                const Divider(height: 12),
                const _SectionLabel('ITEM DICUCI:'),
                const SizedBox(height: 4),
                _OptionalItemsWidget(rawItems: optionalItems),
              ],

              const Divider(height: 16),

              // ── Kalkulasi harga (urutan & logika sinkron dengan nota_text_builder) ──
              _row('SubTotal', CurrencyFormatter.formatToRupiah(totalOrder)),

              // Biaya jemput & antar terpisah
              if (jemputBiaya > 0)
                _row('Jemput', CurrencyFormatter.formatToRupiah(jemputBiaya)),
              if (antarBiaya > 0)
                _row('Antar', CurrencyFormatter.formatToRupiah(antarBiaya)),
              // Total gabungan jika keduanya ada
              if (jemputBiaya > 0 && antarBiaya > 0)
                _row(
                  'Tot. J+A',
                  CurrencyFormatter.formatToRupiah(totalJemputAntar),
                ),

              if (discount > 0)
                _row(
                  'Diskon',
                  '-${CurrencyFormatter.formatToRupiah(discount)}',
                ),

              if (roundingAmount != 0 && (nota?.cnSettRounding ?? true))
                _row(
                  'Pembulatan',
                  '${roundingAmount > 0 ? '+' : '-'}${CurrencyFormatter.formatToRupiah(roundingAmount.abs())}',
                ),

              if (isLunas && cashAmount > 0)
                _row('Cash', CurrencyFormatter.formatToRupiah(cashAmount)),

              _row(
                'Total',
                CurrencyFormatter.formatToRupiah(grandTotal),
                bold: true,
              ),

              if (isDPBelumLunas) ...[
                _row('DP Dibayar', CurrencyFormatter.formatToRupiah(nominalDP)),
              ],

              if (isBelumLunasWithoutDP)
                _row(
                  'Sisa Bayar',
                  CurrencyFormatter.formatToRupiah(grandTotal),
                ),

              const SizedBox(height: 12),

              // ── Status banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Column(
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 14,
                      ),
                    ),
                    if (isSelesai) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SIAP DIAMBIL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Sisa Bayar (sinkron: muncul di bawah status banner, sama seperti ~~Sisa Bayar di text builder) ──
              if (isDPBelumLunas || isBelumLunasWithoutDP) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sisa Bayar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatToRupiah(
                          isDPBelumLunas ? sisaBayar : grandTotal,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Footer (pakai footer WhatsApp, bukan footer fisik) ──
              if (waFooter.isNotEmpty)
                Center(
                  child: Text(
                    waFooter,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kNotaText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    children: [
                      TextSpan(text: 'Powered by '),
                      TextSpan(
                        text: 'AyoCuci POS',
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: _kNotaText,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: value.contains('Rp') ? AppPalette.primary : _kNotaText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Seperti _row tapi value bisa wrap ke bawah (untuk alamat panjang — sinkron _wrapAddress di text builder)
  Widget _rowWrapValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kNotaText,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            ':',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kNotaText,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kNotaText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label helper ──────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        color: _kNotaText,
      ),
    );
  }
}

// ── Detail item (sinkron penuh dengan _formatOrderDetail di nota_text_builder) ──────
class _DetailItem extends StatelessWidget {
  final dynamic d;
  final bool showDuration;
  const _DetailItem({required this.d, required this.showDuration});

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // ── Resolusi nama (sinkron persis dengan _formatOrderDetail) ──
    // 1. nama_layanan (field langsung, tanpa kurung)
    String name = d['nama_layanan']?.toString() ?? '';

    // 2. dtr_nama_layanan — ekstrak isi dalam kurung jika ada (sama seperti text builder)
    if (name.isEmpty) {
      final dtrNama = d['dtr_nama_layanan']?.toString() ?? '';
      final parenRegex = RegExp(r'^.*?\(\s*(.*?)\s*\)$');
      final match = parenRegex.firstMatch(dtrNama);
      name = match != null ? match.group(1)! : dtrNama;
    }

    // 3. Fallback ke nama_kategori / dtr_nama_kategori
    if (name.isEmpty) {
      name =
          d['dtr_nama_sub_kategori']?.toString() ??
          d['nama_sub_kategori']?.toString() ??
          d['sub_kategori']?.toString() ??
          d['service_name']?.toString() ??
          d['nama_kategori']?.toString() ??
          d['dtr_nama_kategori']?.toString() ??
          '-';
    }

    final qty = d['dtr_qty'] ?? d['qty'] ?? 0;
    final qtyDouble = _toDouble(qty);
    // Preview nota mengikuti hasil cetak thermal → satuan luas tetap "m".
    final satuan = (d['dtr_satuan'] ?? d['satuan'] ?? '').toString();
    final subtotal = _toDouble(d['dtr_subtotal'] ?? d['subtotal']);
    final unitPrice = qtyDouble == 0 ? 0.0 : subtotal / qtyDouble;

    final qtyStr = qtyDouble % 1 == 0
        ? qtyDouble.toInt().toString()
        : qtyDouble
              .toStringAsFixed(4)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');

    // ── Durasi (sinkron nota_text_builder: pakai duration/durasi/dtr_durasi) ──
    final durasi = d['duration'] ?? d['durasi'] ?? d['dtr_durasi'];
    final durasiSatuan =
        (d['duration_unit'] ??
                d['durasi_satuan'] ??
                d['dtr_durasi_satuan'] ??
                d['dtr_satuan_durasi'] ??
                d['satuan_durasi'] ??
                'Jam')
            .toString();
    final durasiStr =
        (showDuration &&
            durasi != null &&
            durasi.toString().isNotEmpty &&
            durasi.toString() != '0')
        ? ' ($durasi $durasiSatuan)'
        : '';

    // Pecah nama jika ada catatan dalam kurung (sinkron nota_text_builder)
    final parenMatch = RegExp(r'^(.*?)(\s*\(.*\))\s*$').firstMatch(name);
    final mainName = parenMatch != null ? parenMatch.group(1)!.trim() : name;
    final parenNote = parenMatch != null ? parenMatch.group(2)!.trim() : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mainName$durasiStr',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kNotaText,
            ),
          ),
          if (parenNote.isNotEmpty)
            Text(
              parenNote,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kNotaMuted,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$qtyStr $satuan x ${CurrencyFormatter.formatToRupiah(unitPrice)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kNotaMuted,
                ),
              ),
              Text(
                CurrencyFormatter.formatToRupiah(subtotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kNotaText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Optional items widget (sinkron dengan _formatOptionalItems di nota_text_builder) ──
class _OptionalItemsWidget extends StatelessWidget {
  final dynamic rawItems;
  const _OptionalItemsWidget({required this.rawItems});

  @override
  Widget build(BuildContext context) {
    if (rawItems is! List || rawItems.isEmpty) return const SizedBox.shrink();

    // Group by service_name (sinkron dengan _formatOptionalItems)
    final grouped = <String, List<Map>>{};
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final serviceName = raw['service_name']?.toString().trim() ?? '';
      grouped.putIfAbsent(serviceName, () => []).add(raw);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    grouped.forEach((serviceName, items) {
      if (serviceName.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '- $serviceName',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kNotaText,
              ),
            ),
          ),
        );
      }
      for (final item in items) {
        final itemName =
            (item['name'] ??
                    item['item_name'] ??
                    item['nama_item'] ??
                    item['item_id'] ??
                    '-')
                .toString()
                .trim();
        final qty = item['qty'] ?? 1;
        final keterangan = item['keterangan']?.toString().trim() ?? '';
        final note = keterangan.isNotEmpty ? ' ($keterangan)' : '';
        final prefix = serviceName.isNotEmpty ? '    ' : '- ';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4),
            child: Text(
              '$prefix$itemName x $qty pcs$note',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kNotaMuted,
              ),
            ),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
