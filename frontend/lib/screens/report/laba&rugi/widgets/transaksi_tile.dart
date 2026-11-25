import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransaksiTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback? onTap;

  const TransaksiTile({super.key, required this.row, this.onTap});

  String _formatDate(String dateStr) {
    try {
      final raw = dateStr.contains('T') ? dateStr.split('T').first : dateStr;
      final parts = raw.split('-');
      if (parts.length != 3) return dateStr;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      return DateFormat('EEEE, dd/MM/yy', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value.abs());
  }

  @override
  Widget build(BuildContext context) {
    final rawDate = row['tanggal']?.toString() ?? '';
    final tanggal = _formatDate(rawDate);
    final pendapatan = (row['pendapatan'] ?? 0).toDouble();
    final pengeluaran = (row['pengeluaran'] ?? 0).toDouble();
    final labaRugi = (row['labaRugi'] ?? 0).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.018),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tanggal,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFont.w600,
                      color: AppPalette.ink.withValues(alpha: 0.78),
                      height: 1.2,
                    ),
                  ),
                ),
                if (onTap != null) ...const [
                  SizedBox(width: 8),
                  Text(
                    'Rincian',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 10.5,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppPalette.muted,
                    size: 15,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pendapatan
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pendapatan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w600,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+ ${_formatCurrency(pendapatan)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF27AE60),
                      ),
                    ),
                  ],
                ),

                // Pengeluaran
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Pengeluaran',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w600,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(pengeluaran)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                        color: AppPalette.danger,
                      ),
                    ),
                  ],
                ),

                // Laba/Rugi
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Laba/Rugi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w600,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${labaRugi >= 0 ? '+ ' : '- '}${_formatCurrency(labaRugi)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                        color: labaRugi >= 0
                            ? const Color(0xFF27AE60)
                            : AppPalette.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
