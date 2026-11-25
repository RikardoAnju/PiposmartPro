import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/modal_diskon.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/diskon_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DiscountSection extends StatelessWidget {
  const DiscountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        // ✅ Sembunyikan diskon jika mode pelunasan
        if (provider.isLunasMode) return const SizedBox.shrink();

        final selectedDiscount = provider.selectedDiskon;
        final discountAmount = provider.discountAmount;
        final bool hasDiscount = discountAmount > 0 || selectedDiscount != null;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              final transactionProvider = Provider.of<TransactionProvider>(
                context,
                listen: false,
              );
              final diskonProvider = Provider.of<DiskonProvider>(
                context,
                listen: false,
              );

              diskonProvider.fetchDiscounts();

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: transactionProvider),
                    ChangeNotifierProvider.value(value: diskonProvider),
                  ],
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.52,
                    minChildSize: 0.4,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (_, scrollController) =>
                        DiscountModal(scrollController: scrollController),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasDiscount
                        ? AppPalette.primary.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.discount_outlined,
                    size: 22,
                    color: hasDiscount
                        ? AppPalette.primary
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasDiscount
                            ? (selectedDiscount?.nama ?? 'Diskon Terpilih')
                            : 'Pilih Diskon',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: AppFont.w600,
                          color: hasDiscount ? Colors.black87 : Colors.black54,
                        ),
                      ),
                      if (hasDiscount && selectedDiscount != null) ...[
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            return Text(
                              selectedDiscount.tipe.toLowerCase() == 'persen'
                                  ? 'Potongan ${selectedDiscount.formattedPercentage}'
                                  : 'Potongan ${currencyFormatter.format(selectedDiscount.nilai)}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    selectedDiscount.tipe.toLowerCase() ==
                                        'persen'
                                    ? Colors.grey.shade600
                                    : AppPalette.primary,
                                fontWeight:
                                    selectedDiscount.tipe.toLowerCase() ==
                                        'persen'
                                    ? AppFont.w500
                                    : AppFont.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasDiscount && discountAmount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-${currencyFormatter.format(discountAmount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.primary,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
