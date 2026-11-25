import 'dart:io';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';
import 'package:ayocucinew/shared/widgets/nota_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class SendNotaImage {
  static const MethodChannel _channel = MethodChannel(
    'com.ayocuci/file_provider',
  );

  static Future<void> share({
    required BuildContext context,
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
    bool isBusiness = false,
    bool directToWhatsApp = false,
  }) async {
    // Simpan navigator & messenger SEBELUM async gap
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Tampilkan loading sebagai route agar dismissnya terkontrol
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black38,
        pageBuilder: (_, _, __) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
      ),
    );

    try {
      final controller = ScreenshotController();

      final imageBytes = await controller.captureFromWidget(
        NotaPreviewWidget(snapshot: snapshot, customer: customer, nota: nota),
        pixelRatio: 2.0,
        context: context,
      );

      final dir = await getTemporaryDirectory();
      final trxId = (snapshot['tr_id'] ?? snapshot['tr_code'] ?? 'nota')
          .toString()
          .replaceAll('/', '_')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/nota_$trxId.png');
      await file.writeAsBytes(imageBytes);

      // Dismiss loading dulu, tunggu animasi selesai
      navigator.pop();
      await Future.delayed(const Duration(milliseconds: 300));

      final phone = _cleanPhone(customer?.phone ?? '');
      final caption = _buildCaption(snapshot: snapshot, customer: customer, nota: nota);

      if (directToWhatsApp && Platform.isAndroid && phone.isNotEmpty) {
        try {
          await _channel.invokeMethod('shareImageToWhatsApp', {
            'path': file.path,
            'isBusiness': isBusiness,
            'phone': phone,
            'text': caption,
          });
          return;
        } catch (_) {
          // Fallback ke share sheet jika intent direct gagal di device tertentu.
        }
      }

      // Fallback generic share sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: caption,
        ),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Gagal kirim gambar: $e')));
    }
  }

  // Caption hanya pengantar singkat — rincian nota sudah tercetak di gambar,
  // jadi tidak perlu diulang sebagai teks.
  static String _buildCaption({
    required Map snapshot,
    required Customer? customer,
    NotaSettings? nota,
  }) {
    final outletName = nota?.cnNamaOutlet ?? 'AyoCuci Laundry';
    final rawName = customer?.name.trim() ?? '';
    final greetName = rawName.isNotEmpty ? ' $rawName' : '';

    final lines = <String>[
      'Halo Kak$greetName 👋',
      '🧺 Terima kasih sudah mempercayakan cucian ke $outletName.',
      'Rincian pesanan bisa dilihat pada gambar nota di atas ya.',
      'Lihat nota online: ${NotaTextBuilder.getLinkNota(snapshot)}',
    ];

    final footerText = nota?.whatsappFooterText ?? '';
    if (footerText.isNotEmpty) {
      lines.add(footerText);
    }

    return lines.join('\n\n');
  }

  static String _cleanPhone(String phone) {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) return '62${p.substring(1)}';
    if (!p.startsWith('62')) return '62$p';
    return p;
  }
}
