import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/unit_label.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionSummarySection extends StatefulWidget {
  final List cartItems;

  const TransactionSummarySection({super.key, required this.cartItems});

  @override
  State<TransactionSummarySection> createState() =>
      _TransactionSummarySectionState();
}

class _TransactionSummarySectionState extends State<TransactionSummarySection> {
  bool showDetail = false;
  static const _animDuration = Duration(milliseconds: 250);
  static const _animCurve = Curves.easeInOutCubic;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => showDetail = !showDetail),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ringkasan Transaksi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFont.w600,
                    color: Colors.black87,
                  ),
                ),
                AnimatedRotation(
                  turns: showDetail ? 0.5 : 0,
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

          ClipRect(
            child: AnimatedSize(
              duration: _animDuration,
              curve: _animCurve,
              alignment: Alignment.topCenter,
              child: showDetail
                  ? Column(
                      children: [
                        const SizedBox(height: 14),
                        ...widget.cartItems.asMap().entries.map((entry) {
                          final item = entry.value;
                          final qty = item.qty % 1 == 0
                              ? item.qty.toInt()
                              : item.qty;

                          return _buildSummaryItem(item, qty);
                        }),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(dynamic item, dynamic qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFAFAFAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              item.iconPath,
              width: 28,
              height: 28,
              errorBuilder: (c, e, s) => const Icon(
                Icons.local_laundry_service,
                size: 28,
                color: AppPalette.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Nama kategori (bold)
                Text(
                  item.categoryName,
                  style: const TextStyle(
                    fontWeight: AppFont.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Baris 2: Nama layanan (abu-abu kecil)
                Text(
                  item.serviceName,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: AppFont.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Baris 3: Qty x Harga
                Text(
                  '$qty ${displayUnitLabel(item.unit)} x ${currencyFormatter.format(item.price)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),

          // Harga & Durasi
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(item.subtotal),
                style: const TextStyle(
                  fontWeight: AppFont.w700,
                  fontSize: 14,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.duration} ${item.durationUnit}',
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontSize: 10,
                    fontWeight: AppFont.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
