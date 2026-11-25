class PaymentNameHelper {
  PaymentNameHelper._();

  // ─── Bank ──────────────────────────────────────────────────────────────────

  static const Map<String, String> _shortToFull = {
    'BCA': 'Bank Central Asia',
    'BNI': 'Bank Negara Indonesia',
    'BRI': 'Bank Rakyat Indonesia',
    'Mandiri': 'Bank Mandiri',
    'CIMB': 'CIMB Niaga',
    'BSI': 'Bank Syariah Indonesia',
    'Permata': 'Bank Permata',
    'Danamon': 'Bank Danamon',
    'BTPN': 'Bank BTPN',
    'Mega': 'Bank Mega',
    'OCBC NISP': 'Bank OCBC NISP',
    'Panin': 'Bank Panin',
    'UOB': 'Bank UOB Indonesia',
  };

  static const Map<String, String> _fullToShort = {
    'Bank Central Asia': 'BCA',
    'Bank Negara Indonesia': 'BNI',
    'Bank Rakyat Indonesia': 'BRI',
    'Bank Mandiri': 'Mandiri',
    'CIMB Niaga': 'CIMB',
    'Bank Syariah Indonesia': 'BSI',
    'Bank Permata': 'Permata',
    'Bank Danamon': 'Danamon',
    'Bank BTPN': 'BTPN',
    'Bank Mega': 'Mega',
    'Bank OCBC NISP': 'OCBC NISP',
    'Bank Panin': 'Panin',
    'Bank UOB Indonesia': 'UOB',
  };

  /// 'BCA' → 'Bank Central Asia'
  static String getFullBankName(String bankName) {
    if (_shortToFull.containsKey(bankName)) return _shortToFull[bankName]!;
    final upper = bankName.toUpperCase();
    for (final entry in _shortToFull.entries) {
      if (entry.key.toUpperCase() == upper) return entry.value;
    }
    return bankName;
  }

  /// 'Bank Central Asia' → 'BCA', jika tidak dikenal kembalikan ''
  static String getShortBankName(String bankName) {
    if (_fullToShort.containsKey(bankName)) return _fullToShort[bankName]!;
    for (final entry in _fullToShort.entries) {
      if (bankName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    final match = RegExp(r'\(([^)]+)\)').firstMatch(bankName);
    return match?.group(1) ?? '';
  }

  /// Menghasilkan label tampilan untuk bank, misal "Bank Central Asia (BCA)"
  static String getBankDisplayName(String bankName) {
    final full = getFullBankName(bankName);
    if (full != bankName) return '$full ($bankName)';
    final short = getShortBankName(bankName);
    if (short.isNotEmpty && short != bankName) return '$bankName ($short)';
    return bankName;
  }

  // ─── E-Wallet ──────────────────────────────────────────────────────────────

  static const Map<String, String> _ewalletNames = {
    'gopay': 'GoPay',
    'ovo': 'OVO',
    'dana': 'DANA',
    'shopeepay': 'ShopeePay',
    'linkaja': 'LinkAja',
    'jenius': 'Jenius',
  };

  /// 'gopay' → 'GoPay'
  static String getEwalletDisplayName(String provider) {
    final lower = provider.toLowerCase();
    if (_ewalletNames.containsKey(lower)) return _ewalletNames[lower]!;
    if (provider.isEmpty) return provider;
    return provider[0].toUpperCase() + provider.substring(1);
  }

  // ─── Category ──────────────────────────────────────────────────────────────

  static const Map<String, String> _categoryDisplayNames = {
    'Transfer': 'Transfer Bank',
    'Cash': 'Cash',
    'E-Wallet': 'E-Wallet',
    'QRIS': 'QRIS',
  };

  /// 'Transfer' → 'Transfer Bank'
  static String getCategoryDisplayName(String category) {
    return _categoryDisplayNames[category] ?? category;
  }

  static String getCategoryDescription(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return 'Pembayaran tunai';
      case 'qris':
        return 'Scan QR Code';
      case 'transfer':
        return 'Transfer Bank';
      case 'e-wallet':
        return 'Dompet Digital';
      default:
        return 'Metode pembayaran';
    }
  }
}
