import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CashCalculatorWidget extends StatefulWidget {
  final double grandTotal;
  final Function(double) onCashChanged;

  const CashCalculatorWidget({
    super.key,
    required this.grandTotal,
    required this.onCashChanged,
  });

  @override
  State<CashCalculatorWidget> createState() => _CashCalculatorWidgetState();
}

class _CashCalculatorWidgetState extends State<CashCalculatorWidget> {
  final TextEditingController _cashController = TextEditingController();
  int? _selectedQuickAmount;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _selectedQuickAmount = 0;
    _cashController.text = CurrencyFormatter.formatInputToRupiah(
      widget.grandTotal.toInt().toString(),
    );
    Future.microtask(() {
      if (mounted) widget.onCashChanged(widget.grandTotal);
    });
  }

  @override
  void didUpdateWidget(CashCalculatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grandTotal != widget.grandTotal &&
        _selectedQuickAmount == 0) {
      _cashController.text = CurrencyFormatter.formatInputToRupiah(
        widget.grandTotal.toInt().toString(),
      );
      widget.onCashChanged(widget.grandTotal);
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int index, double amount) {
    final actualAmount = index == 0 ? widget.grandTotal : amount;
    setState(() {
      _selectedQuickAmount = index;
      _showCustomInput = false;
      _cashController.text = CurrencyFormatter.formatInputToRupiah(
        actualAmount.toInt().toString(),
      );
    });
    widget.onCashChanged(actualAmount);
  }

  void _showCustomInputField() {
    setState(() {
      _selectedQuickAmount = null;
      _showCustomInput = true;
      _cashController.clear();
    });
    widget.onCashChanged(0);
  }

  Widget _buildQuickAmountButton({
    required int index,
    required double amount,
    required String label,
    bool isCustom = false,
  }) {
    final isSelected = isCustom
        ? _showCustomInput
        : _selectedQuickAmount == index;
    final displayAmount = index == 0 ? widget.grandTotal : amount;

    String displayLabel = label;
    if (!isCustom && label != 'Uang Pas') {
      displayLabel = CurrencyFormatter.formatToRupiah(
        displayAmount,
      ).replaceAll('Rp', '').trim();
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isCustom) {
            _showCustomInputField();
          } else {
            _selectQuickAmount(index, displayAmount);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppPalette.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppPalette.primary.withValues(alpha: 0.08)
                : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              displayLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w600,
                color: isSelected ? AppPalette.primary : Colors.grey.shade700,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildQuickAmountButton(
              index: 0,
              amount: widget.grandTotal,
              label: 'Uang Pas',
            ),
            const SizedBox(width: 8),
            _buildQuickAmountButton(index: 1, amount: 50000, label: '50.000'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickAmountButton(index: 2, amount: 100000, label: '100.000'),
            const SizedBox(width: 8),
            _buildQuickAmountButton(
              index: 3,
              amount: 0,
              label: 'Lainnya',
              isCustom: true,
            ),
          ],
        ),
        if (_showCustomInput) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _cashController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                final formatted = CurrencyFormatter.formatInputToRupiah(
                  newValue.text,
                );
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            decoration: InputDecoration(
              hintText: 'Contoh: 500.000',
              hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: AppFont.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w500,
              letterSpacing: 0.5,
            ),
            onChanged: (value) {
              final amount = CurrencyFormatter.parseRupiahToDouble(value);
              widget.onCashChanged(amount);
            },
          ),
        ],
      ],
    );
  }
}
