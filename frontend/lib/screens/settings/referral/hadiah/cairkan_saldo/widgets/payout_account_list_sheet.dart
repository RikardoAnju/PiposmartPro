import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutAccountListSheet extends StatelessWidget {
  final List<ReferralPayoutAccountModel> accounts;
  final ReferralPayoutAccountModel? selected;
  final ValueChanged<ReferralPayoutAccountModel> onSelect;
  final VoidCallback onAddNew;
  final ValueChanged<ReferralPayoutAccountModel> onEdit;

  const PayoutAccountListSheet({
    super.key,
    required this.accounts,
    required this.selected,
    required this.onSelect,
    required this.onAddNew,
    required this.onEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ReferralPayoutAccountModel> accounts,
    required ReferralPayoutAccountModel? selected,
    required ValueChanged<ReferralPayoutAccountModel> onSelect,
    required VoidCallback onAddNew,
    required ValueChanged<ReferralPayoutAccountModel> onEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayoutAccountListSheet(
        accounts: accounts,
        selected: selected,
        onSelect: onSelect,
        onAddNew: onAddNew,
        onEdit: onEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            if (accounts.length >= 3)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2196F3),
                      size: 16,
                    ),

                    const SizedBox(width: 8),

                    const Expanded(
                      child: Text(
                        'Hanya dapat menyimpan 3 rekening/e-wallet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...accounts.map(
                      (acc) => _AccountTile(
                        account: acc,
                        isSelected: selected?.id == acc.id,
                        onTap: () {
                          onSelect(acc);
                          Navigator.of(context).pop();
                        },
                        onEdit: () {
                          Navigator.of(context).pop();
                          onEdit(acc);
                        },
                      ),
                    ),

                    if (accounts.length < 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            onAddNew();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.grey,
                                  size: 20,
                                ),

                                SizedBox(width: 8),

                                Text(
                                  'Tambah Rekening',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final ReferralPayoutAccountModel account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AccountTile({
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppPalette.primary : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Radio<bool>(
            value: true,
            groupValue: isSelected,
            onChanged: (_) => onTap(),
            activeColor: AppPalette.primary,
          ),
          title: Text(
            account.bankName,
            style: const TextStyle(fontWeight: AppFont.w600, fontSize: 14),
          ),
          subtitle: Text(
            account.accountNumber,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: TextButton(
            onPressed: onEdit,
            child: const Text(
              'Edit',
              style: TextStyle(
                color: AppPalette.primary,
                fontWeight: AppFont.w600,
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
