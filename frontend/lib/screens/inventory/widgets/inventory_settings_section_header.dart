import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class InventorySettingsSectionHeader extends StatelessWidget {
  const InventorySettingsSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: AppFont.w800,
          color: AppPalette.ink,
        ),
      ),
      const Spacer(),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            '+ $actionLabel',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: AppFont.w700,
              color: AppPalette.primary,
            ),
          ),
        ),
    ],
  );
}
