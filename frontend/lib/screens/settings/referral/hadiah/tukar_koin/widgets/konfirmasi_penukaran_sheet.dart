import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class KonfirmasiPenukaranSheet extends StatelessWidget {
  final int nominalSaldo;
  final int totalKoin;
  final String outletName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const KonfirmasiPenukaranSheet({
    super.key,
    required this.nominalSaldo,
    required this.totalKoin,
    required this.outletName,
    required this.onConfirm,
    required this.onCancel,
  });

  static final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static Future<bool?> show(
    BuildContext context, {
    required int nominalSaldo,
    required int totalKoin,
    required String outletName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => KonfirmasiPenukaranSheet(
        nominalSaldo: nominalSaldo,
        totalKoin: totalKoin,
        outletName: outletName,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + Title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppPalette.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfirmasi Penukaran',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Tukar saldo menjadi koin laundry',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Detail card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Saldo ditukar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo yang Ditukar',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      _fmt.format(nominalSaldo),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Total koin highlight
                Column(
                  children: [
                    const Text(
                      'TOTAL KOIN DIDAPAT',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalKoin koin',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: AppFont.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
                // Outlet tujuan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outlet Tujuan',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.store_rounded,
                          size: 16,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          outletName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Warning info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppPalette.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan data sudah benar. Proses ini tidak dapat dibatalkan.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF795548)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Tukar Sekarang',
                style: TextStyle(fontSize: 15, fontWeight: AppFont.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: onCancel,
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
