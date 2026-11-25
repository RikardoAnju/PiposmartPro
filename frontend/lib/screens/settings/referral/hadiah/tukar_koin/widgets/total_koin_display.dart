import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TotalKoinDisplay extends StatelessWidget {
  final int totalKoin;

  const TotalKoinDisplay({super.key, required this.totalKoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            color: AppPalette.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Koin Didapat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Koin masuk ke outlet tujuan',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '$totalKoin koin',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w700,
              color: AppPalette.primary,
            ),
          ),
        ],
      ),
    );
  }
}
