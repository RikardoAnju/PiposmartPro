import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PaymentStatusSection extends StatefulWidget {
  const PaymentStatusSection({super.key});

  @override
  State<PaymentStatusSection> createState() => _PaymentStatusSectionState();
}

class _PaymentStatusSectionState extends State<PaymentStatusSection> {
  String selectedStatus = 'Belum Lunas';
  bool payWithDP = false;
  final TextEditingController dpController = TextEditingController();
  final FocusNode _dpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    dpController.addListener(_syncDPAmountFromController);
    final provider = context.read<TransactionProvider>();

    if (provider.isLunasMode) {
      selectedStatus = 'Lunas';
      payWithDP = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setPayWithDP(false);
      });
      return;
    }

    selectedStatus = 'Belum Lunas';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.selectedCustomer != null) {
        provider.setPendingOrder(dpAmount: 0.0, isPaid: false);
      }
    });
  }

  @override
  void dispose() {
    dpController.removeListener(_syncDPAmountFromController);
    dpController.dispose();
    _dpFocusNode.dispose();
    super.dispose();
  }

  void _syncDPAmountFromController() {
    _updateDPAmount(dpController.text);
  }

  bool _isDpAboveGrandTotal(TransactionProvider provider) {
    if (!payWithDP || selectedStatus != 'Belum Lunas') return false;
    final dpAmount = CurrencyFormatter.parseRupiahToDouble(dpController.text);
    return dpAmount > provider.grandTotal;
  }

  void _updateDPAmount(String rawValue) {
    if (payWithDP && selectedStatus == 'Belum Lunas') {
      double dpAmount = CurrencyFormatter.parseRupiahToDouble(rawValue);
      final provider = context.read<TransactionProvider>();

      provider.setPendingOrder(dpAmount: dpAmount, isPaid: false);
    }
  }

  void _setPayWithDp(bool value, TransactionProvider provider) {
    setState(() {
      payWithDP = value;
      if (!payWithDP) {
        dpController.clear();
      }
    });
    provider.setPayWithDP(value);
    if (!value) {
      provider.setPendingOrder(
        dpAmount: 0.0,
        isPaid: false,
      );
      provider.clearPaymentMethod();
    }
  }

  bool get canSelectPaymentMethod {
    if (selectedStatus == 'Lunas') return true;
    if (selectedStatus == 'Belum Lunas' && payWithDP) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final isFromDetail = provider.isLunasMode;
    final isDpInvalid = _isDpAboveGrandTotal(provider);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Pembayaran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaymentStatusButton(
                  text: 'Lunas',
                  isSelected: selectedStatus == 'Lunas',
                  isDisabled: !isFromDetail && payWithDP,
                  isLocked: isFromDetail,
                  onTap: isFromDetail || payWithDP
                      ? () {}
                      : () {
                          setState(() {
                            selectedStatus = 'Lunas';
                            payWithDP = false;
                            dpController.clear();
                          });
                          provider.setPayWithDP(false);
                          provider.setPendingOrder(dpAmount: 0.0, isPaid: true);
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentStatusButton(
                  text: 'Belum Lunas',
                  isSelected: selectedStatus == 'Belum Lunas',
                  isDisabled: isFromDetail,
                  isLocked: isFromDetail,
                  onTap: isFromDetail
                      ? () {}
                      : () {
                          setState(() {
                            selectedStatus = 'Belum Lunas';
                            payWithDP = false;
                            dpController.clear();
                          });
                          provider.setPayWithDP(false);
                          provider.setPendingOrder(
                            dpAmount: 0.0,
                            isPaid: false,
                          );
                          provider.clearPaymentMethod();
                        },
                ),
              ),
            ],
          ),
          if (!isFromDetail) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: selectedStatus == 'Belum Lunas'
                    ? () => _setPayWithDp(!payWithDP, provider)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IgnorePointer(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: payWithDP,
                            onChanged: (_) {},
                            activeColor: AppPalette.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bayar DP (Down Payment)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.w500,
                            color: selectedStatus == 'Belum Lunas'
                                ? Colors.black87
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: payWithDP && selectedStatus == 'Belum Lunas'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        const Text(
                          'Nominal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: dpController,
                          focusNode: _dpFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          onChanged: _updateDPAmount,
                          onTapOutside: (_) => _dpFocusNode.unfocus(),
                          autofocus: false,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nominal DP',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            prefixText: 'Rp ',
                            prefixStyle: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: AppFont.w500,
                            ),
                            suffixText:
                                'Max: ${CurrencyFormatter.formatToRupiah(provider.grandTotal)}',
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDpInvalid
                                    ? const Color(0xFFF3C7C7)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDpInvalid
                                    ? const Color(0xFFE57373)
                                    : AppPalette.primary,
                                width: 1.5,
                              ),
                            ),
                            errorText: isDpInvalid
                                ? 'Nominal DP tidak boleh melebihi total transaksi'
                                : null,
                            errorStyle: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE57373),
                              fontWeight: AppFont.w500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> getPaymentData() {
    return {
      'status': selectedStatus,
      'payWithDP': payWithDP,
      'dpAmount': payWithDP
          ? CurrencyFormatter.parseRupiahToDouble(dpController.text)
          : 0.0,
      'canSelectPaymentMethod': canSelectPaymentMethod,
    };
  }
}

class _PaymentStatusButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isLocked;

  const _PaymentStatusButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool showDisabledStyle = isLocked ? !isSelected : isDisabled;

    return GestureDetector(
      onTap: (isDisabled || isLocked) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: showDisabledStyle
              ? Colors.grey.shade200
              : (isSelected ? AppPalette.primary : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: showDisabledStyle
                ? Colors.grey.shade300
                : (isSelected ? AppPalette.primary : Colors.grey.shade300),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFont.w600,
              color: showDisabledStyle
                  ? Colors.grey.shade400
                  : (isSelected ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final formatted = CurrencyFormatter.formatInputToRupiah(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
