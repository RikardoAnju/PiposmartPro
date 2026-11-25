import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PayoutNominalInput extends StatelessWidget {
  final TextEditingController controller;
  final int availableBalance;
  final int minAmount;
  final int maxAmount;
  final List<int> quickAmounts;
  final ValueChanged<int> onQuickSelect;

  const PayoutNominalInput({
    super.key,
    required this.controller,
    required this.availableBalance,
    required this.minAmount,
    required this.maxAmount,

    this.quickAmounts = const [100000, 200000, 500000, 1000000],
    required this.onQuickSelect,
  });

  String _fmtRp(int v) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final upperLimit = maxAmount > 0 && maxAmount < availableBalance
        ? maxAmount
        : availableBalance;
    final validChips = quickAmounts
        .where((a) => a >= minAmount && a <= upperLimit)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: 'Nominal saldo yang akan dicairkan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFont.w600,
              color: Colors.black87,
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppPalette.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            final formatted = CurrencyFormatter.formatInputToRupiah(value);
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          },
          style: const TextStyle(
            fontSize: 15,
            fontWeight: AppFont.w600,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
              fontSize: 15,
              fontWeight: AppFont.w700,
              color: Colors.black87,
            ),
            hintText: NumberFormat.decimalPattern('id_ID').format(minAmount),
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppPalette.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // ✅ Info saldo tersedia
        Text(
          'Saldo tersedia: ${_fmtRp(availableBalance)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),

        // ✅ Chip hanya muncul jika ada yang lolos filter saldo
        if (validChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: validChips
                .map(
                  (a) => GestureDetector(
                    onTap: () => onQuickSelect(a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _fmtRp(a),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: AppFont.w600,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],

        // ✅ Pesan jika saldo tidak cukup untuk nominal minimum
        if (availableBalance < minAmount) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Saldo minimum pencairan adalah ${_fmtRp(minAmount)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
        if (maxAmount > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Maksimal pencairan per request adalah ${_fmtRp(maxAmount)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
