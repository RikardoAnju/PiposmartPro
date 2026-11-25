import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_helpers.dart';

class MetodePembayaranWidget extends StatelessWidget {
  const MetodePembayaranWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final trx = provider.currentDetail;
        if (trx == null) return const SizedBox.shrink();

        final paymentHistory = trx.paymentHistoryFull
            .where((entry) => _hasPaymentInfo(entry))
            .toList();

        if (paymentHistory.isEmpty) {
          if (trx.paymentMethod == null) {
            return const SizedBox.shrink();
          }

          paymentHistory.add({
            'payment_method': trx.paymentMethod!.toJson(),
            'amount': trx.dpAmount > 0 ? trx.dpAmount : trx.totalPrice,
            'paid_at': trx.paidAt?.toIso8601String(),
          });
        }

        if (paymentHistory.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 13, fontWeight: AppFont.w700),
              ),
              const SizedBox(height: 12),
              ...List.generate(paymentHistory.length, (index) {
                final entry = paymentHistory[index];
                final isFirst = index == 0;
                final metodePembayaran =
                    entry['metode_pembayaran'] as Map<String, dynamic>? ??
                    entry['payment_method'] as Map<String, dynamic>?;

                final String namaMetode = metodePembayaran != null
                    ? (metodePembayaran['Nama'] ??
                          metodePembayaran['name'] ??
                          'Cash')
                    : (entry['nama_metode'] ?? 'Cash');

                final String kategori = metodePembayaran != null
                    ? (metodePembayaran['Kategori'] ??
                          metodePembayaran['category'] ??
                          'Cash')
                    : (entry['kategori'] ?? 'Cash');

                final String deskripsi = metodePembayaran != null
                    ? (metodePembayaran['Deskripsi'] ??
                              metodePembayaran['description'] ??
                              '')
                          .toString()
                    : (entry['deskripsi'] ?? entry['description'] ?? '')
                          .toString();

                final String? namaBank = metodePembayaran != null
                    ? (metodePembayaran['NamaBank'] ??
                          metodePembayaran['bank_name'])
                    : entry['nama_bank'];

                final String? ewalletProvider = metodePembayaran != null
                    ? (metodePembayaran['EwalletProvider'] ??
                          metodePembayaran['ewallet_provider'])
                    : entry['nama_ewallet'];

                final String? accountNumber = metodePembayaran != null
                    ? (metodePembayaran['NomorAkun'] ??
                          metodePembayaran['account_number'])
                    : entry['nomor_rekening'];

                final String? accountHolder = metodePembayaran != null
                    ? (metodePembayaran['NamaPemilik'] ??
                          metodePembayaran['account_holder'])
                    : entry['nama_pemilik'];

                final String? phoneNumber = metodePembayaran != null
                    ? (metodePembayaran['NomorHP'] ??
                          metodePembayaran['phone_number'])
                    : entry['nomor_hp'];

                final double jumlah =
                    ((entry['jumlah_dp'] ?? entry['amount'] ?? 0) as num)
                        .toDouble();
                final double depositUsageAmount =
                    ((entry['deposit_usage_amount'] ?? 0) as num).toDouble();
                final depositBalanceAfterRaw = entry['deposit_balance_after'];
                final double? depositBalanceAfter =
                    depositBalanceAfterRaw is num
                    ? depositBalanceAfterRaw.toDouble()
                    : double.tryParse('$depositBalanceAfterRaw');
                final isKiloanDeposit =
                    kategori.toLowerCase() == 'deposit' &&
                    (namaMetode.toLowerCase().contains('kg') ||
                        namaMetode.toLowerCase().contains('kiloan'));

                final DateTime? tanggal = DateTime.tryParse(
                  (entry['tanggal_dp'] ??
                          entry['created_at'] ??
                          entry['paid_at'] ??
                          '')
                      .toString(),
                )?.toLocal();

                final kategoriLower = kategori.toLowerCase();

                final String? specificLogo = kategoriLower == 'transfer'
                    ? PaymentAssetUtil.getBankLogo(namaBank)
                    : kategoriLower == 'e-wallet'
                    ? PaymentAssetUtil.getEwalletLogo(ewalletProvider)
                    : null;
                final String logoPath =
                    specificLogo ?? PaymentAssetUtil.getCategoryImage(kategori);

                final String badgeLabel = _getBadgeLabel(
                  kategoriLower,
                  namaBank,
                  ewalletProvider,
                  namaMetode,
                  deskripsi,
                );
                final String accountInfo = _getAccountInfo(
                  kategoriLower,
                  accountNumber,
                  accountHolder,
                  phoneNumber,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isFirst) ...[
                      const Divider(height: 20, color: Color(0xFFEEEEEE)),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Badge metode
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    logoPath,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    isAntiAlias: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      badgeLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: AppFont.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Nominal rata kanan; deposit kiloan memakai satuan Kg.
                        Text(
                          isKiloanDeposit
                              ? '${formatCompactQuantity(depositUsageAmount)} Kg'
                              : 'Rp ${AppHelpers.formatNumber(jumlah.toInt())}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (tanggal != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          AppHelpers.formatDate(tanggal),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                    if (kategoriLower == 'deposit' &&
                        depositBalanceAfter != null) ...[
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          isKiloanDeposit
                              ? 'Sisa deposit ${formatCompactQuantity(depositBalanceAfter)} Kg'
                              : 'Sisa deposit Rp ${AppHelpers.formatNumber(depositBalanceAfter.toInt())}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ),
                    ],
                    if (accountInfo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        accountInfo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: AppFont.w400,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  bool _hasPaymentInfo(Map<String, dynamic> entry) {
    final metodePembayaran =
        entry['metode_pembayaran'] as Map<String, dynamic>? ??
        entry['payment_method'] as Map<String, dynamic>?;
    final namaMetode = entry['nama_metode']?.toString().trim() ?? '';
    final kategori = entry['kategori']?.toString().trim() ?? '';
    final amount = entry['jumlah_dp'] ?? entry['amount'];
    final parsedAmount = amount is num
        ? amount.toDouble()
        : double.tryParse('$amount') ?? 0.0;

    return metodePembayaran != null ||
        namaMetode.isNotEmpty ||
        kategori.isNotEmpty ||
        parsedAmount > 0;
  }

  String _getBadgeLabel(
    String category,
    String? bankName,
    String? ewalletProvider,
    String namaMetode,
    String deskripsi,
  ) {
    if (category == 'deposit') {
      return namaMetode.toLowerCase().contains('kg') ||
              namaMetode.toLowerCase().contains('kiloan')
          ? 'Deposit Kiloan'
          : 'Deposit Rupiah';
    }
    if (category == 'qris') {
      final qrisIdentity = '$namaMetode $deskripsi'.toLowerCase();
      return qrisIdentity.contains('nobu') ? 'QRIS Nobu' : 'QRIS Outlet';
    }
    if (namaMetode.trim().isNotEmpty) return namaMetode.trim();
    if (category == 'cash') return 'Tunai / Cash';
    if (category == 'transfer') return bankName ?? 'Transfer';
    if (category == 'e-wallet') return ewalletProvider ?? 'E-Wallet';
    return namaMetode;
  }

  String _getAccountInfo(
    String category,
    String? accountNumber,
    String? accountHolder,
    String? phoneNumber,
  ) {
    if (category == 'transfer') {
      if (accountNumber != null && accountHolder != null) {
        return '$accountNumber a/n $accountHolder';
      }
      return accountNumber ?? '';
    }
    if (category == 'e-wallet' && phoneNumber != null) {
      return phoneNumber;
    }
    return '';
  }
}
