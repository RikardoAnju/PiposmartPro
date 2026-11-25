import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LayananTableRow extends StatelessWidget {
  final TransaksiLayananItem item;
  final bool isEven;

  const LayananTableRow({super.key, required this.item, required this.isEven});

  void _showDetailBottomSheet(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Detail Layanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppFont.w900,
                color: Color(0xFF221918),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            // Gradient Card for Service Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppPalette.primary, AppPalette.primaryWarm],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaLayanan,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subLabel.isEmpty ? 'Layanan utama' : item.subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFont.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Pesanan',
                    '${item.totalPesanan}',
                    Icons.shopping_bag_rounded,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Quantity',
                    item.totalQty,
                    Icons.scale_rounded,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFullWidthStatCard(
              'Total Kontribusi Penjualan',
              currencyFormatter.format(item.totalHarga),
              Icons.monetization_on_rounded,
              const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: AppFont.w700,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w900,
              color: Color(0xFF221918),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: AppFont.w700,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: AppFont.w900,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.decimalPattern('id_ID');
    final trxLabel = '${item.totalPesanan} Trx';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetailBottomSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: isEven ? const Color(0xFFFFFCFA) : const Color(0xFFFFFFFF),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFF4E6E1), width: 0.8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaLayanan,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 11.8,
                        fontWeight: AppFont.w900,
                        color: Color(0xFF221918),
                        letterSpacing: -0.15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subLabel.isEmpty ? 'Layanan utama' : item.subLabel,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontSize: 9.2,
                        fontWeight: AppFont.w700,
                        color: Color(0xFFAA9A94),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      trxLabel,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.2,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF514541),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.totalQty,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF6F625D),
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Rp ${currencyFormatter.format(item.totalHarga)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10.8,
                      fontWeight: AppFont.w900,
                      color: AppPalette.primary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
