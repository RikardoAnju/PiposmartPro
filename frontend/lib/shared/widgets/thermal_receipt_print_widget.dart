import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ThermalReceiptPrintWidget extends StatelessWidget {
  final Map snapshot;
  final Customer? customer;
  final NotaSettings? nota;
  final int paperWidth;
  final String? linkNota;

  const ThermalReceiptPrintWidget({
    super.key,
    required this.snapshot,
    required this.customer,
    required this.nota,
    required this.paperWidth,
    required this.linkNota,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        (nota?.cnSettLogo == true && (nota?.cnLogo.isNotEmpty ?? false))
        ? ApiClient.resolveImageVariantUrl(nota!.cnLogo, width: 240)
        : null;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id');
    final width = paperWidth >= 80 ? 420.0 : 300.0;
    final padding = paperWidth >= 80 ? 18.0 : 14.0;
    // Nama outlet: sedikit lebih besar agar menonjol dari alamat, tapi tetap
    // di bawah ukuran nama pelanggan (21/18) yang jadi elemen paling besar.
    final outletFont = paperWidth >= 80 ? 20.5 : 17.5;
    final normalFont = paperWidth >= 80 ? 15.0 : 12.0;
    final smallFont = paperWidth >= 80 ? 13.0 : 11.0;

    final trxCode =
        snapshot['tr_id']?.toString() ??
        snapshot['tr_code']?.toString() ??
        snapshot['transaction_code']?.toString() ??
        '-';
    final outletName = nota?.cnNamaOutlet ?? 'AyoCuci Laundry';
    final outletAddress = nota?.cnAlamat ?? '';
    final kontakOutlet = nota?.cnKontak ?? '';
    final customerName =
        customer?.name ??
        snapshot['customer_name']?.toString() ??
        snapshot['pelanggan']?.toString() ??
        '-';
    final kasir =
        snapshot['tr_userupdate']?.toString() ??
        snapshot['kasir_name']?.toString() ??
        '-';
    final catatan =
        snapshot['catatan']?.toString() ?? snapshot['notes']?.toString() ?? '';
    final showKasir = nota?.cnSettKasir ?? true;
    final showKeterangan = nota?.cnSettKeterangan ?? true;
    final showRounding = nota?.cnSettRounding ?? true;

    final details = snapshot['details'] as List? ?? [];
    final optionalItems = snapshot['optional_items'];
    final hasOptionalItems = optionalItems is List && optionalItems.isNotEmpty;

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
    final jemputBiaya = _toDouble(snapshot['jemput_biaya']);
    final antarBiaya = _toDouble(snapshot['antar_biaya']);
    final totalJemputAntar = jemputBiaya + antarBiaya;
    final jemputAlamat = (snapshot['jemput_alamat'] ?? '').toString().trim();
    final antarAlamat = (snapshot['antar_alamat'] ?? '').toString().trim();

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

    final sisaBayar = _toDouble(
      snapshot['tr_sisa'] ??
          snapshot['sisa_bayar'] ??
          (nominalDP > 0 ? grandTotal - nominalDP : 0.0),
    );

    final paymentStatusText =
        snapshot['tr_status_pembayaran']?.toString() ??
        snapshot['payment_status']?.toString() ??
        snapshot['status_pembayaran']?.toString() ??
        '-';
    final paymentStatus = paymentStatusText.toLowerCase();
    final isLunas = paymentStatus == 'lunas';
    final isBelumLunasWithoutDP = !isLunas && nominalDP <= 0;
    final isDPBelumLunas = !isLunas && nominalDP > 0;

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

    final statusLabel = isLunas ? 'LUNAS' : 'BELUM LUNAS';
    final footer =
        (nota?.cnSettNota == true && (nota?.cnFooterNota ?? '').isNotEmpty)
        ? nota!.cnFooterNota
        : 'Harap membawa bon ini ketika mengambil pakaian';

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl != null) ...[
                Center(
                  child: SizedBox(
                    width: paperWidth >= 80 ? 78 : 62,
                    height: paperWidth >= 80 ? 78 : 62,
                    child: AppCachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                ),
                SizedBox(height: paperWidth >= 80 ? 10 : 8),
              ],
              Text(
                outletName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: outletFont,
                  fontWeight: AppFont.w700,
                  color: Colors.black,
                  height: 1.05,
                ),
              ),
              if (outletAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    outletAddress,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: smallFont,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                ),
              if (kontakOutlet.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    kontakOutlet,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: smallFont, color: Colors.black),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  trxCode,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: smallFont, color: Colors.black),
                ),
              ),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              Text(
                customerName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: paperWidth >= 80 ? 21 : 18,
                  fontWeight: AppFont.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              if (showKasir) _line('Kasir', kasir, normalFont),
              _line('Tgl Masuk', dateFormat.format(createdAt), normalFont),
              _line('Est Selesai', estDate, normalFont),
              if (jemputAlamat.isNotEmpty)
                _rightLine('Alamat Jemput', jemputAlamat, normalFont),
              if (antarAlamat.isNotEmpty)
                _rightLine('Alamat Antar', antarAlamat, normalFont),
              if (showKeterangan && catatan.isNotEmpty)
                _wrapLine('Catatan', catatan, normalFont),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              ...details.map(
                (d) => _detailItem(
                  d,
                  normalFont,
                  smallFont,
                  showDuration: nota?.cnSettDurasi ?? true,
                ),
              ),
              if (hasOptionalItems) ...[
                SizedBox(height: paperWidth >= 80 ? 10 : 8),
                const _ThermalDivider(),
                SizedBox(height: paperWidth >= 80 ? 10 : 8),
                ..._optionalItems(optionalItems, normalFont),
              ],
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              _priceLine(
                'SubTotal',
                CurrencyFormatter.formatToRupiah(totalOrder),
                normalFont,
              ),
              if (jemputBiaya > 0)
                _priceLine(
                  'Jemput',
                  CurrencyFormatter.formatToRupiah(jemputBiaya),
                  normalFont,
                ),
              if (antarBiaya > 0)
                _priceLine(
                  'Antar',
                  CurrencyFormatter.formatToRupiah(antarBiaya),
                  normalFont,
                ),
              if (jemputBiaya > 0 && antarBiaya > 0)
                _priceLine(
                  'Tot.J+A',
                  CurrencyFormatter.formatToRupiah(totalJemputAntar),
                  normalFont,
                ),
              if (discount > 0)
                _priceLine(
                  'Diskon',
                  '-${CurrencyFormatter.formatToRupiah(discount)}',
                  normalFont,
                ),
              if (roundingAmount != 0 && showRounding)
                _priceLine(
                  'Bulat',
                  '${roundingAmount > 0 ? '+' : '-'}${CurrencyFormatter.formatToRupiah(roundingAmount.abs())}',
                  normalFont,
                ),
              if (isLunas && cashAmount > 0)
                _priceLine(
                  'Cash',
                  CurrencyFormatter.formatToRupiah(cashAmount),
                  normalFont,
                ),
              _priceLine(
                'Total',
                CurrencyFormatter.formatToRupiah(grandTotal),
                normalFont,
                bold: true,
              ),
              if (isDPBelumLunas)
                _priceLine(
                  'DP Dibayar',
                  CurrencyFormatter.formatToRupiah(nominalDP),
                  normalFont,
                ),
              SizedBox(height: paperWidth >= 80 ? 10 : 8),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 12 : 10),
              Text(
                statusLabel,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: paperWidth >= 80 ? 26 : 22,
                  fontWeight: AppFont.w800,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              if (isSelesai)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      Text(
                        'CUCIAN SUDAH SELESAI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: paperWidth >= 80 ? 16 : 13,
                          fontWeight: AppFont.w700,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'SIAP DIAMBIL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: paperWidth >= 80 ? 18 : 15,
                          fontWeight: AppFont.w700,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isDPBelumLunas || isBelumLunasWithoutDP) ...[
                SizedBox(height: paperWidth >= 80 ? 10 : 8),
                Text(
                  isDPBelumLunas
                      ? 'Kurang: ${CurrencyFormatter.formatToRupiah(sisaBayar)}'
                      : CurrencyFormatter.formatToRupiah(grandTotal),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: paperWidth >= 80 ? 24 : 20,
                    fontWeight: AppFont.w800,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
              ],
              SizedBox(height: paperWidth >= 80 ? 12 : 10),
              const _ThermalDivider(),
              SizedBox(height: paperWidth >= 80 ? 12 : 10),
              Text(
                footer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: smallFont,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              if (linkNota != null && linkNota!.isNotEmpty) ...[
                SizedBox(height: paperWidth >= 80 ? 14 : 12),
                Center(
                  child: QrImageView(
                    data: linkNota!,
                    version: QrVersions.auto,
                    size: paperWidth >= 80 ? 132 : 110,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
              SizedBox(height: paperWidth >= 80 ? 12 : 10),
              Text(
                'Powered By AyoCuci POS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: smallFont,
                  fontWeight: AppFont.w600,
                  color: Colors.black,
                ),
              ),
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

  Widget _line(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapLine(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          ),
          Text(
            ': ',
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightLine(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: fontSize, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(
    String label,
    String value,
    double fontSize, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? AppFont.w700 : AppFont.w500,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? AppFont.w700 : AppFont.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
    dynamic d,
    double fontSize,
    double smallFont, {
    required bool showDuration,
  }) {
    String name = d['nama_layanan']?.toString() ?? '';
    if (name.isEmpty) {
      final dtrNama = d['dtr_nama_layanan']?.toString() ?? '';
      final parenRegex = RegExp(r'^.*?\(\s*(.*?)\s*\)$');
      final match = parenRegex.firstMatch(dtrNama);
      name = match != null ? match.group(1)! : dtrNama;
    }
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
    final subtotal = _toDouble(d['dtr_subtotal'] ?? d['subtotal']);
    // Catatan: printer thermal tidak mendukung superscript "²", jadi satuan luas
    // tetap dicetak sebagai "m" (bukan "m²") — beda dengan tampilan layar.
    final satuan = (d['dtr_satuan'] ?? d['satuan'] ?? '').toString();
    final unitPrice = qtyDouble == 0 ? 0.0 : subtotal / qtyDouble;
    final qtyStr = qtyDouble % 1 == 0
        ? qtyDouble.toInt().toString()
        : qtyDouble
              .toStringAsFixed(4)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
    final durasi = d['duration'] ?? d['durasi'] ?? d['dtr_durasi'];
    final durasiSatuan =
        d['duration_unit'] ??
        d['durasi_satuan'] ??
        d['dtr_durasi_satuan'] ??
        '';
    final durasiStr =
        (showDuration &&
            durasi != null &&
            durasi.toString().isNotEmpty &&
            durasi.toString() != '0')
        ? ' ($durasi $durasiSatuan)'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$name$durasiStr',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: AppFont.w600,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$qtyStr $satuan x ${CurrencyFormatter.formatToRupiah(unitPrice)}',
                  style: TextStyle(fontSize: smallFont, color: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.formatToRupiah(subtotal),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: smallFont, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _optionalItems(dynamic rawItems, double fontSize) {
    if (rawItems is! List || rawItems.isEmpty) return const [];
    final grouped = <String, List<Map>>{};
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final serviceName = raw['service_name']?.toString().trim() ?? '';
      grouped.putIfAbsent(serviceName, () => []).add(raw);
    }

    final widgets = <Widget>[];
    grouped.forEach((serviceName, items) {
      if (serviceName.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              serviceName,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: AppFont.w600,
                color: Colors.black,
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
        final suffix = keterangan.isNotEmpty ? ' ($keterangan)' : '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: TextStyle(fontSize: fontSize, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$qty pcs$suffix',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: fontSize, color: Colors.black),
                ),
              ],
            ),
          ),
        );
      }
    });
    return widgets;
  }
}

class _ThermalDivider extends StatelessWidget {
  const _ThermalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.black);
  }
}
