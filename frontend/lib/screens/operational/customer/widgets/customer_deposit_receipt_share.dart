import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../shared/widgets/custom_toast.dart';

class CustomerDepositReceiptShare {
  static Future<void> send({
    required BuildContext context,
    required String customerName,
    required String customerPhone,
    required String title,
    required String amount,
    required String depositType,
    required String createdAt,
    required String balanceAfter,
    String cashAmount = '',
    String discountAmount = '',
    String paymentMethod = '',
    String createdBy = '',
    String note = '',
    String adjustmentNote = '',
  }) async {
    final outletName = context.read<AppProvider>().outlet?.nama.trim() ?? '';
    final lines = <String>[
      if (outletName.isNotEmpty) '*$outletName*',
      '*BUKTI $title*',
      '',
      'Pelanggan: $customerName',
      if (createdBy.trim().isNotEmpty) 'Dibuat oleh: $createdBy',
      'Jenis saldo: $depositType',
      'Waktu: $createdAt',
      'Nilai: $amount',
      if (cashAmount.isNotEmpty) 'Uang diterima saat top up: $cashAmount',
      if (discountAmount.isNotEmpty) 'Diskon program deposit: $discountAmount',
      if (cashAmount.isNotEmpty)
        'Metode penerimaan: ${paymentMethod.trim().isEmpty ? 'Manual' : paymentMethod.trim()}',
      'Saldo saat transaksi: $balanceAfter',
      if (adjustmentNote.isNotEmpty) 'Catatan penyesuaian: $adjustmentNote',
      if (note.trim().isNotEmpty) 'Catatan: ${note.trim()}',
      '',
      'Terima kasih telah menggunakan layanan kami.',
    ];
    final message = lines.join('\n');
    final phone = _normalizePhone(customerPhone);
    final uri = Uri.https('wa.me', phone.isEmpty ? '/' : '/$phone', {
      'text': message,
    });

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (_) {
      if (!context.mounted) return;
      CustomToast.show(
        context,
        message: 'WhatsApp tidak dapat dibuka.',
        isError: true,
      );
    }
  }

  static String _normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
    if (phone.isNotEmpty && !phone.startsWith('62')) phone = '62$phone';
    return phone;
  }
}
