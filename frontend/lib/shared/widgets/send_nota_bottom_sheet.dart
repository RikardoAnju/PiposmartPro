import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';
import 'package:ayocucinew/shared/widgets/send_nota_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SendNotaBottomSheet extends StatelessWidget {
  final BuildContext hostContext;
  final Map snapshot;
  final Customer? customer;
  final NotaSettings? nota;
  final bool isBusiness;

  const SendNotaBottomSheet({
    super.key,
    required this.hostContext,
    required this.snapshot,
    required this.customer,
    this.nota,
    this.isBusiness = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 18),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAED),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    'Kirim Nota via WhatsApp',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pilih format nota yang ingin dikirim ke customer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7B8794),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SendOptionCard(
                    icon: Icons.receipt_long_rounded,
                    iconBg: const Color(0xFFFFF1EB),
                    iconColor: AppPalette.primary,
                    title: 'Kirim sebagai Teks',
                    subtitle:
                        'Pesan invoice rapi yang langsung terbuka di chat customer.',
                    onTap: () {
                      Navigator.pop(context);
                      _sendAsText();
                    },
                  ),
                  const SizedBox(height: 12),
                  _SendOptionCard(
                    icon: Icons.image_outlined,
                    iconBg: const Color(0xFFEEF7FF),
                    iconColor: const Color(0xFF2F80ED),
                    title: 'Kirim sebagai Gambar',
                    subtitle:
                        'Kirim nota dalam bentuk gambar agar tampil seperti struk.',
                    onTap: () {
                      Navigator.pop(context);
                      SendNotaImage.share(
                        context: hostContext,
                        snapshot: snapshot,
                        customer: customer,
                        nota: nota,
                        isBusiness: isBusiness,
                        directToWhatsApp: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendAsText() {
    final phone = _cleanPhone(customer?.phone ?? '');

    final message = NotaTextBuilder.buildWhatsAppMessage(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
    );
    final encoded = Uri.encodeComponent(message);
    final data = phone.isEmpty
        ? 'whatsapp://send?text=$encoded'
        : 'whatsapp://send?phone=$phone&text=$encoded';

    if (defaultTargetPlatform == TargetPlatform.android) {
      AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp',
        data: data,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } else {
      launchUrl(Uri.parse(data), mode: LaunchMode.externalApplication);
    }
  }

  String _cleanPhone(String phone) {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) return '62${p.substring(1)}';
    if (!p.startsWith('62')) return '62$p';
    return p;
  }
}

class _SendOptionCard extends StatelessWidget {
  const _SendOptionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D101828),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8794),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFFB8C0CC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
