import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LayananTableHeader extends StatelessWidget {
  const LayananTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: const BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 7,
            child: Text(
              'LAYANAN',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: AppFont.w900,
                color: AppPalette.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'DETAIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: AppFont.w900,
                color: AppPalette.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'PENJUALAN',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: AppFont.w900,
                color: AppPalette.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
