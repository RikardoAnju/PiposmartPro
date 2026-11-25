import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutConfirmationSheet extends StatelessWidget {
  final int amount;
  final ReferralPayoutAccountModel account;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PayoutConfirmationSheet({
    super.key,
    required this.amount,
    required this.account,
    required this.isLoading,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required int amount,
    required ReferralPayoutAccountModel account,
    required bool isLoading,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isLoading,
      builder: (ctx) => PayoutConfirmationSheet(
        amount: amount,
        account: account,
        isLoading: isLoading,
        onConfirm: onConfirm,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  String get _fmtAmount => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    'assets/icons/ic_dollar.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfirmasi Pencairan',
                    style: TextStyle(
                      fontWeight: AppFont.w700,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Cairkan bonus referral terpilih',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jumlah Pencairan',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      _fmtAmount,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/icons/icon_bank.webp',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekening Tujuan',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${account.bankName} - ${account.accountNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: AppFont.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'a.n. ${account.accountName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppPalette.warning,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan data sudah benar. Proses ini tidak dapat dibatalkan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF795548),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Cairkan Sekarang',
                      style: TextStyle(
                        fontWeight: AppFont.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: isLoading ? null : onCancel,
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
