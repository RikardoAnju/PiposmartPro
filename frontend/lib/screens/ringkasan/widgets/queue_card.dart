import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/queue_item_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QueueCard extends StatelessWidget {
  final QueueItem item;
  final VoidCallback? onTap;

  const QueueCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    String formattedEstimate = DateFormat(
      'EEEE, dd-MM-yyyy',
      'id_ID',
    ).format(item.tglEstimasi);

    bool isLunas = item.statusPembayaran.toLowerCase() == 'lunas';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.pelangganNama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: AppFont.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLunas ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.statusPembayaran,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                      color: isLunas
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.login_rounded,
              "Masuk",
              DateFormat('EEEE, dd-MM-yyyy', 'id_ID').format(item.tglMasuk),
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              Icons.timer_outlined,
              "Est Selesai",
              formattedEstimate,
            ),
            const SizedBox(height: 12),
            // Divider tipis & subtle
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.id,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "Lihat Detail",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.red.shade800,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          "$label : ",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: AppFont.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
