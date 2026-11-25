import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_helpers.dart';

class StatusPembayaranWidget extends StatelessWidget {
  const StatusPembayaranWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final trx = provider.currentDetail;
        if (trx == null) return const SizedBox.shrink();

        final isLunas = trx.paymentStatus == 'Lunas';

        final hargaPesanan = (trx.totalKotor - trx.jemputBiaya - trx.antarBiaya).clamp(0, double.infinity);
        final potonganDiskon = trx.potonganDiskon;
        final roundingAmount = trx.roundingAmount;
        final totalAkhir = trx.totalPrice;

        final dpAmount = trx.dpAmount;
        final sisaBayar = trx.sisaBayar ?? (totalAkhir - dpAmount);
        final hasOutstandingOrChange = !isLunas || sisaBayar.abs() > 0.009;

        final hasDiskon = potonganDiskon > 0;
        final hasRounding = roundingAmount != 0;
        final hasDP = dpAmount > 0;

        final hasJemput = trx.jemputBiaya > 0;
        final hasAntar = trx.antarBiaya > 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rincian Pembayaran',
                      style: TextStyle(fontSize: 13, fontWeight: AppFont.w800, color: Color(0xFF1A1A2E)),
                    ),
                    _StatusBadge(status: trx.paymentStatus, isLunas: isLunas),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              _SummaryRow(label: 'Harga Pesanan', value: 'Rp ${AppHelpers.formatNumber(hargaPesanan.toInt())}'),

              if (hasJemput)
                _SummaryRow(
                  label: 'Biaya Jemput',
                  value: 'Rp ${AppHelpers.formatNumber(trx.jemputBiaya.toInt())}',
                  valueColor: Colors.blue,
                ),

              if (hasAntar)
                _SummaryRow(
                  label: 'Biaya Antar',
                  value: 'Rp ${AppHelpers.formatNumber(trx.antarBiaya.toInt())}',
                  valueColor: Colors.deepPurple,
                ),

              if (hasDiskon)
                _SummaryRow(
                  label: trx.diskon?.isPercentage == true
                      ? 'Potongan Diskon (${trx.diskon!.formattedPercentage})'
                      : 'Potongan Diskon',
                  value: '- Rp ${AppHelpers.formatNumber(potonganDiskon.toInt())}',
                  valueColor: Colors.green,
                ),

              if (hasRounding)
                _SummaryRow(
                  label: 'Pembulatan',
                  value:
                      '${roundingAmount > 0 ? "+ " : "- "}Rp ${AppHelpers.formatNumber(roundingAmount.abs().toInt())}',
                  valueColor: Colors.blueGrey,
                ),

              const Divider(height: 1, color: AppColors.border),

              _SummaryRow(
                label: 'Total Tagihan',
                value: 'Rp ${AppHelpers.formatNumber(totalAkhir.toInt())}',
                labelBold: true,
                valueFontSize: 16,
                valueColor: AppColors.primary,
              ),

              if (hasDP) ...[
                const Divider(height: 1, color: AppColors.border),
                _SummaryRow(
                  label: isLunas ? 'Telah Dibayar' : 'DP Dibayar',
                  value: '- Rp ${AppHelpers.formatNumber(dpAmount.toInt())}',
                  valueColor: Colors.green,
                ),
                if (hasOutstandingOrChange) ...[
                  const Divider(height: 1, color: AppColors.border),
                  _SummaryRow(
                    label: isLunas ? 'Kembalian' : 'Sisa Tagihan',
                    value: 'Rp ${AppHelpers.formatNumber(sisaBayar.abs().toInt())}',
                    valueColor: isLunas ? Colors.blue : AppColors.primary,
                    labelBold: true,
                    valueFontSize: 14,
                    highlight: !isLunas,
                  ),
                ],
              ],
              if (!hasDP && !isLunas && totalAkhir > 0) ...[
                const Divider(height: 1, color: AppColors.border),
                _SummaryRow(
                  label: 'Sisa Tagihan',
                  value: 'Rp ${AppHelpers.formatNumber(totalAkhir.toInt())}',
                  valueColor: AppColors.primary,
                  labelBold: true,
                  valueFontSize: 14,
                  highlight: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isLunas;

  const _StatusBadge({required this.status, required this.isLunas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLunas ? AppColors.greenSoft : AppColors.redSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: AppFont.w800,
          color: isLunas ? AppColors.green : AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool labelBold;
  final double valueFontSize;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelBold = false,
    this.valueFontSize = 13,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: highlight ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: labelBold ? AppFont.w700 : AppFont.w500,
                color: labelBold ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: AppFont.w800,
                color: valueColor ?? (labelBold ? Colors.black : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
