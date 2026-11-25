import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PaymentInfoSection extends StatefulWidget {
  const PaymentInfoSection({super.key});

  @override
  State<PaymentInfoSection> createState() => _PaymentInfoSectionState();
}

class _PaymentInfoSectionState extends State<PaymentInfoSection> {
  bool showInfo = true;
  static const _animDuration = Duration(milliseconds: 250);
  static const _animCurve = Curves.easeInOutCubic;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final isLunas = provider.isLunasMode;
    final subtotal = provider.subtotal;
    final discountAmount = isLunas
        ? provider.discountAmountFromDetail
        : provider.discountAmount;
    final selectedDiscount = isLunas ? null : provider.selectedDiskon;
    final displayedRoundingAmount = isLunas
        ? (provider.pendingOrder?['rounding_amount'] as num?)?.toDouble() ?? 0.0
        : provider.roundingAmount;

    // FIX: selalu pakai getter yang sudah reaktif terhadap perubahan _jemputAntar
    final jemputBiaya = provider.jemputBiayaDisplay;
    final antarBiaya = provider.antarBiayaDisplay;
    final totalJemputAntar = jemputBiaya + antarBiaya;

    final dpAmount = isLunas ? provider.dpAmountFromDetail : provider.dpAmount;
    final grandTotal = provider.grandTotal;

    // FIX: mode pelunasan pakai totalToPay (sudah ikut perubahan jemput/antar baru)
    // bukan sisaBayarFromDetail yang nilainya statis dari nota lama
    final remainingPayment = isLunas
        ? provider.totalToPay
        : grandTotal - dpAmount;

    // Label total menyesuaikan mode
    final totalLabel = isLunas ? 'Total Pelunasan' : 'Total';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
        children: [
          InkWell(
            onTap: () => setState(() => showInfo = !showInfo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Informasi Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w600,
                      color: Colors.black87,
                    ),
                  ),
                  AnimatedRotation(
                    turns: showInfo ? 0.5 : 0,
                    duration: _animDuration,
                    curve: _animCurve,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: _animDuration,
              curve: _animCurve,
              alignment: Alignment.topCenter,
              child: showInfo
                  ? Column(
                      children: [
                        const _SubtleDivider(horizontalPadding: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          child: Column(
                            children: [
                              _PaymentRow(
                                label: 'Subtotal',
                                value: currencyFormatter.format(subtotal),
                              ),

                              if (discountAmount > 0) ...[
                                const SizedBox(height: 10),
                                _PaymentRow(
                                  label: selectedDiscount?.isPercentage == true
                                      ? selectedDiscount!.paymentLabel
                                      : 'Diskon',
                                  value:
                                      '- ${currencyFormatter.format(discountAmount)}',
                                  isGreen: true,
                                ),
                              ],

                              if (displayedRoundingAmount != 0) ...[
                                const SizedBox(height: 10),
                                _PaymentRow(
                                  label: 'Pembulatan',
                                  value:
                                      '${displayedRoundingAmount > 0 ? '+ ' : '- '}${currencyFormatter.format(displayedRoundingAmount.abs())}',
                                ),
                              ],

                              // FIX: section ini sekarang reaktif —
                              // muncul/hilang otomatis saat kasir toggle jemput/antar
                              if (totalJemputAntar > 0) ...[
                                const SizedBox(height: 14),
                                const _SubtleDivider(),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppPalette.primarySoft,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_rounded,
                                        color: AppPalette.primary,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Jemput & Antar',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: AppFont.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (jemputBiaya > 0) ...[
                                  const SizedBox(height: 10),
                                  _PaymentRow(
                                    label: 'Biaya Jemput',
                                    value: currencyFormatter.format(
                                      jemputBiaya,
                                    ),
                                    isIndented: true,
                                  ),
                                ],
                                if (antarBiaya > 0) ...[
                                  const SizedBox(height: 10),
                                  _PaymentRow(
                                    label: 'Biaya Antar',
                                    value: currencyFormatter.format(antarBiaya),
                                    isIndented: true,
                                  ),
                                ],
                              ],

                              const SizedBox(height: 14),
                              const _SubtleDivider(),
                              const SizedBox(height: 14),

                              // Mode pelunasan: tampilkan total pelunasan langsung (tanpa baris DP)
                              if (isLunas) ...[
                                _PaymentRow(
                                  label: totalLabel,
                                  value: currencyFormatter.format(
                                    remainingPayment,
                                  ),
                                  isBold: true,
                                ),
                              ] else ...[
                                _PaymentRow(
                                  label: totalLabel,
                                  value: currencyFormatter.format(grandTotal),
                                  isBold: true,
                                ),
                                if (dpAmount > 0) ...[
                                  const SizedBox(height: 14),
                                  const _SubtleDivider(),
                                  const SizedBox(height: 14),
                                  _PaymentRow(
                                    label: 'DP Dibayar',
                                    value:
                                        '- ${currencyFormatter.format(dpAmount)}',
                                    isOrange: true,
                                  ),
                                  const SizedBox(height: 10),
                                  _PaymentRow(
                                    label: 'Sisa Pembayaran',
                                    value: currencyFormatter.format(
                                      remainingPayment,
                                    ),
                                    isBold: true,
                                    isRed: true,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGreen;
  final bool isRed;
  final bool isOrange;
  final bool isIndented;

  const _PaymentRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isGreen = false,
    this.isRed = false,
    this.isOrange = false,
    this.isIndented = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = AppPalette.primary;
    if (isGreen) valueColor = Colors.green.shade600;
    if (isRed || isOrange) valueColor = AppPalette.primary;

    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 30.0 : 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isIndented ? 13 : 14,
              fontWeight: isBold ? AppFont.w600 : AppFont.w400,
              color: isIndented ? Colors.grey.shade600 : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isIndented ? 13 : 14,
              fontWeight: isBold ? AppFont.w600 : AppFont.w500,
              color: value.contains('Rp')
                  ? AppPalette.primary
                  : (isIndented ? Colors.grey.shade700 : valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtleDivider extends StatelessWidget {
  final double horizontalPadding;

  const _SubtleDivider({this.horizontalPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(height: 1, color: const Color(0xFFF0E6E3)),
    );
  }
}
