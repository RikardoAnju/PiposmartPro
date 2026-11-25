// nota_text_builder.dart

import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/metode_pembayaran_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';

class NotaTextBuilder {
  static String _pad(String label, {int width = 11}) {
    return label.padRight(width);
  }

  // Satu-satunya sumber lebar karakter per ukuran kertas. Dipakai untuk
  // divider, baris info, baris item, dan kolom nominal, supaya semuanya
  // benar-benar sejajar di kertas fisik (harus sinkron dengan lineChars/
  // dividerChars di permission_provider.dart's _buildEscPosBytes).
  static int _charWidth(double? paperWidth) {
    if (paperWidth == null) {
      return 31; // preview WhatsApp (monospace ```)
    }
    if (paperWidth >= 88) {
      return 56;
    }
    if (paperWidth >= 80) {
      return 48;
    }
    return 28;
  }

  static int _dividerWidth(double? paperWidth) => _charWidth(paperWidth);
  static int _lineWidth(double? paperWidth) => _charWidth(paperWidth);
  static int _priceWidth(double? paperWidth) => _charWidth(paperWidth);

  // Lebar kolom label pada blok SubTotal/Total/Diskon/dst dibuat TETAP
  // (tidak dihitung ulang per baris) supaya nilai nominal di semua baris
  // jatuh pada kolom yang sama persis.
  static int _priceLabelWidth(int width) => width >= 48 ? 18 : 12;

  static String _fixedPriceLine(
    String label,
    String value, {
    required int width,
  }) {
    final cleanLabel = label.trim();
    final cleanValue = value.trim();
    final gap = width >= 48 ? 2 : 1;
    final labelWidth = _priceLabelWidth(width);
    final clippedLabel = cleanLabel.length > labelWidth
        ? cleanLabel.substring(0, labelWidth)
        : cleanLabel;
    final valueColumnWidth = width - labelWidth - gap;
    final paddedValue = cleanValue.length < valueColumnWidth
        ? cleanValue.padLeft(valueColumnWidth)
        : cleanValue;
    return '${clippedLabel.padRight(labelWidth)}${' ' * gap}$paddedValue';
  }

  static String _dividerFor(double? paperWidth) =>
      '-' * _dividerWidth(paperWidth);

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static String _rupiahWithoutPrefix(dynamic value) {
    return CurrencyFormatter.formatToRupiah(value).replaceAll('Rp', '').trim();
  }

  static String _paymentMethodId(dynamic method) {
    if (method is PaymentMethod) return method.id.trim().toUpperCase();
    if (method is Map) {
      return (method['id'] ?? method['ID'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
    }
    return '';
  }

  static ({String id, double usage}) _depositPayment(Map snapshot) {
    String id = _paymentMethodId(snapshot['payment_method']);
    double usage = 0;

    final history =
        snapshot['payment_history_full'] as List? ??
        snapshot['payment_history'] as List?;
    if (history != null) {
      for (final rawEntry in history.reversed) {
        if (rawEntry is! Map) continue;
        final nestedMethod =
            rawEntry['metode_pembayaran'] ?? rawEntry['payment_method'];
        final historyId = _paymentMethodId(nestedMethod).isNotEmpty
            ? _paymentMethodId(nestedMethod)
            : (rawEntry['metode_pembayaran_id'] ??
                      rawEntry['payment_method_id'] ??
                      '')
                  .toString()
                  .trim()
                  .toUpperCase();
        if (historyId != 'DEPOSIT_RUPIAH' && historyId != 'DEPOSIT_KG') {
          continue;
        }
        id = historyId;
        usage = id == 'DEPOSIT_KG'
            ? _toDouble(rawEntry['deposit_usage_amount'])
            : _toDouble(rawEntry['jumlah_dp'] ?? rawEntry['amount']);
        break;
      }
    }

    return (id: id, usage: usage);
  }

  static String _wrapAddress(
    String label,
    String address, {
    int lineWidth = 32,
  }) {
    final int indent = label.length + 2;
    final int contentWidth = lineWidth - indent;

    final words = address.split(' ');
    final lines = <String>[];
    String current = '';

    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if ('$current $word'.length <= contentWidth) {
        current += ' $word';
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) lines.add(current);

    final buffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      if (i == 0) {
        buffer.writeln('$label: ${lines[i]}');
      } else {
        buffer.writeln(' ' * indent + lines[i]);
      }
    }

    return buffer.toString().trimRight();
  }

  static List<String> _wrapTextByWords(String text, {required int width}) {
    if (text.trim().isEmpty) return const [];
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (current.isEmpty) {
        current = word;
        continue;
      }

      final candidate = '$current $word';
      if (candidate.length <= width) {
        current = candidate;
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines;
  }

  /// Word-wrap teks footer sambil MEMPERTAHANKAN baris baru yang diketik
  /// pengguna (mis. footer berisi poin 1..4, masing-masing di baris sendiri).
  /// Tanpa ini, [_wrapTextByWords] menggabung semua poin jadi satu paragraf
  /// karena menganggap "\n" sebagai spasi biasa.
  static List<String> _wrapFooterLines(String text, {required int width}) {
    final out = <String>[];
    for (final rawLine in text.split('\n')) {
      if (rawLine.trim().isEmpty) {
        out.add(''); // pertahankan baris kosong antar poin
      } else {
        out.addAll(_wrapTextByWords(rawLine, width: width));
      }
    }
    // Rapikan baris kosong menggantung di awal/akhir.
    while (out.isNotEmpty && out.first.isEmpty) {
      out.removeAt(0);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  static String _justifyBetween(
    String left,
    String right, {
    required int width,
    int minGap = 1,
    String padChar = ' ',
  }) {
    final cleanRight = right.trimLeft();
    var cleanLeft = left.trimRight();

    final maxLeftLen = width - cleanRight.length - minGap;
    if (maxLeftLen < 0) {
      return cleanRight;
    }
    if (cleanLeft.length > maxLeftLen) {
      cleanLeft = cleanLeft.substring(0, maxLeftLen);
    }

    final gap = width - cleanLeft.length - cleanRight.length;
    return '$cleanLeft${padChar * gap}$cleanRight';
  }

  static String _centerBlock(String text, {required int width}) {
    final lines = text.split('\n');
    return lines
        .map((line) => _center(line.trimRight(), width: width))
        .join('\n');
  }

  static String build({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
  }) {
    final body = buildWithFlags(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      showKasir: nota?.cnSettKasir ?? true,
      showKeterangan: nota?.cnSettKeterangan ?? true,
      footer: _resolveFooter(nota),
      outletName: nota?.cnNamaOutlet ?? 'AyoCuci Laundry',
      outletAddress: nota?.cnAlamat ?? '',
      kontakOutlet: nota?.cnKontak ?? '',
    );

    final linkNota = getLinkNota(snapshot);

    return '$body\n-\nLihat Nota : $linkNota';
  }

  /// SATU-SATUNYA perakit pesan WhatsApp (teks). Semua entry-point — modal
  /// selesai transaksi, detail transaksi, dsb — WAJIB lewat sini supaya isi &
  /// urutan (body → footer WA → link) selalu identik dan tidak drift lagi.
  ///
  /// Susunan: body nota + footer WhatsApp ("Terima Kasih") + baris "Lihat Nota".
  ///
  /// CATATAN: footer nota FISIK (cnFooterNota, mis. "Harap membawa bon ini
  /// ketika mengambil pakaian") sengaja TIDAK disertakan di nota digital —
  /// tidak masuk akal menyuruh bawa bon fisik pada pesan WA/gambar. Footer
  /// fisik hanya untuk cetak thermal.
  static String buildWhatsAppMessage({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
  }) {
    final body = buildForWhatsApp(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      showKasir: nota?.cnSettKasir ?? true,
      showKeterangan: nota?.cnSettKeterangan ?? true,
      footer: '',
      outletName: nota?.cnNamaOutlet ?? 'AyoCuci Laundry',
      outletAddress: nota?.cnAlamat ?? '',
      kontakOutlet: nota?.cnKontak ?? '',
    );

    // Footer fisik dikosongkan di atas → body bisa berakhir dengan newline
    // menggantung; rapikan agar tak ada baris kosong sebelum footer WA.
    final trimmedBody = body.trimRight();
    final waFooterText = nota?.whatsappFooterText ?? '';
    final waFooter = waFooterText.isNotEmpty ? '\n$waFooterText' : '';
    final linkNota = '\nLihat Nota : ${getLinkNota(snapshot)}';

    return '$trimmedBody$waFooter$linkNota';
  }

  static String buildForWhatsApp({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
    required bool showKasir,
    required bool showKeterangan,
    required String footer,
    required String outletName,
    required String outletAddress,
    required String kontakOutlet,
  }) {
    return buildWithFlags(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      showKasir: showKasir,
      showKeterangan: showKeterangan,
      footer: footer,
      outletName: outletName,
      outletAddress: outletAddress,
      kontakOutlet: kontakOutlet,
      usePrintMarkers: false,
    );
  }

  static String buildForPrinterMerchant({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
  }) {
    return buildWithFlags(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      label: 'Untuk Merchant',
      showKasir: nota?.cnSettKasir ?? true,
      showKeterangan: nota?.cnSettKeterangan ?? true,
      footer: _resolveFooter(nota),
      outletName: nota?.cnNamaOutlet ?? 'AyoCuci Laundry',
      outletAddress: nota?.cnAlamat ?? '',
      kontakOutlet: nota?.cnKontak ?? '',
    );
  }

  static String buildForPrinterCustomer({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
    double? paperWidth,
  }) {
    return buildWithFlags(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      label: 'Untuk Customer',
      showKasir: nota?.cnSettKasir ?? true,
      showKeterangan: nota?.cnSettKeterangan ?? true,
      footer: _resolveFooter(nota),
      outletName: nota?.cnNamaOutlet ?? 'AyoCuci Laundry',
      outletAddress: nota?.cnAlamat ?? '',
      kontakOutlet: nota?.cnKontak ?? '',
      paperWidth: paperWidth,
    );
  }

  static String buildWithFlags({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
    String label = '',
    required bool showKasir,
    required bool showKeterangan,
    required String footer,
    required String outletName,
    required String outletAddress,
    required String kontakOutlet,
    double? paperWidth,
    bool usePrintMarkers = true,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id');
    final divider = _dividerFor(paperWidth);
    final infoLabelWidth = 11;
    final padChar = ' ';
    // Right-justified columns via _justifyBetween drift out of alignment in
    // WhatsApp's monospace (```) rendering once the gap gets wide (confirmed:
    // the price section's ~15-18 char gaps misalign while the item-detail
    // lines' shorter ~7-10 char gaps look fine). The small fixed-width
    // "label : value" pattern (_pad, same as the Kasir/Tgl Masuk info lines)
    // doesn't have that problem, so use it for the WhatsApp price section.
    final bool isWhatsApp = paperWidth == null;
    String priceLine(String label, String value) {
      if (isWhatsApp) {
        return '${_pad(label, width: infoLabelWidth)}: $value';
      }
      return _fixedPriceLine(label, value, width: _priceWidth(paperWidth));
    }

    String infoLine(String label, String value) => isWhatsApp
        ? '${_pad(label, width: infoLabelWidth)}: $value'
        : '${_pad(label, width: infoLabelWidth)}:$value';

    final trxCode =
        snapshot['tr_id']?.toString() ??
        snapshot['tr_code']?.toString() ??
        snapshot['transaction_code']?.toString() ??
        '-';

    final kasir = snapshot['tr_userupdate'] ?? snapshot['kasir_name'] ?? '-';

    final customerName =
        customer?.name ??
        snapshot['customer_name'] ??
        snapshot['pelanggan'] ??
        '-';

    final catatan =
        snapshot['catatan']?.toString() ?? snapshot['notes']?.toString() ?? '';

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

    final jemputAlamat = snapshot['jemput_alamat']?.toString() ?? '';
    final antarAlamat = snapshot['antar_alamat']?.toString() ?? '';
    final jemputBiaya = _toDouble(snapshot['jemput_biaya']);
    final antarBiaya = _toDouble(snapshot['antar_biaya']);
    final totalJemputAntar = jemputBiaya + antarBiaya;

    final rawTotalKotor = _toDouble(
      snapshot['total_kotor'] ??
          snapshot['subtotal_kotor'] ??
          snapshot['tr_total_kotor'],
    );

    final details = snapshot['details'] as List?;

    final depositPayment = _depositPayment(snapshot);
    final isDepositRupiah = depositPayment.id == 'DEPOSIT_RUPIAH';
    final isDepositKg = depositPayment.id == 'DEPOSIT_KG';
    final depositUsage = depositPayment.usage > 0
        ? depositPayment.usage
        : isDepositKg
        ? (details ?? const []).fold<double>(
            0,
            (sum, detail) =>
                sum +
                ((detail is Map &&
                        (detail['dtr_satuan'] ?? detail['satuan'] ?? '')
                                .toString()
                                .trim()
                                .toLowerCase() ==
                            'kg')
                    ? _toDouble(detail['dtr_qty'] ?? detail['qty'])
                    : 0),
          )
        : isDepositRupiah
        ? grandTotal
        : 0;

    final totalOrder = () {
      if (details != null && details.isNotEmpty) {
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

      if (rawTotalKotor > 0) {
        final val = rawTotalKotor - totalJemputAntar;
        if (val >= 0) return val;
      }

      final roundingAmt = _toDouble(
        snapshot['rounding_amount'] ?? snapshot['tr_rounding'] ?? 0,
      );
      return (grandTotal + discount - totalJemputAntar - roundingAmt).clamp(
        0.0,
        double.infinity,
      );
    }();

    final sisaBayar = _toDouble(
      snapshot['tr_sisa'] ??
          snapshot['sisa_bayar'] ??
          (nominalDP > 0 ? grandTotal - nominalDP : 0.0),
    );

    final cashAmount = _toDouble(
      snapshot['tr_cash'] ?? snapshot['cash_received'] ?? snapshot['cash'],
    );

    final roundingAmount = _toDouble(
      snapshot['rounding_amount'] ?? snapshot['tr_rounding'] ?? 0,
    );

    final paymentStatusText =
        snapshot['tr_status_pembayaran']?.toString() ??
        snapshot['payment_status']?.toString() ??
        snapshot['status_pembayaran']?.toString() ??
        '-';

    final paymentStatus = paymentStatusText.toLowerCase();

    final rawOrderStatus =
        snapshot['tr_status']?.toString() ??
        snapshot['tr_status_order']?.toString() ??
        snapshot['status_order']?.toString() ??
        snapshot['status']?.toString() ??
        snapshot['order_status']?.toString() ??
        snapshot['status_pesanan']?.toString() ??
        '';

    final orderStatusText = rawOrderStatus;
    final orderStatus = orderStatusText.toLowerCase().trim();

    final parfumNama = () {
      final direct = snapshot['parfum_nama']?.toString() ?? '';
      if (direct.isNotEmpty && direct != '-') return direct;

      final parfumObj = snapshot['parfum'];
      if (parfumObj is Map) {
        // API detail transaksi mengembalikan key ber-capital ("Nama"), tapi
        // sumber snapshot lain (mis. hasil checkout) pakai "nama"/"name"
        // lowercase. Cek semua variannya.
        final name =
            (parfumObj['nama'] ??
                    parfumObj['Nama'] ??
                    parfumObj['name'] ??
                    parfumObj['Name'] ??
                    '')
                .toString();
        if (name.isNotEmpty && name != '-') return name;
      }

      final alt = snapshot['nama_parfum']?.toString() ?? '';
      if (alt.isNotEmpty && alt != '-') return alt;

      return '';
    }();

    final isLunas = paymentStatus == 'lunas';
    final isBelumLunasWithoutDP = !isLunas && nominalDP <= 0;
    final isDPBelumLunas = !isLunas && nominalDP > 0;

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

      if (raw is DateTime) {
        createdAt = raw;
      } else if (raw != null) {
        createdAt = DateTime.parse(raw.toString());
      } else {
        createdAt = DateTime.now();
      }
    } catch (_) {
      createdAt = DateTime.now();
    }

    final entryDate = dateFormat.format(createdAt);

    String estDate = '-';

    if (details != null && details.isNotEmpty) {
      final readyAt =
          details.first['ready_at'] ?? details.first['dtr_ready_at'];

      if (readyAt != null) {
        try {
          final dt = readyAt is DateTime
              ? readyAt
              : DateTime.parse(readyAt.toString());
          estDate = dateFormat.format(dt);
        } catch (_) {
          estDate = '-';
        }
      }
    }

    final orderDetail = _formatOrderDetail(
      details,
      showDuration: nota?.cnSettDurasi ?? true,
      lineWidth: _lineWidth(paperWidth),
      padChar: padChar,
    );
    final optionalItemDetail = _formatOptionalItems(
      snapshot['optional_items'],
      lineWidth: _lineWidth(paperWidth),
      padChar: padChar,
    );
    final optionalItemSection = optionalItemDetail.isNotEmpty
        ? '\n$divider\n$optionalItemDetail'
        : '';

    final StringBuffer price = StringBuffer();

    price.writeln(
      priceLine('SubTotal', CurrencyFormatter.formatToRupiah(totalOrder)),
    );

    if (jemputBiaya > 0) {
      price.writeln(
        priceLine('Jemput', CurrencyFormatter.formatToRupiah(jemputBiaya)),
      );
    }

    if (antarBiaya > 0) {
      price.writeln(
        priceLine('Antar', CurrencyFormatter.formatToRupiah(antarBiaya)),
      );
    }

    if (jemputBiaya > 0 && antarBiaya > 0) {
      price.writeln(
        priceLine(
          'Tot.J+A',
          CurrencyFormatter.formatToRupiah(totalJemputAntar),
        ),
      );
    }

    if (discount > 0) {
      price.writeln(
        priceLine('Diskon', '-Rp ${_rupiahWithoutPrefix(discount)}'),
      );
    }

    if (roundingAmount != 0 && (nota?.cnSettRounding ?? true)) {
      final sign = roundingAmount > 0 ? '+' : '-';
      price.writeln(
        priceLine(
          'Bulat',
          '$sign Rp ${_rupiahWithoutPrefix(roundingAmount.abs())}',
        ),
      );
    }

    if (isLunas && cashAmount > 0) {
      price.writeln(
        priceLine('Cash', CurrencyFormatter.formatToRupiah(cashAmount)),
      );
    }

    price.writeln(
      priceLine('Total', CurrencyFormatter.formatToRupiah(grandTotal)),
    );

    if (isDepositRupiah || isDepositKg) {
      price.writeln(
        priceLine('Metode', isDepositKg ? 'Deposit Kg' : 'Deposit Rupiah'),
      );
      final usageText = isDepositKg
          ? '${NumberFormat.decimalPattern('id_ID').format(depositUsage)} Kg'
          : CurrencyFormatter.formatToRupiah(depositUsage);
      price.writeln(priceLine('Deposit', usageText));
    }

    if (isDPBelumLunas) {
      price.writeln(
        priceLine('DP Dibayar', CurrencyFormatter.formatToRupiah(nominalDP)),
      );
    }

    final statusBayarLabel = isLunas ? 'LUNAS' : 'BELUM LUNAS';
    final statusBanner = statusBayarLabel;
    final statusNote = isSelesai ? 'CUCIAN SUDAH SELESAI\nSIAP DIAMBIL' : '';

    // ── Header: outlet info + trxCode (tanpa Pelanggan di sini) ──
    final List<String> headerLines = [outletName];

    if (outletAddress.isNotEmpty) {
      headerLines.add(outletAddress);
    }

    if (kontakOutlet.isNotEmpty) {
      headerLines.add(kontakOutlet);
    }

    headerLines.add(trxCode);

    final outletHeader = usePrintMarkers
        ? _centerBlock(headerLines.join('\n'), width: _lineWidth(paperWidth))
        : headerLines.join('\n');

    // ── Info section ──
    final StringBuffer info = StringBuffer();

    if (showKasir) {
      info.writeln(infoLine('Kasir', kasir));
    }

    info.writeln(infoLine('Tgl Masuk', entryDate));
    info.writeln(infoLine('Est Selesai', estDate));

    if (parfumNama.isNotEmpty) {
      info.writeln(infoLine('Parfum', parfumNama));
    }

    if (jemputAlamat.isNotEmpty) {
      info.writeln(
        _wrapAddress('Jemput', jemputAlamat, lineWidth: _lineWidth(paperWidth)),
      );
    }

    if (antarAlamat.isNotEmpty) {
      info.writeln(
        _wrapAddress('Antar', antarAlamat, lineWidth: _lineWidth(paperWidth)),
      );
    }

    if (showKeterangan && catatan.isNotEmpty) {
      info.writeln(infoLine('Catatan', catatan));
    }

    // Catatan "CUCIAN SUDAH SELESAI / SIAP DIAMBIL" (kalau pesanan selesai),
    // di-center per baris.
    final selesaiLines = statusNote.isNotEmpty
        ? (usePrintMarkers
              ? statusNote
                    .split('\n')
                    .map((line) => _center(line, width: _lineWidth(paperWidth)))
                    .toList()
              : statusNote.split('\n'))
        : <String>[];

    final remainingAmount = CurrencyFormatter.formatToRupiah(
      isDPBelumLunas ? sisaBayar : grandTotal,
    );
    final remainingPaymentLine = isDPBelumLunas
        ? 'Kurang: $remainingAmount'
        : remainingAmount;
    final hasNominalBelumLunas = isDPBelumLunas || isBelumLunasWithoutDP;

    final customerLine = usePrintMarkers
        ? '~~CUST~~$customerName'
        : customerName;

    // Blok status dengan hierarki yang benar:
    //   BELUM LUNAS            (banner besar)
    //   Rp21.500               (nominal, TEPAT di bawah banner)
    //   CUCIAN SUDAH SELESAI   (catatan status, kalau pesanan selesai)
    //   SIAP DIAMBIL
    //   ----------------       (divider penutup, kalau ada nominal)
    // Sebelumnya nominal keliru diletakkan setelah "SIAP DIAMBIL" sehingga
    // urutannya terbaca acak (banner, catatan, baru nominal di bawah).
    final statusBlock = [
      usePrintMarkers ? '~~STATUS~~$statusBanner' : statusBanner,
      if (hasNominalBelumLunas)
        usePrintMarkers ? '~~$remainingPaymentLine' : remainingPaymentLine,
      ...selesaiLines,
      if (hasNominalBelumLunas) divider,
    ].join('\n');

    // Footer (mis. "Harap membawa bon ini ketika mengambil pakaian") datang
    // sebagai satu baris panjang. Baris lain sudah di-word-wrap sebelum
    // dicetak (_wrapTextByWords); footer tidak, jadi printer/byte-encoder
    // memotongnya berdasarkan jumlah karakter mentah dan bisa memutus
    // tengah kata. Bungkus per-kata di sini juga, khusus untuk cetak fisik.
    final wrappedFooter = usePrintMarkers && footer.isNotEmpty
        ? _wrapFooterLines(footer, width: _lineWidth(paperWidth)).join('\n')
        : footer;

    final infoBlock = info.toString().trimRight();
    // Padding spasi hanya dapat sejajar secara konsisten jika WhatsApp
    // merender blok ini dengan font monospace. Fence tidak dipakai pada nota
    // cetak, sehingga keluaran printer fisik tetap sama seperti sebelumnya.
    final formattedInfo = isWhatsApp ? '```\n$infoBlock\n```' : infoBlock;

    final rawText =
        '''$outletHeader
$divider
$customerLine
$divider
$formattedInfo
$divider
$orderDetail$optionalItemSection
$divider
${price.toString().trimRight()}
$divider
$statusBlock
$wrappedFooter''';

    if (!usePrintMarkers) return rawText;

    // Printer men-center-align setiap baris secara independen (supaya blok
    // teks jatuh di tengah kertas fisik, bukan nempel kiri — lihat
    // permission_provider.dart). Itu cuma menghasilkan kolom yang rapi kalau
    // SEMUA baris punya panjang yang sama persis; kalau tidak, tiap baris
    // bergeser beda-beda seolah "indent acak" (mis. baris "Kasir"/"Parfum"
    // yang variatif panjangnya, atau nama layanan tambahan yang lebih
    // pendek dari baris qty/harga di bawahnya). Baris header/divider/marker
    // (~~...) sudah punya penanganan lebar/alignment sendiri, sisanya kita
    // pad rata kanan ke lebar tetap di sini.
    final width = _lineWidth(paperWidth);
    final paddedLines = rawText.split('\n').map((line) {
      if (line.startsWith('~~') ||
          line.startsWith('---') ||
          line.startsWith('===') ||
          line.length >= width) {
        return line;
      }
      return line.padRight(width);
    });

    return paddedLines.join('\n');
  }

  static String getLinkNota(Map snapshot) {
    final String webBaseUrl = "${ApiClient.plainUrl}/nota/";

    final trxCode =
        snapshot['tr_id']?.toString() ??
        snapshot['tr_code']?.toString() ??
        snapshot['transaction_code']?.toString() ??
        '-';

    final encodedId = base64Url
        .encode(utf8.encode(trxCode))
        .replaceAll('=', '');

    return "$webBaseUrl$encodedId";
  }

  static String _resolveFooter(NotaSettings? nota) {
    final showCustom = nota?.cnSettNota ?? false;
    final customText = nota?.cnFooterNota ?? '';

    return (showCustom && customText.isNotEmpty) ? customText : '';
  }

  static String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;

    final total = width - text.length;
    final left = total ~/ 2;
    final right = total - left;

    return ' ' * left + text + ' ' * right;
  }

  static String _formatOrderDetail(
    List? details, {
    required bool showDuration,
    required int lineWidth,
    String padChar = ' ',
  }) {
    if (details == null || details.isEmpty) {
      return 'Tidak ada detail';
    }

    return details
        .map((d) {
          String name = d['nama_layanan']?.toString() ?? '';

          if (name.isEmpty) {
            final dtrNama = d['dtr_nama_layanan']?.toString() ?? '';
            final parenRegex = RegExp(r'^.*?\(\s*(.*?)\s*\)$');
            final match = parenRegex.firstMatch(dtrNama);
            name = match != null ? match.group(1)! : dtrNama;
          }

          if (name.isEmpty) {
            name =
                d['nama_kategori']?.toString() ??
                d['dtr_nama_kategori']?.toString() ??
                '-';
          }

          final qty = d['dtr_qty'] ?? d['qty'] ?? 0;
          final qtyDouble = _toDouble(qty);
          final satuan = d['dtr_satuan'] ?? d['satuan'] ?? '';
          final subtotal = _toDouble(d['dtr_subtotal'] ?? d['subtotal']);
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

          final left =
              '$qtyStr $satuan x ${CurrencyFormatter.formatToRupiah(unitPrice)}';
          final right = CurrencyFormatter.formatToRupiah(subtotal);
          final wrapWidth = lineWidth;
          final nameLines = _wrapTextByWords(
            '$name$durasiStr',
            width: wrapWidth,
          );
          final safeNameBlock = nameLines.isEmpty ? '-' : nameLines.join('\n');
          return '$safeNameBlock\n${_justifyBetween(left, right, width: wrapWidth, minGap: 2, padChar: padChar)}';
        })
        // Baris kosong antar layanan supaya tiap item (nama + qty/harga)
        // terbaca sebagai satu grup, tidak menempel ke layanan berikutnya.
        .join('\n\n');
  }

  static String _formatOptionalItems(
    dynamic rawItems, {
    required int lineWidth,
    String padChar = ' ',
  }) {
    if (rawItems is! List || rawItems.isEmpty) return '';

    final grouped = <String, List<Map>>{};
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final serviceName = raw['service_name']?.toString().trim() ?? '';
      grouped.putIfAbsent(serviceName, () => []).add(raw);
    }

    if (grouped.isEmpty) return '';

    final lines = <String>[];
    grouped.forEach((serviceName, items) {
      if (serviceName.isNotEmpty) {
        final wrapWidth = lineWidth;
        lines.addAll(_wrapTextByWords(serviceName, width: wrapWidth));
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
        lines.add('$itemName $qty pcs$note');
      }
    });

    return lines.join('\n');
  }
}
