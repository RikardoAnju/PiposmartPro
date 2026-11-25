import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class NominalInputSection extends StatefulWidget {
  final TextEditingController controller;
  final int minNominal;
  final List<int> quickAmounts;
  final ValueChanged<int> onQuickSelect;

  const NominalInputSection({
    super.key,
    required this.controller,
    this.minNominal = 25000,
    this.quickAmounts = const [25000, 50000, 100000, 200000],
    required this.onQuickSelect,
  });

  @override
  State<NominalInputSection> createState() => _NominalInputSectionState();
}

class _NominalInputSectionState extends State<NominalInputSection> {
  static const Color kPrimary = AppPalette.primary;

  int? selectedAmount;

  static final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Text(
                  'Rp',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Colors.black87,
                  ),
                ),
              ),

              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: AppFont.w500,
                  ),
                  onChanged: (value) {
                    setState(() => selectedAmount = null);

                    final formatted = CurrencyFormatter.formatInputToRupiah(
                      value,
                    );

                    widget.controller.value = TextEditingValue(
                      text: formatted.replaceAll('Rp ', ''),
                      selection: TextSelection.collapsed(
                        offset: formatted.replaceAll('Rp ', '').length,
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Minimal ${_fmt.format(widget.minNominal).replaceAll('Rp ', '')}',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.quickAmounts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 4.2,
          ),
          itemBuilder: (context, index) {
            final amount = widget.quickAmounts[index];
            final isSelected = selectedAmount == amount;

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: kPrimary.withValues(alpha: 0.12),
                highlightColor: kPrimary.withValues(alpha: 0.05),
                onTap: () {
                  setState(() {
                    selectedAmount = amount;
                  });

                  final formatted = CurrencyFormatter.formatInputToRupiah(
                    amount.toString(),
                  );

                  widget.controller.value = TextEditingValue(
                    text: formatted.replaceAll('Rp ', ''),
                    selection: TextSelection.collapsed(
                      offset: formatted.replaceAll('Rp ', '').length,
                    ),
                  );

                  widget.onQuickSelect(amount);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? kPrimary : Colors.grey.shade300,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimary.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: isSelected ? 0.97 : 1,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      child: Text(_fmt.format(amount)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
