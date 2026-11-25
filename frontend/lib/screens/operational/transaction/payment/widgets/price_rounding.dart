import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/transaction_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RoundingSelector extends StatelessWidget {
  const RoundingSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        const roundingUnit = TransactionProvider.roundingUnit;
        bool isPelunasanPerluRounding =
            provider.isLunasMode && provider.canRoundInPelunasan;
        bool isOrderBaruPerluRounding = !provider.isLunasMode;

        if (provider.isLunasMode && !provider.canRoundInPelunasan) {
          return const SizedBox.shrink();
        }
        if (!isOrderBaruPerluRounding && !isPelunasanPerluRounding) {
          return const SizedBox.shrink();
        }

        // Ambil nilai dasar yang akan dibulatkan
        final totalToRound = provider.totalBeforeRounding;
        if (totalToRound <= 0) return const SizedBox.shrink();

        // Sembunyikan jika nominal sudah bulat (kelipatan 500)
        if (totalToRound % roundingUnit == 0) return const SizedBox.shrink();

        // Hitung opsi pembulatan
        final floorVal = (totalToRound / roundingUnit).floor() * roundingUnit;
        final ceilVal = (totalToRound / roundingUnit).ceil() * roundingUnit;

        final fmt = NumberFormat.currency(
          locale: 'id',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        final selectedFloor = provider.roundingMode == RoundingMode.floor;
        final selectedCeil = provider.roundingMode == RoundingMode.ceil;
        final noneSelected = provider.roundingMode == RoundingMode.none;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppPalette.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.isLunasMode
                        ? 'Bulatkan Sisa Bayar'
                        : 'Opsi Pembulatan Akhir',
                    style: const TextStyle(
                      fontWeight: AppFont.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    fmt.format(provider.grandTotal),
                    style: const TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 14,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip(
                      label: 'Normal',
                      selected: noneSelected,
                      onTap: () => provider.setRoundingMode(RoundingMode.none),
                    ),
                    const SizedBox(width: 10),
                    _buildChip(
                      label: fmt.format(floorVal),
                      selected: selectedFloor,
                      onTap: () => provider.setRoundingMode(RoundingMode.floor),
                    ),
                    const SizedBox(width: 10),
                    _buildChip(
                      label: fmt.format(ceilVal),
                      selected: selectedCeil,
                      onTap: () => provider.setRoundingMode(RoundingMode.ceil),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                provider.isLunasMode
                    ? "* Sisa tagihan asli: ${fmt.format(totalToRound)}"
                    : "* Total asli: ${fmt.format(totalToRound)}",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppPalette.primary : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? AppFont.w700 : AppFont.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
