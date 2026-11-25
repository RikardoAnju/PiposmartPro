import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/permission_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NotaPrintProvider extends ChangeNotifier {
  bool _isPrinting = false;
  String? _lastError;

  bool get isPrinting => _isPrinting;
  String? get lastError => _lastError;

  static const _packageWa = 'com.whatsapp';
  static const _packageWaBusiness = 'com.whatsapp.w4b';

  void _setLoading(bool v) {
    _isPrinting = v;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  NotaSettings? getNota(BuildContext context) => _getNota(context);

  NotaSettings? _getNota(BuildContext context) =>
      context.read<NotaSettingsProvider>().notaSettings;

  /// A transaction-detail screen can stay open while the user switches the
  /// app's active outlet elsewhere, so `nota` (letterhead) here always
  /// reflects whichever outlet is *currently* active, not necessarily the
  /// outlet that actually owns `snapshot`. Printing that combination puts
  /// one outlet's transaction on another outlet's letterhead. Block it
  /// instead of silently printing mismatched data.
  bool _outletMismatch(BuildContext context, Map snapshot) {
    final activeOutletId = context.read<AppProvider>().outlet?.id;
    final snapshotOutletId = snapshot['outlet_id']?.toString();
    if (activeOutletId == null || activeOutletId.isEmpty) return false;
    if (snapshotOutletId == null || snapshotOutletId.isEmpty) return false;
    return activeOutletId != snapshotOutletId;
  }

  String? _getLogoUrl(NotaSettings? nota) {
    if (nota?.cnSettLogo != true) return null;
    if (nota?.cnLogo.isEmpty ?? true) return null;
    return ApiClient.resolveUploadUrl(nota!.cnLogo);
  }

  int _getPaperWidth(NotaSettings? nota) {
    final ukuran = nota?.cnUkuran ?? 58;
    if (ukuran == 80) return 80;
    if (ukuran == 88) return 88;
    return 58;
  }

  String _buildWaText(Map snapshot, Customer? customer, NotaSettings? nota) {
    final body = _buildBodyText(snapshot, customer, nota);
    final footerText = nota?.whatsappFooterText ?? '';
    final waFooter = footerText.isNotEmpty ? '\n$footerText' : '';
    final linkNota = '\nLihat Nota : ${NotaTextBuilder.getLinkNota(snapshot)}';
    // WhatsApp renders plain messages in a proportional font, so the
    // padRight-based column alignment in _justifyBetween (SubTotal/Total/
    // Diskon/dsb) only lines up visually inside WhatsApp's monospace
    // formatting (```). Wrap the body so it actually looks aligned.
    return '```$body$waFooter```$linkNota';
  }

  String _buildPrinterText(
    Map snapshot,
    Customer? customer,
    NotaSettings? nota,
  ) {
    final bool showKasir = nota?.cnSettKasir ?? true;
    final bool showKeterangan = nota?.cnSettKeterangan ?? true;
    final bool showFooterCustom = nota?.cnSettNota ?? false;
    final outletName = nota?.cnNamaOutlet ?? 'AyoCuci Laundry';
    final outletAddress = nota?.cnAlamat ?? '';
    final kontakOutlet = nota?.cnKontak ?? '';
    final footer =
        (showFooterCustom &&
            nota?.cnFooterNota != null &&
            nota!.cnFooterNota.isNotEmpty)
        ? nota.cnFooterNota
        : '';

    return NotaTextBuilder.buildWithFlags(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      showKasir: showKasir,
      showKeterangan: showKeterangan,
      footer: footer,
      outletName: outletName,
      outletAddress: outletAddress,
      kontakOutlet: kontakOutlet,
      paperWidth: _getPaperWidth(nota).toDouble(),
    );
  }

  String _buildBodyText(Map snapshot, Customer? customer, NotaSettings? nota) {
    final bool showKasir = nota?.cnSettKasir ?? true;
    final bool showKeterangan = nota?.cnSettKeterangan ?? true;
    final bool showFooterCustom = nota?.cnSettNota ?? false;
    final outletName = nota?.cnNamaOutlet ?? 'AyoCuci Laundry';
    final outletAddress = nota?.cnAlamat ?? '';
    final kontakOutlet = nota?.cnKontak ?? '';
    final footer =
        (showFooterCustom &&
            nota?.cnFooterNota != null &&
            nota!.cnFooterNota.isNotEmpty)
        ? nota.cnFooterNota
        : '';

    return NotaTextBuilder.buildForWhatsApp(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
      showKasir: showKasir,
      showKeterangan: showKeterangan,
      footer: footer,
      outletName: outletName,
      outletAddress: outletAddress,
      kontakOutlet: kontakOutlet,
    );
  }

  String? _getLink(BuildContext context, Map snapshot) {
    final showQr = _getNota(context)?.cnSettQr ?? true;
    return showQr ? NotaTextBuilder.getLinkNota(snapshot) : null;
  }

  String _cleanPhone(String phone) {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) return '62${p.substring(1)}';
    if (!p.startsWith('62')) return '62$p';
    return p;
  }

  Future<({bool hasPersonal, bool hasBusiness})> checkInstalledWaApps() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final personalUri = Uri.parse('whatsapp://send?text=halo');
      final businessUri = Uri.parse('whatsapp-business://send?text=halo');
      final hasPersonal = await canLaunchUrl(personalUri);
      final hasBusiness = await canLaunchUrl(businessUri);

      // Di iOS, WhatsApp Business kadang tetap merespons via scheme whatsapp://
      // dan preflight bisa false negative. Jika personal ada, izinkan keduanya
      // supaya user tetap bisa lanjut ke aplikasi WA yang tersedia.
      if (hasPersonal) {
        return (hasPersonal: true, hasBusiness: true);
      }

      return (hasPersonal: hasPersonal, hasBusiness: hasBusiness);
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      final fallback = Uri.parse('whatsapp://send?text=halo');
      final has = await canLaunchUrl(fallback);
      return (hasPersonal: has, hasBusiness: has);
    }

    bool hasPersonal = false;
    bool hasBusiness = false;

    try {
      final intentPersonal = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: _packageWa,
        data: 'whatsapp://send?text=halo',
      );
      hasPersonal = await intentPersonal.canResolveActivity() ?? false;
    } catch (_) {
      hasPersonal = false;
    }

    try {
      final intentBusiness = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: _packageWaBusiness,
        data: 'whatsapp://send?text=halo',
      );
      hasBusiness = await intentBusiness.canResolveActivity() ?? false;
    } catch (_) {
      hasBusiness = false;
    }

    return (hasPersonal: hasPersonal, hasBusiness: hasBusiness);
  }

  Future<bool> isWhatsAppInstalled({required bool isBusiness}) async {
    final installed = await checkInstalledWaApps();
    return isBusiness ? installed.hasBusiness : installed.hasPersonal;
  }

  String getWhatsAppUnavailableMessage({required bool isBusiness}) {
    return isBusiness
        ? 'WhatsApp Business tidak terinstall di perangkat ini'
        : 'WhatsApp tidak terinstall di perangkat ini';
  }

  Future<void> sendWhatsApp({
    required Map snapshot,
    required Customer? customer,
    required bool isBusiness,
    NotaSettings? nota,
  }) async {
    _lastError = null;

    final phone = customer?.phone ?? '';

    final message = _buildWaText(snapshot, customer, nota);
    final cleanedPhone = _cleanPhone(phone);
    final package = isBusiness ? _packageWaBusiness : _packageWa;
    final encodedMsg = Uri.encodeComponent(message);
    final waData = phone.isEmpty
        ? 'whatsapp://send?text=$encodedMsg'
        : 'whatsapp://send?phone=$cleanedPhone&text=$encodedMsg';

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          package: package,
          data: waData,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        final canResolve = await intent.canResolveActivity() ?? false;
        if (canResolve) {
          await intent.launch();
          return;
        }
        _lastError = getWhatsAppUnavailableMessage(isBusiness: isBusiness);
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('AndroidIntent error: $e');
      }
    }

    final fallbackUri = Uri.parse(waData);

    if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } else {
      _lastError = getWhatsAppUnavailableMessage(isBusiness: isBusiness);
      notifyListeners();
    }
  }

  Future<void> printMerchantOnly({
    required BuildContext context,
    required Map snapshot,
    required Customer? customer,
  }) async {
    _setLoading(true);
    _lastError = null;

    if (_outletMismatch(context, snapshot)) {
      _lastError =
          'Transaksi ini bukan milik outlet yang sedang aktif. Muat ulang halaman transaksi sebelum mencetak.';
      _setLoading(false);
      notifyListeners();
      return;
    }

    try {
      final nota = _getNota(context);
      final linkNota = (nota?.cnSettQr ?? true)
          ? NotaTextBuilder.getLinkNota(snapshot)
          : null;
      final paperWidth = _getPaperWidth(nota);
      final perm = context.read<PermissionProvider>();
      final merchantText = _buildPrinterText(snapshot, customer, nota);

      final result = await perm.printReceipt(
        merchantText,
        linkNota: linkNota,
        logoUrl: _getLogoUrl(nota),
        context: context,
        paperWidth: paperWidth,
      );

      if (result['success'] != true) {
        _lastError = result['message'] ?? 'Gagal mencetak struk merchant';
        notifyListeners();
      }
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> printNota({
    required BuildContext context,
    required Map snapshot,
    required Customer? customer,
  }) => _debugPrint(context: context, snapshot: snapshot, customer: customer);

  Future<Map<String, dynamic>> _debugPrint({
    required BuildContext context,
    required Map snapshot,
    required Customer? customer,
  }) async {
    _setLoading(true);
    _lastError = null;

    if (_outletMismatch(context, snapshot)) {
      _lastError =
          'Transaksi ini bukan milik outlet yang sedang aktif. Muat ulang halaman transaksi sebelum mencetak.';
      _setLoading(false);
      notifyListeners();
      return {'success': false, 'message': _lastError};
    }

    try {
      final nota = _getNota(context);
      final linkNota = _getLink(context, snapshot);
      final paperWidth = _getPaperWidth(nota);
      final perm = context.read<PermissionProvider>();
      final text = _buildPrinterText(snapshot, customer, nota);
      final result = await perm.printReceipt(
        text,
        linkNota: linkNota,
        logoUrl: _getLogoUrl(nota),
        context: context,
        paperWidth: paperWidth,
      );

      if (result['success'] != true) {
        _lastError = result['message'] ?? 'Gagal mencetak';
        notifyListeners();
      }

      return result;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    } finally {
      _setLoading(false);
    }
  }
}
