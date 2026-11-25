import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DetailPengeluaranTile extends StatelessWidget {
  final int jumlahPengeluaran;
  final String tanggal;
  final String tanggalRaw;
  final double totalJumlah;
  final VoidCallback? onLihatDetail;

  const DetailPengeluaranTile({
    super.key,
    required this.jumlahPengeluaran,
    required this.tanggal,
    required this.tanggalRaw,
    required this.totalJumlah,
    this.onLihatDetail,
  });

  bool _isToday(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final now = DateTime.now();
      final dateOnly = dateStr.contains('T')
          ? dateStr.split('T').first
          : dateStr;
      final parts = dateOnly.split('-');
      if (parts.length != 3) return false;
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final today = _isToday(tanggalRaw);

    return Container(
      decoration: AppDecorations.card(
        radius: 18,
        border: today
            ? Border.all(
                color: AppPalette.primary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : AppBorders.card,
        shadow: today ? AppShadows.card : AppShadows.cardSoft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            if (today)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: AppPalette.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'HARI INI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: AppFont.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLihatDetail,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppPalette.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tanggal,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: today
                                    ? AppFont.w800
                                    : AppFont.w600,
                                color: today
                                    ? AppPalette.primary
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$jumlahPengeluaran transaksi',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: AppFont.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                formatter.format(totalJumlah),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: AppFont.w900,
                                  color: AppPalette.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Color(0xFFD0D0D0),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
