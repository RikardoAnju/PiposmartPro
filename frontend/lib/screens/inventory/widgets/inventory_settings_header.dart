import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class InventorySettingsHeader extends StatelessWidget {
  const InventorySettingsHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 21,
                color: AppPalette.ink,
              ),
            ),
          ),
        ),
        const Text(
          'Pengaturan Inventory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: AppFont.w800,
            color: AppPalette.ink,
          ),
        ),
      ],
    ),
  );
}
