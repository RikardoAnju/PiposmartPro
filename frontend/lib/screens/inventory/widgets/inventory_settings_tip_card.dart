import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class InventorySettingsTipCard extends StatelessWidget {
  const InventorySettingsTipCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1EC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          color: AppPalette.primary,
          size: 19,
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Gunakan Sesuaikan Stok untuk memastikan jumlah barang sesuai dengan stok fisik di sistem.',
            style: TextStyle(fontSize: 11, height: 1.35, color: AppPalette.ink),
          ),
        ),
      ],
    ),
  );
}
