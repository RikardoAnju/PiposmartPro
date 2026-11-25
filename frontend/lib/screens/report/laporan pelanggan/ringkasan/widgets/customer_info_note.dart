import 'package:flutter/material.dart';

class CustomerInfoNote extends StatelessWidget {
  final String message;

  const CustomerInfoNote({
    super.key,
    this.message =
        'Menampilkan seluruh pelanggan yang bertransaksi pada periode terpilih, diurutkan dari nilai transaksi terbesar hingga terkecil.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF43A047),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
