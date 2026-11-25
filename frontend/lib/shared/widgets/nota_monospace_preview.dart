import 'package:flutter/material.dart';

import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';

/// Preview struk WYSIWYG: merender teks yang PERSIS dikirim ke printer
/// (`NotaTextBuilder`) dalam font monospace, dengan interpretasi marker yang
/// sama seperti `_buildEscPosBytes` (header bold/center, separator, baris besar
/// `~~CUST~~`/`~~STATUS~~`/`~~`, keyword center). Karena sumber teksnya sama,
/// preview tidak akan pernah drift dari hasil cetak lagi.
class NotaMonospacePreview extends StatelessWidget {
  final Map snapshot;
  final Customer? customer;
  final NotaSettings? nota;

  /// Logo header (idealnya sudah versi monokrom agar mirip hasil thermal).
  final Widget? logo;

  const NotaMonospacePreview({
    super.key,
    required this.snapshot,
    required this.customer,
    this.nota,
    this.logo,
  });

  static const _mono = 'monospace';
  static const _ink = Color(0xFF1A1A1A);

  static const _centerKeywords = [
    'DETAIL PESANAN:',
    'LUNAS',
    'BELUM LUNAS',
    'DP / BELUM LUNAS',
    'CUCIAN SUDAH SELESAI',
    'SIAP DIAMBIL',
  ];

  @override
  Widget build(BuildContext context) {
    // Lebar kertas nyata (mis. 58mm → 28 kolom) agar separator & kolom harga
    // sama lebar seperti hasil cetak (bukan lebar default 31 WhatsApp).
    final paper = ((nota?.cnUkuran ?? 58)).toDouble();
    final text = NotaTextBuilder.buildForPrinterCustomer(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      paperWidth: paper,
    );
    final lines = text.split('\n');
    final firstEq = lines.indexWhere((l) => l.startsWith('==='));
    final headerCount = firstEq > 0 ? firstEq : 1;

    const base = TextStyle(
      fontFamily: _mono,
      fontSize: 12,
      height: 1.32,
      color: _ink,
      letterSpacing: 0,
    );

    final children = <Widget>[];
    if (logo != null) {
      children.add(
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Center(child: logo)),
      );
    }

    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i];

      // Baris besar: ~~CUST~~ / ~~STATUS~~ / ~~ (sisa bayar) → besar + bold, center.
      if (raw.startsWith('~~')) {
        String t;
        if (raw.startsWith('~~CUST~~')) {
          t = raw.substring(8);
        } else if (raw.startsWith('~~STATUS~~')) {
          t = raw.substring(10);
        } else {
          t = raw.substring(2);
        }
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              t,
              textAlign: TextAlign.center,
              style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        );
        continue;
      }

      final isHeader = i < headerCount;
      final isSeparator = raw.startsWith('---') || raw.startsWith('===');
      final isCenterKeyword =
          _centerKeywords.any((k) => raw.trim().startsWith(k));
      // Header (nama outlet/alamat/kontak), separator, dan keyword status →
      // rata TENGAH. Baris item/info/harga → rata KIRI agar kolom lurus persis
      // seperti hasil cetak (bukan mengambang di tengah).
      final centered = isHeader || isSeparator || isCenterKeyword;

      children.add(
        Text(
          raw.isEmpty ? ' ' : raw,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: (i == 0 || isCenterKeyword)
              ? base.copyWith(fontWeight: FontWeight.w700)
              : base,
        ),
      );
    }

    // Kertas struk: lebar mengikuti teks (IntrinsicWidth) supaya baris rata-kiri
    // mengisi penuh dan kolom harga mepet ke kanan seperti struk asli.
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
