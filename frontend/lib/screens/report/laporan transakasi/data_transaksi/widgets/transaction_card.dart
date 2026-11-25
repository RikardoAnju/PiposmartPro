import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionCard extends StatelessWidget {
  final OmsetDetail item;
  final VoidCallback? onDetail;

  const TransactionCard({super.key, required this.item, this.onDetail});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    const primaryColor = AppPalette.primary;
    final isCancelled = item.statusOrder.toLowerCase() == 'batal';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailPesananScreen(transactionId: item.id),
              ),
            );
            onDetail?.call();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Nama Pelanggan & Badges ──
                // ── Row 1: Nama Pelanggan & Total Harga ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (item.namaPelanggan.isNotEmpty &&
                                item.namaPelanggan != 'Tanpa Nama')
                            ? item.namaPelanggan
                            : 'Tanpa Nama',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currencyFormatter.format(item.totalHarga),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: AppFont.w900,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Row 2: Badges ──
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: isCancelled
                      ? const [
                          _Badge(
                            label: 'BATAL',
                            color: Color(0xFFDC2626),
                            bgColor: Color(0xFFFFE4E6),
                          ),
                        ]
                      : [
                          if (item.metodePembayaran != null &&
                              item.metodePembayaran!.isNotEmpty)
                            _Badge(
                              label: item.metodePembayaran!.toUpperCase(),
                              color: const Color(0xFF3B82F6),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                          _Badge(
                            label: item.statusPembayaran.toUpperCase(),
                            color:
                                item.statusPembayaran.toLowerCase() == 'lunas'
                                ? const Color(0xFF10B981)
                                : primaryColor,
                            bgColor:
                                item.statusPembayaran.toLowerCase() == 'lunas'
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                          ),
                          if (item.statusPembayaran.toLowerCase() ==
                                  'belum lunas' &&
                              item.dpAmount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _Badge(
                                  label: 'DP',
                                  color: Color(0xFF8B5CF6), // Purple color
                                  bgColor: Color(0xFFF3E8FF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currencyFormatter.format(item.dpAmount),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: AppFont.w700,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                        ],
                ),

                const SizedBox(height: 12),

                // ── Row 3: Info Tanggal ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _InfoRow(
                        Icons.access_time,
                        "Masuk: ${item.tanggalMasuk}",
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _InfoRow(
                        Icons.event_available,
                        "Est: ${item.tanggalSelesai}",
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24, thickness: 0.5),

                // ── Row 3: Invoice & Action ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.nomorNota,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: AppFont.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: const [
                        Text(
                          "Lihat Detail",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.grey,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: AppFont.w700,
        ),
      ),
    );
  }
}
