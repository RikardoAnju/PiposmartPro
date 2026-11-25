class PaymentAssetUtil {
  PaymentAssetUtil._();

  static String? getBankLogo(String? bankName) {
    if (bankName == null) return null;
    final bank = bankName.toLowerCase();
    if (bank.contains('bca')) return 'assets/bank/bca.webp';
    if (bank.contains('mandiri')) return 'assets/bank/mandiri.webp';
    if (bank.contains('bni')) return 'assets/bank/bni.webp';
    if (bank.contains('bri')) return 'assets/bank/bri.webp';
    if (bank.contains('bsi') || bank.contains('syariah')) {
      return 'assets/bank/bsi.webp';
    }
    if (bank.contains('cimb')) return 'assets/bank/cimb.webp';
    return null;
  }

  static String? getEwalletLogo(String? provider) {
    if (provider == null) return null;
    final ewallet = provider.toLowerCase();
    if (ewallet.contains('gopay')) return 'assets/E-Wallet/gopay.webp';
    if (ewallet.contains('ovo')) return 'assets/E-Wallet/ovo.webp';
    if (ewallet.contains('dana')) return 'assets/E-Wallet/dana.webp';
    if (ewallet.contains('shopee') || ewallet.contains('spay')) {
      return 'assets/E-Wallet/shope-pay.webp';
    }
    if (ewallet.contains('linkaja') || ewallet.contains('link aja')) {
      return 'assets/E-Wallet/link-aja.webp';
    }
    if (ewallet.contains('seabank')) return 'assets/E-Wallet/seabnk.webp';
    return null;
  }

  static String getCategoryImage(String category) {
    switch (category) {
      case 'Cash':
        return 'assets/icons/icon_cash.webp';
      case 'QRIS':
        return 'assets/icons/icon_qris.webp';
      case 'Transfer':
        return 'assets/icons/icon_bank.webp';
      case 'E-Wallet':
        return 'assets/icons/icon_Ewallet.webp';
      default:
        return 'assets/icons/icon_cash.webp';
    }
  }
}
