import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutAccountSelector extends StatelessWidget {
  final ReferralPayoutAccountModel? selectedAccount;
  final VoidCallback onTap;

  const PayoutAccountSelector({
    super.key,
    required this.selectedAccount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: 'Rekening Tujuan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFont.w600,
              color: Colors.black87,
            ),
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(color: AppPalette.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: selectedAccount != null
                    ? AppPalette.primary
                    : Colors.grey.shade300,
                width: selectedAccount != null ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (selectedAccount != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppPalette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAccount!.bankName,
                          style: const TextStyle(
                            fontWeight: AppFont.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          selectedAccount!.accountNumber,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      'Pilih rekening tujuan',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
