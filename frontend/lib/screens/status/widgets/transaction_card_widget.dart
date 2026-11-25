import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/queue_item_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionCardWidget extends StatelessWidget {
  final QueueItem trx;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;

  const TransactionCardWidget({
    super.key,
    required this.trx,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppPalette.primary : Colors.grey[200]!,
            width: 1.5,
          ),
          boxShadow: AppShadows.cardSoft,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio Button indikator seleksi
                if (isSelectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? AppPalette.primary : Colors.grey[300],
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // MENGGUNAKAN EXPANDED: Untuk mencegah overflow saat mode seleksi aktif
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BARIS 1: Nama Pelanggan & Badge Pembayaran
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              trx.pelangganNama,
                              style: const TextStyle(
                                fontWeight: AppFont.w700,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow
                                  .ellipsis, // Cegah overflow teks nama
                            ),
                          ),
                          const SizedBox(width: 8), // Gap minimal
                          _buildPaymentBadge(trx.statusPembayaran),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // BARIS 2: Info Tanggal & Harga
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Dibungkus Flexible agar info row tidak mendorong harga keluar layar
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  Icons.access_time,
                                  "Masuk : ${DateFormat('EEEE, dd-MM-yy', 'id').format(trx.tglMasuk)}",
                                ),
                                _buildInfoRow(
                                  Icons.event_available,
                                  "Selesai : ${DateFormat('EEEE, dd-MM-yy', 'id').format(trx.tglEstimasi)}",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(trx.total),
                            style: const TextStyle(
                              fontWeight: AppFont.w900,
                              fontSize: 16,
                              color: AppPalette.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 32, thickness: 0.5),

            // BARIS BAWAH: Invoice & Tombol Detail
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // Dibungkus Expanded agar invoice panjang tidak nabrak tombol
                  child: Text(
                    trx.invoice,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: AppFont.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Bungkus teks dan icon dalam Row agar sejajar di kanan
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
                    SizedBox(
                      width: 4,
                    ), // Kasih jarak tipis antara teks dan icon
                    Icon(
                      Icons
                          .arrow_forward_ios_rounded, // Pakai icon arrow yang rounded biar modern
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
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Penting agar tidak serakah lebar
        children: [
          Icon(icon, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Flexible(
            // Pastikan teks info juga fleksibel
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String status) {
    bool isLunas = status == "Lunas";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLunas ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLunas
              ? Colors.green.withValues(alpha: 0.3)
              : AppPalette.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isLunas ? Colors.green[700] : AppPalette.primary,
          fontSize: 10,
          fontWeight: AppFont.w700,
        ),
      ),
    );
  }
}
