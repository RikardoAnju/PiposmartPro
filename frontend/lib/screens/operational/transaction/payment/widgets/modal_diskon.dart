import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/settings/diskon/diskon_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/diskon_provider.dart';
import 'package:ayocucinew/data/models/diskon_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DiscountModal extends StatefulWidget {
  final ScrollController? scrollController;

  const DiscountModal({super.key, this.scrollController});

  @override
  State<DiscountModal> createState() => _DiscountModalState();
}

class _DiscountModalState extends State<DiscountModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiskonProvider>().fetchDiscounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    // Ambil bottom inset sekali di sini agar tidak perlu MediaQuery di dalam Consumer
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Consumer2<TransactionProvider, DiskonProvider>(
      builder: (context, transactionProvider, diskonProvider, _) {
        final selectedDiskon = transactionProvider.selectedDiskon;
        final discounts = diskonProvider.discounts;
        final isLoading = diskonProvider.isLoading;

        // Filter hanya diskon aktif & berlaku hari ini (mendukung diskon
        // berulang per hari, mis. "Jumat Berkah").
        final activeDiscounts = discounts.where((d) {
          if (d.status != 1) return false;
          final now = DateTime.now();
          if (d.isRecurring) {
            return d.hari.contains(now.weekday);
          }
          return now.isAfter(d.tanggalMulai) &&
              now.isBefore(d.tanggalAkhir.add(const Duration(days: 1)));
        }).toList();

        final hasContent = isLoading || activeDiscounts.isNotEmpty;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // ── Handle bar ──────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Pilih Diskon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppFont.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Divider hanya saat ada konten ───────
              if (hasContent) const Divider(height: 1),

              // ── Body ────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(
                        child: AppCircularLoader(color: AppPalette.primary),
                      )
                    : activeDiscounts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.discount_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada diskon',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: AppFont.w600,
                                color: Color(0xFF999999),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tambahkan diskon baru lewat tombol di bawah',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFBBBBBB),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount:
                            activeDiscounts.length +
                            (selectedDiskon != null ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          if (selectedDiskon != null && index == 0) {
                            return _buildNoDiscountItem(transactionProvider);
                          }
                          final discountIndex = selectedDiskon != null
                              ? index - 1
                              : index;
                          final discount = activeDiscounts[discountIndex];
                          final isSelected = selectedDiskon?.id == discount.id;
                          return _buildDiscountItem(
                            discount,
                            isSelected,
                            currencyFormatter,
                            transactionProvider,
                          );
                        },
                      ),
              ),

              // ── Divider atas tombol ──────────────────
              const Divider(height: 1),

              // ── Tombol Tambah Diskon ─────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DiskonFormScreen(),
                          ),
                        );
                        if (result == true) {
                          if (!mounted) return;
                          final safeContext = context;
                          if (!safeContext.mounted) return;
                          safeContext.read<DiskonProvider>().fetchDiscounts();
                        }
                      },
                      icon: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Tambah Diskon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: AppFont.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDiscountItem(TransactionProvider provider) {
    return InkWell(
      onTap: () {
        provider.selectDiskon(null);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tidak Pakai Diskon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFont.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lanjutkan tanpa diskon',
                    style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Pilih',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: AppFont.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountItem(
    Diskon discount,
    bool isSelected,
    NumberFormat formatter,
    TransactionProvider provider,
  ) {
    return InkWell(
      onTap: () {
        provider.selectDiskon(isSelected ? null : discount);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discount.nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: AppFont.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDiscountDescription(discount, formatter),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppPalette.primary.withValues(alpha: 0.12)
                    : AppPalette.primary,
                borderRadius: BorderRadius.circular(999),
                border: isSelected
                    ? Border.all(color: AppPalette.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                isSelected ? 'Terpilih' : 'Pilih',
                style: TextStyle(
                  color: isSelected ? AppPalette.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: AppFont.w600,
                ),
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  String _getDiscountDescription(Diskon discount, NumberFormat formatter) {
    if (discount.tipe.toLowerCase() == 'persen') {
      return 'Potongan: ${discount.formattedPercentage} / Transaksi';
    }
    return 'Potongan: ${formatter.format(discount.nilai)} / Transaksi';
  }
}

void showDiscountModal(
  BuildContext context, {
  required Function(Diskon?) onDiscountSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) =>
          DiscountModal(scrollController: scrollController),
    ),
  );
}
